#!/bin/bash
cd $PBS_O_WORKDIR
sleep 5
for p in $(seq 1 100 )
do
	echo "active learning on MnFePw is starting"
	./md_al_mtp.sh
	cp dump.trj pot_save/
	cp train.cfg pot_save/
	cd pot_save
	mlip check_errors curr.almtp train.cfg >> report.txt
	mv report.txt report_${p}.txt
	mv train.cfg train_${p}.cfg
	cp curr.almtp curr_${p}.almtp
	cd ../
	cp pot_save/curr.almtp .
done
