#!/bin/bash
#PBS -N vDOS
#PBS -S /bin/bash
#PBS -q mono
#PBS -l walltime=1008:00:00,nodes=1:ppn=1
ulimit -s unlimited
cd $PBS_O_WORKDIR
module load gcc/11.4.0 ompi mkl/2025.3
export LD_LIBRARY_PATH=/K/av245900/Codes/lammps_mlip3_2026_06_01/lammps/src:$LD_LIBRARY_PATH

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
#./start-run.sh
#./run_lammps.sh
#./train_multiple.sh

wait_for_jobs() {
    echo "Waiting for jobs to complete..."
    is_training_finished=0
    while [ $is_training_finished -ne 1 ]; do
        sleep 10  # Check every 10 seconds
        cfg_cal=$(qstat | grep yy276937 | grep "_diff_" | wc -l)
        
        if [ "$cfg_cal" -gt 2 ]; then
            echo "$(date) - There are $cfg_cal jobs still running"
        else
            echo "$(date) - Time to run more simulation!!!"
            is_training_finished=1
        fi
    done
    sleep 3
}

wait_for_jobs
./MDANSE.sh