#!/bin/bash
n_poscar=$(grep "BEGIN" nbh.cfg | wc -l)
cd $PBS_O_WORKDIR
for ((i=4; i<$n_poscar; i++))
do
	cd VASP/"$i"
	if [ -f "is_vasp_finished.txt" ]; then
		echo $i vasp_finished
	else
		qsub sub_vasp.sh
		echo $i vasp_submited
	fi
	cd ../..
done
