#/bin/bash

# Preamble, common for all examples

module purge
module load icc/20 impi/20 mkl/20
MLP_EXE=/W/av245900/Codes/mlip-3/bin/mlp
TMP_DIR=./out
mkdir -p $TMP_DIR

# Body:
$MLP_EXE train init.almtp train_one.cfg --save_to=curr.almtp --iteration_limit=100 --al_mode=nbh
