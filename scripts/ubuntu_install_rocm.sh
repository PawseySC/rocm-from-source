#!/bin/sh

# Author: Cristian Di Pietrantonio

# ============================================================================================================
#                                           INPUT PARAMETERS
#
# Modify the following variables to customise the installation.
# ============================================================================================================

# which branch of the ROCM repo to check out.
ROCM_VERSION_BRANCH=roc-5.1.x
GFX_ARCHS="gfx908" # https://llvm.org/docs/AMDGPUUsage.html check this
# number of cores to be used to build software
NCORES=8
# installation directory
ROCM_INSTALL_DIR=/opt/rocm-dev2
# remove build folder, if exists?
CLEAN_BUILD=0
# if the system does not have a gpu, the script has to do some hacks.
SYSTEM_HAS_GPU=0
BUILD_FOLDER="`pwd`/build"
# always pick the latest version please.
CMAKE_VERSION=3.23.1
BUILD_TYPE=Release


# ************************************************************************************************************
# *               !! USER INPUT STOPS HERE - DO NOT MODIFY ANYTHING BELOW THIS POINT !!
# ************************************************************************************************************

# include helper functions
SCRIPT_DIR="$( cd "$( dirname "$0" )" && pwd )"
. "${SCRIPT_DIR}/common/utils.sh"

# ============================================================================================================
#                                  DEPENDENCIES FROM PACKET MANAGERS
# ============================================================================================================

apt install -y gfortran libnuma-dev libudev-dev xxd libdrm-dev libudev-dev libelf-dev libc6-dev-i386 \
    python3-pip curl git libgl1-mesa-dev libglu1-mesa-dev freeglut3-dev mesa-common-dev wget \
    libssl-dev python3.8-venv libomp-dev
pip3 install cppheaderparser argparse virtualenv



# ============================================================================================================
#                                              INSTALL
# ============================================================================================================

. "${SCRIPT_DIR}/common/set_env.sh"
. "${SCRIPT_DIR}/common/install_rocm.sh"

# TODO remove build dir