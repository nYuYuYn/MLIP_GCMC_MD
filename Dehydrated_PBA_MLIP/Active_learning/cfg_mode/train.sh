#!/bin/bash
echo "training is starting"

job_script=$(cat <<EOF
#!/bin/bash
ulimit -s unlimited
cd $PBS_O_WORKDIR
module purge
module load icc/20 impi/20 mkl/20 || { echo "Failed to load Intel modules"; exit 1; }
module load python/anaconda3 || { echo "Failed to load Anaconda module"; exit 1; }
mpirun -np 192 /W/av245900/HT-SHARE/binaries/mlip3_icc20_impi20_mkl20 train curr.almtp train.cfg --iteration_limit=10000 --al_mode=cfg  --weight_scaling_forces=1 --weight_scaling=2 --save_to=curr.almtp 
echo "1" >> is_training_finished.txt
EOF
)

echo "$job_script" | qsub -N MD_training -S /bin/bash -q huge -l nodes=3:ppn=64,walltime=120:00:00

echo "Monitoring job completion..."
files_to_check=("is_training_finished.txt")

while true; do
  all_exist=true
  for file in "${files_to_check[@]}"; do
    if [[ ! -f $file ]]; then
      all_exist=false
      break
    fi
  done

  if $all_exist; then
    echo "Training MLIP has finished"
    break
  fi

  echo "Waiting for training finish..."
  sleep 30  # Check every 30 seconds
done

echo "training completed"