#!/bin/bash
#PBS -N resubmit_700_4
#PBS -S /bin/bash
#PBS -q mono
#PBS -l walltime=1008:00:00,nodes=1:ppn=1
ulimit -s unlimited
cd $PBS_O_WORKDIR
echo "Working directory: $PBS_O_WORKDIR"
module load icc/20 impi/20 mkl/20
module load python/anaconda3

temp=700
dir=4
current_fi=0.002
current_mu=-2
Nt_0=200
current_temp=$temp

# Configuration
JOB_NAME="${temp}_Nt_loop_${dir}"
USER_ID="yy276937"
CHECK_INTERVAL=60  # seconds between checks
MAX_RETRIES=10     # maximum number of times to resubmit the job
dir_path="/K/yy276937/MTP_AIMD/production_run/free_E/test/Nt_${temp}/${dir}"
job_script="/K/yy276937/MTP_AIMD/production_run/free_E/test/run_loop_bias_${temp}.sh"

# Initialize counters
retry_count=0
is_training_finished=0

# Logging function
log_message() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1"
}

# Function to check if job is still running
is_job_running() {
    local job_count=$(qstat | grep "$USER_ID" | grep "$JOB_NAME" | wc -l)
    [ "$job_count" -gt 0 ]
}

# Function to find latest data file
find_latest_data_file() {
    local latest_file=""
    if [ -d "$dir_path" ]; then
        cd "$dir_path" || return 1
        
        # Find data files using pattern matching
        shopt -s nullglob
        local files=( ${temp}loop_bias_*.data )
        
        if [ ${#files[@]} -gt 0 ]; then
            # Sort files by numeric index instead of modification time
            local highest_index=0
            local highest_file=""
            
            for file in "${files[@]}"; do
                # Extract index from filename
                local index=$(echo "$(basename "$file")" | sed -n "s/${temp}loop_bias_\([0-9]\+\)\.data/\1/p")
                if [ -n "$index" ] && [ "$index" -gt "$highest_index" ]; then
                    highest_index=$index
                    highest_file=$file
                fi
            done
            
            latest_file=$highest_file
        fi
        
        shopt -u nullglob
    fi
    echo "$latest_file"
}

# Function to find latest log file
find_latest_log_file() {
    local latest_log=""
    if [ -d "$dir_path" ]; then
        cd "$dir_path" || return 1
        
        shopt -s nullglob
        local log_files=( loop_bias_${dir}.log_* )
        
        if [ ${#log_files[@]} -gt 0 ]; then
            # Sort log files by numeric suffix instead of modification time
            local highest_trial=0
            local highest_log=""
            
            for logfile in "${log_files[@]}"; do
                # Extract trial number from log filename (e.g., loop_bias_3.log_1 -> 1)
                local trial_num=$(echo "$(basename "$logfile")" | sed -n "s/loop_bias_${dir}\.log_\([0-9]\+\)/\1/p")
                if [ -n "$trial_num" ] && [ "$trial_num" -gt "$highest_trial" ]; then
                    highest_trial=$trial_num
                    highest_log=$logfile
                fi
            done
            
            latest_log=$highest_log
        fi
        
        shopt -u nullglob
    fi
    echo "$latest_log"
}

# Function to extract index from filename
extract_index() {
    local filename="$1"
    local pattern="$2"
    echo "$filename" | sed -n "s/.*${pattern}_\([0-9]\+\).*/\1/p"
}

# Function to update job script
update_job_script() {
    local last_N="$1"
    local next_N="$2"
    local trial="$3"
    
    # Navigate to script directory
    cd "$(dirname "$job_script")" || {
        log_message "ERROR: Cannot access job script directory"
        return 1
    }
    
    # Create backup of original script
    if [ ! -f "run_loop_bias.sh.backup" ]; then
        cp run_loop_bias.sh run_loop_bias.sh.backup 2>/dev/null || {
            log_message "WARNING: Could not create backup of run_loop_bias.sh"
        }
    fi
    
    # Copy and modify the job script
    cp run_loop_bias.sh "$job_script" || {
        log_message "ERROR: Failed to copy job script"
        return 1
    }
    
    # Update script parameters using more robust sed commands
    sed -i "5s|.*|current_fi=${current_fi}|" "$job_script"
    sed -i "6s|.*|current_mu=${current_mu}|" "$job_script"
    sed -i "7s|.*|Nt_0=${Nt_0}|" "$job_script"
    sed -i "8s|.*|current_temp=${current_temp}|" "$job_script"
    sed -i "9s|.*|last_N=${last_N}|" "$job_script"
    sed -i "10s|.*|next_N=${next_N}|" "$job_script"
    sed -i "11s|.*|dir=${dir}|" "$job_script"
    sed -i "12s|.*|trial=${trial}|" "$job_script"
    
    # Update data file path (assuming $file should be $job_script)
    sed -i "17s|.*|    current_data=Nt_${current_temp}/${dir}/${current_temp}loop_bias_${last_N}.data|" "$job_script"
    
    chmod +x "$job_script"
    
    log_message "Job script updated successfully"
    log_message "Parameters: last_N=${last_N}, next_N=${next_N}, trial=${trial}"
    log_message "Data file: Nt_${current_temp}/${dir}/${current_temp}loop_bias_${last_N}.data"
    
    return 0
}

# Main execution
log_message "Starting job monitoring script"
log_message "Monitoring job: $JOB_NAME for user: $USER_ID"
log_message "Maximum retries: $MAX_RETRIES"
log_message "Check interval: $CHECK_INTERVAL seconds"

# Main monitoring loop
while [ $is_training_finished -ne 1 ] && [ $retry_count -lt $MAX_RETRIES ]; do
    log_message "Checking job status (attempt $((retry_count + 1))/$MAX_RETRIES)..."
    
    if ! is_job_running; then
        log_message "Job has terminated, processing restart..."
        
        # Find latest files
        latest_data=$(find_latest_data_file)
        latest_log=$(find_latest_log_file)
        
        log_message "Latest data file: ${latest_data:-'None found'}"
        log_message "Latest log file: ${latest_log:-'None found'}"
        
        # Debug: List available files
        if [ -d "$dir_path" ]; then
            cd "$dir_path"
            log_message "Available data files: $(ls ${temp}loop_bias_*.data 2>/dev/null | tr '\n' ' ')"
            log_message "Available log files: $(ls loop_bias_${dir}.log* 2>/dev/null | tr '\n' ' ')"
        fi
        
        # Extract indices
        last_N=""
        latest_try_N=""
        
        if [ -n "$latest_data" ]; then
            # Extract index from data file name (e.g., 800loop_bias_22.data -> 22)
            filename=$(basename "$latest_data")
            log_message "Processing data file: $filename"
            
            # Try multiple extraction patterns to be more robust
            last_N=$(echo "$filename" | sed -n "s/${temp}loop_bias_\([0-9]\+\)\.data/\1/p")
            if [ -z "$last_N" ]; then
                # Fallback pattern without temperature prefix
                last_N=$(echo "$filename" | sed -n "s/.*loop_bias_\([0-9]\+\)\.data/\1/p")
                log_message "Using fallback pattern for extraction"
            fi
            
            log_message "Extracted index: '$last_N'"
        fi
        
        if [ -n "$latest_log" ]; then
            # Extract trial number from log file name (e.g., loop_bias_3.log_1 -> 1)
            filename_log=$(basename "$latest_log")
            latest_try_N=$(echo "$filename_log" | sed -n "s/loop_bias_${dir}\.log_\([0-9]\+\)/\1/p")
            log_message "Processing log file: $filename_log"
            log_message "Extracted trial number: '$latest_try_N'"
        fi
        
        if [ -z "$last_N" ]; then
            log_message "WARNING: No data file index found, using default (0)"
            last_N=0
        else
            log_message "Extracted data file index: $last_N"
        fi
        
        next_N=$((last_N + 1))
        
        # Set trial based on log file index if available, otherwise use retry count
        if [ -n "$latest_try_N" ] && [ "$latest_try_N" -gt 0 ]; then
            trial=$((latest_try_N + 1))
            log_message "Using trial number based on log file index: $trial"
        else
            trial=$((retry_count + 1))
            log_message "Using trial number based on retry count: $trial"
        fi
        
        # Update job script
        if update_job_script "$last_N" "$next_N" "$trial"; then
            log_message "Resubmitting job (attempt $trial/$MAX_RETRIES)"
            
            # Submit the job and capture job ID
            job_output=$("$job_script" 2>&1)
            if [ $? -eq 0 ]; then
                log_message "Job resubmitted successfully: $job_output"
                retry_count=$((retry_count + 1))
            else
                log_message "ERROR: Failed to resubmit job: $job_output"
                break
            fi
        else
            log_message "ERROR: Failed to update job script"
            break
        fi
        
        # Wait before next check
        sleep $CHECK_INTERVAL
    else
        log_message "Job is still running"
        sleep $CHECK_INTERVAL
    fi
done

# Final status check
if [ $retry_count -ge $MAX_RETRIES ]; then
    log_message "ERROR: Maximum retry attempts ($MAX_RETRIES) reached. Stopping monitoring."
    exit 1
elif [ $is_training_finished -eq 1 ]; then
    log_message "Training completed successfully!"
    exit 0
else
    log_message "Job monitoring completed after $retry_count resubmission(s)"
    exit 0
fi