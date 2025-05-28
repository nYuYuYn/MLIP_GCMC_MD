#/bin/bash
#Preamble, common for all examples
module purge
module load icc/20 impi/20 mkl/20
MLP_EXE=/W/av245900/Codes/mlip-3/bin/mlp
TMP_DIR=./out
mkdir -p $TMP_DIR

#echo $(pwd TMP_DIR)

# Body:
# This converts OUTCAR to the internal format out/relax.cfg.
$MLP_EXE convert train_one.cfg  train_AIMD2.cfg #--output_format=lammps_datafile
