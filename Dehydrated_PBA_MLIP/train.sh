#!/bin/bash
rm is_training_finished.txt

weight_scaling_forces=1
weight_scaling=2
current_sf=1 
current_fw=0.01

job_script=$(cat <<EOF
#!/bin/bash
ulimit -s unlimited
cd $PBS_O_WORKDIR
module purge
module load icc/20 impi/20 mkl/20 || { echo "Failed to load Intel modules"; exit 1; }
mpirun -np 192 /K/yy276937/MTP_AIMD/mlip train /K/yy276937/MTP_AIMD/curr.almtp /K/yy276937/MTP_AIMD/hydration/train.cfg --iteration_limit=10000 --al_mode=cfg  --scale_by_force=${current_sf} --force_weight=${current_fw} --weight_scaling_forces=${weight_scaling_forces} --weight_scaling=${weight_scaling}  --save_to=/K/yy276937/MTP_AIMD/curr_sf1_fw0.01.almtp
echo "1" >> is_training_finished.txt
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
    empty_large=$((1500 - large))
    empty_standard=$((1500 - csp_standard - csp_long))

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
        echo "$job_script" | qsub -N MD_dehy -S /bin/bash -q huge -l nodes=3:ppn=64,walltime=120:00:00
    fi

    if [ "$max_var" == "empty_large" ]; then
        echo "$job_script" | qsub -N MD_dehy -S /bin/bash -q large -l nodes=5:ppn=40,walltime=120:00:00
    fi

    if [ "$max_var" == "empty_standard" ]; then
        echo "$job_script" | qsub -N MD_dehy -S /bin/bash -q csp-standard -l nodes=6:ppn=32,walltime=24:00:00
    fi
