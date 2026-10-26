#!/bin/bash
rm MD_h2o*
rm MD_selection*
rm MD_train*
rm MLIP3_H2O_lv12*
rm MD_selection*

module load gcc/11.4.0 ompi mkl/2025.3
export LD_LIBRARY_PATH=/K/av245900/Codes/lammps_mlip3_2026_06_01/lammps/src:$LD_LIBRARY_PATH
for p in $(seq 1 1000 )
do
	echo "active learning on MnFePw is starting"
    if echo $p > curr_cycle; then
        echo "Successfully wrote $p to curr_cycle"
    else
        echo "Failed to write $p to curr_cycle"
        exit 1
    fi
	./md_al_mtp_2.sh
    mkdir MD_analysis/${p}
    mv POSCAR* MD_analysis/${p}
    cp train.cfg pot_save/
    cp curr.almtp pot_save/
    cd pot_save
    mv timestep.txt timestep${p}.txt
	../mlip check_errors curr.almtp train.cfg >> report.txt
	mv report.txt report_${p}.txt
	mv train.cfg train_${p}.cfg
	cp curr.almtp curr_${p}.almtp
	cd ../
	cp pot_save/curr.almtp .
done
