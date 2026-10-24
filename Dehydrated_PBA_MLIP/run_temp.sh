#!/bin/bash
export OMP_NUM_THREADS=1
export LC_NUMERIC=C

echo "lammps MD is starting"

num_Na=($(seq 400 400 3600))
list=($(seq 3 1 4))
for i in "${list[@]}"; do
    index=$((i - 1))
    current_Na="${num_Na[$index]}"
    mkdir -p diffusion_${current_temp}
    #current_data=diffusion_400/400_diffusion_${current_Na}.data
    current_data=${current_Na}_temp_restart
    random_seed=$((RANDOM % 9999999 + 1))
    current_input="${current_Na}_temp.my"
    cp raise_temp.my $current_input

    echo "input file: ${current_input}"
    echo "data file: ${current_data}"
    echo "seed ${random_seed}"
    echo "log ${current_Na}_temp.log"
    echo ""


    # Update `in_test.my` file
    sed -i "5s|.*|variable current_Na equal ${current_Na}|" $current_input
    sed -i "7s|.*|read_data  ${current_data}|" $current_input
    sed -i "7s|.*|read_restart  ${current_data}.*|" $current_input
    sed -i "14s|.*|variable seed index ${random_seed}|" $current_input
    sed -i "35s|.*|dump dump all custom 4000 dump.${current_Na}_temp.trj id type x y z|" $current_input
    sed -i "36s|.*|restart 50000 ${current_Na}_temp_restart|" $current_input
    sed -i "37s|.*|log ${current_Na}_temp.log|" $current_input
    sed -i '74c\    write_data Na_${current_Na}_${curTemp}K.data' $current_input
    job_script=$(cat <<EOF
#!/bin/bash
ulimit -s unlimited
cd \$PBS_O_WORKDIR
module purge
module load icc/20 impi/20 mkl/20 || { echo "Failed to load Intel modules"; exit 1; }
module load python/anaconda3 || { echo "Failed to load Anaconda module"; exit 1; }
mpirun -np 192 /W/av245900/HT-SHARE/binaries/lammps_mlip3_icc20_impi20_mkl20 -in $current_input
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

    empty_huge=$((2000 - huge))
    empty_large=$((2000 - large))
    empty_standard=$((2000 - csp_standard))

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
        echo "$job_script" | qsub -N temp_${i} -S /bin/bash -q huge -l nodes=3:ppn=64,walltime=120:00:00
    fi

    if [ "$max_var" == "empty_large" ]; then
        echo "$job_script" | qsub -N temp_${i} -S /bin/bash -q large -l nodes=5:ppn=40,walltime=120:00:00
    fi

    if [ "$max_var" == "empty_standard" ]; then
        echo "$job_script" | qsub -N temp_${i} -S /bin/bash -q csp-standard -l nodes=6:ppn=32,walltime=24:00:00
    fi

    if [[ $? -ne 0 ]]; then
        echo "Job submission failed for in_${i}.my"
        cat qsub_${i}.log
    else
        echo "Job in_${i}.my submitted successfully"
    fi
    sleep 3
done