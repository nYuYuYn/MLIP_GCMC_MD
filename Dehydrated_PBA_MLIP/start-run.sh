#!/bin/bash

for p in $(seq 623 1000 )
do
	echo "active learning on MnFePw is starting"
    if echo $p > curr_cycle.txt; then
        echo "Successfully wrote $p to curr_cycle.txt"
    else
        echo "Failed to write $p to curr_cycle.txt"
        exit 1
    fi
	./md_al_mtp.sh
    mkdir MD_analysis/${p}
    mv POSCAR* MD_analysis/${p}
	mv gcmc_1.log pot_save/gcmc_1_${p}.log
    mv gcmc_2.log pot_save/gcmc_2_${p}.log
    mv gcmc_3.log pot_save/gcmc_3_${p}.log
    mv gcmc_4.log pot_save/gcmc_4_${p}.log
    mv gcmc_5.log pot_save/gcmc_5_${p}.log
    mv gcmc_6.log pot_save/gcmc_6_${p}.log
    mv gcmc_7.log pot_save/gcmc_7_${p}.log
    mv gcmc_8.log pot_save/gcmc_8_${p}.log
    mv dump.gcmc_1.trj pot_save/dump.gcmc_1_${p}.trj
    mv dump.gcmc_2.trj pot_save/dump.gcmc_2_${p}.trj
    mv dump.gcmc_3.trj pot_save/dump.gcmc_3_${p}.trj
    mv dump.gcmc_4.trj pot_save/dump.gcmc_4_${p}.trj
    mv dump.gcmc_5.trj pot_save/dump.gcmc_5_${p}.trj
    mv dump.gcmc_6.trj pot_save/dump.gcmc_6_${p}.trj
    mv dump.gcmc_7.trj pot_save/dump.gcmc_7_${p}.trj
    mv dump.gcmc_8.trj pot_save/dump.gcmc_8_${p}.trj
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
