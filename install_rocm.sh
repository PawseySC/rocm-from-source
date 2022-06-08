#!/bin/bash

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

# ============================================================================================================
#                                                 TODO
# ============================================================================================================

# 1. Check that rocFFT now works
# 2. Try to build rocALUTION
# 3. Build Tensile by itself, then use it as dependency in rocblas and miopen
# 4. Try to figure out how to better install dependencies.
# 5. What about the kernel driver?

# ============================================================================================================
#                                           HELPER FUNCTIONS
# ============================================================================================================

# Takes as argument an absolute path to a directory and adds the include, lib, bin directories within it 
# to the build and runtime linux environment variables 
function export_vars {
    export LD_LIBRARY_PATH=$1/lib:$LD_LIBRARY_PATH
    export LIBRARY_PATH=$1/lib:$LIBRARY_PATH
    export LD_LIBRARY_PATH=$1/lib64:$LD_LIBRARY_PATH
    export LIBRARY_PATH=$1/lib64:$LIBRARY_PATH
    export PATH=$1/bin:$PATH
    export CPATH=$1/include:$CPATH
    export CPATH=$1/inc:$CPATH
    export CMAKE_PREFIX_PATH=$1:$CMAKE_PREFIX_PATH
}


# Executes a bash command line, stopping the execution of the script if something goes wrong.
function run_command {
    echo "Running command $@"
    # All the following mess is due to the ';' present in some CMake parameters.
    # We need to put arguments to cmake into single quotes.
    string_to_eval=""
    for arg in $@;
    do
        string_to_eval="$string_to_eval '$arg'"
    done
    eval "$string_to_eval"
    if [ $? -ne 0 ]; then
        echo "Error running a command: $@"
           exit 1
    fi           
}


