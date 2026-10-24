#!/bin/bash
#PBS -N HaHa_lv12
#PBS -S /bin/bash
#PBS -q mono
#PBS -l walltime=1008:00:00,nodes=1:ppn=1
ulimit -s unlimited
cd $PBS_O_WORKDIR
echo $PBS_O_WORKDIR
module load icc/20 impi/20 mkl/20
module load python/anaconda3


# Define job configurations
# Format: "current_fi current_mu Nt_0 current_temp last_N dir trial enable"
# enable: 1 = run job, 0 = skip job
job_configs=(
    "0.002 -2 200 300  17 1 1  0"
    "0.002 -2 200 300  60 2 11 0"
    "0.002 -2 200 300  36 3 2  0"
    "0.002 -2 200 400  33 1 1  0"
    "0.002 -2 200 400  14 2 1  0"
    "0.002 -2 200 400  63 3 11 0"
    "0.002 -2 200 500  60 1 17 0"
    "0.002 -2 200 500  48 2 11 0"
    "0.002 -2 200 500  59 3 13 1"
    "0.002 -2 200 600  82 1 1  0"
    "0.002 -2 200 600  35 2 2  0"
    "0.002 -2 200 600  72 3 11 1"
    "0.002 -2 200 700  80 1 1  0"
    "0.002 -2 200 700  40 2 1  0"
    "0.002 -2 200 700  39 3 2  1"
    "0.002 -2 200 700  9  4 2  1"
    "0.002 -2.5 200 800  82 1 1 0"
    "0.002 -2.5 200 800  42 2 1 0"
    "0.002 -2.5 200 800  63 3 1 0"
    "0.002 -2.5 200 800  8  4 2 1"
    "0.002 -3 150 900  80 1 1  0"
    "0.002 -3 150 900  20 2 1  0"
    "0.002 -3 150 900  35 3 16 0"
    "0.002 -3 150 1000 79 1 1 0"
    "0.002 -3 150 1000 0  2 1 0"
    "0.002 -3 150 1000 49 3 1 0"
    "0.002 -3 150 1000 0  4 1 0"
    "0.002 -3 150 1100 23 1 1 0"
    "0.002 -3 150 1100 12 2 1 0"
    "0.002 -3 150 1100 44 3 1 0"
)

# Function to wait for jobs to finish
wait_for_jobs() {
    echo "Waiting for jobs to complete..."
    is_training_finished=0
    while [ $is_training_finished -ne 1 ]; do
        sleep 10  # Check every 10 seconds
        cfg_cal=$(qstat | grep yy276937 | grep "Nt_loop" | wc -l)
        
        if [ "$cfg_cal" -gt 7 ]; then
            echo "$(date) - There are $cfg_cal jobs still running"
        else
            echo "$(date) - Time to run more simulation!!!"
            is_training_finished=1
        fi
    done
    sleep 3
}

# Main loop
for i in "${!job_configs[@]}"; do
    echo "######### $((i + 1)) #########"
    
    # Parse configuration
    read -r current_fi current_mu Nt_0 current_temp last_N dir trial enable <<< "${job_configs[i]}"
    next_N=$((last_N + 1))
    
    # Check if job should be skipped
    if [ "$enable" -eq 0 ]; then
        echo "Skipping job $((i + 1)): dir=$dir (disabled)"
        continue
    fi
    
    echo "Running job $((i + 1)): current_temp=$current_temp dir=$dir, last_N=$last_N, trial=$trial"

    # Copy and create unique script files for each job
    cp /K/yy276937/MTP_AIMD/production_run/free_E/test/run_loop_bias.sh /K/yy276937/MTP_AIMD/production_run/free_E/test/run_loop_bias_${current_temp}_${dir}.sh

    file=/K/yy276937/MTP_AIMD/production_run/free_E/test/run_loop_bias_${current_temp}_${dir}.sh
    
    # Update run_loop_bias.sh
    sed -i "5s|.*|current_fi=${current_fi}|" "$file"
    sed -i "6s|.*|current_mu=${current_mu}|" "$file"
    sed -i "7s|.*|Nt_0=${Nt_0}|" "$file"
    sed -i "8s|.*|current_temp=${current_temp}|" "$file"
    sed -i "9s|.*|last_N=${last_N}|" "$file"
    sed -i "10s|.*|next_N=${next_N}|" "$file"
    sed -i "11s|.*|dir=${dir}|" "$file"
    sed -i "12s|.*|trial=${trial}|" "$file"
    
    # Set current_data based on last_N
    if [ "$last_N" != "0" ]; then
        sed -i "17s|.*|    current_data=Nt_${current_temp}/${dir}/${current_temp}loop_bias_${last_N}.data|" "$file"
    else
        sed -i "17s|.*|    current_data=1100_bias_105.data|" "$file"
    fi
    
    # Execute the main script
    "$file"

    # Copy and create unique resubmit script
    cp /K/yy276937/MTP_AIMD/production_run/free_E/test/resubmit.sh /K/yy276937/MTP_AIMD/production_run/free_E/test/resubmit_${current_temp}_${dir}.sh
    file2=/K/yy276937/MTP_AIMD/production_run/free_E/test/resubmit_${current_temp}_${dir}.sh
    
    # Update resubmit.sh
    sed -i "2s|.*|#PBS -N resubmit_${current_temp}_${dir}|" "$file2"
    sed -i "12s|.*|temp=${current_temp}|" "$file2"
    sed -i "13s|.*|dir=${dir}|" "$file2"
    sed -i "14s|.*|current_fi=${current_fi}|" "$file2"
    sed -i "15s|.*|current_mu=${current_mu}|" "$file2"
    sed -i "16s|.*|Nt_0=${Nt_0}|" "$file2"
    
    # Submit the job
    qsub "$file2"
    sleep 3
    
    # Wait for jobs to complete before proceeding to next iteration
    wait_for_jobs
done

echo "All job configurations completed!"