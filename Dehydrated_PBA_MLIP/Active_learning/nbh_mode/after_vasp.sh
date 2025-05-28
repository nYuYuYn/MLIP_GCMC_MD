n_poscar=$(grep "BEGIN" nbh.cfg | wc -l)
n_poscar_prev=$((${n_poscar}-1))
n_poscar_aft=$((${n_poscar}+1))

for ((i=0; i<$n_poscar; i++))
do
    mlip convert VASP/"$i"/OUTCAR VASP/"$i"/calculated.cfg --input_format=outcar 
    cat VASP/"$i"/calculated.cfg >> train.cfg
    rm -r VASP/"$i"/
    echo $i > vasp_cfg.txt
done

is_training_finished=0
if [ $n_poscar -gt 0 ]; then
	./train.sh
fi

while [ $is_training_finished -ne 1 ]
do
    sleep 5
    if [ -f is_training_finished.txt ]; then
        is_training_finished=1
        echo $is_training_finished
    else
        is_training_finished=0
        echo $is_training_finished
    fi
done
sleep 5

rm -f nbh.cfg
rm *.txt
rm POSCAR*
rm -f nbh_36.cfg
rm -f MTP_nbh_*    
rm -f relax_*.log
