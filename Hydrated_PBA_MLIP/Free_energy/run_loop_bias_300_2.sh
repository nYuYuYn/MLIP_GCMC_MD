#!/bin/bash

export OMP_NUM_THREADS=1
export LC_NUMERIC=C

wait_for_jobs() {
    echo "Waiting for jobs to complete..."
    is_training_finished=0
    while [ $is_training_finished -ne 1 ]; do
        sleep 10  # Check every 10 seconds
        cfg_cal=$(qstat | grep yy276937 | grep "300_re_*" | wc -l)
        
        if [ "$cfg_cal" -gt 8 ]; then
            echo "$(date) - There are $cfg_cal jobs still running"
        else
            echo "$(date) - Time to run more simulation!!!"
            is_training_finished=1
        fi
    done
    sleep 3
}

current_fi=0.005
current_mu=-2.5
Nt_0=1700
current_temp=300


dir=2
i=2
trial=1

files=(
/K/yy276937/MTP_AIMD/hydration/Nt_400/2/400loop_bias_1.data
/K/yy276937/MTP_AIMD/hydration/Nt_400/2/400loop_bias_2.data
/K/yy276937/MTP_AIMD/hydration/Nt_400/2/400loop_bias_3.data
/K/yy276937/MTP_AIMD/hydration/Nt_400/2/400loop_bias_4.data
/K/yy276937/MTP_AIMD/hydration/Nt_400/2/400loop_bias_5.data
/K/yy276937/MTP_AIMD/hydration/Nt_400/2/400loop_bias_6.data
/K/yy276937/MTP_AIMD/hydration/Nt_400/2/400loop_bias_7.data
/K/yy276937/MTP_AIMD/hydration/Nt_400/2/400loop_bias_8.data
/K/yy276937/MTP_AIMD/hydration/Nt_400/2/400loop_bias_9.data
/K/yy276937/MTP_AIMD/hydration/Nt_400/2/400loop_bias_10.data
/K/yy276937/MTP_AIMD/hydration/Nt_400/2/400loop_bias_11.data
/K/yy276937/MTP_AIMD/hydration/Nt_400/2/400loop_bias_12.data
/K/yy276937/MTP_AIMD/hydration/Nt_400/2/400loop_bias_13.data
/K/yy276937/MTP_AIMD/hydration/Nt_400/2/400loop_bias_14.data
/K/yy276937/MTP_AIMD/hydration/Nt_400/2/400loop_bias_15.data
/K/yy276937/MTP_AIMD/hydration/Nt_400/2/400loop_bias_16.data
/K/yy276937/MTP_AIMD/hydration/Nt_400/2/400loop_bias_17.data
/K/yy276937/MTP_AIMD/hydration/Nt_400/2/400loop_bias_18.data
/K/yy276937/MTP_AIMD/hydration/Nt_400/2/400loop_bias_19.data
/K/yy276937/MTP_AIMD/hydration/Nt_400/2/400loop_bias_20.data
/K/yy276937/MTP_AIMD/hydration/Nt_400/2/400loop_bias_21.data
/K/yy276937/MTP_AIMD/hydration/Nt_400/2/400loop_bias_22.data
/K/yy276937/MTP_AIMD/hydration/Nt_400/2/400loop_bias_23.data
/K/yy276937/MTP_AIMD/hydration/Nt_400/2/400loop_bias_24.data
/K/yy276937/MTP_AIMD/hydration/Nt_400/2/400loop_bias_25.data
/K/yy276937/MTP_AIMD/hydration/Nt_400/2/400loop_bias_26.data
/K/yy276937/MTP_AIMD/hydration/Nt_400/2/400loop_bias_27.data
/K/yy276937/MTP_AIMD/hydration/Nt_400/2/400loop_bias_28.data
/K/yy276937/MTP_AIMD/hydration/Nt_400/2/400loop_bias_29.data
/K/yy276937/MTP_AIMD/hydration/Nt_400/2/400loop_bias_30.data
/K/yy276937/MTP_AIMD/hydration/Nt_400/2/400loop_bias_31.data
/K/yy276937/MTP_AIMD/hydration/Nt_400/2/400loop_bias_32.data
/K/yy276937/MTP_AIMD/hydration/Nt_400/2/400loop_bias_33.data
/K/yy276937/MTP_AIMD/hydration/Nt_400/2/400loop_bias_34.data
/K/yy276937/MTP_AIMD/hydration/Nt_400/2/400loop_bias_35.data
/K/yy276937/MTP_AIMD/hydration/Nt_400/2/400loop_bias_36.data
/K/yy276937/MTP_AIMD/hydration/Nt_400/2/400loop_bias_37.data
/K/yy276937/MTP_AIMD/hydration/Nt_400/2/400loop_bias_38.data
/K/yy276937/MTP_AIMD/hydration/Nt_400/2/400loop_bias_39.data
/K/yy276937/MTP_AIMD/hydration/Nt_400/2/400loop_bias_40.data
/K/yy276937/MTP_AIMD/hydration/Nt_400/2/400loop_bias_41.data
/K/yy276937/MTP_AIMD/hydration/Nt_400/2/400loop_bias_42.data
/K/yy276937/MTP_AIMD/hydration/Nt_400/2/400loop_bias_43.data
/K/yy276937/MTP_AIMD/hydration/Nt_400/2/400loop_bias_44.data
/K/yy276937/MTP_AIMD/hydration/RDF_lv16_E0_sf0.1_f0.1/Na_32_O_32_5.data
/K/yy276937/MTP_AIMD/hydration/RDF_lv16_E0_sf0.1_f0.1/Na_32_O_32_6.data
/K/yy276937/MTP_AIMD/hydration/RDF_lv16_E0_sf0.1_f0.1/Na_32_O_32_8.data
/K/yy276937/MTP_AIMD/hydration/RDF_lv16_E0_sf0.1_f0.1/Na_32_O_32_9.data
/K/yy276937/MTP_AIMD/hydration/RDF_lv16_E0_sf0.1_f0.1/Na_32_O_32_10.data
/K/yy276937/MTP_AIMD/hydration/RDF_lv16_E0_sf0.1_f0.1/Na_32_O_32_11.data
/K/yy276937/MTP_AIMD/hydration/RDF_lv16_E0_sf0.1_f0.1/Na_32_O_32_13.data
/K/yy276937/MTP_AIMD/hydration/RDF_lv16_E0_sf0.1_f0.1/Na_32_O_32_14.data
/K/yy276937/MTP_AIMD/hydration/RDF_lv16_E0_sf0.1_f0.1/Na_32_O_32_16.data
/K/yy276937/MTP_AIMD/hydration/RDF_lv16_E0_sf0.1_f0.1/Na_32_O_32_17.data
/K/yy276937/MTP_AIMD/hydration/RDF_lv16_E0_sf0.1_f0.1/Na_32_O_32_19.data
/K/yy276937/MTP_AIMD/hydration/RDF_lv16_E0_sf0.1_f0.1/Na_32_O_32_20.data
/K/yy276937/MTP_AIMD/hydration/RDF_lv16_E0_sf0.1_f0.1/Na_32_O_32_22.data
/K/yy276937/MTP_AIMD/hydration/RDF_lv16_E0_sf0.1_f0.1/Na_32_O_32_24.data
/K/yy276937/MTP_AIMD/hydration/RDF_lv16_E0_sf0.1_f0.1/Na_32_O_32_25.data
/K/yy276937/MTP_AIMD/hydration/RDF_lv16_E0_sf0.1_f0.1/Na_32_O_32_27.data
/K/yy276937/MTP_AIMD/hydration/RDF_lv16_E0_sf0.1_f0.1/Na_32_O_32_29.data
/K/yy276937/MTP_AIMD/hydration/RDF_lv16_E0_sf0.1_f0.1/Na_32_O_32_31.data
/K/yy276937/MTP_AIMD/hydration/RDF_lv16_E0_sf0.1_f0.1/Na_32_O_32_32.data
/K/yy276937/MTP_AIMD/hydration/RDF_lv16_E0_sf0.1_f0.1/Na_32_O_32_34.data
/K/yy276937/MTP_AIMD/hydration/RDF_lv16_E0_sf0.1_f0.1/Na_32_O_32_36.data
/K/yy276937/MTP_AIMD/hydration/RDF_lv16_E0_sf0.1_f0.1/Na_32_O_32_38.data
/K/yy276937/MTP_AIMD/hydration/RDF_lv16_E0_sf0.1_f0.1/Na_32_O_32_39.data
/K/yy276937/MTP_AIMD/hydration/RDF_lv16_E0_sf0.1_f0.1/Na_32_O_32_39.data
/K/yy276937/MTP_AIMD/hydration/RDF_lv16_E0_sf0.1_f0.1/Na_32_O_32_39.data
/K/yy276937/MTP_AIMD/hydration/RDF_lv16_E0_sf0.1_f0.1/Na_32_O_32_39.data
)

