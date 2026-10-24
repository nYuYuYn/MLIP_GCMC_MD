#!/bin/sh
echo "pre-train is starting"
mpirun -np 64 /W/av245900/HT-SHARE/binaries/mlip3_icc20_impi20_mkl20 train init_16.almtp train_one.cfg --iteration_limit=10000 --al_mode=nbh  --site_en_weight=1 --force_weight=0.05 --stress_weight=0.005 --weight_scaling_forces=1 --weight_scaling=2  --save_to=nbh_20.almtp
echo "pre-train completed"
echo "1" >> is_training_finished.txt

