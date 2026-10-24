#!/bin/bash

rm -f in_diffuse_*.txt

export OMP_NUM_THREADS=1
export LC_NUMERIC=C

num_Na=($(seq 400 800 3600))
list=($(seq 1 4 5))
current_temp=700
for i in "${list[@]}"; do
    index=$((i - 1))
    current_Na="${num_Na[$index]}"
    mkdir -p diffusion_${current_temp}
    current_data=diffusion_400/400_diffusion_${current_Na}.data
    #current_data=Na_${current_Na}_${current_temp}K.data
    random_seed=$((RANDOM % 9999999 + 1))
    current_input="${current_temp}_diffuse_${i}.my"
    cp in_diffuse.my $current_input
    
    echo "Processing index $i with MTP file: $current_mtp"
    echo "current temp: ${current_temp}"
    echo "input file: ${current_input}"
    echo "data file: ${current_data}"
    echo "seed ${random_seed}"
    echo "log diffusion_${current_temp}/${current_temp}_diffusion_${current_Na}.log"
    echo ""

    sed -i "5s|.*|variable T equal ${current_temp}|" $current_input
    sed -i "8s|.*|read_data  ${current_data}|" $current_input
    sed -i "15s|.*|variable seed index ${random_seed}|" $current_input
    sed -i "36s|.*|dump dump all custom 4000 diffusion_${current_temp}/dump.${current_temp}_diffuse_${current_Na}.trj id type x y z|" $current_input
    sed -i "37s|.*|restart 50000 diffusion_${current_temp}/${current_temp}_diffusion_${current_Na}_restart|" $current_input
    sed -i "38s|.*|log diffusion_${current_temp}/${current_temp}_diffusion_${current_Na}.log|" $current_input
    sed -i "64s|.*|fix avg_msd_PB PB ave/time 500 10 5000 c_msd_PB[1] c_msd_PB[2] c_msd_PB[3] c_msd_PB[4] file diffusion_${current_temp}/${current_temp}K_msd_PB_${current_Na}.dat mode scalar |" $current_input
    sed -i "65s|.*|fix avg_msd_Na Na ave/time 500 10 5000 c_msd_Na[1] c_msd_Na[2] c_msd_Na[3] c_msd_Na[4] file diffusion_${current_temp}/${current_temp}K_msd_Na_${current_Na}.dat mode scalar |" $current_input
    sed -i "72s|.*|write_data diffusion_${current_temp}/${current_temp}K_diffusion_${current_Na}.data|" $current_input
    
    job_script=$(cat <<EOF
#!/bin/bash
ulimit -s unlimited
cd \$PBS_O_WORKDIR
module purge
module load icc/20 impi/20 mkl/20 || { echo "Failed to load Intel modules"; exit 1; }
module load python/anaconda3 || { echo "Failed to load Anaconda module"; exit 1; }
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
    empty_standard=$((1000 - csp_standard))

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
    sleep 5
done
