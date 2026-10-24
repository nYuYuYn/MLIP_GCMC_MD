#!/bin/bash

resubmit_task_large() {
    job_id=$1
    dir_num=$2
    qdel "$job_id"
    echo "Deleted job $job_id"
    cd "$PBS_O_WORKDIR"  || exit  # Ensure directory change is successful
    echo "$PBS_O_WORKDIR"
    sed -i "8s/.*/NCORE = 40/" "VASP/$dir_num/INCAR"
    sed -i "4s/.*/#PBS -q large/" "VASP/$dir_num/sub_vasp.sh"
    sed -i "5s/.*/#PBS -l walltime=24:00:00,nodes=1:ppn=40/" "VASP/$dir_num/sub_vasp.sh"
    echo "Changed $dir_num INCAR"
    qsub "VASP/$dir_num/sub_vasp.sh"
    echo "Submitted job $dir_num to LARGE"
}

resubmit_task_standard() {
    job_id=$1
    dir_num=$2
    qdel "$job_id"
    echo "Deleted job $job_id"
    cd "$PBS_O_WORKDIR" || exit  # Ensure directory change is successful
    echo "$PBS_O_WORKDIR"
    sed -i "8s/.*/NCORE = 32/" "VASP/$dir_num/INCAR"
    sed -i "4s/.*/#PBS -q csp-standard/" "VASP/$dir_num/sub_vasp.sh"
    sed -i "5s/.*/#PBS -l walltime=24:00:00,nodes=1:ppn=32/" "VASP/$dir_num/sub_vasp.sh"
    echo "Changed $dir_num INCAR"
    qsub "VASP/$dir_num/sub_vasp.sh"
    echo "Submitted job $dir_num to STD"
}


# Main script
num_cal=$(qstat | grep "Q" | wc -l)
while [ $num_cal -gt 0 ]; do
	# Count the number of tasks in the nbh queue
    # Check if there are any tasks in the nbh queue
    if [ $num_cal -gt 0 ]; then
    # Check standard queue
		std_waiting=$(qstat | grep yy276937 | grep "csp-standard" | grep "Q" | wc -l)
		large_waiting=$(qstat | grep yy276937 | grep "large" | grep "Q" | wc -l)
		std_running=$(qstat | grep yy276937 | grep "csp-standard" | grep "R" | wc -l)
		large_running=$(qstat | grep yy276937 | grep "large" | grep "R" | wc -l)
        
		if [ $std_waiting -gt 0 ] && [ $large_waiting -eq 0 ]; then #STD is full but large is available
			echo 
		    echo "STD queues are full now."
		    qstat_output=$(qstat | grep yy276937 | grep "csp-standard" | grep Q)
		    while read -r line; do
		        job_id=$(echo "$line" | awk '{print $1}')
		        dir_num=$(echo "$line" | awk '{print $2}' | grep -o '[0-9]*')
		        resubmit_task_large "$job_id" "$dir_num"
		    done <<< "$qstat_output"
			sleep 60
		    num_cal=$(qstat | grep yy276937 | grep "nbh" | grep "Q" | wc -l)

		elif [ $large_waiting -gt 0 ] && [ $std_waiting -ge 0 ]; then #Large is full but STD is available or full 
		    echo 
		    echo "LARGE queues are full now. Queue in STD."
		    qstat_output=$(qstat | grep yy276937 | grep "large" | grep Q)
			while read -r line; do
		        job_id=$(echo "$line" | awk '{print $1}')
		        dir_num=$(echo "$line" | awk '{print $2}' | grep -o '[0-9]*')
		        resubmit_task_standard "$job_id" "$dir_num"
			done <<< "$qstat_output"
            sleep 60
			num_cal=$(qstat | grep yy276937 | grep "nbh" | grep "Q" | wc -l)
		    
		elif [ $large_waiting -gt 0 ] && [ $std_waiting -gt 0 ]; then #Both STD and large are full and is waiting
		    echo
		    echo "All queues are fully now. RELAX!"
			sleep 60
		    num_cal=$(qstat | grep yy276937 | grep "nbh" | grep "Q" | wc -l)
			
		fi
	else
        echo "No tasks in the nbh queue."
    fi
	echo sleeping
	sleep 60  # Check every minute
	num_cal=$(qstat | grep yy276937 | grep "nbh" | grep "Q" | wc -l)
done