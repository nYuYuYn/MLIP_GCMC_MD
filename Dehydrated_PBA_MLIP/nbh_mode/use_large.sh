
#!/bin/bash

# Function to resubmit a task to another queue
resubmit_task_large() {
    job_id=$1
    dir_num=$2
    qdel "$job_id"
    echo delet job "$job_id"
    cd $PBS_O_WORKDIR  # Ensure directory change is successful
	echo $PBS_O_WORKDIR
    sed -i "7s/.*/NCORE = 40/" "VASP/$dir_num/INCAR"
    sed -i "4s/.*/#PBS -q large/" "VASP/$dir_num/sub_vasp.sh"
    sed -i "5s/.*/#PBS -l walltime=24:00:00,nodes=2:ppn=40/" "VASP/$dir_num/sub_vasp.sh"
    echo changed "$dir_num" INCAR
    qsub "VASP/$dir_num/sub_vasp.sh"
    echo submit job "$dir_num" at LARGE 
}

resubmit_task_standard() {
    job_id=$1
    dir_num=$2
    qdel "$job_id"
    echo delet job "$job_id"
    cd $PBS_O_WORKDIR  # Ensure directory change is successful
	echo $PBS_O_WORKDIR
    sed -i "7s/.*/NCORE = 32/" "VASP/$dir_num/INCAR"
    sed -i "4s/.*/#PBS -q csp/" "VASP/$dir_num/sub_vasp.sh"
    sed -i "5s/.*/#PBS -l walltime=24:00:00,nodes=4:ppn=32/" "VASP/$dir_num/sub_vasp.sh"
    echo changed "$dir_num" INCAR
    qsub "VASP/$dir_num/sub_vasp.sh"
    echo submit job "$dir_num" at STD
}


# Main script
num_cal=$(qstat | grep yy276937 | grep "nbh" | wc -l)
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
			sleep 10
		    num_cal=$(qstat | grep yy276937 | grep "nbh" | wc -l)
		    
		elif [ $large_waiting -gt 0 ] && [ $std_waiting -ge 0 ]; then #large is full but STD is available or full 
		    echo 
		    echo "LARGE queues are full now."
		    qstat_output=$(qstat | grep yy276937 | grep "large" | grep Q)
		    
			while read -r line; do
		        job_id=$(echo "$line" | awk '{print $1}')
		        dir_num=$(echo "$line" | awk '{print $2}' | grep -o '[0-9]*')
		        resubmit_task_standard "$job_id" "$dir_num"
			done <<< "$qstat_output"
			echo "STD queue is full, check HUGE"
			if [ $std_waiting -gt 0 ]; then
				./use_huge.sh
				echo "sleeping and checking HUGE queue"
				sleep 10
			fi
		    
			while pgrep -f "use_huge.sh" > /dev/null; do
				sleep 10
		    done
			
			num_cal=$(qstat | grep yy276937 | grep "nbh" | wc -l)
		    
		elif [ $large_waiting -gt 0 ] && [ $std_waiting -gt 0 ]; then #Both STD and large are full and is waiting
		    echo
		    echo "All queues are fully now. RELAX!"
			sleep 10
		    num_cal=$(qstat | grep yy276937 | grep "nbh" | wc -l)
			
		elif [ $large_waiting -eq 0 ] && [ $std_waiting -eq 0 ]; then #All jobs are running now
		    echo
		    echo "All jobs are running now. RELAX!"
			sleep 10
		    num_cal=$(qstat | grep yy276937 | grep "nbh" | wc -l)
			
		fi
	else
        echo "No tasks in the nbh queue."
    fi
	echo sleeping
	sleep 60  # Check every minute
	num_cal=$(qstat | grep yy276937 | grep "nbh" | wc -l)
done
		







































































