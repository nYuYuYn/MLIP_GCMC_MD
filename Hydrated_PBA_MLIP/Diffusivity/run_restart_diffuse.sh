#!/bin/bash
module load gcc/11.4.0 ompi mkl/2025.3
export LD_LIBRARY_PATH=/K/av245900/Codes/lammps_mlip3_2026_06_01/lammps/src:$LD_LIBRARY_PATH
rm -f in_diffuse_*.txt

export OMP_NUM_THREADS=1
export LC_NUMERIC=C

wait_for_jobs() {
    echo "Waiting for jobs to complete..."
    is_training_finished=0
    while [ $is_training_finished -ne 1 ]; do
        sleep 10  # Check every 10 seconds
        cfg_cal=$(qstat | grep yy276937 | grep "_diff_" | wc -l)
        
        if [ "$cfg_cal" -gt 10 ]; then
            echo "$(date) - There are $cfg_cal jobs still running"
        else
            echo "$(date) - Time to run more simulation!!!"
            is_training_finished=1
        fi
    done
    sleep 3
}

#wait_for_jobs

export OMP_NUM_THREADS=1
export LC_NUMERIC=C
list=(9) # 6 9)
current_temp=400
for i in "${list[@]}"; do
    index=$((i - 1))
    mkdir -p ${current_temp}_diffusion_20_r02_65
    current_dir="${current_temp}_diffusion_20_r02_65"
    current_data="${current_temp}_diffusion_20_r02_65/${current_temp}_diffusion_${i}_restart.*"
    #current_data="${current_temp}_diffusion_20_short/${current_temp}_diffusion_${i}_restart.*"
    random_seed=$((RANDOM % 9999999 + 1))
    current_input="${current_temp}_restart_diffuse_${i}.my"
    cp restart_diffuse.my $current_input
    
    echo "current temp: ${current_temp}"
    echo "input file: ${current_input}"
    echo "data file: ${current_data}"
    echo "seed ${random_seed}"
    echo "log ${current_dir}/diffusion_${i}.log"
    echo ""
    
    sed -i "5s|.*|variable T equal ${current_temp}|" $current_input
    sed -i "8s|.*|read_restart  ${current_data}|" $current_input
    #sed -i "8s|.*|read_data  ${current_data}|" $current_input
    sed -i "16s|.*|pair_style mlip load_from=curr.almtp|" $current_input
    sed -i "21s|.*|restart 50000 ${current_dir}/${current_temp}_diffusion_${i}_restart|" $current_input
    sed -i "22s|.*|#log ${current_dir}/${current_temp}_diffusion_${i}.log|" $current_input
    sed -i "53s|.*|#fix avg_msd_PB PB ave/time 500 10 5000 c_msd_PB[1] c_msd_PB[2] c_msd_PB[3] c_msd_PB[4] file ${current_dir}/${current_temp}K_msd_PB_${i}.dat mode scalar |" $current_input
    sed -i "54s|.*|#fix avg_msd_Na Na ave/time 500 10 5000 c_msd_Na[1] c_msd_Na[2] c_msd_Na[3] c_msd_Na[4] file ${current_dir}/${current_temp}K_msd_Na_${i}.dat mode scalar |" $current_input
    sed -i "55s|.*|#fix avg_msd_h2o Na ave/time 500 10 5000 c_msd_h2o[1] c_msd_h2o[2] c_msd_h2o[3] c_msd_h2o[4] file ${current_dir}/${current_temp}K_msd_h2o_${i}.dat mode scalar |" $current_input
    sed -i "60s|.*|run 10000|" $current_input
    sed -i "61s|.*|write_data ${current_dir}/${current_temp}K_${i}.data|" $current_input
    sed -i "62s|.*|dump dump all custom 5 ${current_dir}/dump.${current_temp}_diffuse_${i}_short.trj id type x y z|" $current_input
    sed -i "63s|.*|run 10000|" $current_input
    
    job_script=$(cat <<EOF
#!/bin/bash
ulimit -s unlimited
cd \$PBS_O_WORKDIR
module purge
module load gcc/11.4.0 ompi mkl/2025.3
export LD_LIBRARY_PATH=/K/av245900/Codes/lammps_mlip3_2026_06_01/lammps/src:$LD_LIBRARY_PATH
mpirun -np 320 /W/av245900/HT-SHARE/binaries/lammps_mlip3_gcc11.4.0_ompi4.1.8_mkl2025.3 -in ${current_input} -log  ${current_dir}/${current_temp}_diffusion_${i}_short.log
EOF
    )

    running_cores=$(qstat -f | awk '/Job Id:/{id=$3} /queue =/{queue=$3} /job_state = R/{running=1} /Resource_List.nodes/{if(running){split($3,a,":ppn="); nodes=a[1]; ppn=a[2]; counts[queue]+=(nodes*ppn); running=0}} END{for(q in counts) print q, counts[q]}')

    # Split the output into individual queue and core count pairs
    while read queue count; do
        # Replace dash with underscore in variable names
        queue_var=$(echo "$queue" | tr '-' '_')
        eval "$queue_var=$count"
    done <<< "$running_cores"

    empty_huge=$((2000 - huge))
    empty_large=$((2000 - large))
    empty_standard=$((200 - csp_standard - csp_long))

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
        echo "$job_script" | qsub -N ${current_temp}K_diff_${i} -S /bin/bash -q huge -l nodes=5:ppn=64,walltime=168:00:00
    fi

    if [ "$max_var" == "empty_large" ]; then
        echo "$job_script" | qsub -N ${current_temp}K_diff_${i} -S /bin/bash -q large -l nodes=8:ppn=40,walltime=120:00:00
    fi

    if [ "$max_var" == "empty_standard" ]; then
        echo "$job_script" | qsub -N ${current_temp}K_diff_${i} -S /bin/bash -q csp-standard -l nodes=10:ppn=32,walltime=24:00:00
    fi

    if [[ $? -ne 0 ]]; then
        echo "Job submission failed for ${current_temp}K_diff_${i}"
        cat qsub_${i}.log
    else
        echo "Job ${current_temp}K_diff_${i} submitted successfully"
    fi
    sleep 1
    wait_for_jobs
done
