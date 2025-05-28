#!/bin/bash
#PBS -N MLIP3_nbh_lv12
#PBS -S /bin/bash
#PBS -q huge
#PBS -l walltime=168:00:00,nodes=1:ppn=64
ulimit -s unlimited
cd $PBS_O_WORKDIR
module load icc/20 impi/20 mkl/20
module load python/anaconda3
#./use_huge.sh
#./use_large.sh
#./restart-run.sh
#./boost.sh
#./after_vasp.sh
#./start-run.sh
#./run_lammps.sh
#./no_vasp.sh
#./train.sh
#./after_vasp.sh
./start-run.sh
