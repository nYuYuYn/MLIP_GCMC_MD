#!/bin/bash
#PBS -N hydration
#PBS -S /bin/bash
#PBS -q large
#PBS -l walltime=120:00:00,nodes=1:ppn=40
#PBS -j oe
#PBS -o hydration.log

module purge
module load icc/20 impi/20 mkl/20 || { echo "Failed to load Intel modules"; exit 1; }
module load python/maxiforge || { echo "Failed to load Anaconda module"; exit 1; }

ulimit -s unlimited
cd $PBS_O_WORKDIR

export OMP_NUM_THREADS=1
export LC_NUMERIC=C

echo "lammps MD is starting"

#num_Na=(32 32 32 32 32 32 32 32)
#num_O=(32 32 32 32 32 32 32 32)
mu=($(seq -1.5 0.02 1.9)) #(-4.5 -4 -3.5 -3 -2.5 -2 -1.5 -1)
temp=300
current_dir=lv16_hydration_3
current_mtp=./MTP/curr_lv16.almtp
#current_mtp=./curr.almtp
mkdir -p ${current_dir}

num_jobs=40
list=($(seq 1 1 40))
for i in "${list[@]}"; do
    index=$((i - 1))
    #current_Na=${num_Na[$index]}
    #current_O=${num_O[$index]}
    current_mu=${mu[$index]}
    current_data="MnFePBA_300K_full.data"
    #"h2o_16_300K_2_full.data"
    #"MnFePBA_300K_full.data"
    #"Na14"   #"h2o_16_300K_2_full.data"
    random_seed=$((RANDOM % 9999999 + 1))
    current_input="hydration_${i}.my"
    
    cp hydration.my $current_input

    echo "input file: ${current_input}"
    echo "data file: ${current_data}"
    echo "seed ${random_seed}"
    echo "mu ${current_mu}"
    #echo "log Na_${current_Na}_O_${current_O}_temp.log"
    echo "current_dir ${current_dir}"
    echo "current_mtp ${current_mtp}"
    echo ""


    # Update `in_test.my` file
    #sed -i "4s|.*|variable Na equal ${current_Na}|" $current_input
    #sed -i "5s|.*|variable O equal ${current_O}|" $current_input
    sed -i "6s|.*|variable T equal ${temp}|" $current_input
    sed -i "7s|.*|variable N equal ${i}|" $current_input
    sed -i "8s|.*|variable current_dir string  ${current_dir}|" $current_input
    sed -i "10s|.*|read_data  ${current_data}|" $current_input
    #sed -i "11s|.*|read_restart RDF_lv16_E0_sf0.1_f0.1/Na_32_O_32_temp_restart.1000000|" $current_input
    sed -i "12s|.*|variable mu equal ${current_mu}|" $current_input
    sed -i "21s|.*|variable seed index ${random_seed}|" $current_input
    sed -i "34s|.*|pair_style  mlip load_from=${current_mtp}|" $current_input
    sed -i "48s|.*|dump dump all custom 2000 ${current_dir}/dump.hydration_${i}.trj id type x y z|" $current_input
    sed -i "49s|.*|restart 20000 ${current_dir}/hydration_${i}_restart|" $current_input
    sed -i "50s|.*|log ${current_dir}/hydration_${i}.log|" $current_input
    sed -i "65s|.*|fix rdf_output all ave/time 50 10 2000 c_myRDF[*] file ${current_dir}/${temp}K_rdf_hydration_${i}_.rdf mode vector|" $current_input
    sed -i "69s|.*|dump ONa_dump O custom 2000 ${current_dir}/${temp}K_ONa_coord_hydration_${i}.txt id type c_ONacoord|" $current_input
    sed -i "70s|.*|dump NaN_dump Na custom 2000 ${current_dir}/${temp}K_NaN_coord_hydration_${i}.txt id type c_ONacoord|" $current_input
    sed -i "79s|.*|write_data ${current_dir}/hydration_${i}_0.data|" $current_input
    sed -i "80s|.*|write_dump all custom ${current_dir}/hydration_${i}_0.dump id type x y z|" $current_input
    sed -i '86s|.*|    print "OUTER ITERATION: ${N} MU: ${mu}"|' $current_input
    sed -i "100s|.*|    fix fgcmc H2O gcmc 8000 20 0 0 ${random_seed} ${temp} ${current_mu} 0.2 mol h2omol group H2O region system overlap_cutoff 0.5|" $current_input
    #sed -i "101s|.*|    fix fgcmc_Na Na gcmc 2000 0 300 5 ${random_seed} ${temp} -2 0.1 full_energy region system|" $current_input
    sed -i '113s|.*|    write_data ${current_dir}/hydration_${N}_${M}.data|' $current_input
    sed -i '114s|.*|    write_dump all custom ${current_dir}/hydration_${N}_${M}.dump id type x y z|' $current_input
    sed -i "127s|.*|write_data ${current_dir}/hydration_${i}_final.data|" $current_input
    sed -i "128s|.*|write_dump all custom ${current_dir}/hydration_${i}_final.dump id type x y z|" $current_input
done

# Launch jobs on different cores
for ((j=1; j<=num_jobs; j++)); do
  (
    input_file="hydration_${j}.my"
    taskset -c $((j - 1)) mpirun -np 1 /W/av245900/HT-SHARE/binaries/lammps_mlip3_icc20_impi20_mkl20 -in $input_file
  ) &
done

wait
echo "All jobs finished"