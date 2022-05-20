#!/bin/bash

# Author: Cristian Di Pietrantonio

# Input parameters
ROCM_VERSION=5.1.0
ROCM_VERSION_BRANCH=5.1.x
GFX_ARCHS="gfx908" # https://llvm.org/docs/AMDGPUUsage.html check this
NCORES=8
ROCM_INSTALL_DIR=/opt/rocm-dev2
CLEAN_BUILD=0
SYSTEM_HAS_GPU=0
START_DIR=`pwd`
CMAKE_VERSION=3.23.1
BUILD_TYPE=Release

export CMAKE_PREFIX_PATH=$ROCM_INSTALL_DIR:$ROCM_INSTALL_DIR/rocclr:$ROCM_INSTALL_DIR/include/hsa:$CMAKE_PREFIX_PATH
export CPATH=$ROCM_INSTALL_DIR/rocclr/include/elf:$ROCM_INSTALL_DIR/include/hsa:$CPATH


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



function run_command {
    echo "Running command $@"
    # All the following mess is due to the ';' present in some parameters. We need to put arguments to cmake into single quotes.
    declare -i count
    count=0
    string_to_eval=""
    for arg in $@;
    do
    if [ $count -eq 0 ]; then
            string_to_eval="$arg"
    else
            string_to_eval="$string_to_eval '$arg'"
    fi
    (( count=count+1 ))
    done
    eval "$string_to_eval"
    if [ $? -ne 0 ]; then
        echo "Error running a command: $@"
           exit 1
    fi           
}

function apply_hipamd_patch {
    cd $BUILD_FOLDER/hipamd
    patch -p1 << 'EOF'
--- a/CMakeLists.txt	2022-05-01 23:39:05.857043471 +0000
+++ b/CMakeLists.txt	2022-05-01 23:40:39.727778449 +0000
@@ -144,6 +144,9 @@
     set(HIP_PACKAGING_VERSION_PATCH ${HIP_VERSION_PATCH}-${HIP_VERSION_GITHASH})
   endif()
 else()
+  set(HIP_VERSION_BUILD_ID 0)
+  set(HIP_VERSION_BUILD_NAME "")
+  set(HIP_VERSION_PATCH 1)
   # FIXME: Some parts depend on this being set.
   set(HIP_PACKAGING_VERSION_PATCH "0")
 endif()
@@ -187,8 +190,10 @@
 set (HIP_LIB_VERSION_MINOR ${HIP_VERSION_MINOR})
 if (${ROCM_PATCH_VERSION} )
    set (HIP_LIB_VERSION_PATCH ${ROCM_PATCH_VERSION})
-else ()
+elseif (DEFINED HIP_VERSION_GITHASH)
    set (HIP_LIB_VERSION_PATCH ${HIP_VERSION_PATCH}-${HIP_VERSION_GITHASH})
+else ()
+   set (HIP_LIB_VERSION_PATCH ${HIP_VERSION_PATCH})
 endif ()
 set (HIP_LIB_VERSION_STRING "${HIP_LIB_VERSION_MAJOR}.${HIP_LIB_VERSION_MINOR}.${HIP_LIB_VERSION_PATCH}")
 if (DEFINED ENV{ROCM_RPATH})
EOF
    cd $BUILD_FOLDER
}


