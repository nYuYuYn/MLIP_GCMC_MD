#!/bin/bash

for i in {0..16}
do
    dir_name="Na${i}"

    # Create the directory if it doesn't exist
    mkdir -p $dir_name

    # Copy files to the new directory
#    cp POTCAR $dir_name
#    cp KPOINTS $dir_name
#    cp POSCAR $dir_name
    cp INCAR $dir_name
    cp single_6.sh $dir_name
    #cp ICONST $dir_name
    #cp AIMD_analysis.ipynb $dir_name  # Assuming the extension should be .ipynb

    cd $dir_name
    #mkdir pot_save

    # Modify POSCAR
    #sed -i "7s/.*/   48    8    8   48   $i/" POSCAR
    #sed -i "$((121 + i)),136d" POSCAR

    # Modify INCAR
    sed -i "23s/.*/MAGMOM = 48*0 8*4.5 8*0.5 48*0 $i*0/" INCAR
    
    # Modify single_6.sh
    sed -i "2s/.*/#PBS -N AIMD_Na$i/" single_6.sh
    qsub single_6.sh
    # Go back to the parent directory
    cd ..
done




