# Executes a cmake installation of the project specified as first argument, optionally using the cmake
# flags passed as further arguments.
function cmake_install {
    run_command cd "${BUILD_FOLDER}"
    PACKAGE_NAME="$1"
    SOURCE_DIR=".."
    if [ $# -eq 1 ]; then
        CMAKE_FLAGS="-DCMAKE_BUILD_TYPE=${BUILD_TYPE} -DCMAKE_INSTALL_PREFIX=${ROCM_INSTALL_DIR}"
    else
        CMAKE_FLAGS=""
        declare -i narg
        narg=0
        for arg in $@;
        do
            (( narg=narg + 1 ))
            if [ $narg -eq 1 ]; then continue; fi;
            CMAKE_FLAGS="$CMAKE_FLAGS $arg"
        done
    fi
    echo "Installing ${PACKAGE_NAME} .."
    cd "${PACKAGE_NAME}"
    if [ "${PACKAGE_NAME}" = "ROCR-Runtime" ] || [ "${PACKAGE_NAME}" = "atmi" ]; then
        run_command cd src
    elif [ "${PACKAGE_NAME}" = "ROCm-CompilerSupport" ]; then
        run_command cd lib/comgr
    elif [ "${PACKAGE_NAME}" = "llvm-project" ]; then
        SOURCE_DIR="../llvm"
    fi
    [ -d build ] || mkdir build 
    run_command cd build
    run_command cmake "${CMAKE_FLAGS}" "${SOURCE_DIR}"
    run_command make -j ${NCORES} install
    run_command cd "${BUILD_FOLDER}"
}


# ============================================================================================================
#                                  DEPENDENCIES FROM PACKET MANAGERS
# ============================================================================================================

apt install -y gfortran libnuma-dev libudev-dev xxd libdrm-dev libudev-dev libelf-dev libc6-dev-i386 \
    python3-pip curl git libgl1-mesa-dev libglu1-mesa-dev freeglut3-dev mesa-common-dev wget \
    libssl-dev libdw-dev python3.8-venv libomp-dev
pip3 install cppheaderparser argparse virtualenv



# ============================================================================================================
#                                        ENVIRONMENT VARIABLES
# ============================================================================================================

# TODO: remove this> export CMAKE_PREFIX_PATH=${ROCM_INSTALL_DIR}:${ROCM_INSTALL_DIR}/rocclr:${ROCM_INSTALL_DIR}/include/hsa:$CMAKE_PREFIX_PATH

# Needed at build time and runtime
export_vars "${ROCM_INSTALL_DIR}"
export_vars "${ROCM_INSTALL_DIR}/rocclr"
export_vars "${ROCM_INSTALL_DIR}/opencl"
export_vars "${ROCM_INSTALL_DIR}/llvm"
export_vars "${ROCM_INSTALL_DIR}/hip"
export_vars "${ROCM_INSTALL_DIR}/roctracer"
export_vars "${ROCM_INSTALL_DIR}/rocrand"
export_vars "${ROCM_INSTALL_DIR}/rocblas"
export_vars "${ROCM_INSTALL_DIR}/rocsparse"
export_vars "${ROCM_INSTALL_DIR}/boost"
export_vars "${ROCM_INSTALL_DIR}/mlir"

export HIP_PATH="${ROCM_INSTALL_DIR}/hip"
export HSA_PATH="${ROCM_INSTALL_DIR}/hsa"
export HIP_CLANG_PATH="${ROCM_INSTALL_DIR}/llvm/bin"
export ROCM_PATH="${ROCM_INSTALL_DIR}"
export HIP_ROCCLR_HOME=${ROCM_INSTALL_DIR}/hip/rocclr
export HIP_RUNTIME=rocclr

# export CMAKE_PREFIX_PATH=$ROCM_INSTALL_DIR:$ROCM_INSTALL_DIR/rocclr:$ROCM_INSTALL_DIR/include/hsa:$CMAKE_PREFIX_PATH

# ============================================================================================================
#                                       BUILD ENVIRONMENT SETUP
# ============================================================================================================
# Just for build time?
export CPATH="${ROCM_INSTALL_DIR}/rocclr/include/elf:${ROCM_INSTALL_DIR}/include/hsa:$CPATH"

if [ -d "${BUILD_FOLDER}" ] && [ $CLEAN_BUILD -eq 1 ]; then
    echo "Cleaning up previous build."
    run_command rm -rf "${BUILD_FOLDER}"
fi
[ -d "${BUILD_FOLDER}" ] || mkdir -p "${BUILD_FOLDER}/build-deps/bin"
export_vars "${BUILD_FOLDER}/build-deps"

# we need "python" and "pip" executables
if [[ `which python` == "" ]]; then
    run_command cd "${BUILD_FOLDER}/build-deps/bin"; ln -s `which python3` python;
fi
if [[ `which pip` == "" ]]; then
    run_command cd "${BUILD_FOLDER}/build-deps/bin"; ln -s `which pip3` pip;
fi
# Always use the latest cmake. ROCMm depends heavily on latest CMake features, including HIP support.
if ! [ -f "${BUILD_FOLDER}/build-deps/bin/cmake" ]; then
    run_command cd "${BUILD_FOLDER}"
    run_command wget "https://github.com/Kitware/CMake/releases/download/v${CMAKE_VERSION}/cmake-${CMAKE_VERSION}.tar.gz"
    run_command tar -xf "cmake-${CMAKE_VERSION}.tar.gz"
    run_command cd "cmake-${CMAKE_VERSION}"
    run_command ./configure --prefix="${BUILD_FOLDER}/build-deps"
    run_command make -j $NCORES
    run_command make install
fi
cd "${BUILD_FOLDER}"
if ! [ -d hipamd ]; then # use the 'hipamd' folder presence as a flag of software already being do 
    # Dowload all the ROCM repositories with the repo tool. First, we need the tool
    run_command curl https://storage.googleapis.com/git-repo-downloads/repo -o "${BUILD_FOLDER}/build-deps/bin/repo"
    run_command chmod a+x "${BUILD_FOLDER}/build-deps/bin/repo"
    echo "Downloading ROCM repositories"
    run_command repo init -u https://github.com/RadeonOpenCompute/ROCm.git -b ${ROCM_VERSION_BRANCH}
    run_command repo sync
    # Needed for rocBLAS
    run_command git clone -b cpp-3.0.1 https://github.com/msgpack/msgpack-c.git
    # needed for rocsolver
    run_command git clone -b6.1.2 https://github.com/fmtlib/fmt.git
    # Need to clone manually for now, to be fixed in next release
    run_command git clone -b release/rocm-rel-5.0 https://github.com/ROCmSoftwarePlatform/hipRAND.git
    # Needed fo Tensile
    run_command wget https://boostorg.jfrog.io/artifactory/main/release/1.72.0/source/boost_1_72_0_rc2.tar.gz
    run_command tar -xf boost_1_72_0_rc2.tar.gz
    # Needed for MIOpen
    run_command wget https://www.sqlite.org/snapshot/sqlite-snapshot-202205121156.tar.gz
    run_command tar -xf sqlite-snapshot-202205121156.tar.gz
    run_command git clone -b release/rocm-5.1 https://github.com/ROCmSoftwarePlatform/llvm-project-mlir.git
    run_command wget https://sourceware.org/pub/bzip2/bzip2-1.0.8.tar.gz
    run_command tar -xf bzip2-1.0.8.tar.gz
fi



# ============================================================================================================
#                                       BUILD ROCM DEPENDENCIES
# ============================================================================================================

run_command cd "${BUILD_FOLDER}/sqlite-snapshot-202205121156"
run_command ./configure --prefix="${ROCM_INSTALL_DIR}"
run_command make -j $NCORES install


cmake_install msgpack-c -DCMAKE_BUILD_TYPE=${BUILD_TYPE} -DCMAKE_INSTALL_PREFIX=${ROCM_INSTALL_DIR} \
    -DMSGPACK_BUILD_TESTS=OFF -DMSGPACK_BUILD_EXAMPLES=OFF


cmake_install fmt -DCMAKE_BUILD_TYPE=${BUILD_TYPE} -DCMAKE_INSTALL_PREFIX=${ROCM_INSTALL_DIR} \
    -DCMAKE_CXX_FLAGS=-fPIC



run_command cd "${BUILD_FOLDER}/bzip2-1.0.8"
run_command make -j $NCORES install CFLAGS=-fPIC  PREFIX=$ROCM_INSTALL_DIR


run_command cd "${BUILD_FOLDER}/boost_1_72_0"
# the following is needed due to a bug in boost 1.72 installation process
OLD_CPLUS_VAR=$CPLUS_INCLUDE_PATH
export CPLUS_INCLUDE_PATH=""
( unset CPLUS_INCLUDE_PATH; unset CPATH; ./bootstrap.sh --prefix="${ROCM_INSTALL_DIR}/boost" )
export CPLUS_INCLUDE_PATH=$OLD_CPLUS_VAR
run_command ./b2 headers
run_command ./b2 -j$NCORES cxxflags=-fPIC cflags=-fPIC install toolset=gcc --with=all --prefix="${ROCM_INSTALL_DIR}/boost"


# ============================================================================================================
#                                       BUILD ROCM PACKAGES
# ============================================================================================================


cmake_install ROCT-Thunk-Interface

# LLVM
DEVICE_LIBS="${BUILD_FOLDER}/ROCm-Device-Libs"
BITCODE_DIR="${ROCM_INSTALL_DIR}/llvm/amdgcn/bitcode"

cmake_install llvm-project -DCMAKE_BUILD_TYPE="${BUILD_TYPE}" \
     -DLLVM_ENABLE_PROJECTS="llvm;clang;lld;compiler-rt" \
     -DLLVM_TARGETS_TO_BUILD="AMDGPU;X86"\
     -DLLVM_EXTERNAL_PROJECTS=device-libs \
     -DCMAKE_INSTALL_PREFIX="${ROCM_INSTALL_DIR}/llvm"\
     -DLLVM_EXTERNAL_DEVICE_LIBS_SOURCE_DIR="$DEVICE_LIBS"

# The following is needed otherwise clang complains when executing hipcc
ln -s "${ROCM_INSTALL_DIR}/llvm/amdgcn" "${ROCM_INSTALL_DIR}/amdgcn"

cmake_install ROCR-Runtime -DCMAKE_BUILD_TYPE="${BUILD_TYPE}" -DCMAKE_INSTALL_PREFIX="${ROCM_INSTALL_DIR}"\
    -DBITCODE_DIR="$BITCODE_DIR"

cmake_install rocm-cmake
cmake_install clang-ocl -DCMAKE_BUILD_TYPE="${BUILD_TYPE}" -DROCM_DIR="${ROCM_INSTALL_DIR}" \
    -DCMAKE_INSTALL_PREFIX="${ROCM_INSTALL_DIR}"

cmake_install ROCm-CompilerSupport
cmake_install rocm_smi_lib
cmake_install rocminfo

# install opencl runtime
# was OPENCL_DIR
ROCM_OPENCL_RUNTIME_SRC="${BUILD_FOLDER}/ROCm-OpenCL-Runtime"
# TODO: ask ashley about this
run_command mkdir -p /etc/OpenCL/vendors/
run_command cp "${ROCM_OPENCL_RUNTIME_SRC}/config/amdocl64.icd" /etc/OpenCL/vendors/
cmake_install ROCm-OpenCL-Runtime -DCMAKE_BUILD_TYPE="${BUILD_TYPE}" -DUSE_COMGR_LIBRARY=ON \
    -DROCM_PATH="${ROCM_INSTALL_DIR}" -DCMAKE_INSTALL_PREFIX="${ROCM_INSTALL_DIR}/opencl"

# HIP
COMMON_HIP="${BUILD_FOLDER}/HIP"
if [ ${SYSTEM_HAS_GPU} -eq 0 ];  then
    run_command cd "${ROCM_INSTALL_DIR}/bin"
    run_command mv rocm_agent_enumerator rocm_agent_enumerator_backup
    echo """#!/bin/bash
    echo gfx908

    """ > rocm_agent_enumerator
    run_command chmod 0755 rocm_agent_enumerator
fi


ROCCLR_DIR="${BUILD_FOLDER}/ROCclr"

cmake_install hipamd -DCMAKE_BUILD_TYPE=${BUILD_TYPE} -DHIP_COMMON_DIR=$COMMON_HIP \
    -DCMAKE_PREFIX_PATH="${BUILD_FOLDER}/rocclr;${ROCM_INSTALL_DIR}" -DROCM_PATH=${ROCM_INSTALL_DIR} \
    -DCMAKE_INSTALL_PREFIX="${ROCM_INSTALL_DIR}/hip" -DHSA_PATH=${ROCM_INSTALL_DIR}/hsa \
    -DROCCLR_PATH=${ROCCLR_DIR} -DAMD_OPENCL_PATH=$ROCM_OPENCL_RUNTIME_SRC \
    -DCMAKE_HIP_ARCHITECTURES=$GFX_ARCHS -DHIP_LLVM_ROOT="${ROCM_INSTALL_DIR}/llvm"

# revert back previous hack
# if [ ${SYSTEM_HAS_GPU} -eq 0 ]; then
#     cd "${ROCM_INSTALL_DIR}/bin"
#     mv rocm_agent_enumerator_backup rocm_agent_enumerator
#     cd "${BUILD_FOLDER}"
# fi

cmake_install roctracer -DCMAKE_BUILD_TYPE=${BUILD_TYPE} -DHIP_VDI=1 -DCMAKE_INSTALL_PREFIX="${ROCM_INSTALL_DIR}"
cmake_install rocprofiler
cmake_install HIPIFY -DCMAKE_BUILD_TYPE=${BUILD_TYPE} -DCMAKE_INSTALL_PREFIX=${ROCM_INSTALL_DIR}/hipify
cmake_install ROCdbgapi
cmake_install rocr_debug_agent -DCMAKE_MODULE_PATH=${ROCM_INSTALL_DIR}/hip/cmake -DCMAKE_BUILD_TYPE=${BUILD_TYPE} \
    -DCMAKE_INSTALL_PREFIX=${ROCM_INSTALL_DIR} -DCMAKE_HIP_ARCHITECTURES="$GFX_ARCHS"

cmake_install rocm_bandwidth_test
cmake_install half

cmake_install rocBLAS -DCMAKE_PREFIX_PATH="${ROCM_INSTALL_DIR}/llvm;${ROCM_INSTALL_DIR};${ROCM_INSTALL_DIR}/hip" \
     -DRUN_HEADER_TESTING=OFF -DBUILD_TESTING=OFF \
     -DTensile_CODE_OBJECT_VERSION=V3 -DCMAKE_INSTALL_PREFIX=${ROCM_INSTALL_DIR} -DAMDGPU_TARGETS="$GFX_ARCHS" \
     -DCMAKE_BUILD_TYPE=${BUILD_TYPE} -DCMAKE_TOOLCHAIN_FILE=../toolchain-linux.cmake

cmake_install rocRAND -DCMAKE_BUILD_TYPE=${BUILD_TYPE} -DCMAKE_INSTALL_PREFIX=${ROCM_INSTALL_DIR} \
    -DAMDGPU_TARGETS=$GFX_ARCHS -DCMAKE_CXX_COMPILER=hipcc -DBUILD_HIPRAND=OFF


cmake_install rocSOLVER -DCMAKE_BUILD_TYPE=${BUILD_TYPE} -DCMAKE_INSTALL_PREFIX=${ROCM_INSTALL_DIR} \
    -DCMAKE_CXX_COMPILER=hipcc -DAMDGPU_TARGETS=$GFX_ARCHS

cmake_install rocPRIM -DCMAKE_BUILD_TYPE=${BUILD_TYPE} -DCMAKE_INSTALL_PREFIX=${ROCM_INSTALL_DIR} \
    -DCMAKE_CXX_COMPILER=hipcc -DAMDGPU_TARGETS=$GFX_ARCHS

cmake_install rocSPARSE -DCMAKE_BUILD_TYPE=${BUILD_TYPE} -DCMAKE_INSTALL_PREFIX=${ROCM_INSTALL_DIR} \
    -DCMAKE_CXX_COMPILER=hipcc -DAMDGPU_TARGETS=$GFX_ARCHS -DBUILD_CLIENTS_SAMPLES=OFF

# DOES NOT COMPILE -  https://github.com/ROCmSoftwarePlatform/rocALUTION/issues/144
# cmake_install rocALUTION -DCMAKE_BUILD_TYPE=${BUILD_TYPE} -DCMAKE_INSTALL_PREFIX=${ROCM_INSTALL_DIR} \
#     -DCMAKE_CXX_COMPILER=hipcc -DAMDGPU_TARGETS=$GFX_ARCHS -DBUILD_CLIENTS_SAMPLES=OFF \
#     -DCMAKE_MODULE_PATH="${ROCM_INSTALL_DIR}/hip/cmake;${ROCM_INSTALL_DIR}" #  remove this last option


cmake_install hipBLAS -DCMAKE_BUILD_TYPE=${BUILD_TYPE} -DCMAKE_INSTALL_PREFIX=${ROCM_INSTALL_DIR} \
    -DCMAKE_CXX_COMPILER=hipcc -DAMDGPU_TARGETS="$GFX_ARCHS"

cmake_install hipSOLVER -DCMAKE_BUILD_TYPE=${BUILD_TYPE} -DCMAKE_INSTALL_PREFIX=${ROCM_INSTALL_DIR} \
    -DCMAKE_CXX_COMPILER=hipcc -DAMDGPU_TARGETS="$GFX_ARCHS"

cmake_install hipSPARSE -DCMAKE_BUILD_TYPE=${BUILD_TYPE} -DCMAKE_INSTALL_PREFIX=${ROCM_INSTALL_DIR} \
    -DCMAKE_CXX_COMPILER=hipcc -DAMDGPU_TARGETS="$GFX_ARCHS"

cmake_install hipCUB -DCMAKE_BUILD_TYPE=${BUILD_TYPE} -DCMAKE_INSTALL_PREFIX=${ROCM_INSTALL_DIR} \
    -DCMAKE_CXX_COMPILER=hipcc -DAMDGPU_TARGETS="$GFX_ARCHS"

# # DOES NOT COMPILE - https://github.com/ROCmSoftwarePlatform/rocFFT/issues/363
# will be fixed in next release
# cmake_install rocFFT -DCMAKE_BUILD_TYPE=${BUILD_TYPE} -DCMAKE_INSTALL_PREFIX=${ROCM_INSTALL_DIR} \
#     -DCMAKE_CXX_COMPILER=hipcc -DAMDGPU_TARGETS="$GFX_ARCHS"

# cmake_install hipFFT -DCMAKE_BUILD_TYPE=${BUILD_TYPE} -DCMAKE_INSTALL_PREFIX=${ROCM_INSTALL_DIR} \
#     -DCMAKE_CXX_COMPILER=hipcc -DAMDGPU_TARGETS=$GFX_ARCHS \
#     -DCMAKE_MODULE_PATH="${ROCM_INSTALL_DIR}/hip/cmake;${ROCM_INSTALL_DIR}"

cmake_install rocThrust -DCMAKE_BUILD_TYPE=${BUILD_TYPE} -DCMAKE_INSTALL_PREFIX=${ROCM_INSTALL_DIR} \
    -DCMAKE_CXX_COMPILER=hipcc -DAMDGPU_TARGETS="$GFX_ARCHS"

cmake_install hipfort
cmake_install rccl -DCMAKE_BUILD_TYPE=${BUILD_TYPE} -DCMAKE_INSTALL_PREFIX=${ROCM_INSTALL_DIR} \
    -DCMAKE_CXX_COMPILER=hipcc -DAMDGPU_TARGETS="$GFX_ARCHS"

# FIXTHIS WARNING: #pragma message: cl_version.h: CL_TARGET_OPENCL_VERSION is not defined. Defaulting to 220 (OpenCL 2.2)
cmake_install MIOpenGEMM


# # TODO: compile tensile separately
# export LD_LIBRARY_PATH:/lib/llvm-10/lib:$LD_LIBRARY_PATH
# export LIBRARY_PATH:/lib/llvm-10/lib:$LIBRARY_PATH
# run_command cd ${BUILD_FOLDER}/Tensile/Tensile/Source
# run_command mkdir build
# run_command cd build
# run_command cmake -DCMAKE_BUILD_TYPE=${BUILD_TYPE} -DCMAKE_INSTALL_PREFIX=${ROCM_INSTALL_DIR} \
#     -DTensile_CODE_OBJECT_VERSION=V3 -DCMAKE_CXX_COMPILER=hipcc -DTENSILE_GPU_ARCHS=$GFX_ARCHS ..
# run_command make -j $NCORES


cmake_install MIOpenTensile -DCMAKE_BUILD_TYPE=${BUILD_TYPE} -DCMAKE_INSTALL_PREFIX=${ROCM_INSTALL_DIR}\
    -DTensile_CODE_OBJECT_VERSION=V3 -DAMDGPU_TARGETS=$GFX_ARCHS -DCMAKE_CXX_COMPILER=hipcc


cmake_install llvm-project-mlir -DCMAKE_PREFIX_PATH=${ROCM_INSTALL_DIR} -DCMAKE_BUILD_TYPE=${BUILD_TYPE}\
    -DBUILD_FAT_LIBMLIRMIOPEN=1 -DCMAKE_INSTALL_PREFIX=${ROCM_INSTALL_DIR}/mlir # NOT USED? -DAMDGPU_TARGETS="$GFX_ARCHS"

TODO investigate  MIOPEN_USE_MIOPENGEMM=ON and MIOPEN_USE_MIOPENTENSILE


cmake_install MIOpen -DCMAKE_PREFIX_PATH=${ROCM_INSTALL_DIR} -DCMAKE_BUILD_TYPE=${BUILD_TYPE} \
    -DCMAKE_INSTALL_PREFIX=${ROCM_INSTALL_DIR} -DAMDGPU_TARGETS=$GFX_ARCHS -DCMAKE_CXX_COMPILER=clang++\
    -DMIOPEN_USE_MIOPENGEMM=ON


export GFXLIST="${GFX_ARCHS}" # e.g.: gfx900 is for AMD Vega GPUs
cmake_install atmi -DCMAKE_INSTALL_PREFIX=${ROCM_INSTALL_DIR} -DCMAKE_BUILD_TYPE=${BUILD_TYPE} \
    -DLLVM_DIR="${ROCM_INSTALL_DIR}/llvm" -DDEVICE_LIB_DIR=${DEVICE_LIBS} -DATMI_DEVICE_RUNTIME=ON \
    -DATMI_HSA_INTEROP=ON -DROCM_DIR="${ROCM_INSTALL_DIR}/hsa"