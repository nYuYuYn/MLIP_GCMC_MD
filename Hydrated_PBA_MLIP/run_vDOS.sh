#!/bin/bash

rm -f in_diffuse_*.txt

export OMP_NUM_THREADS=1
export LC_NUMERIC=C

wait_for_jobs() {
    echo "Waiting for jobs to complete..."
    is_training_finished=0
    while [ $is_training_finished -ne 1 ]; do
        sleep 10  # Check every 10 seconds
        cfg_cal=$(qstat | grep yy276937 | grep "_vDOS_" | wc -l)
        
        if [ "$cfg_cal" -gt 2 ]; then
            echo "$(date) - There are $cfg_cal jobs still running"
        else
            echo "$(date) - Time to run more simulation!!!"
            is_training_finished=1
        fi
    done
    sleep 3
}

data=("MnFePBA_300K.data" "h2o_16_300K_2.data")
export OMP_NUM_THREADS=1
export LC_NUMERIC=C

list=($(seq 1 1 2))
current_temp=300

for i in "${list[@]}"; do
    index=$((i - 1))
    mkdir -p ${current_temp}_vDOS
    current_dir="${current_temp}_vDOS"
    current_data="${data[$index]}"
    #current_data="${current_temp}_diffusion_8/${current_temp}K_diffusion_${i}.data"
    random_seed=$((RANDOM % 9999999 + 1))
    current_input="${current_temp}_vDOS_${i}.my"
    cp vDOS.my $current_input
    
    echo "current temp: ${current_temp}"
    echo "input file: ${current_input}"
    echo "data file: ${current_data}"
    echo "seed ${random_seed}"
    echo "log ${current_dir}/vDOS_${i}.log"
    echo ""
    
    sed -i "5s|.*|variable T equal ${current_temp}|" $current_input
    #sed -i "8s|.*|read_restart  ${current_data}|" $current_input
    sed -i "8s|.*|read_data  ${current_data}|" $current_input
    sed -i "26s|.*|pair_style mlip load_from=./MTP/curr_lv16.almtp|" $current_input
    sed -i "62s|.*|dump dump all custom 5 ${current_dir}/dump.${current_temp}_vDOS_${i}.trj id type x y z|" $current_input
    sed -i "31s|.*|log ${current_dir}/${current_temp}_vDOS_${i}.log|" $current_input
    sed -i "57s|.*|write_data ${current_dir}/${current_temp}_vDOS_${i}.data|" $current_input
    sed -i "58s|.*|write_dump all atom ${current_dir}/${current_temp}_vDOS_dump_${i}.trj|" $current_input
    
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
    empty_standard=$((1500 - csp_standard - csp_long))

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
        echo "$job_script" | qsub -N ${current_temp}_vDOS_${i} -S /bin/bash -q huge -l nodes=3:ppn=64,walltime=168:00:00
    fi

    if [ "$max_var" == "empty_large" ]; then
        echo "$job_script" | qsub -N ${current_temp}_vDOS_${i} -S /bin/bash -q large -l nodes=5:ppn=40,walltime=120:00:00
    fi

    if [ "$max_var" == "empty_standard" ]; then
        echo "$job_script" | qsub -N ${current_temp}_vDOS_${i} -S /bin/bash -q csp-standard -l nodes=6:ppn=32,walltime=24:00:00
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
