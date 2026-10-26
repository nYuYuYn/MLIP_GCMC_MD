#!/bin/bash
#PBS -N MD_h2o
#PBS -q large
#PBS -l walltime=12:00:00,nodes=1:ppn=40
#PBS -j oe
#PBS -o multi_lammps.log

echo "lammps MD is starting"
rm is_lammps_finished_*.txt

ulimit -s unlimited
cd $PBS_O_WORKDIR

# Load Modules
module purge
#module load icc/20 impi/20 mkl/20 python/maxiforge || { echo "Module load failed"; exit 1; }
module load gcc/11.4.0 ompi mkl/2025.3
export LD_LIBRARY_PATH=/K/av245900/Codes/lammps_mlip3_2026_06_01/lammps/src:$LD_LIBRARY_PATH
export OMP_NUM_THREADS=1
export LC_NUMERIC=C

cut_off=0.5

# --- Configuration ---
num_jobs=40

mu_values=(-7 -6.5 -5 -4.5 -4 -3.5 -3 -2.5 -2 -1.5 -1 -0.5 0 0.5 1)

echo "Generating input files and launching $num_jobs jobs..."

for i in $(seq 1 $num_jobs); do
    idx=$((i - 1))

    #if [ $i -le 15 ]; then
    #    current_data="h2o_16_300K_2_full.data"
    #elif [ $i -le 30 ]; then
    #    current_data="vac_no_Na_1_full.data"
    #else
    #    current_data="Na_0_O_0_full.data"
    #fi 
    # Structure assignment
    if [ $i -le 8 ]; then
        current_data="vac_no_Na_1_full.data"
    elif [ $i -le 16 ]; then
        current_data="vac_no_Na_2_full.data"
    elif [ $i -le 24 ]; then
        current_data="vac_no_Na_3_full.data"
    elif [ $i -le 32 ]; then
        current_data="vac_no_Na_4_full.data"
    else
        current_data="vac_w_Na_1_full.data"
    fi

    # μ assignment: repeats every 8 jobs
    mu_index=$(( (i - 1) % 8 ))
    current_mu="${mu_values[$mu_index]}"

    current_temp=400 #"${temp[$idx]}"
    current_input="input_${i}.my"

    random_seed=$(( (RANDOM + i) % 9999999 + 1 ))

    echo "Job $i: data=$current_data, mu=$current_mu"

    # Prepare input file
    cp in_test.my "$current_input"

    # Use | as delimiter in sed to avoid issues with paths/slashes
    sed -i "5s|.*|variable T equal ${current_temp}|" $current_input
    sed -i "8s|.*|read_data ${current_data}|" $current_input
    sed -i "18s|.*|variable seed index ${random_seed}|" $current_input
    sed -i "25s|.*|#delete_atoms group Na|" $current_input
    sed -i "26s|.*|pair_style mlip load_from=curr.almtp extrapolation_control=true extrapolation_control:threshold_break=6 extrapolation_control:threshold_save=1.6 extrapolation_control:save_extrapolative_to=preselected_${i}.cfg|" $current_input
    sed -i "40s|.*|dump dump all atom 200 dump.gcmc_no_Na_20_${i}.trj|" $current_input

    #################### H2O GCMC ####################
    sed -i "72s|.*|fix halt_upper O halt 2000 v_nO > 80 error continue|" $current_input
    sed -i "74s|.*|fix fgcmc_h2o H2O gcmc 8000 100 0 0 ${random_seed} ${current_temp} ${current_mu} 0.2 mol h2omol group H2O region system overlap_cutoff ${cut_off}|" $current_input
    sed -i "83s|.*|unfix fgcmc_h2o|" $current_input
    #################### H2O GCMC ####################

    #################### Na GCMC style: atomic ####################
    sed -i "71s|.*|#fix halt_upper Na halt 2000 v_nNa > 32 error continue|" $current_input
    sed -i "73s|.*|#fix fgcmc_na Na gcmc 3000 30 0 0 ${random_seed} ${current_temp} ${current_mu} 0.2 mol Namol group Na full_energy region system overlap_cutoff ${cut_off}|" $current_input
    sed -i "82s|.*|#unfix fgcmc_na|" $current_input
    #################### Na GCMC style: atomic ####################

    sed -i "89s|.*|write_data MnFePBA_gcmc_${i}.data|" $current_input
    sed -i "90s|.*|write_dump all atom MnFePBA_gcmc_dump_${i}.trj|" $current_input

    # Launch Job in background
    (
        echo "Starting job $i on core $idx"
        # taskset pins the process to a specific CPU core
        taskset -c $idx /W/av245900/HT-SHARE/binaries/lammps_mlip3_gcc11.4.0_ompi4.1.8_mkl2025.3 -in $current_input -log gcmc_${i}.log
        echo "1" > is_lammps_finished_${i}.txt
    ) &
done

wait
echo "All $num_jobs jobs finished."