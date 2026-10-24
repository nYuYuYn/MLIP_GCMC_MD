#!/bin/bash
export OMP_NUM_THREADS=1
export LC_NUMERIC=C

N=10
temp=300
current_input=${temp}K_RDF_${N}.my
current_data=1100_bias_105.data
#300loop_bias_1.data
#Na_${N}_${temp}K.data
cp relax.my $current_input

sed -i "5s|.*|variable T equal ${temp}|" $current_input
sed -i "6s|.*|variable N equal ${N}|" $current_input
sed -i "8s|.*|read_data ${current_data}|" $current_input

job_script=$(cat <<EOF
#!/bin/bash
ulimit -s unlimited
cd \$PBS_O_WORKDIR
module purge
module load icc/20 impi/20 mkl/20 || { echo "Failed to load Intel modules"; exit 1; }
module load python/anaconda3 || { echo "Failed to load Anaconda module"; exit 1; }
mpirun -np 64 /W/av245900/HT-SHARE/binaries/lammps_mlip3_icc20_impi20_mkl20 -in $current_input #-log Nt_${current_temp}/loop_bias_${i}.log
echo "1" >> is_lammps_finished_${i}.txt
EOF
    )
while read queue count; do
    # Replace dash with underscore in variable names
    queue_var=$(echo "$queue" | tr '-' '_')
    eval "$queue_var=$count"
done <<< "$running_cores"

empty_huge=$((2000 - huge))
empty_large=$((2000 - large))
empty_standard=$((2000 - csp_standard - csp_long))

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
    echo "$job_script" | qsub -N RDF_${N}_${temp}K -S /bin/bash -q huge -l nodes=1:ppn=64,walltime=120:00:00
fi

if [ "$max_var" == "empty_large" ]; then
    echo "$job_script" | qsub -N RDF_${N}_${temp}K -S /bin/bash -q large -l nodes=2:ppn=40,walltime=120:00:00
fi

if [ "$max_var" == "empty_standard" ]; then
    echo "$job_script" | qsub -N RDF_${N}_${temp}K -S /bin/bash -q csp-standard -l nodes=2:ppn=32,walltime=24:00:00
fi

if [[ $? -ne 0 ]]; then
    echo "Job submission failed for in_${i}.my"
    cat qsub_${i}.log
else
    echo "Job in_${i}.my submitted successfully"
fi
sleep 3
export OMP_NUM_THREADS=1
