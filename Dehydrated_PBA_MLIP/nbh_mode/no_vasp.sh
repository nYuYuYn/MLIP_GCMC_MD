#!/bin/bash
rm -f section_*.cfg
rm -f preselected.cfg.*
rm -f preselected.cfg
rm -f selected.cfg
rm -f nbh.cfg
rm -f *.txt
for ((x=0; x<=0; x++)); do

    cp curr.almtp pot_save/
    touch preselected.cfg
    is_lammps_finished=0
    ./run_lammps.sh
    log_file="log.lammps"
    first_value=$(tail -n 1 "$log_file" | awk '{print $1}')
    echo $first_value > timestep.txt
    mv log.lammps gcmc.log
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
		if test -f selected.cfg; then
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
			sed -i "63s/.*/write_dump all custom relax_$i.dump id type x y z/" relax.my 
			./run_relax.sh
            mv log.lammps relax_$i.log
			mlip convert relax_$i.dump POSCAR$i --input_format=lammps_dump --output_format=poscar
		done

        # final check on the POSCAR. If the POSCAR has too many defects, remove it to save DFT time.
        for ((i=0; i<$n_poscar; i++))
        do 
            numbers=$(awk 'NR==6 {print $1, $2, $3, $4, $5}' POSCAR"$i") 
            read n_C n_Mn n_Fe n_N n_Na <<< "$numbers" 
            
            # Conditions for absolute differences
            abs_diff_C_N=$(echo "sqrt(($n_C - 192)^2) > 10 || sqrt(($n_N - 192)^2) > 10" | bc)
            abs_diff_Mn_Fe=$(echo "sqrt(($n_Mn - 32)^2) > 5 || sqrt(($n_Fe - 32)^2) > 3" | bc)
            
            # Check if any condition is true
            if (( abs_diff_C_N == 1 || abs_diff_Mn_Fe == 1 )); then
                echo "There're too many defects in the PBC cell, delete the POSCAR"$i"."
                rm POSCAR"$i"
            else
                echo "The PBC cell is ok to run VASP. Move on POSCAR"$i"."
            fi
        done
    
		#rm -f PBC_*.data
		#rm -f center_*.txt
		#rm -f section_*.cfg
		#rm -f relax_*.dump

        
	elif [ $n_preselected -eq 0 ]; then
		exit
	fi

done
