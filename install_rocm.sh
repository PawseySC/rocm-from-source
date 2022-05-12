#!/bin/bash

# Author: Cristian Di Pietrantonio

# Input parameters
ROCM_VERSION=5.1.0
ROCM_VERSION_BRANCH=5.1.x
GFX_ARCHS="gfx906,gfx908"
NCORES=8
ROCM_INSTALL_DIR=/opt/rocm-dev2
CLEAN_BUILD=0
SYSTEM_HAS_GPU=0
START_DIR=`pwd`


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
	eval "$@"
	if [ $? -ne 0 ]; then
	    echo "Error running a command: $@"
       	exit 1
	fi	       
}


function log {
    echo "$1"
}



function cmake_install {
	cd $BUILD_FOLDER
	PACKAGE_NAME="$1"
	CMAKE_FLAGS="$2"
	SOURCE_DIR=".."
    if [ $# -eq 1 ]; then
		CMAKE_FLAGS="-DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=$ROCM_INSTALL_DIR"
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
	run_command cmake $CMAKE_FLAGS $SOURCE_DIR
	run_command make -j $NCORES install
    cd $BUILD_FOLDER
}



export_vars $ROCM_INSTALL_DIR
export_vars $ROCM_INSTALL_DIR/rocclr
export_vars $ROCM_INSTALL_DIR/opencl
export_vars $ROCM_INSTALL_DIR/llvm
export_vars $ROCM_INSTALL_DIR/hip
export_vars $ROCM_INSTALL_DIR/roctracer


# Setting up build process and dependencies
apt install -y libnuma-dev libudev-dev xxd libdrm-dev libudev-dev libelf-dev libc6-dev-i386 python3-pip sqlite3 curl git libgl1-mesa-dev libglu1-mesa-dev freeglut3-dev mesa-common-dev wget libssl-dev
pip3 install cppheaderparser argparse

BUILD_FOLDER="$START_DIR/build"
export_vars "$BUILD_FOLDER/build-deps"
if [ -d "$BUILD_FOLDER" ] && [ $CLEAN_BUILD -eq 1 ]; then
    log "Cleaning up previous build."
    rm -rf "$BUILD_FOLDER"
fi
[ -d "$BUILD_FOLDER" ] || mkdir -p "$BUILD_FOLDER/build-deps/bin"
# we need a "python" executable
if [[ `which python` == "" ]]; then
    run_command cd "$BUILD_FOLDER/build-deps/bin"; ln -s `which python3` python;
fi
cd $BUILD_FOLDER
if ! [ -d hipamd ]; then 
    # Dowload all the ROCM repositories with the repo tool. First, we need the tool
    run_command curl https://storage.googleapis.com/git-repo-downloads/repo -o "$BUILD_FOLDER/bin/repo"
    run_command chmod a+x "$BUILD_FOLDER/bin/repo"
    log "Downloading ROCM repositories"
    run_command repo init -u https://github.com/RadeonOpenCompute/ROCm.git -b roc-${ROCM_VERSION_BRANCH}
    run_command repo sync
fi

#INSTALL cmake
# cd $BUILD_FOLDER
# wget https://github.com/Kitware/CMake/releases/download/v3.21.3/cmake-3.21.3.tar.gz
# tar -xf cmake-3.21.3.tar.gz
# cd cmake-3.21.3
# ./configure --prefix=$BUILD_FOLDER/build-deps
# make -j $NCORES
# make install


# # ROCT-Thunk-Interface
# cmake_install ROCT-Thunk-Interface

# LLVM
DEVICE_LIBS="$BUILD_FOLDER/ROCm-Device-Libs"
BITCODE_DIR=$ROCM_INSTALL_DIR/llvm/amdgcn/bitcode
# cd llvm-project
# mkdir build 
# cd build
# cmake ../llvm -DCMAKE_BUILD_TYPE=Release \
#      -DLLVM_ENABLE_PROJECTS="llvm;clang;lld;compiler-rt" \
#      -DLLVM_TARGETS_TO_BUILD="AMDGPU;X86"\
#      -DLLVM_EXTERNAL_PROJECTS="device-libs" \
#      -DCMAKE_INSTALL_PREFIX=$ROCM_INSTALL_DIR/llvm\
#      -DLLVM_EXTERNAL_DEVICE_LIBS_SOURCE_DIR=$DEVICE_LIBS
# make -j $NCORES install
# cd $BUILD_FOLDER

# # ROCM Runtime
# apt install -y libelf-dev libc6-dev-i386
# cmake_install ROCR-Runtime "-DCMAKE_INSTALL_PREFIX=$ROCM_INSTALL_DIR -DBITCODE_DIR=$BITCODE_DIR"

# # ROCM cmake
# cmake_install rocm-cmake

# # opencl
# export ROCM_DIR=$ROCM_INSTALL_DIR
# cmake_install clang-ocl "-DROCM_DIR=$ROCM_INSTALL_DIR -DCMAKE_INSTALL_PREFIX=$ROCM_INSTALL_DIR"


# # ROCm compiler support
# cd ROCm-CompilerSupport/lib/comgr
# run_command mkdir build && cd build
# run_command cmake -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=$ROCM_INSTALL_DIR ..
# run_command make -j $NCORES install

# # ROCM-smi-lib
# cmake_install rocm_smi_lib

# # ROCM info
# cmake_install rocminfo
export OPENCL_DIR=$BUILD_FOLDER/ROCm-OpenCL-Runtime
export ROCCLR_DIR=$BUILD_FOLDER/ROCclr


## install opencl runtime
# cd $OPENCL_DIR
# run_command mkdir -p /etc/OpenCL/vendors/
# run_command cp config/amdocl64.icd /etc/OpenCL/vendors/
# mkdir build
# cd build
# run_command cmake -DCMAKE_BUILD_TYPE=Release -DUSE_COMGR_LIBRARY=ON -DROCM_PATH=$ROCM_INSTALL_DIR -DCMAKE_INSTALL_PREFIX=$ROCM_INSTALL_DIR/opencl ..
# run_command make -j$NCORES install

# download roctracer and rocprofiler as they are needed for hip, but do not install them yet
# rocprofiler
export PROFILER_DIR=$BUILD_FOLDER/rocprofiler
# roctracer
export TRACER_DIR=$BUILD_FOLDER/roctracer

# HIP
COMMON_HIP=$BUILD_FOLDER/HIP
# Missing file
#run_command cp $OPENCL_DIR/amdocl/cl_vk_amd.hpp amdocl/ 
# if [ ${SYSTEM_HAS_GPU} -eq 0 ]; then
#     cd $ROCM_INSTALL_DIR/bin
#     mv rocm_agent_enumerator rocm_agent_enumerator_backup
#     echo """#!/bin/bash
#     echo gfx908

#     """ > rocm_agent_enumerator
#     chmod 0777 rocm_agent_enumerator
# fi
# cd $BUILD_FOLDER/hipamd
# mkdir build 
# cd build
# export HIP_CLANG_PATH=$ROCM_INSTALL_DIR/llvm/bin 
# export HIP_PATH=$ROCM_INSTALL_DIR/hip
# export HSA_PATH=$ROCM_INSTALL_DIR/hsa
# export HIP_ROCCLR_HOME=$ROCM_INSTALL_DIR/hip/rocclr
# export HIP_RUNTIME=rocclr
# export HSA_PATH=$ROCM_INSTALL_DIR/hsa
# export CMAKE_HIP_ARCHITECTURES="$GFX_ARCHS"
# cmake -DCMAKE_BUILD_TYPE=Release -DHIP_COMMON_DIR=$COMMON_HIP -DCMAKE_PREFIX_PATH="$BUILD_FOLDER/rocclr;$ROCM_INSTALL_DIR" -DROCM_PATH=$ROCM_INSTALL_DIR -DCMAKE_INSTALL_PREFIX="$ROCM_INSTALL_DIR/hip" -DHSA_PATH=$ROCM_INSTALL_DIR/hsa -DROCCLR_PATH=$ROCCLR_DIR -DAMD_OPENCL_PATH=$OPENCL_DIR  -DCMAKE_HIP_ARCHITECTURES="$GFX_ARCHS" ..
# run_command make -j $NCORES install

# if [ ${SYSTEM_HAS_GPU} -eq 0 ]; then
#     cd $ROCM_INSTALL_DIR/bin
#     mv rocm_agent_enumerator_backup rocm_agent_enumerator
#     cd $BUILD_FOLDER
# fi

# # ROCTracer and ROCprofiler install
# cmake_install roctracer "-DCMAKE_BUILD_TYPE=Release -DHIP_VDI=1 -DCMAKE_INSTALL_PREFIX=$ROCM_INSTALL_DIR"
# cmake_install rocprofiler



# HIPIFY tools
cmake_install HIPIFY "-DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=$ROCM_INSTALL_DIR/hipify"

#ROCdbgapi
cmake_install ROCdbgapi


#rocr_debug_agent
# apt install -y libdw-dev
cmake_install rocr_debug_agent "-DCMAKE_MODULE_PATH=$ROCM_INSTALL_DIR/hip/cmake -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=$ROCM_INSTALL_DIR -DCMAKE_HIP_ARCHITECTURES=$GFX_ARCHS"

#rocm_bandwidth_test
cmake_install rocm_bandwidth_test