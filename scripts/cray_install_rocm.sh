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

# which branch of the ROCM repo to check out.
ROCM_VERSION=5.1.3
ROCM_VERSION_BRANCH=roc-5.1.x
GFX_ARCHS="gfx908" # https://llvm.org/docs/AMDGPUUsage.html check this
# number of cores to be used to build software
NCORES=128
# installation directory
export ROCM_INSTALL_DIR=$MYSOFTWARE/mulan-stuff/rocm-dev3
MODULEFILE_DIR="${ROCM_INSTALL_DIR}/modulefiles/rocm"
MODULEFILE_PATH="${MODULEFILE_DIR}/${ROCM_VERSION}.lua"
# remove build folder, if exists?
CLEAN_BUILD=0
# if the system does not have a gpu, the script has to do some hacks.
SYSTEM_HAS_GPU=0
BUILD_FOLDER="`pwd`/build2"
# always pick the latest version please.
CMAKE_VERSION=3.23.1
BUILD_TYPE=Release


# ************************************************************************************************************
# *               !! USER INPUT STOPS HERE - DO NOT MODIFY ANYTHING BELOW THIS POINT !!
# ************************************************************************************************************

SCRIPT_DIR="$( cd "$( dirname "$0" )" && pwd )"


# include helper functions
. "${SCRIPT_DIR}/common/utils.sh"

# ============================================================================================================
#                                             DEPENDENCIES
# ============================================================================================================

module load gcc/10.3.0
module load cray-python cray-dsmml/0.2.2

. "${SCRIPT_DIR}/common/install_build_deps.sh"
. "${SCRIPT_DIR}/common/install_rocm_deps.sh"
. "${SCRIPT_DIR}/common/install_x11.sh"


# ============================================================================================================
#                                        ENVIRONMENT VARIABLES
# ============================================================================================================

. "${SCRIPT_DIR}/common/set_env.sh"



if [ -d "${BUILD_FOLDER}" ] && [ $CLEAN_BUILD -eq 1 ]; then
    echo "Cleaning up previous build."
    run_command rm -rf "${BUILD_FOLDER}"
fi


. "${SCRIPT_DIR}/common/install_rocm.sh"

[ -d ${MODULEFILE_DIR} ] || mkdir -p ${MODULEFILE_DIR}
"${SCRIPT_DIR}/common/generate_modfile.sh" > ${MODULEFILE_PATH}

