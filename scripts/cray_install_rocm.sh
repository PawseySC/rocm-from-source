#!/bin/sh

# Author: Cristian Di Pietrantonio

# ============================================================================================================
#                                           INPUT PARAMETERS
#
# Modify the following variables to customise the installation.
# ============================================================================================================

# TODO: on every compute node
# run_command mkdir -p /etc/OpenCL/vendors/
# run_command echo "libamdocl64.so" > /etc/OpenCL/vendors/amdocl64.icd

# ------------------------------------------------------------------------------------------------------------
#                                              ROCm version
# ------------------------------------------------------------------------------------------------------------
# ROCm version - used to dynamically generate paths.
ROCM_VERSION=5.2.0
# Pawsey build script revision
SCRIPT_REVISION=0
# which branch of the ROCM repo to check out.
ROCM_VERSION_BRANCH=roc-5.2.x
# Which GPU architectures to support. More info at the following link:
#      https://llvm.org/docs/AMDGPUUsage.html
GFX_ARCHS="gfx908"

# -----------------------------------------------------------------------------------------------------------
#                                         installation directory
# -----------------------------------------------------------------------------------------------------------

# Locations for ROCm binaries and its dependencies' binaries differ so that you can rebuild only ROCm
# without having to rebuild dependencies, when it is not needed.
ROOT_INSTALL_DIR=/group/pawsey0001/cdipietrantonio/mulan-stuff/rocm

# Modify the following only if necessary.
export ROCM_INSTALL_DIR="${ROOT_INSTALL_DIR}/rocm-${ROCM_VERSION}rev${SCRIPT_REVISION}"
export ROCM_DEPS_INSTALL_DIR="${ROOT_INSTALL_DIR}/rocm-deps"
MODULEFILE_DIR="${ROCM_INSTALL_DIR}/modulefiles/rocm"
MODULEFILE_PATH="${MODULEFILE_DIR}/${ROCM_VERSION}.lua"

# -----------------------------------------------------------------------------------------------------------
#                                            build parameters
# -----------------------------------------------------------------------------------------------------------
# remove the build folder, if exists?
CLEAN_BUILD=0
# Install ROCm dependencies? Might not be needed if they are already installed (from a previous build).
BUILD_ROCM_DEPS=1
BUILD_FOLDER="`pwd`/build"
BUILD_TYPE=Release
# number of cores to be used to build software
NCORES=128
# The script will build the latest cmake as ROCm heavily depends on the latest cmake.
# Specify the latest version please.
CMAKE_VERSION=3.23.1

# -----------------------------------------------------------------------------------------------------------
#                                          system dependencies
# -----------------------------------------------------------------------------------------------------------
# Unload any PrgEnv, we want to use gcc explicitly to a void mixing libc implementations.
module purge
module load gcc/10.3.0
export PATH=/opt/gcc/10.3.0/snos/bin:$PATH
module use /group/pawsey0001/cdipietrantonio/mulan-stuff/modulefiles
module load python/3.8.5 
module load cray-dsmml/0.2.2
module list
PYTHON_VERSION=3.8 
# module load cray-python cray-dsmml/0.2.2


# ************************************************************************************************************
# *               !! USER INPUT STOPS HERE - DO NOT MODIFY ANYTHING BELOW THIS POINT !!
# ************************************************************************************************************

RPATH1=$ROCM_INSTALL_DIR/lib
RPATH2=$ROCM_INSTALL_DIR/lib64
export CFLAGS="-Wl,-rpath=$RPATH1 -Wl,-rpath=$RPATH2"
export CXXFLAGS="$CFLAGS"

SCRIPT_DIR="$( cd "$( dirname "$0" )" && pwd )"
. "${SCRIPT_DIR}/common/utils.sh"

if [ -d "${BUILD_FOLDER}" ] && [ $CLEAN_BUILD -eq 1 ]; then
    echo "Cleaning up previous build."
    run_command rm -rf "${BUILD_FOLDER}"
fi

# include helper functions
. "${SCRIPT_DIR}/common/set_env.sh"
. "${SCRIPT_DIR}/common/install_build_deps.sh"
if [ $BUILD_ROCM_DEPS -eq 1 ]; then
    . "${SCRIPT_DIR}/common/install_rocm_deps.sh"
fi
. "${SCRIPT_DIR}/common/install_rocm.sh"

[ -d ${MODULEFILE_DIR} ] || run_command mkdir -p ${MODULEFILE_DIR}
"${SCRIPT_DIR}/common/generate_modfile.sh" > ${MODULEFILE_PATH}

