#!/bin/bash
#PBS -N AIMD_Na15
#PBS -S /bin/bash
#PBS -q huge
#PBS -l walltime=24:00:00,nodes=2:ppn=64
ulimit -s unlimited
cd $PBS_O_WORKDIR
module purge
module load EXTRA icc/20 mkl/20 impi/20 hdf5/1.10.2 libxc/5.2.0
BIN=/W/av245900/Codes/VASP_6.4.2_shmem/vasp.6.4.2/bin/vasp_gam
mpirun -np $PBS_NP $BIN