N=($(seq 1 1 70))
for j in "${N[@]}"; do
    idx=$((j - 1))
    last_N="${N[$idx]}"
    mkdir -p Nt_${current_temp}/${i}
    current_data=${files[$idx]}
    #/K/yy276937/MTP_AIMD/hydration/free_E_lammps_data/Na_32_O_32_${j}.data
    
    random_seed=$((RANDOM % 9999999 + 1))
    current_input=${current_temp}_loop_bias_${dir}_${last_N}.my
    cp loop_bias.my $current_input
    
    echo "Processing index $i with MTP file"
    echo "current temp: ${current_temp}"
    echo "input file: ${current_input}"
    echo "data file: ${current_data}"
    echo "mu: ${current_mu}"
    echo "fi: ${current_fi}"
    echo "last_N: ${last_N}"
    echo "seed ${random_seed}"
    echo "log Nt_${current_temp}/${i}/loop_bias_${i}.log_${last_N}"
    echo ""

    # Update `in_test.my` file
    sed -i "5s|.*|variable T equal ${current_temp}|" $current_input
    sed -i "6s|.*|variable i equal ${i}|" $current_input
    sed -i "8s|.*|read_data ${current_data}|" $current_input
    #sed -i "8s|.*|read_restart ${current_data}.*|" $current_input
    sed -i "16s|.*|variable seed index ${random_seed}|" $current_input
    sed -i "23s|.*|pair_style mlip load_from=curr.almtp|" $current_input
    sed -i "32s|.*|log Nt_${current_temp}/${i}/loop_bias_${i}.log_${j}|" $current_input
    sed -i "33s|.*|dump dump all custom 4000 Nt_${current_temp}/${i}/dump.loop_bias_${i}_${j}.trj id type x y z|" $current_input
    sed -i "34s|.*|restart 20000 Nt_${current_temp}/${i}/${current_temp}_restart_${j}|" $current_input
    sed -i "59s|.*|variable        N loop ${last_N} ${last_N}|" $current_input
    sed -i "60s|.*|variable        currNt equal ${Nt_0}-(v_N-1)*25|" "$current_input"
    sed -i "70s|.*|    variable k equal ${current_fi}|" $current_input
    sed -i "112s|.*|    fix fgcmc Na gcmc 2000 2000 2000 5 ${random_seed} ${current_temp} $(printf "%.4f" ${current_mu}) 0.1 full_energy region system|" $current_input
    sed -i '82c\    fix logAtoms all print 2000 \"${step} ${atoms}\" file Nt_${T}/${i}/atoms_log_${N}.txt screen no title "Step Atoms"' $current_input
    sed -i '113c\        fix avgNa all ave/time 10 100 10000 v_total_atoms file Nt_${T}/${i}/${T}_converge_${N}.txt mode scalar' $current_input
    sed -i '114c\        fix avgEnergy all ave/time 10 100 10000 c_thermo_pe file Nt_${T}/${i}/${T}_energy_${N}.txt mode scalar' $current_input
    sed -i '154c\    write_data Nt_${T}/${i}/${T}loop_bias_${N}.data' $current_input

    job_script=$(cat <<EOF
#!/bin/bash
ulimit -s unlimited
cd \$PBS_O_WORKDIR
module purge
module load icc/20 impi/20 mkl/20 || { echo "Failed to load Intel modules"; exit 1; }
module load python/maxiforge || { echo "Failed to load Anaconda module"; exit 1; }
mpirun -np 192 /W/av245900/HT-SHARE/binaries/lammps_mlip3_icc20_impi20_mkl20 -in $current_input
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
    empty_standard=$((1800 - csp_standard - csp_long))

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
        echo "$job_script" | qsub -N ${current_temp}_re_${j} -S /bin/bash -q huge -l nodes=3:ppn=64,walltime=120:00:00
    fi

    if [ "$max_var" == "empty_large" ]; then
        echo "$job_script" | qsub -N ${current_temp}_re_${j} -S /bin/bash -q large -l nodes=5:ppn=40,walltime=120:00:00
    fi

    if [ "$max_var" == "empty_standard" ]; then
        echo "$job_script" | qsub -N ${current_temp}_re_${j} -S /bin/bash -q csp-standard -l nodes=6:ppn=32,walltime=24:00:00
    fi

    if [[ $? -ne 0 ]]; then
        echo "Job submission failed for in_${i}.my"
        cat qsub_${i}.log
    else
        echo "Job in_${i}.my submitted successfully"
    fi
    sleep 1

    wait_for_jobs
done
