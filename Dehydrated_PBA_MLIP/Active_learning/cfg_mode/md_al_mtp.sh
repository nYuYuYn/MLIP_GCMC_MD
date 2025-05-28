#!/bin/bash
rm -f preselected.cfg.*
rm -f preselected.cfg
rm -f selected.cfg
rm -f nbh.cfg
rm -f *.txt
rm -f *.log

for ((x=0; x<=0; x++)); do

    cp curr.almtp pot_save/
    touch preselected.cfg
    is_lammps_finished=0
    ./run_lammps.sh
    timestep_1=$(tail -n 1 "gcmc_1.log" | awk '{print $1}')
    timestep_2=$(tail -n 1 "gcmc_2.log" | awk '{print $1}')
    timestep_3=$(tail -n 1 "gcmc_3.log" | awk '{print $1}')
    timestep_4=$(tail -n 1 "gcmc_4.log" | awk '{print $1}')
    timestep_5=$(tail -n 1 "gcmc_5.log" | awk '{print $1}')
    timestep_6=$(tail -n 1 "gcmc_6.log" | awk '{print $1}')
    timestep_7=$(tail -n 1 "gcmc_7.log" | awk '{print $1}')
    timestep_8=$(tail -n 1 "gcmc_8.log" | awk '{print $1}')
    echo $timestep_1 $timestep_2 $timestep_3 $timestep_4 $timestep_5 $timestep_6 $timestep_7 $timestep_8 > timestep.txt
    cat preselected* >> preselected.cfg
    mv timestep.txt pot_save/timestep.txt
    
    while [ $is_lammps_finished -ne 1 ]
    do
        sleep 5
        if [ -f is_lammps_finished.txt ]; then
            is_lammps_finished=1
            echo $is_lammps_finished
        else
            is_lammps_finished=0
            echo $is_lammps_finished
        fi
    done
    sleep 5
    #python modify_dump.py
    n_preselected=$(grep "BEGIN" preselected.cfg | wc -l)
    is_selection_finished=0
    if [ $n_preselected -gt 0 ]; then
        echo "selection"
        ./select.sh
        while [ $is_selection_finished -ne 1 ]
        do
            sleep 5
            if [ -f is_selection_finished.txt ]; then
                is_selection_finished=1
                echo $is_selection_finished
            else
                is_selection_finished=0
                echo $is_selection_finished
            fi
        done
        sleep 5
        if [ -s selected.cfg ]; then
            echo " selected.cfg exists"
        else
            echo "selected.cfg not exist"
            exit
        fi
        rm -f preselected.cfg
        rm -f preselected*

