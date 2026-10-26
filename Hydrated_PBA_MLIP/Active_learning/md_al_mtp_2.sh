#!/bin/bash
rm -f preselected.cfg.*
rm -f preselected.cfg
rm -f selected.cfg
rm -f nbh.cfg
rm -f *.txt
rm -f *.log

export OMP_NUM_THREADS=1
export LC_NUMERIC=C
module load gcc/11.4.0 ompi mkl/2025.3
export LD_LIBRARY_PATH=/K/av245900/Codes/lammps_mlip3_2026_06_01/lammps/src:$LD_LIBRARY_PATH
# Helper: query running cores per queue, with safe defaults for empty queues
get_queue_cores() {
    local running_cores
    running_cores=$(qstat -f | awk '
        /Job Id:/       { id=$3 }
        /queue =/       { queue=$3 }
        /job_state = R/ { running=1 }
        /Resource_List.nodes/ {
            if (running) {
                split($3, a, ":ppn=")
                nodes=a[1]; ppn=a[2]
                counts[queue]+=(nodes*ppn)
                running=0
            }
        }
        END { for (q in counts) print q, counts[q] }
    ')

    # Reset all queue vars to 0 before parsing (avoids stale values between calls)
    huge=0; large=0; csp_standard=0; csp_long=0

    while read -r queue count; do
        queue_var=$(echo "$queue" | tr '-' '_')
        eval "${queue_var}=${count}"
    done <<< "$running_cores"
}

# Helper: pick queue with most free cores and set $best_queue
pick_best_queue() {
    local cap_huge=${1:-2000}
    local cap_large=${2:-2000}
    local cap_standard=${3:-2000}

    get_queue_cores

    local empty_huge=$(( cap_huge     - huge ))
    local empty_large=$(( cap_large   - large ))
    local empty_standard=$(( cap_standard - csp_standard - csp_long ))

    echo "  huge     : $empty_huge available cores"
    echo "  large    : $empty_large available cores"
    echo "  standard : $empty_standard available cores"

    best_queue="empty_huge"
    local max_value=$empty_huge

    if (( empty_large > max_value )); then
        max_value=$empty_large
        best_queue="empty_large"
    fi
    if (( empty_standard > max_value )); then
        best_queue="empty_standard"
    fi

    echo "  -> Submitting to: $best_queue"
}

for ((x=0; x<=0; x++)); do

    cp curr.almtp pot_save/
    touch preselected.cfg

    # ------------------------------------------------------------------ LAMMPS
    #./run_lammps_3.sh

    qsub run_lammps_2.sh

    is_lammps_finished=0
    while [ $is_lammps_finished -ne 1 ]; do
        sleep 5
        finished_jobs=$(ls is_lammps_finished_*.txt 2>/dev/null | wc -l)
        if [ "$finished_jobs" -eq 8 ]; then
            echo "All 8 LAMMPS jobs have finished successfully."
            is_lammps_finished=1
        else
            MD_cal=$(qstat 2>/dev/null | grep yy276937 | grep "MD_h2o" | wc -l)
            echo "Waiting for LAMMPS... $finished_jobs/8 completed. ($MD_cal jobs currently in queue)"
        fi
    done

    echo "LAMMPS MD completed"
    #echo "1" >> is_lammps_finished.txt

    # Collect timesteps from all logs
    timesteps=()
    for j in $(seq 1 8); do
        timesteps+=( "$(tail -n 1 "gcmc_${j}.log" | awk '{print $1}')" )
    done
    echo "${timesteps[@]}" > timestep.txt

    cat preselected_*.cfg* >> preselected.cfg 2>/dev/null || true
    mv timestep.txt pot_save/timestep.txt

#python3 << 'EOF'
#with open("preselected.cfg", "r") as f:
#    content = f.read()
#
#blocks = content.split("BEGIN_CFG")
#complete = [b for b in blocks if "END_CFG" in b]
#
#with open("preselected_clean.cfg", "w") as f:
#    f.write("BEGIN_CFG".join(complete))#
#
#print(f"Kept {len(complete)} complete blocks out of {len(blocks)-1} total")
#EOF

# Bug 2 fix: replace the dirty file with the cleaned one
#    mv preselected_clean.cfg preselected.cfg

    # --------------------------------------------------------------- SELECTION
    n_preselected=$(grep -c "BEGIN_CFG" preselected.cfg 2>/dev/null || echo 0)

    if [ "$n_preselected" -eq 0 ]; then
        echo "No preselected structures. Exiting."
        exit 0
    fi

    echo "Preselected $n_preselected structures — running selection..."
    ./select.sh || { echo "ERROR: select.sh failed. Exiting."; exit 1; }

    while [ ! -f is_selection_finished.txt ]; do
        sleep 5
        echo "Waiting for selection..."
    done
    sleep 5

    if [ ! -s selected.cfg ]; then
        echo "WARNING: selected.cfg is empty. Nothing to do for this iteration."
        exit 1
    fi

    rm -f preselected.cfg preselected_*.cfg*

    # ---------------------------------------------------- CONVERT TO POSCAR(S)
    python radius_cutoff.py #only select structure with min_distance > 0.2 A
    mlip convert filtered_selected.cfg POSCAR --output_format=poscar
    n_poscar=$(grep -c "BEGIN_CFG" filtered_selected.cfg 2>/dev/null || echo 0)

    if [ "$n_poscar" -eq 0 ]; then
        echo "No structures selected for DFT. Exiting."
        exit 0
    fi

    # mlip names output POSCAR when n=1, POSCAR0..N-1 when n>1
    if [ "$n_poscar" -eq 1 ]; then
        mv POSCAR POSCAR0
    fi

    # Stage VASP input files
    for ((i=0; i<n_poscar; i++)); do
        mkdir -p VASP/"$i"
        cp POSCAR"$i" VASP/"$i"/POSCAR
        #cp VASP/POTCAR  VASP/"$i"/
        cp VASP/INCAR   VASP/"$i"/
        cp VASP/KPOINTS VASP/"$i"/
        cp VASP/sub_vasp.sh VASP/"$i"/
    done

    # ---------------------------------------------------------------- VASP SUBMIT
    for ((i=0; i<n_poscar; i++)); do
        cd VASP/"$i"

        # Fix job name (was erroneously {$i} with literal braces)
        sed -i "2s/.*/#PBS -N ${i}_h2o/" sub_vasp.sh

        # Build MAGMOM line from POSCAR element counts (line 6)
        numbers=$(awk 'NR==6 {print $1,$2,$3,$4,$5,$6,$7}' POSCAR)
        field_count=$(echo "$numbers" | wc -w)

        case "$field_count" in
            7) read -r n_C n_Mn n_Fe n_N n_Na n_O n_H <<< "$numbers"
                if [ "$n_Na" -eq 0 ]; then
                       # Na present in elements but count is 0 → treat as no-Na
                       awk 'NR==6 {$5=$6; $6=$7; $7=""; print; next} {print}' POSCAR > POSCAR.tmp && mv POSCAR.tmp POSCAR
                       replacement="MAGMOM = ${n_C}*0.0 ${n_Mn}*5.0 ${n_Fe}*0.0 ${n_N}*0.0 ${n_O}*0.0 ${n_H}*0.0"
                       cp ./../../POTCAR_no_Na POTCAR
                   else
                       replacement="MAGMOM = ${n_C}*0.0 ${n_Mn}*5.0 ${n_Fe}*0.0 ${n_N}*0.0 ${n_Na}*0.0 ${n_O}*0.0 ${n_H}*0.0"
                       cp ./../../POTCAR_all POTCAR
                   fi ;;

        
            6) read -r n_C n_Mn n_Fe n_N n_O n_H <<< "$numbers"
               replacement="MAGMOM = ${n_C}*0.0 ${n_Mn}*5.0 ${n_Fe}*0.0 ${n_N}*0.0 ${n_O}*0.0 ${n_H}*0.0"
               cp ./../../POTCAR_no_Na POTCAR ;;
        
            5) read -r n_C n_Mn n_Fe n_N n_Na <<< "$numbers"
               replacement="MAGMOM = ${n_C}*0.0 ${n_Mn}*5.0 ${n_Fe}*0.0 ${n_N}*0.0 ${n_Na}*0.0"
               cp ./../../POTCAR_all POTCAR ;;
        
            *) echo "ERROR: Unexpected field count ($field_count) in POSCAR line 6 for VASP/$i — skipping."
               cd ../../
               continue ;;
        esac
        
        sed -i "23s/.*/$replacement/" INCAR

        pick_best_queue 2200 2000 1500

        case "$best_queue" in
            empty_huge)
                sed -i "8s|.*|NCORE = 64|"  INCAR
                sed -i "4s|.*|#PBS -q huge|" sub_vasp.sh
                sed -i "5s|.*|#PBS -l walltime=24:00:00,nodes=1:ppn=64|" sub_vasp.sh
                qsub sub_vasp.sh ;;
            empty_large)
                sed -i "8s|.*|NCORE = 80|"  INCAR
                sed -i "4s|.*|#PBS -q large|" sub_vasp.sh
                sed -i "5s|.*|#PBS -l walltime=24:00:00,nodes=2:ppn=40|" sub_vasp.sh
                qsub sub_vasp.sh ;;
            empty_standard)
                sed -i "8s|.*|NCORE = 64|"  INCAR
                sed -i "4s|.*|#PBS -q csp-standard|" sub_vasp.sh
                sed -i "5s|.*|#PBS -l walltime=24:00:00,nodes=2:ppn=32|" sub_vasp.sh
                qsub sub_vasp.sh ;;
        esac

        cd ../../
        sleep 10
    done

    sleep 90

    # ---------------------------------------------------------- WAIT FOR VASP
    is_vasp_finished=0
    if [ $n_poscar -gt 0 ]; then
        while [ $is_vasp_finished -ne 1 ]
        do
            sleep 100
            n_vasp_finished=$(grep -rH "1" VASP/*/is_vasp_finished.txt | wc -l)
            cfg_cal=$(qstat | grep yy276937 | grep "h2o" | wc -l)
            
            if [ "$cfg_cal" -gt 0 ]; then
                echo "There are $cfg_cal jobs still running"
                is_vasp_finished=0
                echo $is_vasp_finished
            else
                echo All jobs are finished
                is_vasp_finished=1
                echo $is_vasp_finished
            fi
        done
    fi
    sleep 5
    # ----------------------------------------------------- COLLECT VASP OUTPUT
    for ((i=0; i<n_poscar; i++)); do
        /W/av245900/HT-SHARE/binaries/mlip3_icc20_impi20_mkl20 convert VASP/"$i"/OUTCAR VASP/"$i"/calculated.cfg --input_format=outcar
    
        numbers=$(awk 'NR==6 {print $1,$2,$3,$4,$5,$6,$7}' VASP/"$i"/POSCAR)
        field_count=$(echo "$numbers" | wc -w)
    
        if [ "$field_count" -eq 6 ]; then
            python remap.py VASP/"$i"/calculated.cfg
        fi
    
        cat VASP/"$i"/calculated.cfg >> vasp.cfg
        cat VASP/"$i"/calculated.cfg >> new_vasp.cfg
    
        number=$(cat VASP/"$i"/is_vasp_finished.txt)
        if [ "$number" -eq 1 ]; then
            echo "POSCAR$i calculated successfully."
        else
            echo "WARNING: POSCAR$i flagged as not properly finished!"
        fi
    
        echo "$i" > vasp_cfg.txt
        rm -rf VASP/"$i"/
    done

    python clean.py
    cat cleaned_vasp.cfg >> train.cfg
    rm -f cleaned_vasp.cfg new_vasp.cfg

    # ---------------------------------------------------------------- TRAINING
    ./train.sh

    is_training_finished=0
    while [ $is_training_finished -ne 1 ]; do
        sleep 60
        train_cal=$(qstat 2>/dev/null | grep yy276937 | grep "MD_trainin" | wc -l)
        if [ "$train_cal" -ne 0 ]; then
            echo "$(date) - Training running ($train_cal jobs in queue)..."
        else
            # Double-check with the sentinel file written by train.sh
            if [ -f is_training_finished.txt ]; then
                echo "$(date) - Training complete!"
                is_training_finished=1
            else
                echo "$(date) - qstat shows no training jobs but sentinel file absent — waiting..."
            fi
        fi
    done
    sleep 5

    # ----------------------------------------------------------------- CLEANUP
    rm -f *.txt
    rm -f nbh_36.cfg MTP_nbh_*

done