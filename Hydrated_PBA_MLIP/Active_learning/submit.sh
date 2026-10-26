#!/bin/bash
#PBS -N free_E
#PBS -S /bin/bash
#PBS -q mono
#PBS -l walltime=1008:00:00,nodes=1:ppn=1
ulimit -s unlimited
cd $PBS_O_WORKDIR
module load gcc/11.4.0 ompi mkl/2025.3
export LD_LIBRARY_PATH=/K/av245900/Codes/lammps_mlip3_2026_06_01/lammps/src:$LD_LIBRARY_PATH

#mlip calculate_efs ./MTP/curr_20_cfg_r02_70.almtp ./train.cfg --output_filename=./MTP/cal_train_20_r02_70.cfg

#mlip calculate_efs ./curr.almtp ./train.cfg --output_filename=./MTP/cal_train_20_r02_65.cfg

mlip calculate_efs ./MTP/curr_20_cfg_r02_60.almtp ./validation/vac_AIMD.cfg --output_filename=./validation/cal_vac_AIMD_20_r02_60.cfg

#mlip calculate_efs ./MTP/curr_20_cfg_r02_70.almtp ./validation/vacancy/vacancy.cfg --output_filename=./validation/cal_vacancy_20_r02_70.cfg

#mlip calculate_grade ./MTP/curr_20_cfg_r02_65.almtp ./validation/vac_AIMD.cfg ./validation/grade_vac_AIMD_20_r02_65.cfg

#mlip calculate_efs ./MTP/curr_20_cfg_r02.almtp ./validation/vacancy/vacancy.cfg --output_filename=./validation/cal_vacancy_20_r02.cfg
#mlip calculate_efs ./MTP/curr_16_cfg_r02.almtp ./validation/vacancy/vacancy.cfg --output_filename=./validation/cal_vacancy_16_r02.cfg
#mlip calculate_efs ./MTP/curr_20_cfg.almtp ./validation/vacancy/vacancy.cfg --output_filename=./validation/cal_vacancy_20.cfg
#mlip calculate_efs ./MTP/curr_16.almtp ./validation/vacancy/vacancy.cfg --output_filename=./validation/cal_vacancy_16.cfg
#sleep 5

#./run_loop_bias_vac.sh
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
#is_training_finished=0
#./run_loop_bias_300_3.sh
#./run_loop_bias_vac.sh
#./run_restart_diffuse.sh

wait_for_jobs() {
    echo "Waiting for jobs to complete..."
    is_training_finished=0
    while [ $is_training_finished -ne 1 ]; do
        sleep 10  # Check every 10 seconds
        cfg_cal=$(qstat | grep yy276937 | grep "_diff_" | wc -l)
        
        if [ "$cfg_cal" -gt 0 ]; then
            echo "$(date) - There are $cfg_cal jobs still running"
        else
            echo "$(date) - Time to run more simulation!!!"
            is_training_finished=1
        fi
    done
    sleep 3
}

#wait_for_jobs
#./../MDANSE.sh

is_vasp_finished=0
while [ $is_vasp_finished -ne 1 ]
do
    sleep 10
    cfg_cal=$(qstat | grep yy276937 | grep "MD_trainin" | wc -l)
    
    if [ "$cfg_cal" -gt 0 ]; then
        echo "There are $cfg_cal jobs still running"
        is_vasp_finished=0
        echo $is_vasp_finished
    else
        echo All jobs are finished
        is_vasp_finished=1
        echo $is_vasp_finished
    fi
done

#./start-run.sh
#./run_lammps.sh
#./train_multiple.sh
