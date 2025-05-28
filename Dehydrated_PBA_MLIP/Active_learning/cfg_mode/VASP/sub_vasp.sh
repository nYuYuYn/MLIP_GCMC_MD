#!/bin/bash
#PBS -N PBA_PBC_nbh_%i
#PBS -S /bin/bash
#PBS -q csp
#PBS -l walltime=24:00:00,nodes=2:ppn=32
ulimit -s unlimited
cd $PBS_O_WORKDIR
module purge
module load EXTRA vasp/6.4.2
BIN=/home/prog/usr/prod/applications/vasp/6.4.2/bin/vasp_gam
mpirun -np $PBS_NP $BIN
echo "1" >> is_vasp_finished.txt
