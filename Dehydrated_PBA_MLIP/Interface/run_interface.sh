#!/bin/bash
export OMP_NUM_THREADS=1

x_size=(96 128)
list=($(seq 10 1 11))  # Sequence of numbers from 1 to 8

for i in "${list[@]}"; do
    dx=$((i - 9))
    current_x="${x_size[$dx]}"
    random_seed=$((RANDOM % 9999999 + 1))
    current_input="interface_free_${i}.my"
    #cp interface_free.my "$current_input"
    #cp interface_equil.my "$current_input"
    cp interface_free.my "$current_input"
# free: To create the interface by deleting Na on one hald size of the system
# equil: To run NPT to equilibrate the system
# NPBC: NPT at non PBC to simulate the free surface
    echo "current input: ${current_input}"
    #echo "current data: interface/interface_equil_${i}.data"
    echo "current data: MnFePBA_300K.data"
    echo "system size: ${current_x} * 8 * 8"
    echo "seed ${random_seed}"
    echo ""

    #sed -i "10s|.*|read_data  interface/interface_equil_${i}.data|" $current_input
    sed -i "10s|.*|read_data  300K_interface_${i}.data|" $current_input
    #sed -i "10s|.*|read_data MnFePBA_300K.data|" $current_input
    #sed -i "11s|.*|replicate ${current_x} 8 8|" $current_input
    #sed -i "11s|.*|replicate 1 1 1|" $current_input
    sed -i "6s|.*|variable N equal ${i}|" $current_input
    sed -i "7s|.*|variable n equal ${i}|" $current_input


    job_script=$(cat <<EOF
#!/bin/bash
ulimit -s unlimited
cd \$PBS_O_WORKDIR
module purge
module load icc/20 impi/20 mkl/20 || { echo "Failed to load Intel modules"; exit 1; }
module load python/maxiforge || { echo "Failed to load Anaconda module"; exit 1; }
mpirun -np 192 /W/av245900/HT-SHARE/binaries/lammps_mlip3_icc20_impi20_mkl20 -in $current_input 
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
        echo "$job_script" | qsub -N interface_${i} -S /bin/bash -q huge -l nodes=3:ppn=64,walltime=120:00:00
    fi
    
    if [ "$max_var" == "empty_large" ]; then
        echo "$job_script" | qsub -N interface_${i} -S /bin/bash -q large -l nodes=5:ppn=40,walltime=120:00:00
    fi
    
    if [ "$max_var" == "empty_standard" ]; then
        echo "$job_script" | qsub -N interface_${i} -S /bin/bash -q csp-standard -l nodes=6:ppn=32,walltime=24:00:00
    fi
    
    sleep 2
done