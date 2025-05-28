#!/bin/bash
echo "training is starting"
mpirun -np 64 /W/av245900/HT-SHARE/binaries/mlip3_icc20_impi20_mkl20 train curr.almtp train.cfg --iteration_limit=10000 --al_mode=nbh --site_en_weight=1 --weight_scaling_forces=1 --weight_scaling=2  --save_to=curr.almtp 
#--force_weight=0.5 --stress_weight=0.05
echo "training completed"
echo "1" >> is_training_finished.txt

