#!/bin/bash

#export OMP_NUM_THREADS=1
#src=$(pwd)
#cd $src
echo "selection is starting"
/W/av245900/HT-SHARE/binaries/mlip3_icc20_impi20_mkl20 select_add curr.almtp train.cfg preselected.cfg selected.cfg 
echo "selection completed"
echo "1" >> is_selection_finished.txt
