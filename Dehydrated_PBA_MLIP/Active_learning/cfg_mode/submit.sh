#!/bin/bash
#PBS -N MLIP3_lv12
#PBS -S /bin/bash
#PBS -q mono
#PBS -l walltime=1008:00:00,nodes=1:ppn=1
ulimit -s unlimited
cd $PBS_O_WORKDIR
module load icc/20 impi/20 mkl/20
module load python/anaconda3

sleep 5
#./use_huge.sh
#./use_large.sh
#./restart-run.sh
#./after_vasp.sh
#./boost.sh
#./train.sh
#./train_force.sh
#./train_stress.sh
#./train_force_scale.sh
#./select.sh
./start-run.sh
#./run_lammps.sh
#./train_multiple.sh
