#!/bin/bash
#PBS -N AIMD_Na16
#PBS -S /bin/bash
#PBS -q huge
#PBS -l walltime=168:00:00,nodes=3:ppn=64
ulimit -s unlimited
cd $PBS_O_WORKDIR
module purge
module load EXTRA icc/20 mkl/20 impi/20 hdf5/1.10.2 libxc/5.2.0
BIN=/W/av245900/Codes/VASP_6.4.2_shmem/vasp.6.4.2/bin/vasp_gam

list=(4)
index=(0)

for i in "${list[@]}"; do
    for j in "${index[@]}"; do
        current_poscar="POSCAR_h2o_${i}_${j}"
        echo "current POSCAR: ${current_poscar}"
        cp ${current_poscar} POSCAR
        
        numbers=$(awk 'NR==7 {print $1, $2, $3, $4, $5, $6, $7}' POSCAR) 
        read n_C n_Mn n_Fe n_N n_Na n_O n_H <<< "$numbers" 
        replacement="MAGMOM = $n_C*0.0 $n_Mn*5.0 $n_Fe*0.0 $n_N*0.0 $n_Na*0.0 $n_O*0.0 $n_H*0.0"
        sed -i "23s/.*/$replacement/" INCAR
        mv ML_ABN ML_AB
        mv ML_FFN ML_FF
        mpirun -np $PBS_NP $BIN
        sleep 100
        mkdir ./pot_save/"${i}_${j}"
        mv CONTCAR XDATCAR OSZICAR ML_LOGFILE vaspout.h5 ./pot_save/"${i}_${j}"
    done
done
        
    
    

