#!/bin/bash
rm is_selection_finished.txt

echo "selection is starting"

job_script=$(cat <<EOF
#!/bin/bash
ulimit -s unlimited
cd $PBS_O_WORKDIR
module purge
module load gcc/11.4.0 ompi mkl/2025.3
export LD_LIBRARY_PATH=/K/av245900/Codes/lammps_mlip3_2026_06_01/lammps/src:$LD_LIBRARY_PATH
mpirun -np 64 /W/av245900/HT-SHARE/binaries/mlip3_gcc11.4.0_ompi4.1.8_mkl2025.3 select_add /K/yy276937/MTP_AIMD/hydration/curr.almtp /K/yy276937/MTP_AIMD/hydration/train.cfg /K/yy276937/MTP_AIMD/hydration/preselected.cfg /K/yy276937/MTP_AIMD/hydration/selected.cfg 
echo "1" >> is_selection_finished.txt
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
    empty_standard=$((500 - csp_standard - csp_long))

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
        echo "$job_script" | qsub -N MD_selection -S /bin/bash -q huge -l nodes=1:ppn=64,walltime=120:00:00
    fi

    if [ "$max_var" == "empty_large" ]; then
        echo "$job_script" | qsub -N MD_selection -S /bin/bash -q large -l nodes=2:ppn=40,walltime=48:00:00
    fi

    if [ "$max_var" == "empty_standard" ]; then
        echo "$job_script" | qsub -N MD_selection -S /bin/bash -q csp-standard -l nodes=2:ppn=32,walltime=24:00:00
    fi

echo "selection completed"

