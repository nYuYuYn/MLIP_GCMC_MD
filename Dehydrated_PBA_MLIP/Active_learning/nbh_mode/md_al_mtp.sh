#!/bin/bash
rm -f section_*.cfg
rm -f preselected.cfg.*
rm -f preselected.cfg
rm -f selected.cfg
rm -f nbh.cfg
rm -f *.txt
rm -f vasp.cfg
rm -f *.log

for ((x=0; x<=0; x++)); do

    cp curr.almtp pot_save/
    touch preselected.cfg
    is_lammps_finished=0
    ./run_lammps.sh
    timestep_1=$(tail -n 1 "gcmc_1.log" | awk '{print $1}')
    timestep_2=$(tail -n 1 "gcmc_2.log" | awk '{print $1}')
    timestep_3=$(tail -n 1 "gcmc_3.log" | awk '{print $1}')
    timestep_4=$(tail -n 1 "gcmc_4.log" | awk '{print $1}')
    echo $timestep_1 $timestep_2 $timestep_3 $timestep_4 > timestep.txt
    
    cat preselected* >> preselected.cfg
    mv timestep.txt pot_save/timestep.txt
    
    while [ $is_lammps_finished -ne 1 ]
    do
        sleep 5
        if [ -f is_lammps_finished.txt ]; then
            is_lammps_finished=1
            echo $is_lammps_finished
        else
            is_lammps_finished=0
            echo $is_lammps_finished
        fi
    done
    sleep 5

    n_preselected=$(grep "BEGIN" preselected.cfg | wc -l)
    is_selection_finished=0
    if [ $n_preselected -gt 0 ]; then
        echo "selection"
        ./select.sh
        while [ $is_selection_finished -ne 1 ]
        do
            sleep 5
            if [ -f is_selection_finished.txt ]; then
                is_selection_finished=1
                echo $is_selection_finished
            else
                is_selection_finished=0
                echo $is_selection_finished
            fi
        done
        sleep 5
        if [ -s selected.cfg ]; then
            echo " selected.cfg exists"
        else
            echo "selected.cfg not exist"
            exit
        fi
        rm -f preselected.cfg
        rm -f preselected*
		
		# Cut big spheres and small spheres & turn into lammps_datafile
		mlip cut_extrapolative_nbh selected.cfg nbh.cfg --cutoff=20
        #./split_section.sh
		mlip convert nbh.cfg nbh.data --output_format=lammps_datafile

		n_poscar=$(grep "BEGIN" nbh.cfg | wc -l)
		n_poscar_prev=$((${n_poscar}-1))
		n_poscar_aft=$((${n_poscar}+1))

        if [ $n_poscar -eq 1 ]; then
            mv nbh.data nbh.data0
        fi
    
        for ((i=0; i<$n_poscar; i++))
        do
            j=$((${i}+1))
            python data_to_cfg.py $i
            #mlip convert section_$i.cfg section_$j.cfg
            echo "section_$j.cfg is generated, deleting nbh.data$i"
            rm nbh.data$i
        done

		# Relax the cubic cfgs one by one & convert the dump file into the POSCAR 
		for ((i=0; i<$n_poscar; i++))
		do 
			j=$((${i}+1))
			python cut_to_pbc.py $j	 
			# grep the number 
			center=$(awk 'NR==1 {print $1, $2, $3}' center_$j.txt) 
			
			#update the number of atoms to fix relax.my file
			sed -i "8s/.*/read_data  PBC_$j.data/" relax.my #which file to use
			sed -i "36s/.*/region r1 sphere $center 9 side in/" relax.my #Define which atoms to fix
			sed -i "37s/.*/region r2 sphere $center 9 side out/" relax.my #Define which atoms to fix
			sed -i "75s/.*/write_dump all custom relax_$i.dump id type x y z/" relax.my 
			./run_relax.sh
            mv log.lammps relax_$i.log
            mv rdf_final.rdf rdf_final.rdf_$j
            mv FeC_coord_final.txt FeC_coord_final.txt_$j
            mv MnN_coord_final.txt MnN_coord_final.txt_$j
            mv NaN_coord_final.txt NaN_coord_final.txt_$j
			mlip convert relax_$i.dump POSCAR$i --input_format=lammps_dump --output_format=poscar
		done

        # final check on the POSCAR. If the POSCAR has too many defects, remove it to save DFT time.
        for ((i=0; i<$n_poscar; i++))
        do 
            j=$((${i}+1))
            numbers=$(awk 'NR==6 {print $1, $2, $3, $4, $5}' POSCAR"$i") 
            read n_C n_Mn n_Fe n_N n_Na <<< "$numbers" 
            
            # Conditions for absolute differences
            abs_diff_C_N=$(echo "sqrt(($n_C - 192)^2) > 5 || sqrt(($n_N - 192)^2) > 5" | bc)
            abs_diff_Mn_Fe=$(echo "sqrt(($n_Mn - 32)^2) > 2 || sqrt(($n_Fe - 32)^2) > 2" | bc)
            
            # Check if any condition is true
            if (( abs_diff_C_N == 1 || abs_diff_Mn_Fe == 1 )); then
                echo "There're too many defects in the PBC cell, delete the POSCAR"$i"."
                rm POSCAR"$i"
                rm rdf_final.rdf_$j
                rm FeC_coord_final.txt_$j
                rm MnN_coord_final.txt_$j
                rm NaN_coord_final.txt_$j                
            else
                echo "The PBC cell is ok to run VASP. Move on POSCAR"$i"."
            fi
        done
    
		rm -f PBC_*.data
		rm -f center_*.txt
		rm -f section_*.cfg
		rm -f relax_*.dump
		
		for ((i=0; i<$n_poscar; i++))
		do
			cp POSCAR"$i" VASP/
			mkdir -p VASP/"$i"
			if [ $n_poscar -eq 1 ]; then
				mv VASP/POSCAR"$i" VASP/0/POSCAR
			elif [ $n_poscar -gt 1 ]; then
				mv VASP/POSCAR"$i" VASP/"$i"/POSCAR
			fi
			cp VASP/POTCAR VASP/"$i"/
			cp VASP/INCAR VASP/"$i"/
			cp VASP/KPOINTS VASP/"$i"/
			cp VASP/sub_vasp.sh VASP/"$i"/
		done
		
		for ((i=0; i<$n_poscar; i++))
		do
			cd VASP/"$i"
			sed -i "2s/.*/#PBS -N {$i}_PBC_nbh/" sub_vasp.sh
			numbers=$(awk 'NR==6 {print $1, $2, $3, $4, $5}' POSCAR) 
			read n_C n_Mn n_Fe n_N n_Na <<< "$numbers" 
			if [ -z "$n_Na" ]; then
					replacement="MAGMOM = ${n_C}*0 ${n_Mn}*5 ${n_Fe}*0 ${n_N}*0"
					sed -i "23s/.*/$replacement/" INCAR
			else
					replacement="MAGMOM = ${n_C}*0 ${n_Mn}*5 ${n_Fe}*0 ${n_N}*0 ${n_Na}*0"
					sed -i "23s/.*/$replacement/" INCAR
			fi

            std_waiting=$(qstat | grep "csp-standard" | grep "Q" | wc -l)
            large_waiting=$(qstat | grep "large" | grep "Q" | wc -l)
            
            if [ $std_waiting -gt $large_waiting ]; then
                sed -i "8s/.*/NCORE = 40/" INCAR
                sed -i "4s/.*/#PBS -q large/" sub_vasp.sh
                sed -i "5s/.*/#PBS -l walltime=24:00:00,nodes=1:ppn=40/" sub_vasp.sh
                qsub sub_vasp.sh
                echo large is more empty, use large
            fi

            if [ $large_waiting -eq $std_waiting ]; then
                sed -i "8s/.*/NCORE = 64/" INCAR
                sed -i "4s/.*/#PBS -q csp-standard/" sub_vasp.sh
                sed -i "5s/.*/#PBS -l walltime=24:00:00,nodes=2:ppn=32/" sub_vasp.sh
                qsub sub_vasp.sh
                echo large is as full as csp, use csp
            fi
            
            if [ $large_waiting -gt $std_waiting ]; then
                sed -i "8s/.*/NCORE = 64/" INCAR
                sed -i "4s/.*/#PBS -q csp-standard/" sub_vasp.sh
                sed -i "5s/.*/#PBS -l walltime=24:00:00,nodes=2:ppn=32/" sub_vasp.sh
                qsub sub_vasp.sh
                echo csp is more empty, use csp
            fi
    		cd ../../
		done
		sleep 90
		is_vasp_finished=0
		if [ $n_poscar -gt 0 ]; then
			while [ $is_vasp_finished -ne 1 ]
			do
				sleep 10
				n_vasp_finished=$(grep -rH "1" VASP/*/is_vasp_finished.txt | wc -l)
				if [ $n_poscar -eq $n_vasp_finished ]; then
					is_vasp_finished=1
					echo $is_vasp_finished
				else
					is_vasp_finished=0
					echo $is_vasp_finished
				fi
			done
		fi
		sleep 5
		for ((i=0; i<$n_poscar; i++))
		do
    		mlip convert VASP/"$i"/OUTCAR VASP/"$i"/calculated.cfg --input_format=outcar 
    		cat VASP/"$i"/calculated.cfg >> train.cfg
			rm -r VASP/"$i"/
            echo $i > vasp_cfg.txt
		done

        ## remove those unreasonable cfgs and report how many good cfg were added to train.cfg
        #python clean.py
        #cat vasp.cfg >> train.cfg

        #input_file="cleaned_vasp.cfg"
        #n_good=$(grep "BEGIN_CFG" $input_file | wc -l)
        #echo $n_good > vasp_cfg.txt
        #rm vasp.cfg
        #rm cleaned_vasp.cfg
        
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
		#rm POSCAR*
		rm -f nbh_36.cfg
		rm -f MTP_nbh_*    
        rm -f relax_*.log
        rm -f vasp.cfg
	elif [ $n_preselected -eq 0 ]; then
		exit
	fi

done
