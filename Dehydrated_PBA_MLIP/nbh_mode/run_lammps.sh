#!/bin/bash
export OMP_NUM_THREADS=1
echo "lammps MD is starting"
for i in 1 2 3 4; do
  job_script=$(cat <<EOF
#!/bin/bash
ulimit -s unlimited
cd $PBS_O_WORKDIR
module purge
module load icc/20 impi/20 mkl/20 || { echo "Failed to load Intel modules"; exit 1; }
module load python/anaconda3 || { echo "Failed to load Anaconda module"; exit 1; }
mpirun -np 64 /W/av245900/HT-SHARE/binaries/lammps_mlip3_icc20_impi20_mkl20 -in in_${i}.my -log gcmc_${i}.log
echo "1" >> is_lammps_finished_${i}.txt
EOF
)

  echo "$job_script" | qsub -N MD_nbh_${i} -S /bin/bash -q huge -l nodes=1:ppn=64,walltime=120:00:00

  if [[ $? -ne 0 ]]; then
    echo "Job submission failed for in_${i}.my"
    cat qsub_${i}.log
  else
    echo "Job in_${i}.my submitted successfully"
  fi
done

sleep 10

echo "Monitoring job completion..."
files_to_check=("is_lammps_finished_1.txt" "is_lammps_finished_2.txt" "is_lammps_finished_3.txt" "is_lammps_finished_4.txt")

while true; do
  all_exist=true
  for file in "${files_to_check[@]}"; do
    if [[ ! -f $file ]]; then
      all_exist=false
      break
    fi
  done

  if $all_exist; then
    echo "All LAMMPS simulations are finished"
    break
  fi

  echo "Waiting for all jobs to finish..."
  sleep 30  # Check every 30 seconds
done

echo "lammps MD completed"
echo "1" >> is_lammps_finished.txt
