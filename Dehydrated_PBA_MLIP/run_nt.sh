#!/bin/bash
export OMP_NUM_THREADS=1
export LC_NUMERIC=C

current_temp=1100
current_data=full_Na_big_${current_temp}K.data
Nt=($(seq 400 400 4000))
current_fi=0.001
list=($(seq 1 1 10))
for i in "${list[@]}"; do
    current_data=No_Na_big_${current_temp}K.data
    index=$((i - 1))
    current_Nt="${Nt[$index]}"
    #current_data=bias_${current_temp}/${current_temp}_restart_phase_${i}
    current_mu=-3
    random_seed=$((RANDOM % 9999999 + 1))
    current_input=bias_${i}.my
    cp bias.my $current_input
    
    echo "Processing index $i with MTP file: $current_mtp"
    echo "current temp: ${current_temp}"
    echo "input file: ${current_input}"
    echo "data file: ${current_data}"
    echo "mu: ${current_mu}"
    echo "fi: ${current_fi}"
    echo "target Na: ${current_Nt}" 
    echo "seed ${random_seed}"
    echo "log bias_${current_temp}/bias_${i}.log"
    echo ""

    # Update `in_test.my` file
    sed -i "5s|.*|variable T equal ${current_temp}|" $current_input
    sed -i "8s|.*|read_data ${current_data}|" $current_input
    #sed -i "8s|.*|read_restart ${current_data}.500000|" $current_input
    sed -i "15s|.*|variable seed index ${random_seed}|" $current_input
    sed -i "24s|.*|pair_style mlip load_from=curr.almtp|" $current_input
    sed -i "35s|.*|variable k equal ${current_fi}|" $current_input
    sed -i "36s|.*|variable nNa_center equal ${current_Nt}|" $current_input
    sed -i "45s|.*|log bias_${current_temp}/bias_${i}.log append|" $current_input
    sed -i "47s|.*|dump dump all custom 4000 Nt_${current_temp}/dump.bias_${i}.trj id type x y z v_U|" $current_input
    sed -i "48s|.*|restart 50000 bias_${current_temp}/${current_temp}_restart_phase_${i}|" $current_input
    sed -i "89s|.*|fix fgcmc Na gcmc 4000 4000 4000 5 ${random_seed} ${current_temp} $(printf "%.4f" ${current_mu}) 0.1 full_energy region system|" $current_input
    sed -i "104s|.*|write_data bias_${current_temp}/${current_temp}_bias_${i}.data|" $current_input
    sed -i "105s|.*|write_dump all atom bias_${current_temp}/${current_temp}_bias_dump_${i}.trj|" $current_input
    job_script=$(cat <<EOF
#!/bin/bash
ulimit -s unlimited
cd \$PBS_O_WORKDIR
module purge
module load icc/20 impi/20 mkl/20 || { echo "Failed to load Intel modules"; exit 1; }
module load python/anaconda3 || { echo "Failed to load Anaconda module"; exit 1; }
mpirun -np 192 /W/av245900/HT-SHARE/binaries/lammps_mlip3_icc20_impi20_mkl20 -in $current_input -log bias_${current_temp}/bias_${i}.log
echo "1" >> is_lammps_finished_${i}.txt
EOF
    )
##### -log bias_${current_temp}/bias_${i}.log
    running_cores=$(qstat -f | awk '/Job Id:/{id=$3} /queue =/{queue=$3} /job_state = R/{running=1} /Resource_List.nodes/{if(running){split($3,a,":ppn="); nodes=a[1]; ppn=a[2]; counts[queue]+=(nodes*ppn); running=0}} END{for(q in counts) print q, counts[q]}')

    # Split the output into individual queue and core count pairs
    while read queue count; do
        # Replace dash with underscore in variable names
        queue_var=$(echo "$queue" | tr '-' '_')
        eval "$queue_var=$count"
    done <<< "$running_cores"

    empty_huge=$((2000 - huge))
    empty_large=$((1000 - large))
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
        echo "$job_script" | qsub -N MD_bias_${i} -S /bin/bash -q huge -l nodes=3:ppn=64,walltime=120:00:00
    fi

    if [ "$max_var" == "empty_large" ]; then
        echo "$job_script" | qsub -N MD_bias_${i} -S /bin/bash -q large -l nodes=5:ppn=40,walltime=120:00:00
    fi

    if [ "$max_var" == "empty_standard" ]; then
        echo "$job_script" | qsub -N MD_bias_${i} -S /bin/bash -q csp-standard -l nodes=6:ppn=32,walltime=24:00:00
    fi

    if [[ $? -ne 0 ]]; then
        echo "Job submission failed for in_${i}.my"
        cat qsub_${i}.log
    else
        echo "Job in_${i}.my submitted successfully"
    fi
    sleep 3
done
