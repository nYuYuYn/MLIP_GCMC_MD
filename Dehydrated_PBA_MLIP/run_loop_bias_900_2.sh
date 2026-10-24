#!/bin/bash
export OMP_NUM_THREADS=1
export LC_NUMERIC=C

current_fi=0.002
current_mu=-3
Nt_0=150
current_temp=900
last_N=20
next_N=21
dir=2
trial=1

list=(${dir})
for i in "${list[@]}"; do
    mkdir -p Nt_${current_temp}/${i}
    current_data=Nt_900/2/900loop_bias_20.data
    #Nt_${current_temp}/${i}/${current_temp}loop_bias_${last_N}.data
    #1100_bias_105.data
    #Nt_${current_temp}/${i}/${current_temp}loop_bias_${last_N}.data
    #Nt_${current_temp}/${i}/${current_temp}_restart.20000
    #full_Na_big_${current_temp}K.data
    #1100_bias_105.data
    #diffusion_${current_temp}/${current_temp}_restart 

    random_seed=$((RANDOM % 9999999 + 1))
    current_input=${current_temp}_loop_bias_${dir}.my
    cp loop_bias.my $current_input
    
    echo "Processing index $i with MTP file"
    echo "current temp: ${current_temp}"
    echo "input file: ${current_input}"
    echo "data file: ${current_data}"
    echo "mu: ${current_mu}"
    echo "fi: ${current_fi}"
    echo "seed ${random_seed}"
    echo "log Nt_${current_temp}/${i}/loop_bias_${i}.log"
    echo ""

    # Update `in_test.my` file
    sed -i "5s|.*|variable T equal ${current_temp}|" $current_input
    sed -i "6s|.*|variable i equal ${i}|" $current_input
    sed -i "8s|.*|read_data ${current_data}|" $current_input
    #sed -i "8s|.*|read_restart ${current_data}.*|" $current_input
    sed -i "14s|.*|variable seed index ${random_seed}|" $current_input
    #sed -i "24s|.*|pair_style mlip load_from=curr.almtp|" $current_input
    sed -i "32s|.*|log Nt_${current_temp}/${i}/loop_bias_${i}.log_${trial}|" $current_input
    sed -i "33s|.*|dump dump all custom 4000 Nt_${current_temp}/${i}/dump.loop_bias_${i}_${trial}.trj id type x y z|" $current_input
    sed -i "34s|.*|restart 20000 Nt_${current_temp}/${i}/${current_temp}_restart_${trial}|" $current_input
    sed -i "59s|.*|variable        N loop ${next_N} 82|" $current_input
    sed -i "60s|.*|variable        currNt equal ${Nt_0}+(v_N-1)*50|" $current_input
    sed -i "70s|.*|    variable k equal ${current_fi}|" $current_input
    sed -i "110s|.*|    fix fgcmc Na gcmc 2000 2000 2000 5 ${random_seed} ${current_temp} $(printf "%.4f" ${current_mu}) 0.1 full_energy region system|" $current_input
    sed -i '82c\    fix logAtoms all print 2000 \"${step} ${atoms}\" file Nt_${T}/${i}/atoms_log_${N}.txt screen no title "Step Atoms"' $current_input
    sed -i '111c\        fix avgNa all ave/time 10 100 10000 v_total_atoms file Nt_${T}/${i}/${T}_converge_${N}.txt mode scalar' $current_input
    sed -i '112c\        fix avgEnergy all ave/time 10 100 10000 c_thermo_pe file Nt_${T}/${i}/${T}_energy_${N}.txt mode scalar' $current_input
    sed -i '152c\    write_data Nt_${T}/${i}/${T}loop_bias_${N}.data' $current_input
    
    job_script=$(cat <<EOF
#!/bin/bash
ulimit -s unlimited
cd \$PBS_O_WORKDIR
module purge
module load icc/20 impi/20 mkl/20 || { echo "Failed to load Intel modules"; exit 1; }
module load python/anaconda3 || { echo "Failed to load Anaconda module"; exit 1; }
mpirun -np 192 /W/av245900/HT-SHARE/binaries/lammps_mlip3_icc20_impi20_mkl20 -in $current_input #-log Nt_${current_temp}/loop_bias_${i}.log
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
    empty_large=$((2000 - large))
    empty_standard=$((2000 - csp_standard - csp_long))

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
        echo "$job_script" | qsub -N ${current_temp}_Nt_loop_${i} -S /bin/bash -q huge -l nodes=3:ppn=64,walltime=120:00:00
    fi

    if [ "$max_var" == "empty_large" ]; then
        echo "$job_script" | qsub -N ${current_temp}_Nt_loop_${i} -S /bin/bash -q large -l nodes=5:ppn=40,walltime=120:00:00
    fi

    if [ "$max_var" == "empty_standard" ]; then
        echo "$job_script" | qsub -N ${current_temp}_Nt_loop_${i} -S /bin/bash -q csp-standard -l nodes=6:ppn=32,walltime=24:00:00
    fi

    if [[ $? -ne 0 ]]; then
        echo "Job submission failed for in_${i}.my"
        cat qsub_${i}.log
    else
        echo "Job in_${i}.my submitted successfully"
    fi
    sleep 3
done
