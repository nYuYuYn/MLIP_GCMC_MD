#!/bin/bash


echo "selection is starting"

job_script=$(cat <<EOF
#!/bin/bash
ulimit -s unlimited
cd $PBS_O_WORKDIR
module purge
module load icc/20 impi/20 mkl/20 || { echo "Failed to load Intel modules"; exit 1; }
module load python/anaconda3 || { echo "Failed to load Anaconda module"; exit 1; }
mpirun -np 64 /W/av245900/HT-SHARE/binaries/mlip3_icc20_impi20_mkl20 select_add curr.almtp train.cfg preselected.cfg selected.cfg 
echo "1" >> is_selection_finished.txt
EOF
)

echo "$job_script" | qsub -N MD_selection -S /bin/bash -q huge -l nodes=1:ppn=64,walltime=120:00:00

echo "selection completed"

