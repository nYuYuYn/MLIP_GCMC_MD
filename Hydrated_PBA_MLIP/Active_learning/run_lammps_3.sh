#!/bin/bash
export OMP_NUM_THREADS=1
echo "lammps MD is starting"
rm is_lammps_finished_*.txt

#data=("vac_no_Na_1_full.data" "vac_no_Na_1_full.data" "vac_no_Na_2_full.data" "vac_no_Na_2_full.data" "Fe_vac_small_4.data" "Fe_vac_small_4.data" "Fe_vac_small_4.data" "Fe_vac_small_4.data")

#data=("Fe_vac_small_1.data" "Fe_vac_small_2.data" "Fe_vac_small_4.data" "Fe_vac_small_4.data" "Fe_vac_small_4.data" "Fe_vac_small_4.data" "Fe_vac_small_4.data" "Fe_vac_small_4.data")

data=("h2o_16_300K_2.data" "h2o_16_300K_2.data" "h2o_16_300K_2.data" "h2o_16_300K_2.data" "vac_no_Na_1.data" "vac_no_Na_1.data" "vac_no_Na_2.data" "vac_no_Na_2.data")

temp=(400 400 400 400 400 400 400 400)
mu=(-6 -5.5 -5 -4.5 -4 -3.5 -4 -3)
cut_off=0.2
list=($(seq 1 1 8))  # Sequence of numbers from 1 to 8

for i in "${list[@]}"; do
    idx=$((i - 1))
    current_data="${data[$idx]}"
    current_temp="${temp[$idx]}"
    current_mu="${mu[$idx]}"
    #current_Na="${Na_stop[$idx]}"
    current_input="input_${i}.my"
    random_seed=$((RANDOM % 9999999 + 1))

    cp in_test.my "$current_input"

    # Use | as delimiter in sed to avoid issues with paths/slashes
    sed -i "4s|.*|atom_style atomic|" $current_input
    sed -i "5s|.*|variable T equal ${current_temp}|" $current_input
    sed -i "8s|.*|read_data ${current_data}|" $current_input
    sed -i "18s|.*|variable seed index ${random_seed}|" $current_input
# Check if i is odd or even
#    if (( i % 2 != 0 )); then
        # i is ODD: delete the atoms
#        sed -i "25s|.*|delete_atoms group Na|" "$current_input"
#        echo "Job $i: Type 5 atoms will be deleted."
#    else
#        # i is EVEN: comment out the deletion (keep the atoms)
#        sed -i "25s|.*|#delete_atoms group Na|" "$current_input"
#        echo "Job $i: Type 5 atoms will be kept."
#    fi
    sed -i "25s|.*|#delete_atoms group Na|" "$current_input"
    sed -i "26s|.*|pair_style mlip load_from=./MTP/curr_20_cfg_r02_65.almtp extrapolation_control=true extrapolation_control:threshold_break=8 extrapolation_control:threshold_save=1.4 extrapolation_control:save_extrapolative_to=preselected_${i}.cfg|" $current_input
    sed -i "40s|.*|dump dump all atom 200 dump.gcmc_20_r02_65_${i}.trj|" $current_input

    #################### H2O GCMC ####################
    sed -i "72s|.*|#fix halt_upper O halt 2000 v_nO > 30 error continue|" $current_input
    sed -i "74s|.*|#fix fgcmc_h2o H2O gcmc 4000 30 0 0 ${random_seed} ${current_temp} ${current_mu} 0.2 mol h2omol group H2O region system overlap_cutoff ${cut_off}|" $current_input
    sed -i "82s|.*|#unfix fgcmc_h2o|" $current_input
    #################### H2O GCMC ####################

    #################### Na GCMC style: atomic ####################
    sed -i "71s|.*|fix halt_upper Na halt 2000 v_nNa > 17 error continue|" $current_input
    sed -i "72s|.*|fix halt_lower Na halt 2000 v_nNa < 1 error continue|" $current_input
    sed -i "73s|.*|fix fgcmc_na Na gcmc 4000 20 20 5 ${random_seed} ${current_temp} ${current_mu} 0.1 full_energy region system overlap_cutoff ${cut_off}|" $current_input
    sed -i "82s|.*|unfix fgcmc_na|" $current_input
    sed -i "82s|.*|unfix halt_lower|" $current_input
    #################### Na GCMC style: atomic ####################
    
    sed -i "89s|.*|write_data MnFePBA_gcmc_${i}.data|" $current_input
    sed -i "90s|.*|write_dump all atom MnFePBA_gcmc_dump_${i}.trj|" $current_input

    job_script=$(cat <<EOF
#!/bin/bash
ulimit -s unlimited
cd \$PBS_O_WORKDIR
module purge
module load gcc/11.4.0 ompi mkl/2025.3
export LD_LIBRARY_PATH=/K/av245900/Codes/lammps_mlip3_2026_06_01/lammps/src:$LD_LIBRARY_PATH
mpirun -np 64 /W/av245900/HT-SHARE/binaries/lammps_mlip3_gcc11.4.0_ompi4.1.8_mkl2025.3 -in $current_input -log gcmc_${i}.log
echo "1" >> is_lammps_finished_${i}.txt
EOF
    )

    running_cores=$(qstat -f | awk '/Job Id:/{id=$3} /queue =/{queue=$3} /job_state = R/{running=1} /Resource_List.nodes/{if(running){split($3,a,":ppn="); nodes=a[1]; ppn=a[2]; counts[queue]+=(nodes*ppn); running=0}} END{for(q in counts) print q, counts[q]}')

    # Split the output into individual queue and core count pairs
    while read queue count; do
        # Replace dash with underscore in variable names
        queue_var=$(echo "$queue" | tr '-' '_')
        eval "$queue_var=$count"
    done <<< "$running_cores"

    empty_huge=$((2500 - huge))
    empty_large=$((2000 - large))
    empty_standard=$((1000 - csp_standard - csp_long))

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
        echo "$job_script" | qsub -N MD_h2o_${i} -S /bin/bash -q huge -l nodes=1:ppn=64,walltime=7:00:00
    fi

    if [ "$max_var" == "empty_large" ]; then
        echo "$job_script" | qsub -N MD_h2o_${i} -S /bin/bash -q large -l nodes=2:ppn=40,walltime=7:00:00
    fi

    if [ "$max_var" == "empty_standard" ]; then
        echo "$job_script" | qsub -N MD_h2o_${i} -S /bin/bash -q csp-standard -l nodes=2:ppn=32,walltime=7:00:00
    fi

    if [[ $? -ne 0 ]]; then
        echo "Job submission failed for in_${i}.my"
        cat qsub_${i}.log
    else
        echo "Job in_${i}.my submitted successfully"
    fi
    sleep 5
done

sleep 5

