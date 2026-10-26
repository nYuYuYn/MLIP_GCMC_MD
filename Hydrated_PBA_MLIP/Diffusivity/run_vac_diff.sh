#!/bin/bash

module load gcc/11.4.0 ompi mkl/2025.3
export LD_LIBRARY_PATH=/K/av245900/Codes/lammps_mlip3_2026_06_01/lammps/src:$LD_LIBRARY_PATH

rm -f in_diffuse_*.txt
rm 400K_diff*o*
rm 400K_diff*e*

export OMP_NUM_THREADS=1
export LC_NUMERIC=C

wait_for_jobs() {
    echo "Waiting for jobs to complete..."
    is_training_finished=0
    while [ $is_training_finished -ne 1 ]; do
        sleep 3  # Check every 10 seconds
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

#data=("vac_1.data" "vac_2.data" "vac_3.data" "vac_4.data" "vac_5.data" "vac_6.data" "vac_w_Na_1.data" "vac_w_Na_2.data")
data=("Na_0_O_32_vac_06.data" "Na_4_O_32_vac_06.data")
list=(11 12) #$(seq 1 1 8))
current_temp=400
for i in "${list[@]}"; do
    index=$((i - 11))
    mkdir -p ${current_temp}_diffusion_vac_lv20_r02_65_2
    current_dir="${current_temp}_diffusion_vac_lv20_r02_65_2"
    #current_data="${current_dir}/${current_temp}_diffusion_${i}_restart.*"
    #current_data="${current_temp}_diffusion_vac_lv20_r02_65/${current_temp}_diffusion_${i}_restart.*"
    current_data="${data[$index]}"
    #current_data="400K_10.data"
    random_seed=$((RANDOM % 9999999 + 1))
    current_input="${current_dir}/${current_temp}_diffuse_${i}.my"
    cp in_vac.my $current_input
    
    echo "current temp: ${current_temp}"
    echo "input file: ${current_input}"
    echo "data file: ${current_data}"
    echo "seed ${random_seed}"
    echo "log ${current_dir}/diffusion_${i}.log"
    echo ""

    sed -i "5s|.*|variable T equal ${current_temp}|" $current_input
    sed -i "6s|.*|#variable Na equal ${current_Na}|" $current_input
    sed -i "7s|.*|#variable O equal ${current_O}|" $current_input
    sed -i "8s|.*|read_data  ${current_data}|" $current_input
    #sed -i "8s|.*|read_restart  ${current_data}|" $current_input
    sed -i "9s|.*|#replicate 1 1 1|" $current_input
    #sed -i "8s|.*|read_restart  ${current_data}|" $current_input
    sed -i "17s|.*|variable seed index ${random_seed}|" $current_input
    sed -i "25s|.*|pair_style mlip load_from=curr.almtp|" $current_input
    sed -i "32s|.*|restart 50000 ${current_dir}/${current_temp}_diffusion_${i}_restart|" $current_input
    sed -i "67s|.*|fix rdf_output all ave/time 50 20 4000 c_myRDF[*] file ${current_dir}/${current_temp}_diffusion_${i}.rdf mode vector|" $current_input
    sed -i "70s|.*|dump ONa_dump O custom 4000 ${current_dir}/${current_temp}K_ONa_coord_${i}.txt id type c_ONacoord|" $current_input
    sed -i "71s|.*|dump NaN_dump Na custom 4000 ${current_dir}/${current_temp}K_NaN_coord_${i}.txt id type c_NaNcoord|" $current_input
    sed -i "74s|.*|write_data ${current_dir}/${current_temp}K_${i}.data|" $current_input
    sed -i "75s|.*|write_dump all custom ${current_dir}/${current_temp}K_${i}.dump id type x y z|" $current_input
    sed -i "88s|.*|fix avg_msd_PB PB ave/time 500 10 5000 c_msd_PB[1] c_msd_PB[2] c_msd_PB[3] c_msd_PB[4] file ${current_dir}/${current_temp}K_msd_PB_${i}.dat mode scalar |" $current_input
    sed -i "89s|.*|fix avg_msd_Na Na ave/time 500 10 5000 c_msd_Na[1] c_msd_Na[2] c_msd_Na[3] c_msd_Na[4] file ${current_dir}/${current_temp}K_msd_Na_${i}.dat mode scalar |" $current_input
    sed -i "90s|.*|fix avg_msd_h2o Na ave/time 500 10 5000 c_msd_h2o[1] c_msd_h2o[2] c_msd_h2o[3] c_msd_h2o[4] file ${current_dir}/${current_temp}K_msd_h2o_${i}.dat mode scalar |" $current_input

    sed -i "96s|.*|dump dump_short all custom 5 ${current_dir}/dump.${current_temp}_diffuse_short_${i}.trj id type x y z|" $current_input
    sed -i "100s|.*|dump dump all custom 1000 ${current_dir}/dump.${current_temp}_diffuse_${i}.trj id type x y z|" $current_input
    sed -i "101s|.*|dump dump_long all custom 4000 ${current_dir}/dump.${current_temp}_diffuse_long_${i}.trj id type x y z|" $current_input
    
    sed -i "107s|.*|write_data ${current_dir}/${current_temp}K_diffusion_${i}.data|" $current_input
    sed -i "108s|.*|write_dump all custom ${current_dir}/${current_temp}K_diffusion_${i}.dump id type x y z|" $current_input
    
    job_script=$(cat <<EOF
#!/bin/bash
ulimit -s unlimited
cd \$PBS_O_WORKDIR
module purge
module load gcc/11.4.0 ompi mkl/2025.3
export LD_LIBRARY_PATH=/K/av245900/Codes/lammps_mlip3_2026_06_01/lammps/src:$LD_LIBRARY_PATH
mpirun -np 320 /W/av245900/HT-SHARE/binaries/lammps_mlip3_gcc11.4.0_ompi4.1.8_mkl2025.3 -in ${current_input} -log  ${current_dir}/${current_temp}_diffusion_${i}.log
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

    empty_huge=$((2400 - huge))
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
        echo "$job_script" | qsub -N ${current_temp}K_diff_${i} -S /bin/bash -q huge -l nodes=5:ppn=64,walltime=120:00:00
    fi

    if [ "$max_var" == "empty_large" ]; then
        echo "$job_script" | qsub -N ${current_temp}K_diff_${i} -S /bin/bash -q large -l nodes=8:ppn=40,walltime=120:00:00
    fi

    if [ "$max_var" == "empty_standard" ]; then
        echo "$job_script" | qsub -N ${current_temp}K_diff_${i} -S /bin/bash -q csp-standard -l nodes=4:ppn=32,walltime=24:00:00
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
