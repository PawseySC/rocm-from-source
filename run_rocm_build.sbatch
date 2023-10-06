#!/bin/bash -l
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=128
#SBATCH --mem=0
#SBATCH --time=2:00:00 
#SBATCH --job=rocm_install_5.4.3-gcc

export ROCM_VERSION="5.4.3"
export ROOT_INSTALL_DIR=/software/setonix/2023.08/pawsey/software/rocm/gcc/12.2.0/
module load cmake/3.24.3 
module load autoconf/2.69
module load automake/1.16.5
# should make not a hidden moduel considering how often libtool, auto* and pkg-config are used together
module use /software/setonix/2023.08/modules/zen3/gcc/12.2.0/dependencies/.pkg-config/
module load 0.29.2-ru66hcc
# python load 
module load python/3.10.10 
module list
./install_rocm.${ROCM_VERSION}.sh
