#!/bin/bash
export OMP_NUM_THREADS=1
export LC_NUMERIC=C

echo "lammps MD is starting"

mu=($(seq -2.15 0.1 -2.05))
list=($(seq 1 1 1))
    replication="1 1 1"
for i in "${list[@]}"; do
    index=$((i - 1))
    current_temp=1100
    current_mu="${mu[$index]}"
    current_data=${current_temp}/${current_temp}_gcmc_8.data
    current_input=$current_temp/phase_${i}.my
    current_python=$current_temp/equilibrium_check_${i}.py
    random_seed=$((RANDOM % 9999999 + 1))

    cp phase.my $current_input
    cp equilibrium_check.py $current_python

    echo "current data: ${current_data}"
    echo "current temp: ${current_temp}"
    echo "input file: ${current_input}"
    echo "Python file: ${current_python}"
    echo "mu: ${current_mu}"
    echo "seed ${random_seed}"
    echo ""

    # Update `in_test.my` file
    sed -i "5s|.*|variable T equal ${current_temp}|" $current_input
    sed -i "8s|.*|read_data  ${current_data}|" $current_input
    sed -i "9s|.*|replicate ${replication}|" $current_input
    sed -i "15s|.*|variable seed index ${random_seed}|" $current_input
    sed -i "36s|.*|dump dump all custom 2000 dump.phase_${i}.trj id type x y z|" $current_input
    sed -i "37s|.*|restart 50000 ${current_temp}/${current_temp}_restart_phase_${i}|" $current_input
    sed -i "50s|.*|variable mu equal ${current_mu}|" $current_input
    sed -i "51s|.*|variable i equal ${i}|" $current_input  
    sed -i '72c\    log ${current_temp}/mu_${i}_${index}.log' $current_input
    sed -i '81c\    fix fgcmc Na gcmc 4000 100 500 5 65869 ${current_temp} ${mu} 0.1 full_energy region system' $current_input
    sed -i "89s|.*|    fix eqcheck all python/invoke 10000 ${current_python} check_equilibrium|" $current_input
    sed -i "102s|.*|    write_data mu_${i}_${current_temp}K.data|" $current_input
    job_script=$(cat <<EOF
#!/bin/bash
ulimit -s unlimited
cd \$PBS_O_WORKDIR
module purge
module load icc/20 impi/20 mkl/20 || { echo "Failed to load Intel modules"; exit 1; }
module load python/anaconda3 || { echo "Failed to load Anaconda module"; exit 1; }
mpirun -np 192 /W/av245900/HT-SHARE/binaries/lammps_mlip3_icc20_impi20_mkl20 -in $current_input #-log ${current_temp}/free_${i}.log
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
        echo "$job_script" | qsub -N mu_${i}_phase -S /bin/bash -q huge -l nodes=3:ppn=64,walltime=120:00:00
    fi

    if [ "$max_var" == "empty_large" ]; then
        echo "$job_script" | qsub -N mu_${i}_phase -S /bin/bash -q large -l nodes=5:ppn=40,walltime=120:00:00
    fi

    if [ "$max_var" == "empty_standard" ]; then
        echo "$job_script" | qsub -N mu_${i}_phase -S /bin/bash -q csp-standard -l nodes=6:ppn=32,walltime=24:00:00
    fi

    if [[ $? -ne 0 ]]; then
        echo "Job submission failed for in_${i}.my"
        cat qsub_${i}.log
    else
        echo "Job in_${i}.my submitted successfully"
    fi
    sleep 3
done