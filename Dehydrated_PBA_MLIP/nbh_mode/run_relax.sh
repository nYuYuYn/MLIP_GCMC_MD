#!/bin/bash
export OMP_NUM_THREADS=1
mpirun -np 32 /W/av245900/HT-SHARE/binaries/lammps_mlip3_icc20_impi20_mkl20 -in relax.my 
