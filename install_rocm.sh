#!/bin/sh

# Author: Cristian Di Pietrantonio

# ============================================================================================================
#                                           INPUT PARAMETERS
#
# Modify the following variables to customise the installation.
# ============================================================================================================

# Locations for ROCm binaries and its dependencies' binaries differ so that you can rebuild only ROCm
# without having to rebuild dependencies, when it is not needed.
# ROOT_INSTALL_DIR= 

if [ -z ${ROOT_INSTALL_DIR+x} ]; then
    echo "You must set the ROOT_INSTALL_DIR environment variable to the path where to install ROCm."
    exit 1
fi

# Default: 1 if [ -d /opt/cray ], 0 otherwise.
# INSTALL_ON_SUPERCOMPUTER= 

# Which GPU architectures to support. More info at the following link:
#      https://llvm.org/docs/AMDGPUUsage.html
GFX_ARCHS="gfx908;gfx90a"

# Where build files are written.
BUILD_FOLDER=`pwd`/build

BUILD_TYPE=Release


# ============================================================================================================
#                                        ADVANCED PARAMETERS
#
# Usually you shouldn't modify the following section.
# ============================================================================================================

# If you have multiple libstdc++.so files on your system and you intend to use a non-default compiler with its own
# libstdc++ ro compile ROCm, then set the following variable to the path to the "lib" or "lib64" directory of 
# the compiler you intend to use.
# COMPILER_LIBDIR=/pawsey/mulan/raw-builds/GCC/11.1.0/lib64

# ROCm version. Users shouldn't change this because these scripts are tested only for the specified version.
ROCM_VERSION=5.3.0
# Pawsey build script revision
SCRIPT_REVISION=2

# Modify the following only if necessary.
export ROCM_INSTALL_DIR="${ROOT_INSTALL_DIR}/rocm-${ROCM_VERSION}rev${SCRIPT_REVISION}"
export ROCM_DEPS_INSTALL_DIR="${ROCM_INSTALL_DIR}/rocm-deps"

MODULEFILE_DIR="${ROOT_INSTALL_DIR}/modulefiles/rocm"
MODULEFILE_PATH="${MODULEFILE_DIR}/${ROCM_VERSION}.lua"

# Install ROCm dependencies? Might not be needed if they are already installed (from a previous build).
if [ -e "${ROCM_DEPS_INSTALL_DIR}/.completed" ]; then
    echo "ROCm dependencies' installation directory already exists. Not building dependencies.."
    BUILD_ROCM_DEPS=0
else
    BUILD_ROCM_DEPS=1
fi

# If set to 1, previous builds of each project, if any, are deleted before proceeding with a new build.
CLEAN_BUILD=0
# Do not call cmake/make on packages already installed (uses a sentinel file, `rfs_installed`, 
# in the source folder).
SKIP_INSTALLED=1


N_CPU_SOCKETS=`cat /proc/cpuinfo | grep "physical id"  | sort | uniq | wc -l`
N_CORES_PER_SOCKET=`cat /proc/cpuinfo | grep "cpu cores" | head -n1 | grep -oE [0-9]+`
# Number of cores to be used to build software. In general you should be using all the cores available.
NCORES=$(( N_CPU_SOCKETS * N_CORES_PER_SOCKET ))
echo "Running the build with $NCORES cores.."  

# ************************************************************************************************************
# *               !! USER INPUT STOPS HERE - DO NOT MODIFY ANYTHING BELOW THIS POINT !!
# ************************************************************************************************************

SCRIPT_DIR="$( cd "$( dirname "$0" )" && pwd )"
. "${SCRIPT_DIR}/lib/utils.sh"
# We supports several OSes. For each one we adopt a different technique TODO: continue.
OS_NAME=`cat /etc/os-release | grep -E "^NAME" | cut -d'"' -f2`
if [ -z ${INSTALL_ON_SUPERCOMPUTER+x} ]; then
    if [ -d /opt/cray ]; then
        INSTALL_ON_SUPERCOMPUTER=1
    else 
        INSTALL_ON_SUPERCOMPUTER=0
    fi
fi

if ! [ $INSTALL_ON_SUPERCOMPUTER -eq 1 ] && [ `id -u` -ne 0 ]; then 
    echo "You are installing ROCm on a workstation or VM. Please run the script as root."
    exit
fi


if [ $INSTALL_ON_SUPERCOMPUTER -eq 1 ]; then
    continue
    # run_command module purge
    # run_command module load gcc/10.3.0
    # run_command module load cray-python cray-dsmml

elif [ "$OS_NAME" = "Ubuntu" ]; then

    run_command apt install -y build-essential python3.8-dev gfortran libnuma-dev libudev-dev xxd libudev-dev \
        libelf-dev libc6-dev-i386 rsync cmake bc\
        curl git libgl1-mesa-dev libglu1-mesa-dev freeglut3-dev mesa-common-dev wget \
        libssl-dev python3.8-venv python3.8 libomp-dev autoconf pkgconf gawk autopoint flex bison texinfo zip

    run_command curl https://bootstrap.pypa.io/get-pip.py -o get-pip.py
    run_command python3.8 get-pip.py 
    run_command rm get-pip.py
    run_command mkdir -p /etc/OpenCL/vendors/
    run_command echo "libamdocl64.so" > /etc/OpenCL/vendors/amdocl64.icd

else
    echo "System not recognised. Exiting.."
    exit 1
fi

[ -e ${ROCM_INSTALL_DIR}/lib64 ] || run_command mkdir -p ${ROCM_INSTALL_DIR}/lib64
[ -e ${ROCM_INSTALL_DIR}/lib ] || run_command ln -s ${ROCM_INSTALL_DIR}/lib64 ${ROCM_INSTALL_DIR}/lib

PYTHON_VERSION="3.`python3 --version | cut -d "." -f 2`"
# include helper functions
. "${SCRIPT_DIR}/lib/set_env.sh"
. "${SCRIPT_DIR}/lib/install_build_deps.sh"
if [ $BUILD_ROCM_DEPS -eq 1 ]; then
 . "${SCRIPT_DIR}/lib/install_rocm_deps.sh"
fi
. "${SCRIPT_DIR}/lib/install_rocm_projects.sh"

# Generate script to source in order to use the installation
echo "Generating rocm_setup.sh script..."
"${SCRIPT_DIR}/bin/generate_env_script.sh" > "${ROCM_INSTALL_DIR}/rocm_setup.sh"

if [ $INSTALL_ON_SUPERCOMPUTER -eq 1 ]; then
    # In addition, create a modulefile in case a module system exists
    echo "Generating modulefile.."
    [ -d ${MODULEFILE_DIR} ] || run_command mkdir -p ${MODULEFILE_DIR}
    "${SCRIPT_DIR}/bin/generate_modfile.sh" > ${MODULEFILE_PATH}
fi

echo ""
echo "ROCm installation terminated successfully!"
