#!/bin/bash
export OMP_NUM_THREADS=1
echo "lammps MD is starting"
mpirun -np 64 /W/av245900/HT-SHARE/binaries/lammps_mlip3_icc20_impi20_mkl20 -in in_1.my -log gcmc_1.log
mpirun -np 64 /W/av245900/HT-SHARE/binaries/lammps_mlip3_icc20_impi20_mkl20 -in in_2.my -log gcmc_2.log
mpirun -np 64 /W/av245900/HT-SHARE/binaries/lammps_mlip3_icc20_impi20_mkl20 -in in_3.my -log gcmc_3.log
mpirun -np 64 /W/av245900/HT-SHARE/binaries/lammps_mlip3_icc20_impi20_mkl20 -in in_4.my -log gcmc_4.log
#if [ -e "$MnFePBA_after.data" ]; then
#	mpirun -np 32 /W/av245900/HT-SHARE/binaries/lammps_mlip3_icc20_impi20_mkl20 -in gcmc.my > log.lammps.gcmc.e
#else
#	echo active learning broke during MD. No GCMC
#fi
echo "lammps MD completed"
echo "1" >> is_lammps_finished.txt
