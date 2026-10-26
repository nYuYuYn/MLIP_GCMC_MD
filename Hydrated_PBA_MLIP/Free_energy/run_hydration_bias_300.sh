#!/bin/bash
#PBS -N H2O_free_E_3
#PBS -q huge
#PBS -l walltime=120:00:00,nodes=1:ppn=64
#PBS -j oe
#PBS -o multi_lammps.log

ulimit -s unlimited
cd $PBS_O_WORKDIR

# Load Modules
module purge
#module load icc/20 impi/20 mkl/20 python/maxiforge || { echo "Module load failed"; exit 1; }
module load gcc/11.4.0 ompi mkl/2025.3
export LD_LIBRARY_PATH=/K/av245900/Codes/lammps_mlip3_2026_06_01/lammps/src:$LD_LIBRARY_PATH
export OMP_NUM_THREADS=1
export LC_NUMERIC=C

current_fi=0.1
current_mu=-1
Nt_0=0
current_temp=300

dir=1
i=1
trial=1

N=($(seq 1 1 30))
for j in "${N[@]}"; do
    idx=$((j - 1))
    last_N="${N[$idx]}"
    mkdir -p Nt_H_vac_${current_temp}/${i}
    current_data="vac_w_Na_1.data"
    #/K/yy276937/MTP_AIMD/hydration/free_E_lammps_data/Na_32_O_32_${j}.data
    
    random_seed=$((RANDOM % 9999999 + 1))
    current_input=Nt_H_vac_${current_temp}/${i}/${current_temp}_hydration_bias_${dir}_${last_N}.my
    cp loop_bias_hydration.my $current_input
    
    echo "Processing index $i with MTP file"
    echo "current temp: ${current_temp}"
    echo "input file: ${current_input}"
    echo "data file: ${current_data}"
    echo "mu: ${current_mu}"
    echo "fi: ${current_fi}"
    echo "last_N: ${last_N}"
    echo "seed ${random_seed}"
    echo "log Nt_${current_temp}/${i}/loop_bias_${i}.log_${last_N}"
    echo ""

    # Update `in_test.my` file
    sed -i "5s|.*|variable T equal ${current_temp}|" $current_input
    sed -i "6s|.*|variable i equal ${i}|" $current_input
    sed -i "8s|.*|read_data ${current_data}|" $current_input
    #sed -i "8s|.*|read_restart ${current_data}.*|" $current_input
    sed -i "17s|.*|variable seed index ${random_seed}|" $current_input
    sed -i "25s|.*|pair_style mlip load_from=./curr.almtp|" $current_input
    sed -i "41s|.*|log Nt_H_vac_${current_temp}/${i}/loop_bias_${i}.log_${j}|" $current_input
    sed -i "42s|.*|dump dump all custom 1000 Nt_H_vac_${current_temp}/${i}/dump.loop_bias_${i}_${j}.trj id type x y z|" $current_input
    sed -i "43s|.*|restart 10000 Nt_H_vac_${current_temp}/${i}/${current_temp}_restart_${j}|" $current_input
    sed -i "68s|.*|variable        N loop ${last_N} ${last_N}|" $current_input
    sed -i "69s|.*|variable        currNt equal ${Nt_0}+(v_N-1)*2|" "$current_input"
    sed -i "79s|.*|    variable k equal ${current_fi}|" $current_input
    sed -i "121s|.*|    fix fgcmc_h2o H2O gcmc 1000 10 0 0 ${random_seed} ${current_temp} ${current_mu} 0.1 mol h2omol group H2O region system overlap_cutoff 0.5|" $current_input
    sed -i '91c\    fix logAtoms all print 1000 \"${step} ${atoms}\" file Nt_H_vac_${T}/${i}/atoms_log_${N}.txt screen no title "Step Atoms"' $current_input
    sed -i '122c\        fix avgNa all ave/time 10 100 10000 v_total_atoms file Nt_H_vac_${T}/${i}/${T}_converge_${N}.txt mode scalar' $current_input
    sed -i '123c\        fix avgEnergy all ave/time 10 100 10000 c_thermo_pe file Nt_H_vac_${T}/${i}/${T}_energy_${N}.txt mode scalar' $current_input
    sed -i '163c\    write_data Nt_H_vac_${T}/${i}/${T}loop_bias_${N}.data' $current_input

    (
        echo "Starting job $i on core $idx"
        # taskset pins the process to a specific CPU core
        taskset -c $idx /W/av245900/HT-SHARE/binaries/lammps_mlip3_gcc11.4.0_ompi4.1.8_mkl2025.3 -in $current_input
    ) &
done

wait
echo "All $num_jobs jobs finished."    