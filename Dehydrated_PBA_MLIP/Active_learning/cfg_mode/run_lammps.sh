#!/bin/bash
export OMP_NUM_THREADS=1
echo "lammps MD is starting"

data=("MnFePBA_300K.data" "MnFePBA_300K.data" "MnFePBA_300K.data" "MnFePBA_300K.data" \
     "Na0.data" "Na0.data" "Na0.data" "Na0.data")
temp=(300 400 500 600 300 400 500 600)
mu=(-3.5 -3 -2.5 -2.5 -1 -1 -1 -1)
list=($(seq 1 1 8))  # Sequence of numbers from 1 to 8

for i in "${list[@]}"; do
    index=$((i - 1))
    current_data="${data[$index]}"
    current_temp="${temp[$index]}"
    current_mu="${mu[$index]}"
    current_input=in_test_${i}.my
    random_seed=$((RANDOM % 9999999 + 1))
    cp in_test.my $current_input
    
    echo "Processing index $i with MTP file: $current_mtp"
    echo "current temp: ${current_temp}"
    echo "input file: ${current_input}"
    echo "data file: ${current_data}"
    echo "mu: ${current_mu}"
    echo "seed ${random_seed}"

    # Update `in_test.my` file
    sed -i "5s|.*|variable T equal ${current_temp}|" $current_input
    sed -i "8s|.*|read_data  ${current_data}|" $current_input
    sed -i "15s|.*|variable seed index ${random_seed}|" $current_input
    sed -i "24s|.*|pair_style mlip load_from=curr.almtp extrapolation_control=true extrapolation_control:threshold_break=10 extrapolation_control:threshold_save=2 extrapolation_control:save_extrapolative_to=preselected_${i}.cfg|" $current_input
    sed -i "36s|.*|dump dump_${i} all custom 2000 dump.gcmc_${i}.trj id type x y z|" $current_input
    sed -i "75s|.*|fix fgcmc Na gcmc 4000 100 500 5 65869 ${current_temp} ${current_mu} 0.1 full_energy region system max 64 min 0|" $current_input
    sed -i "90s|.*|write_data MnFePBA_gcmc_${i}.data|" $current_input
    sed -i "91s|.*|write_dump all atom MnFePBA_gcmc_dump_${i}.trj|" $current_input
    job_script=$(cat <<EOF
#!/bin/bash
ulimit -s unlimited
cd \$PBS_O_WORKDIR
module purge
module load icc/20 impi/20 mkl/20 || { echo "Failed to load Intel modules"; exit 1; }
module load python/anaconda3 || { echo "Failed to load Anaconda module"; exit 1; }
mpirun -np 64 /W/av245900/HT-SHARE/binaries/lammps_mlip3_icc20_impi20_mkl20 -in $current_input -log gcmc_${i}.log
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
        echo "$job_script" | qsub -N MD_cfg_${i} -S /bin/bash -q huge -l nodes=1:ppn=64,walltime=120:00:00
    fi

    if [ "$max_var" == "empty_large" ]; then
        echo "$job_script" | qsub -N MD_cfg_${i} -S /bin/bash -q large -l nodes=2:ppn=40,walltime=120:00:00
    fi

    if [ "$max_var" == "empty_standard" ]; then
        echo "$job_script" | qsub -N MD_cfg_${i} -S /bin/bash -q csp-standard -l nodes=2:ppn=32,walltime=24:00:00
    fi

    if [[ $? -ne 0 ]]; then
        echo "Job submission failed for in_${i}.my"
        cat qsub_${i}.log
    else
        echo "Job in_${i}.my submitted successfully"
    fi
    sleep 10
done

sleep 10

is_vasp_finished=0
while [ $is_vasp_finished -ne 1 ]
do
    sleep 100
    n_vasp_finished=$(grep -rH "1" VASP/*/is_vasp_finished.txt | wc -l)
    cfg_cal=$(qstat | grep yy276937 | grep "MD_cfg" | wc -l)
    
    if [ "$cfg_cal" -gt 0 ]; then
        echo "There are $cfg_cal jobs still running"
        is_vasp_finished=0
        echo $is_vasp_finished
    else
        echo All jobs are finished
        is_vasp_finished=1
        echo $is_vasp_finished
    fi
done

echo "lammps MD completed"
echo "1" >> is_lammps_finished.txt