function cmake_install {
    cd $BUILD_FOLDER
    PACKAGE_NAME="$1"
    CMAKE_FLAGS="-DCMAKE_BUILD_TYPE=$BUILD_TYPE -DCMAKE_INSTALL_PREFIX=$ROCM_INSTALL_DIR"
    SOURCE_DIR=".."
    if [ $# -eq 2 ]; then
        CMAKE_FLAGS="$2"
    fi
    echo "Installing $PACKAGE_NAME .."
    cd $PACKAGE_NAME
    if [ "$PACKAGE_NAME" = "ROCR-Runtime" ]; then
        cd src
    elif [ "$PACKAGE_NAME" = "llvm-project" ]; then
        SOURCE_DIR="../llvm"
    fi
    mkdir build 
    cd build
    run_command cmake "$CMAKE_FLAGS" "$SOURCE_DIR"
    run_command make -j $NCORES install
    cd $BUILD_FOLDER
}



export_vars $ROCM_INSTALL_DIR
export_vars $ROCM_INSTALL_DIR/rocclr
export_vars $ROCM_INSTALL_DIR/opencl
export_vars $ROCM_INSTALL_DIR/llvm
export_vars $ROCM_INSTALL_DIR/hip
export_vars $ROCM_INSTALL_DIR/roctracer
export_vars $ROCM_INSTALL_DIR/rocrand
export_vars $ROCM_INSTALL_DIR/rocblas
export_vars $ROCM_INSTALL_DIR/rocsparse
export_vars $ROCM_INSTALL_DIR/boost

# Setting up build process and dependencies
apt install -y gfortran libnuma-dev libudev-dev xxd libdrm-dev libudev-dev libelf-dev libc6-dev-i386 python3-pip sqlite3 curl git libgl1-mesa-dev libglu1-mesa-dev freeglut3-dev mesa-common-dev wget libssl-dev libdw-dev python3.8-venv
pip3 install cppheaderparser argparse virtualenv

BUILD_FOLDER="$START_DIR/build"
export_vars "$BUILD_FOLDER/build-deps"
if [ -d "$BUILD_FOLDER" ] && [ $CLEAN_BUILD -eq 1 ]; then
    echo "Cleaning up previous build."
    rm -rf "$BUILD_FOLDER"
fi
[ -d "$BUILD_FOLDER" ] || mkdir -p "$BUILD_FOLDER/build-deps/bin"
# we need "python" and "pip" executables
if [[ `which python` == "" ]]; then
    run_command cd "$BUILD_FOLDER/build-deps/bin"; ln -s `which python3` python;
fi
if [[ `which pip` == "" ]]; then
    run_command cd "$BUILD_FOLDER/build-deps/bin"; ln -s `which pip3` pip;
fi
cd $BUILD_FOLDER
if ! [ -d hipamd ]; then 
    # Dowload all the ROCM repositories with the repo tool. First, we need the tool
    run_command curl https://storage.googleapis.com/git-repo-downloads/repo -o "$BUILD_FOLDER/bin/repo"
    run_command chmod a+x "$BUILD_FOLDER/bin/repo"
    echo "Downloading ROCM repositories"
    run_command repo init -u https://github.com/RadeonOpenCompute/ROCm.git -b roc-${ROCM_VERSION_BRANCH}
    run_command repo sync
    # Needed for rocBLAS
    run_command git clone -b cpp-3.0.1 https://github.com/msgpack/msgpack-c.git
    
fi

# Always use the latest cmake. ROCMm depends heavily on latest CMake features, including HIP support.
# cd $BUILD_FOLDER
# wget https://github.com/Kitware/CMake/releases/download/v${CMAKE_VERSION}/cmake-${CMAKE_VERSION}.tar.gz
# tar -xf cmake-${CMAKE_VERSION}.tar.gz
# cd cmake-${CMAKE_VERSION}
# ./configure --prefix=$BUILD_FOLDER/build-deps
# make -j $NCORES
# make install


# # ROCT-Thunk-Interface
# cmake_install ROCT-Thunk-Interface

# LLVM
DEVICE_LIBS="$BUILD_FOLDER/ROCm-Device-Libs"
BITCODE_DIR=$ROCM_INSTALL_DIR/llvm/amdgcn/bitcode

# cmake_install llvm-project "-DCMAKE_BUILD_TYPE=${BUILD_TYPE} \
#      -DLLVM_ENABLE_PROJECTS=llvm;clang;lld;compiler-rt \
#      -DLLVM_TARGETS_TO_BUILD=AMDGPU;X86\
#      -DLLVM_EXTERNAL_PROJECTS=device-libs \
#      -DCMAKE_INSTALL_PREFIX=$ROCM_INSTALL_DIR/llvm\
#      -DLLVM_EXTERNAL_DEVICE_LIBS_SOURCE_DIR=$DEVICE_LIBS"

# # The following is needed otherwise clang complains when executing hipcc
# ln -s ${ROCM_INSTALL_DIR}/llvm/amdgcn ${ROCM_INSTALL_DIR}/amdgcn

# # ROCM Runtime
# cmake_install ROCR-Runtime "-DCMAKE_BUILD_TYPE=${BUILD_TYPE} -DCMAKE_INSTALL_PREFIX=$ROCM_INSTALL_DIR -DBITCODE_DIR=$BITCODE_DIR"

# # ROCM cmake
# cmake_install rocm-cmake

# # opencl
# cmake_install clang-ocl "-DCMAKE_BUILD_TYPE=${BUILD_TYPE} -DROCM_DIR=$ROCM_INSTALL_DIR -DCMAKE_INSTALL_PREFIX=$ROCM_INSTALL_DIR"


# # ROCm compiler support
# cd ROCm-CompilerSupport/lib/comgr
# run_command mkdir build && cd build
# run_command cmake -DCMAKE_BUILD_TYPE=${BUILD_TYPE} -DCMAKE_INSTALL_PREFIX=$ROCM_INSTALL_DIR ..
# run_command make -j $NCORES install

# # ROCM-smi-lib
# cmake_install rocm_smi_lib

# # ROCM info
# cmake_install rocminfo

# # install opencl runtime
export OPENCL_DIR=$BUILD_FOLDER/ROCm-OpenCL-Runtime
# run_command mkdir -p /etc/OpenCL/vendors/
# run_command cp ${OPENCL_DIR}/config/amdocl64.icd /etc/OpenCL/vendors/
# cmake_install ROCm-OpenCL-Runtime "-DCMAKE_BUILD_TYPE=${BUILD_TYPE} -DUSE_COMGR_LIBRARY=ON -DROCM_PATH=$ROCM_INSTALL_DIR -DCMAKE_INSTALL_PREFIX=$ROCM_INSTALL_DIR/opencl"


# # HIP
COMMON_HIP=$BUILD_FOLDER/HIP
# if [ ${SYSTEM_HAS_GPU} -eq 0 ]; then
#     cd $ROCM_INSTALL_DIR/bin
#     mv rocm_agent_enumerator rocm_agent_enumerator_backup
#     echo """#!/bin/bash
#     echo gfx908

#     """ > rocm_agent_enumerator
#     chmod 0755 rocm_agent_enumerator
# fi

export HIP_CLANG_PATH=$ROCM_INSTALL_DIR/llvm/bin
export ROCM_PATH=${ROCM_INSTALL_DIR}
export ROCCLR_DIR=$BUILD_FOLDER/ROCclr
export HIP_PATH=$ROCM_INSTALL_DIR/hip2
export HSA_PATH=$ROCM_INSTALL_DIR/hsa
export HIP_ROCCLR_HOME=$ROCM_INSTALL_DIR/hip/rocclr
export HIP_RUNTIME=rocclr
# apply_hipamd_patch # see https://github.com/ROCmSoftwarePlatform/rocALUTION/issues/144
# cmake_install hipamd "-DCMAKE_BUILD_TYPE=${BUILD_TYPE} -DHIP_COMMON_DIR=$COMMON_HIP -DCMAKE_PREFIX_PATH=$BUILD_FOLDER/rocclr;$ROCM_INSTALL_DIR\
#     -DROCM_PATH=$ROCM_INSTALL_DIR -DCMAKE_INSTALL_PREFIX=$ROCM_INSTALL_DIR/hip2 -DHSA_PATH=$ROCM_INSTALL_DIR/hsa -DROCCLR_PATH=$ROCCLR_DIR \
#     -DAMD_OPENCL_PATH=$OPENCL_DIR  -DCMAKE_HIP_ARCHITECTURES=$GFX_ARCHS"

# # revert back previous hack
# if [ ${SYSTEM_HAS_GPU} -eq 0 ]; then
#     cd $ROCM_INSTALL_DIR/bin
#     mv rocm_agent_enumerator_backup rocm_agent_enumerator
#     cd $BUILD_FOLDER
# fi

# # ROCTracer and ROCprofiler install
# cmake_install roctracer "-DCMAKE_BUILD_TYPE=${BUILD_TYPE} -DHIP_VDI=1 -DCMAKE_INSTALL_PREFIX=$ROCM_INSTALL_DIR"
# cmake_install rocprofiler
# cmake_install HIPIFY "-DCMAKE_BUILD_TYPE=${BUILD_TYPE} -DCMAKE_INSTALL_PREFIX=$ROCM_INSTALL_DIR/hipify"
# cmake_install ROCdbgapi
# cmake_install rocr_debug_agent "-DCMAKE_MODULE_PATH=$ROCM_INSTALL_DIR/hip/cmake -DCMAKE_BUILD_TYPE=${BUILD_TYPE} \
#     -DCMAKE_INSTALL_PREFIX=$ROCM_INSTALL_DIR -DCMAKE_HIP_ARCHITECTURES=$GFX_ARCHS"
# cmake_install rocm_bandwidth_test
# cmake_install half

# build rocblas (CURRENTLY DOES NOT WORK https://github.com/ROCmSoftwarePlatform/rocBLAS/issues/1250)
# cmake_install msgpack-c "-DCMAKE_BUILD_TYPE=${BUILD_TYPE} -DCMAKE_INSTALL_PREFIX=$ROCM_INSTALL_DIR -DMSGPACK_BUILD_TESTS=OFF -DMSGPACK_BUILD_EXAMPLES=OFF"

# cmake_install rocBLAS "-DCMAKE_BUILD_TYPE=${BUILD_TYPE} -DCMAKE_PREFIX_PATH=$ROCM_INSTALL_DIR/llvm;$ROCM_INSTALL_DIR;$ROCM_INSTALL_DIR/hip\
#      -DCMAKE_TOOLCHAIN_FILE=../toolchain-linux.cmake -DRUN_HEADER_TESTING=OFF -DBUILD_TESTING=OFF -DTensile_CODE_OBJECT_VERSION=V3 \
#     -DCMAKE_INSTALL_PREFIX=$ROCM_INSTALL_DIR  -DAMDGPU_TARGETS=$GFX_ARCHS"
# rocRAND
# cd $BUILD_FOLDER
# git clone -b release/rocm-rel-5.0 https://github.com/ROCmSoftwarePlatform/hipRAND.git
# cmake_install rocRAND "-DCMAKE_BUILD_TYPE=${BUILD_TYPE} -DCMAKE_INSTALL_PREFIX=$ROCM_INSTALL_DIR -DAMDGPU_TARGETS=$GFX_ARCHS -DCMAKE_CXX_COMPILER=hipcc -DBUILD_HIPRAND=OFF"

# rocSOLVER
# git clone -b6.1.2 https://github.com/fmtlib/fmt.git
# cmake_install fmt  "-DCMAKE_BUILD_TYPE=${BUILD_TYPE} -DCMAKE_INSTALL_PREFIX=$ROCM_INSTALL_DIR -DCMAKE_CXX_FLAGS=-fPIC"
# cmake_install rocSOLVER "-DCMAKE_BUILD_TYPE=${BUILD_TYPE} -DCMAKE_INSTALL_PREFIX=$ROCM_INSTALL_DIR  -DCMAKE_CXX_COMPILER=hipcc -DAMDGPU_TARGETS=$GFX_ARCHS"

# cmake_install rocPRIM "-DCMAKE_BUILD_TYPE=${BUILD_TYPE} -DCMAKE_INSTALL_PREFIX=$ROCM_INSTALL_DIR  -DCMAKE_CXX_COMPILER=hipcc -DAMDGPU_TARGETS=$GFX_ARCHS"

# cmake_install rocSPARSE "-DCMAKE_BUILD_TYPE=${BUILD_TYPE} -DCMAKE_INSTALL_PREFIX=$ROCM_INSTALL_DIR  -DCMAKE_CXX_COMPILER=hipcc -DAMDGPU_TARGETS=$GFX_ARCHS -DBUILD_CLIENTS_SAMPLES=OFF"

# DOES NOT COMPILE -  https://github.com/ROCmSoftwarePlatform/rocALUTION/issues/144
# cmake_install rocALUTION "-DCMAKE_BUILD_TYPE=${BUILD_TYPE} -DCMAKE_INSTALL_PREFIX=$ROCM_INSTALL_DIR  -DCMAKE_CXX_COMPILER=hipcc -DAMDGPU_TARGETS=$GFX_ARCHS -DBUILD_CLIENTS_SAMPLES=OFF -DCMAKE_MODULE_PATH=$ROCM_INSTALL_DIR/hip/cmake;$ROCM_INSTALL_DIR" #  remove this last option


# cmake_install hipBLAS  "-DCMAKE_BUILD_TYPE=${BUILD_TYPE} -DCMAKE_INSTALL_PREFIX=$ROCM_INSTALL_DIR  -DCMAKE_CXX_COMPILER=hipcc -DAMDGPU_TARGETS=$GFX_ARCHS"

# cmake_install hipSOLVER  "-DCMAKE_BUILD_TYPE=${BUILD_TYPE} -DCMAKE_INSTALL_PREFIX=$ROCM_INSTALL_DIR  -DCMAKE_CXX_COMPILER=hipcc -DAMDGPU_TARGETS=$GFX_ARCHS"

# cmake_install hipSPARSE  "-DCMAKE_BUILD_TYPE=${BUILD_TYPE} -DCMAKE_INSTALL_PREFIX=$ROCM_INSTALL_DIR  -DCMAKE_CXX_COMPILER=hipcc -DAMDGPU_TARGETS=$GFX_ARCHS"

# cmake_install hipCUB  "-DCMAKE_BUILD_TYPE=${BUILD_TYPE} -DCMAKE_INSTALL_PREFIX=$ROCM_INSTALL_DIR  -DCMAKE_CXX_COMPILER=hipcc -DAMDGPU_TARGETS=$GFX_ARCHS"

# DOES NOT COMPILE - https://github.com/ROCmSoftwarePlatform/rocFFT/issues/363
# cmake_install rocFFT  "-DCMAKE_BUILD_TYPE=${BUILD_TYPE} -DCMAKE_INSTALL_PREFIX=$ROCM_INSTALL_DIR  -DCMAKE_CXX_COMPILER=hipcc -DAMDGPU_TARGETS=$GFX_ARCHS"

# cmake_install hipFFT  "-DCMAKE_BUILD_TYPE=${BUILD_TYPE} -DCMAKE_INSTALL_PREFIX=$ROCM_INSTALL_DIR  -DCMAKE_CXX_COMPILER=hipcc -DAMDGPU_TARGETS=$GFX_ARCHS -DCMAKE_MODULE_PATH=$ROCM_INSTALL_DIR/hip/cmake;$ROCM_INSTALL_DIR"

# cmake_install rocThrust  "-DCMAKE_BUILD_TYPE=${BUILD_TYPE} -DCMAKE_INSTALL_PREFIX=$ROCM_INSTALL_DIR  -DCMAKE_CXX_COMPILER=hipcc -DAMDGPU_TARGETS=$GFX_ARCHS"


# cmake_install hipfort

# cmake_install rccl "-DCMAKE_BUILD_TYPE=${BUILD_TYPE} -DCMAKE_INSTALL_PREFIX=$ROCM_INSTALL_DIR  -DCMAKE_CXX_COMPILER=hipcc -DAMDGPU_TARGETS=$GFX_ARCHS"

#FIXTHIS WARNING: #pragma message: cl_version.h: CL_TARGET_OPENCL_VERSION is not defined. Defaulting to 220 (OpenCL 2.2)
# cmake_install MIOpenGEMM
cd $BUILD_FOLDER
# run_command wget https://boostorg.jfrog.io/artifactory/main/release/1.72.0/source/boost_1_72_0_rc2.tar.gz
# run_command tar -xf boost_1_72_0_rc2.tar.gz
# run_command cd boost_1_72_0
# OLD_CPLUS_VAR=$CPLUS_INCLUDE_PATH
# export CPLUS_INCLUDE_PATH=""
# ( unset CPLUS_INCLUDE_PATH; unset CPATH; ./bootstrap.sh --prefix=$ROCM_INSTALL_DIR/boost )
# export CPLUS_INCLUDE_PATH=$OLD_CPLUS_VAR
# run_command ./b2 headers
# run_command ./b2 -j$NCORES install toolset=gcc --with=all --prefix=$ROCM_INSTALL_DIR/boost

# the following requires boost TODO: compile tensile separately
# apt-get -y install libomp-dev
# export LD_LIBRARY_PATH:/lib/llvm-10/lib:$LD_LIBRARY_PATH
# export LIBRARY_PATH:/lib/llvm-10/lib:$LIBRARY_PATH
# cd $BUILD_FOLDER/Tensile/Tensile/Source
# mkdir build
# cd build
# cmake -DCMAKE_BUILD_TYPE=${BUILD_TYPE} -DCMAKE_INSTALL_PREFIX=$ROCM_INSTALL_DIR -DTensile_CODE_OBJECT_VERSION=V3 -DCMAKE_CXX_COMPILER=hipcc -DTENSILE_GPU_ARCHS=$GFX_ARCHS ..
# make -j $NCORES


# cmake_install MIOpenTensile "-DCMAKE_BUILD_TYPE=${BUILD_TYPE} -DCMAKE_INSTALL_PREFIX=$ROCM_INSTALL_DIR -DTensile_CODE_OBJECT_VERSION=V3   -DAMDGPU_TARGETS=$GFX_ARCHS -DCMAKE_CXX_COMPILER=hipcc"

cd $BUILD_FOLDER
# run_command wget https://www.sqlite.org/snapshot/sqlite-snapshot-202205121156.tar.gz
# run_command tar -xf sqlite-snapshot-202205121156.tar.gz
# run_command cd sqlite-snapshot-202205121156
# run_command ./configure --prefix=$ROCM_INSTALL_DIR
# run_command make -j $NCORES install
# git clone -b release/rocm-5.1 https://github.com/ROCmSoftwarePlatform/llvm-project-mlir.git
# cmake_install llvm-project-mlir "-DCMAKE_PREFIX_PATH=$ROCM_INSTALL_DIR -DCMAKE_BUILD_TYPE=${BUILD_TYPE} -DCMAKE_INSTALL_PREFIX=$ROCM_INSTALL_DIR/mlir -DAMDGPU_TARGETS=$GFX_ARCHS"
# investigate  MIOPEN_USE_MIOPENGEMM            ON                                                                                                                                           
# MIOPEN_USE_MIOPENTENSILE  
# cmake_install MIOpen "-DCMAKE_PREFIX_PATH=$ROCM_INSTALL_DIR -DCMAKE_BUILD_TYPE=${BUILD_TYPE} -DCMAKE_INSTALL_PREFIX=$ROCM_INSTALL_DIR -DAMDGPU_TARGETS=$GFX_ARCHS -DCMAKE_CXX_COMPILER=clang++ -DMIOPEN_USE_MIOPENGEMM=On"

# IS RCP meant to be part of ROCm??

# cd $BUILD_FOLDER/atmi/src
# mkdir build
# cd build
# export GFXLIST="${GFX_ARCHS}" # e.g.: gfx900 is for AMD Vega GPUs
# # ensure you have cmake (version >= 2.8)
# cmake \
#     -DCMAKE_INSTALL_PREFIX=${ROCM_INSTALL_DIR} \
#     -DCMAKE_BUILD_TYPE=Release \
#     -DLLVM_DIR=${ROCM_INSTALL_DIR}/llvm \
#     -DDEVICE_LIB_DIR=${DEVICE_LIBS}  \
#     -DATMI_DEVICE_RUNTIME=ON \
#     -DATMI_HSA_INTEROP=ON    \
#     -DROCM_DIR=${ROCM_INSTALL_DIR}/hsa\
#     ..
# # make all components (Host runtime and device runtime)
# make -j $NCORES
# make install