#!/bin/bash
#cd $PBS_O_WORKDIR
#cp cfg_12.almtp curr.almtp
#cp cfg_lv12_train.cfg train.cfg
for p in $(seq 460 1000 )
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
    mv rdf_final.rdf_* MD_analysis/${p}
    mv FeC_coord_final.txt_* MD_analysis/${p}
    mv MnN_coord_final.txt_* MD_analysis/${p}
    mv NaN_coord_final.txt_* MD_analysis/${p}
	mv gcmc_1.log pot_save/gcmc_1_${p}.log
    mv gcmc_2.log pot_save/gcmc_2_${p}.log
    mv gcmc_3.log pot_save/gcmc_3_${p}.log
    mv gcmc_4.log pot_save/gcmc_4_${p}.log
    mv dump.gcmc_1.trj pot_save/dump.gcmc_1_${p}.trj
    mv dump.gcmc_2.trj pot_save/dump.gcmc_2_${p}.trj
    mv dump.gcmc_3.trj pot_save/dump.gcmc_3_${p}.trj
    mv dump.gcmc_4.trj pot_save/dump.gcmc_4_${p}.trj
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
