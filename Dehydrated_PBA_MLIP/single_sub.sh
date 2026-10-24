#!/bin/bash
#PBS -N NOT_AGAIN
#PBS -S /bin/bash
#PBS -q mono
#PBS -l walltime=1008:00:00,nodes=1:ppn=1
ulimit -s unlimited
cd $PBS_O_WORKDIR
echo $PBS_O_WORKDIR
module load gcc/11.4.0 ompi mkl/2025.3
export LD_LIBRARY_PATH=/K/av245900/Codes/lammps_mlip3_2026_06_01/lammps/src:$LD_LIBRARY_PATH

./run_loop_bias_300_1.sh
./run_loop_bias_400_1.sh
./run_loop_bias_500_1.sh
./run_loop_bias_600_1.sh
./run_loop_bias_700_1.sh

