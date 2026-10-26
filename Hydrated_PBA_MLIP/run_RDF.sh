#!/bin/bash
export OMP_NUM_THREADS=1
export LC_NUMERIC=C

echo "lammps MD is starting"

num_Na=(32 28 28)
num_O=(32 16 4)
mu=(-3.5 -5.2 -5)
temp=300
current_dir=RDF_lv20_vac
current_mtp=curr.almtp
mkdir -p ${current_dir}
list=($(seq 1 1 1))
for i in "${list[@]}"; do
    index=$((i - 1))
    current_Na=${num_Na[$index]}
    current_O=${num_O[$index]}
    current_mu=${mu[$index]}
    current_data="400K_10.data" #"Na_${current_Na}_O_${current_O}.data"
    random_seed=$((RANDOM % 9999999 + 1))
    current_input="Na_${current_Na}_O_${current_O}_RDF_${current_dir}.my"
    cp RDF.my $current_input

    echo "input file: ${current_input}"
    echo "data file: ${current_data}"
    echo "seed ${random_seed}"
    echo "mu ${current_mu}"
    echo "log Na_${current_Na}_O_${current_O}_temp.log"
    echo "current_dir ${current_dir}"
    echo "current_mtp ${current_mtp}"
    echo ""


    # Update `in_test.my` file
    sed -i "5s|.*|variable Na equal ${current_Na}|" $current_input
    sed -i "6s|.*|variable O equal ${current_O}|" $current_input
    sed -i "9s|.*|variable current_dir string  ${current_dir}|" $current_input
    sed -i "11s|.*|read_data  ${current_data}|" $current_input
    #sed -i "11s|.*|read_restart RDF_lv16_E0_sf0.1_f0.1/Na_32_O_32_temp_restart.1000000|" $current_input
    sed -i "12s|.*|variable mu equal ${current_mu}|" $current_input
    sed -i "21s|.*|variable seed index ${random_seed}|" $current_input
    sed -i "32s|.*|pair_style  mlip load_from=${current_mtp}|" $current_input
    sed -i "42s|.*|dump dump all custom 4000 ${current_dir}/dump.Na_${current_Na}_O_${current_O}_temp.trj id type x y z|" $current_input
    sed -i "43s|.*|restart 50000 ${current_dir}/Na_${current_Na}_O_${current_O}_temp_restart|" $current_input
    sed -i "44s|.*|#log ${current_dir}/Na_${current_Na}_O_${current_O}_temp.log|" $current_input
    sed -i "60s|.*|fix rdf_output all ave/time 50 20 4000 c_myRDF[*] file ${current_dir}/${temp}K_rdf_Na_${current_Na}_O_${current_O}.rdf mode vector|" $current_input
    sed -i '74s|.*|write_data ${current_dir}/Na_${Na}_O_${O}_0.data|' $current_input
    sed -i '75s|.*|write_dump all custom ${current_dir}/Na_${Na}_O_${O}_0.dump id type x y z|' $current_input
    sed -i '80s|.*|    print "OUTER ITERATION: ${N} MU: ${mu}"|' $current_input
    sed -i "95s|.*|    fix fgcmc Na gcmc 4000 2000 2000 5 ${random_seed} ${temp} ${current_mu} 0.1 full_energy region system|" $current_input
    sed -i '107s|.*|    write_data ${current_dir}/Na_${Na}_O_${O}_${M}.data|' $current_input
    sed -i '108s|.*|    write_dump all custom ${current_dir}/Na_${Na}_O_${O}_${M}.dump id type x y z|' $current_input
    sed -i "124s|.*|write_data ${current_dir}/Na_${current_Na}_O_${current_O}_final.data|" $current_input
    sed -i "125s|.*|write_dump all custom ${current_dir}/Na_${current_Na}_O_${current_O}_final.dump id type x y z|" $current_input

    job_script=$(cat <<EOF
#!/bin/bash
ulimit -s unlimited
cd \$PBS_O_WORKDIR
module purge
module load gcc/11.4.0 ompi mkl/2025.3
export LD_LIBRARY_PATH=/K/av245900/Codes/lammps_mlip3_2026_06_01/lammps/src:$LD_LIBRARY_PATH
mpirun -np 192 /W/av245900/HT-SHARE/binaries/lammps_mlip3_gcc11.4.0_ompi4.1.8_mkl2025.3 -in $current_input -log  ${current_dir}/300_temp.log
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
        echo "$job_script" | qsub -N RDF_${i} -S /bin/bash -q huge -l nodes=3:ppn=64,walltime=120:00:00
    fi

    if [ "$max_var" == "empty_large" ]; then
        echo "$job_script" | qsub -N RDF_${i} -S /bin/bash -q large -l nodes=5:ppn=40,walltime=120:00:00
    fi

    if [ "$max_var" == "empty_standard" ]; then
        echo "$job_script" | qsub -N RDF_${i} -S /bin/bash -q csp-standard -l nodes=6:ppn=32,walltime=24:00:00
    fi

    if [[ $? -ne 0 ]]; then
        echo "Job submission failed for in_${i}.my"
        cat qsub_${i}.log
    else
        echo "Job in_${i}.my submitted successfully"
    fi
    sleep 3
done