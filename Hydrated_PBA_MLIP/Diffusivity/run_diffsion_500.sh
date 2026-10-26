#!/bin/bash

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

export OMP_NUM_THREADS=1
export LC_NUMERIC=C
O_ls=(4 4 4 16 16 16 32 32 32)
Na_ls=(4 16 28 4 16 28 4 16 28)
list=($(seq 2 1 3))
current_temp=500
for i in "${list[@]}"; do
    index=$((i - 1))
    current_Na="${Na_ls[$index]}"
    current_O="${O_ls[$index]}"
    mkdir -p ${current_temp}_diffusion_4
    current_dir="${current_temp}_diffusion_4"
    current_data="Na_${current_Na}_O_${current_O}.data"
    #current_data="${current_temp}_diffusion/${current_temp}K_Na_${current_Na}_O_${current_O}_final.data"
    random_seed=$((RANDOM % 9999999 + 1))
    current_input="${current_temp}_diffuse_${i}.my"
    cp in_diffuse.my $current_input
    
    echo "current temp: ${current_temp}"
    echo "input file: ${current_input}"
    echo "data file: ${current_data}"
    echo "seed ${random_seed}"
    echo "log ${current_dir}/diffusion_${i}.log"
    echo ""

    sed -i "5s|.*|variable T equal ${current_temp}|" $current_input
    sed -i "6s|.*|variable Na equal ${current_Na}|" $current_input
    sed -i "7s|.*|variable O equal ${current_O}|" $current_input
    sed -i "8s|.*|read_data  ${current_data}|" $current_input
    sed -i "17s|.*|variable seed index ${random_seed}|" $current_input
    sed -i "32s|.*|dump dump all custom 1000 ${current_dir}/dump.${current_temp}_diffuse_${i}.trj id type x y z|" $current_input
    sed -i "33s|.*|restart 50000 ${current_dir}/${current_temp}_diffusion_${i}_restart|" $current_input
    sed -i "34s|.*|log ${current_dir}/${current_temp}_diffusion_${i}.log|" $current_input
    sed -i "73s|.*|fix rdf_output all ave/time 50 20 4000 c_myRDF[*] file ${current_dir}/${current_temp}_diffusion_${i}.rdf mode vector|" $current_input
    sed -i "76s|.*|dump ONa_dump O custom 4000 ${current_dir}/${current_temp}K_ONa_coord_${current_Na}_${current_O}.txt id type c_ONacoord|" $current_input
    sed -i "77s|.*|dump NaN_dump Na custom 4000 ${current_dir}/${current_temp}K_NaN_coord_${current_Na}_${current_O}.txt id type c_NaNcoord|" $current_input
    sed -i "80s|.*|write_data ${current_dir}/${current_temp}K_Na_${current_Na}_O_${current_O}.data|" $current_input
    sed -i "81s|.*|write_dump all custom ${current_dir}/${current_temp}K_Na_${current_Na}_O_${current_O}.dump id type x y z|" $current_input
    sed -i "94s|.*|fix avg_msd_PB PB ave/time 500 10 5000 c_msd_PB[1] c_msd_PB[2] c_msd_PB[3] c_msd_PB[4] file ${current_dir}/${current_temp}K_msd_PB_${i}.dat mode scalar |" $current_input
    sed -i "95s|.*|fix avg_msd_Na Na ave/time 500 10 5000 c_msd_Na[1] c_msd_Na[2] c_msd_Na[3] c_msd_Na[4] file ${current_dir}/${current_temp}K_msd_Na_${i}.dat mode scalar |" $current_input
    sed -i "96s|.*|fix avg_msd_h2o Na ave/time 500 10 5000 c_msd_h2o[1] c_msd_h2o[2] c_msd_h2o[3] c_msd_h2o[4] file ${current_dir}/${current_temp}K_msd_h2o_${i}.dat mode scalar |" $current_input
    sed -i "104s|.*|write_data ${current_dir}/${current_temp}K_diffusion_${i}.data|" $current_input
    sed -i "104s|.*|write_dump all custom ${current_dir}/${current_temp}K_diffusion_${i}.dump id type x y z|" $current_input
    
    job_script=$(cat <<EOF
#!/bin/bash
ulimit -s unlimited
cd \$PBS_O_WORKDIR
module purge
module load icc/20 impi/20 mkl/20 || { echo "Failed to load Intel modules"; exit 1; }
module load python/maxiforge || { echo "Failed to load Anaconda module"; exit 1; }
mpirun -np 192 /W/av245900/HT-SHARE/binaries/lammps_mlip3_icc20_impi20_mkl20 -in ${current_input} 
echo "1" >>is_${current_temp}_diffuse_finished.txt
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
        echo "$job_script" | qsub -N ${current_temp}K_diff_${i} -S /bin/bash -q huge -l nodes=3:ppn=64,walltime=120:00:00
    fi

    if [ "$max_var" == "empty_large" ]; then
        echo "$job_script" | qsub -N ${current_temp}K_diff_${i} -S /bin/bash -q large -l nodes=5:ppn=40,walltime=120:00:00
    fi

    if [ "$max_var" == "empty_standard" ]; then
        echo "$job_script" | qsub -N ${current_temp}K_diff_${i} -S /bin/bash -q csp-standard -l nodes=6:ppn=32,walltime=24:00:00
    fi

    if [[ $? -ne 0 ]]; then
        echo "Job submission failed for ${current_temp}K_diff_${i}"
        cat qsub_${i}.log
    else
        echo "Job ${current_temp}K_diff_${i} submitted successfully"
    fi
    sleep 1
    #wait_for_jobs
done