# use MTP to compute the energy of selected structure, if the energy is larger than 200 eV, those cfg are removed and won't be computed by DFT
        mlip calculate_efs curr.almtp selected.cfg --output_filename=cal_selected.cfg
        python good.py

        cp good.cfg good_selected.cfg
        
        mlip convert good_selected.cfg POSCAR --output_format=poscar
        #rm -f selected.cfg
        n_poscar=$(grep "BEGIN" good_selected.cfg | wc -l)
        n_poscar_prev=$((${n_poscar}-1))
        if [ $n_poscar -gt 0 ]; then
            if [ $n_poscar -eq 1 ]; then
                mv POSCAR POSCAR0
            fi
            for ((i=0; i<$n_poscar; i++))
            do
                cp POSCAR"$i" VASP/
                mkdir -p VASP/"$i"
                if [ $n_poscar -eq 1 ]; then
                    mv VASP/POSCAR"$i" VASP/0/POSCAR
                elif [ $n_poscar -gt 1 ]; then
                    mv VASP/POSCAR"$i" VASP/"$i"/POSCAR
                fi
                cp VASP/POTCAR VASP/"$i"/
                cp VASP/INCAR VASP/"$i"/
                cp VASP/KPOINTS VASP/"$i"/
                cp VASP/sub_vasp.sh VASP/"$i"/
            done
        	###################################
            for ((i=0; i<$n_poscar; i++))
            do
                cd VASP/"$i"
        		sed -i "2s/.*/#PBS -N {$i}_PBC_cfg/" sub_vasp.sh
        		numbers=$(awk 'NR==6 {print $1, $2, $3, $4, $5}' POSCAR) 
                read n_C n_Mn n_Fe n_N n_Na <<< "$numbers" 
                if [ -z "$n_Na" ]; then
                        replacement="MAGMOM = ${n_C}*0 ${n_Mn}*5 ${n_Fe}*0 ${n_N}*0"
                        sed -i "23s/.*/$replacement/" INCAR
                else
                        replacement="MAGMOM = ${n_C}*0 ${n_Mn}*5 ${n_Fe}*0 ${n_N}*0 ${n_Na}*0"
                        sed -i "23s/.*/$replacement/" INCAR
                fi
    
                running_cores=$(qstat -f | awk '/Job Id:/{id=$3} /queue =/{queue=$3} /job_state = R/{running=1} /Resource_List.nodes/{if(running){split($3,a,":ppn="); nodes=a[1]; ppn=a[2]; counts[queue]+=(nodes*ppn); running=0}} END{for(q in counts) print q, counts[q]}')
                
                # Split the output into individual queue and core count pairs
                while read queue count; do
                    # Replace dash with underscore in variable names
                    queue_var=$(echo "$queue" | tr '-' '_')
                    eval "$queue_var=$count"
                done <<< "$running_cores"
                
                empty_huge=$((2000 - huge))
                empty_large=$((2000 - large))
                empty_standard=$((2000 - csp_standard))
                
                echo huge has $empty_huge available cores
                echo large has $empty_large available cores
                echo standard has $empty_standard available cores
                
                max_value=$empty_huge
                max_var="empty_huge"
                
                if (( empty_large > max_value )); then
                    max_value=$empty_large
                    max_var="empty_large"
                fi
                
                if (( empty_standard > max_value )); then
                    max_value=$empty_standard
                    max_var="empty_standard"
                fi
                
                echo submit the job from $max_var
                
                if [ "$max_var" == "empty_huge" ]; then
                    sed -i "8s/.*/NCORE = 64/" INCAR
                    sed -i "4s/.*/#PBS -q huge/" sub_vasp.sh
                    sed -i "5s/.*/#PBS -l walltime=24:00:00,nodes=1:ppn=64/" sub_vasp.sh
                    qsub sub_vasp.sh
                    echo 
                fi
                
                if [ "$max_var" == "empty_large" ]; then
                    sed -i "8s/.*/NCORE = 80/" INCAR
                    sed -i "4s/.*/#PBS -q large/" sub_vasp.sh
                    sed -i "5s/.*/#PBS -l walltime=24:00:00,nodes=2:ppn=40/" sub_vasp.sh
                    qsub sub_vasp.sh
                    echo large is as full as csp, use csp
                fi
                
                 if [ "$max_var" == "empty_standard" ]; then
                    sed -i "8s/.*/NCORE = 64/" INCAR
                    sed -i "4s/.*/#PBS -q csp-standard/" sub_vasp.sh
                    sed -i "5s/.*/#PBS -l walltime=24:00:00,nodes=2:ppn=32/" sub_vasp.sh
                    qsub sub_vasp.sh
                    echo csp is more empty, use csp
                fi
            	cd ../../
                sleep 10
            done
            sleep 90
            #./use_huge.sh
            is_vasp_finished=0
            if [ $n_poscar -gt 0 ]; then
                while [ $is_vasp_finished -ne 1 ]
                do
                    sleep 100
                    n_vasp_finished=$(grep -rH "1" VASP/*/is_vasp_finished.txt | wc -l)
                    cfg_cal=$(qstat | grep yy276937 | grep "cfg" | wc -l)
                    
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
        
            for ((i=0; i<$n_poscar; i++))
            do
                /W/av245900/HT-SHARE/binaries/mlip3_icc20_impi20_mkl20 convert VASP/"$i"/OUTCAR VASP/"$i"/calculated.cfg --input_format=outcar
            	cat VASP/"$i"/calculated.cfg >> vasp.cfg
                cat VASP/"$i"/calculated.cfg >> new_vasp.cfg
                
                number=$(cat VASP/"$i"/is_vasp_finished.txt)
                if [ "$number" -eq 1 ]; then
                    echo The POSCAR$i has been calculated. Great!
                else
                    echo The POSCAR$i is not calculated. WTF!
                fi
                    
                echo $i > vasp_cfg.txt
                rm -r VASP/"$i"/
            done
    
            python clean.py
            cat cleaned_vasp.cfg >> train.cfg
            rm cleaned_vasp.cfg new_vasp.cfg
            
            is_training_finished=0
            if [ $n_poscar -gt 0 ]; then
            
                running_cores=$(qstat -f | awk '/Job Id:/{id=$3} /queue =/{queue=$3} /job_state = R/{running=1} /Resource_List.nodes/{if(running){split($3,a,":ppn="); nodes=a[1]; ppn=a[2]; counts[queue]+=(nodes*ppn); running=0}} END{for(q in counts) print q, counts[q]}')
                
                # Split the output into individual queue and core count pairs
                while read queue count; do
                    # Replace dash with underscore in variable names
                    queue_var=$(echo "$queue" | tr '-' '_')
                    eval "$queue_var=$count"
                done <<< "$running_cores"
                
                empty_huge=$((2000 - huge))
                empty_large=$((2000 - large))
                empty_standard=$((2000 - csp_standard))
                
                echo huge has $empty_huge available cores
                echo large has $empty_large available cores
                echo standard has $empty_standard available cores
                
                max_value=$empty_huge
                max_var="empty_huge"
                
                if (( empty_large > max_value )); then
                    max_value=$empty_large
                    max_var="empty_large"
                fi
                
                if (( empty_standard > max_value )); then
                    max_value=$empty_standard
                    max_var="empty_standard"
                fi
                
                echo submit the job from $max_var
                
               if [ "$max_var" == "empty_huge" ]; then
                    sed -i "11s/.*/mpirun -np 192 /W/av245900/HT-SHARE/binaries/mlip3_icc20_impi20_mkl20 train curr.almtp train.cfg --iteration_limit=10000 --al_mode=cfg  --weight_scaling_forces=1 --weight_scaling=2  --save_to=curr.almtp /" train.sh
                    sed -i "16s/.*/echo "$job_script" | qsub -N MD_trainin -S /bin/bash -q huge -l nodes=3:ppn=64,walltime=120:00:00/" train.sh
                    ./train.sh
                fi
                
               if [ "$max_var" == "empty_large" ]; then
                    sed -i "11s/.*/mpirun -np 160 /W/av245900/HT-SHARE/binaries/mlip3_icc20_impi20_mkl20 train curr.almtp train.cfg --iteration_limit=10000 --al_mode=cfg  --weight_scaling_forces=1 --weight_scaling=2  --save_to=curr.almtp /" train.sh
                    sed -i "16s/.*/echo "$job_script" | qsub -N MD_trainin -S /bin/bash -q huge -l nodes=4:ppn=40,walltime=120:00:00/" train.sh
                    ./train.sh
                fi
                
               if [ "$max_var" == "empty_standard" ]; then
                    sed -i "11s/.*/mpirun -np 160 /W/av245900/HT-SHARE/binaries/mlip3_icc20_impi20_mkl20 train curr.almtp train.cfg --iteration_limit=10000 --al_mode=cfg  --weight_scaling_forces=1 --weight_scaling=2  --save_to=curr.almtp /" train.sh
                    sed -i "16s/.*/echo "$job_script" | qsub -N MD_trainin -S /bin/bash -q csp-standard -l nodes=5:ppn=32,walltime=120:00:00/" train.sh
                    ./train.sh
                fi
            fi
            
            while [ $is_training_finished -ne 1 ]
            do
                sleep 5
                if [ -f is_training_finished.txt ]; then
                    is_training_finished=1
                    echo $is_training_finished
                else
                    is_training_finished=0
                    echo $is_training_finished
                fi
            done
            
            sleep 5
            rm *.txt
            #rm POSCAR*
            rm -f nbh_36.cfg
            rm -f MTP_nbh_* 
        elif [ $n_poscar -eq 0 ]; then
            exit
        fi
            
    elif [ $n_preselected -eq 0 ]; then
        exit
    fi
done