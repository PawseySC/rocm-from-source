if [ -z ${ROCM_INSTALL_DIR+x} ] || [ -z ${BUILD_FOLDER+x} ]; then
    echo "one of the input variables is not set."
    exit 1
fi
INSTALL_DIR="${ROCM_INSTALL_DIR}"

export CPATH="${ROCM_INSTALL_DIR}/rocclr/include/elf:${ROCM_INSTALL_DIR}/include/hsa:$CPATH"

cd "${BUILD_FOLDER}"
if ! [ -d hipamd ]; then # use the 'hipamd' folder presence as a flag of software already being do 
    ROCM_VERSION_BRANCH="roc-${ROCM_VERSION%.*}.x"
    echo "Downloading ROCM repositories at branch ${ROCM_VERSION_BRANCH}"
    run_command repo init -u https://github.com/RadeonOpenCompute/ROCm.git -b ${ROCM_VERSION_BRANCH}
    # MIOpen fails to sync for some reason, but let it go, we are not interested in it for now
    repo sync
    run_command git clone -b release/rocm-rel-5.0 https://github.com/ROCmSoftwarePlatform/hipRAND.git
    # Needed for MIOpen
    # run_command git clone -b release/rocm-5.1 https://github.com/ROCmSoftwarePlatform/llvm-project-mlir.git
   
    run_command cd $BUILD_FOLDER
    git clone https://github.com/ROCm-Developer-Tools/aomp-extras.git
    cd aomp-extras && git checkout rocm-${ROCM_VERSION}
fi


# needed for rocprofiler in/since ROCm 5.3.0
get_aqlprofiler() {
    if [ -e ${ROCM_INSTALL_DIR}/lib/libhsa-amd-aqlprofile64.so ]; then
        echo "AQL profiler precompiled library is already installed."
    else
        echo "Getting the AQL profiler precompiled library..."
        cd $BUILD_FOLDER
        run_command mkdir aqlprofiler
        AQL_FILENAME=hsa-amd-aqlprofile5.3.0_1.0.0.50300-63~22.04_amd64
        [ -e ${AQL_FILENAME} ] || run_command wget http://repo.radeon.com/rocm/apt/5.3/pool/main/h/hsa-amd-aqlprofile5.3.0/${AQL_FILENAME}.deb
        [ -e data.tar.xz ] || run_command ar x ${AQL_FILENAME}.deb
        [ -d opt ] || run_command tar xf data.tar.xz
        run_command cp -r opt/rocm-5.3.0/lib/* ${ROCM_INSTALL_DIR}/lib
        echo "AQL profiler library retrieved."
        cd $BUILD_FOLDER
    fi
}

# ====================================================================================================================
#                                        INSTALLATION PROCESS STARTS HERE
# ====================================================================================================================

cmake_install ROCT-Thunk-Interface

# LLVM
# Here is what is going to happen:
# 1. We need to build llvm, the clang compiler and the device libraries because are needed by ROCR-Runtime.
# 2. We build ROCR-Runtime needed also for openmp offloading.
# 3. We build OpenMP for LLVM as a seperate project. Enabling openmp as LLVM runtime does not work.

DEVICE_LIBS="${BUILD_FOLDER}/ROCm-Device-Libs"
BITCODE_DIR="${ROCM_INSTALL_DIR}/llvm/amdgcn/bitcode"

cmake_install llvm-project -DCMAKE_BUILD_TYPE="${BUILD_TYPE}" \
    -DLLVM_ENABLE_PROJECTS="llvm;clang;lld;compiler-rt;" \
    -DCMAKE_PREFIX_PATH=${ROCM_INSTALL_DIR}\
    -DLLVM_TARGETS_TO_BUILD="AMDGPU;X86"\
    -DCMAKE_INSTALL_PREFIX="${ROCM_INSTALL_DIR}/llvm"\
    -DLLVM_EXTERNAL_DEVICE_LIBS_SOURCE_DIR="$DEVICE_LIBS"\
    -DLLVM_EXTERNAL_PROJECTS=device-libs\
    -DLLVM_ENABLE_RUNTIMES=""

# The following is needed otherwise clang complains when executing hipcc
[ -e  "${ROCM_INSTALL_DIR}/amdgcn" ] || \
    run_command ln -s "${ROCM_INSTALL_DIR}/llvm/amdgcn" "${ROCM_INSTALL_DIR}/amdgcn"

cmake_install ROCR-Runtime -DCMAKE_BUILD_TYPE="${BUILD_TYPE}" -DCMAKE_INSTALL_PREFIX="${ROCM_INSTALL_DIR}" -DBITCODE_DIR="$BITCODE_DIR"

cmake_install aomp-extras -DCMAKE_BUILD_TYPE=${BUILD_TYPE} -DCMAKE_INSTALL_PREFIX=${ROCM_INSTALL_DIR} \
    -DCMAKE_CXX_COMPILER=clang++ -DROCM_DIR=${ROCM_INSTALL_DIR} -DLLVM_DIR=${ROCM_INSTALL_DIR}/llvm -DCMAKE_C_COMPILER=clang -DAOMP_VERSION_STRING="${ROCM_VERSION}" 

# the openmp module is compiled separately
cmake_install llvm-project/openmp -DCMAKE_BUILD_TYPE="${BUILD_TYPE}" \
    -DCMAKE_PREFIX_PATH="${ROCM_INSTALL_DIR}/llvm;${ROCM_INSTALL_DIR}/include/hsa"\
    -DLLVM_DIR=${ROCM_INSTALL_DIR}/llvm\
    -DCMAKE_C_COMPILER=clang -DCMAKE_CXX_COMPILER=clang++\
    -DOPENMP_TEST_C_COMPILER=clang -DOPENMP_TEST_CXX_COMPILER=clang++\
    -DLIBOMPTARGET_AMDGCN_GFXLIST=${GFX_ARCHS}\
    -DDEVICELIBS_ROOT=${DEVICE_LIBS}\
    -DCMAKE_INSTALL_PREFIX="${ROCM_INSTALL_DIR}/llvm"\
    -DOPENMP_ENABLE_LIBOMPTARGET=1\
    -DLIBOMP_COPY_EXPORTS=OFF\
    -DLIBOMPTARGET_ENABLE_DEBUG=ON\
    -DLLVM_INSTALL_PREFIX=$ROCM_INSTALL_DIR/llvm\
    -DLLVM_MAIN_INCLUDE_DIR=$BUILD_FOLDER/llvm-project/llvm/include\
    -DLIBOMPTARGET_LLVM_INCLUDE_DIRS=$BUILD_FOLDER/llvm-project/llvm/include


cmake_install rocm-cmake
# export HIP_DEVICE_LIB_PATH="$BITCODE_DIR"  NNEDED?
cmake_install clang-ocl -DCMAKE_BUILD_TYPE="${BUILD_TYPE}" -DROCM_DIR="${ROCM_INSTALL_DIR}" \
    -DCMAKE_INSTALL_PREFIX="${ROCM_INSTALL_DIR}"

cmake_install ROCm-CompilerSupport
cmake_install rocm_smi_lib
cmake_install rocminfo

# install opencl runtime
ROCM_OPENCL_RUNTIME_SRC="${BUILD_FOLDER}/ROCm-OpenCL-Runtime"
cmake_install ROCm-OpenCL-Runtime -DCMAKE_BUILD_TYPE="${BUILD_TYPE}" -DUSE_COMGR_LIBRARY=ON \
    -DROCM_PATH="${ROCM_INSTALL_DIR}" -DCMAKE_INSTALL_PREFIX="${ROCM_INSTALL_DIR}/opencl"


# install a fake rocm_agent_enumerator - the other does not work
# TODO: understand better the format of $GFX_ARCHS, the print one per line
# not urgent, we have only one architecture on each system now
run_command cd "${ROCM_INSTALL_DIR}/bin"
run_command mv rocm_agent_enumerator rocm_agent_enumerator.old
echo """#!/bin/bash
echo ${GFX_ARCHS}

""" > rocm_agent_enumerator
run_command chmod 0755 rocm_agent_enumerator

# HIP
COMMON_HIP="${BUILD_FOLDER}/HIP"
ROCCLR_DIR="${BUILD_FOLDER}/ROCclr"

cmake_install hipamd -DCMAKE_BUILD_TYPE=${BUILD_TYPE} -DHIP_COMMON_DIR=$COMMON_HIP \
    -DCMAKE_PREFIX_PATH="${BUILD_FOLDER}/rocclr;${ROCM_INSTALL_DIR}" -DROCM_PATH=${ROCM_INSTALL_DIR} \
    -DCMAKE_INSTALL_PREFIX="${ROCM_INSTALL_DIR}" -DHSA_PATH=${ROCM_INSTALL_DIR}/hsa \
    -DROCCLR_PATH=${ROCCLR_DIR} -DAMD_OPENCL_PATH=$ROCM_OPENCL_RUNTIME_SRC \
    -DCMAKE_HIP_ARCHITECTURES=$GFX_ARCHS -DHIP_LLVM_ROOT="${ROCM_INSTALL_DIR}/llvm"

# The following fixes a bug in the installation process for ROCm 5.2
[ -e $ROCM_INSTALL_DIR/hip/lib/cmake/hip/hip-targets.cmake ] || \
    run_command ln -s $ROCM_INSTALL_DIR/lib/cmake/hip/hip-targets.cmake $ROCM_INSTALL_DIR/hip/lib/cmake/hip/hip-targets.cmake
[ -e $ROCM_INSTALL_DIR/hip/lib/cmake/hip/hip-targets-release.cmake ] || \
    run_command ln -s $ROCM_INSTALL_DIR/lib/cmake/hip/hip-targets-release.cmake $ROCM_INSTALL_DIR/hip/lib/cmake/hip/hip-targets-release.cmake

get_aqlprofiler

# There seems to be a circular dependency between rocprofiler and roctracer. Roctracer needs rocprof headers,
# but rocprof needs roctracer to build.
run_command mkdir -p $BUILD_FOLDER/roctracer/inc/rocprofiler
run_command cp ${BUILD_FOLDER}/rocprofiler/src/core/*.h ${BUILD_FOLDER}/roctracer/inc/rocprofiler
run_command cp ${BUILD_FOLDER}/rocprofiler/inc/* ${BUILD_FOLDER}/roctracer/inc/rocprofiler

cmake_install roctracer -DCMAKE_BUILD_TYPE=${BUILD_TYPE} -DHIP_VDI=1 -DCMAKE_INSTALL_PREFIX="${ROCM_INSTALL_DIR}" # -DCMAKE_CXX_FLAGS="-I${BUILD_FOLDER}/roctracer"
cmake_install rocprofiler -DCMAKE_BUILD_TYPE=${BUILD_TYPE} -DCMAKE_INSTALL_PREFIX="${ROCM_INSTALL_DIR}" -DCMAKE_PREFIX_PATH="${ROCM_INSTALL_DIR}/roctracer"
cmake_install HIPIFY -DCMAKE_BUILD_TYPE=${BUILD_TYPE} -DCMAKE_INSTALL_PREFIX=${ROCM_INSTALL_DIR}/hipify
cmake_install ROCdbgapi
cmake_install rocr_debug_agent -DCMAKE_MODULE_PATH=${ROCM_INSTALL_DIR}/hip/cmake -DCMAKE_BUILD_TYPE=${BUILD_TYPE} \
    -DCMAKE_INSTALL_PREFIX=${ROCM_INSTALL_DIR} -DCMAKE_PREFIX_PATH=${ROCM_DEPS_INSTALL_DIR} -DCMAKE_HIP_ARCHITECTURES="$GFX_ARCHS"

# ROCgdb is a bit different
run_command cd "${BUILD_FOLDER}/ROCgdb"
if [ -e rfs_installed ] && [ ${SKIP_INSTALLED} -eq 1 ]; then
  	echo "Boost already installed. Skipping.."
else
    if [ -d build ] && [ $CLEAN_BUILD -eq 1 ]; then
        echo "Cleaning build directory.."
        run_command rm -rf build;
    fi
    [ -d build ] || mkdir build
    cd build
    run_command ../configure  MAKEINFO=false --program-prefix=roc --prefix="${ROCM_INSTALL_DIR}" \
    --enable-64-bit-bfd --enable-targets="x86_64-linux-gnu,amdgcn-amd-amdhsa" \
    --disable-ld --disable-gas --disable-gdbserver --disable-sim \
    --disable-gdbtk  --disable-gprofng --disable-shared --with-expat --with-system-zlib \
    --without-guile --with-rocm-dbgapi="${ROCM_INSTALL_DIR}" 
    run_command make -j $NCORES
    run_command make -j $NCORES install
    run_command touch ../rfs_installed
fi

cmake_install rocm_bandwidth_test
cmake_install half

SAVE_PYTHONPATH=$PYTHONPATH
unset PYTHONPATH
cmake_install rocBLAS -DCMAKE_PREFIX_PATH="${ROCM_INSTALL_DIR}/llvm;${ROCM_INSTALL_DIR};" \
     -DRUN_HEADER_TESTING=OFF -DBUILD_TESTING=OFF -DCMAKE_CXX_COMPILER=hipcc\
     -DTensile_CODE_OBJECT_VERSION=V3 -DCMAKE_INSTALL_PREFIX=${ROCM_INSTALL_DIR} -DAMDGPU_TARGETS="$GFX_ARCHS" \
     -DCMAKE_BUILD_TYPE=${BUILD_TYPE} -DBUILD_FILE_REORG_BACKWARD_COMPATIBILITY=ON  -DCMAKE_TOOLCHAIN_FILE=../toolchain-linux.cmake
export PYTHONPATH=$SAVE_PYTHONPATH

cmake_install rocRAND -DCMAKE_BUILD_TYPE=${BUILD_TYPE} -DCMAKE_INSTALL_PREFIX=${ROCM_INSTALL_DIR} \
    -DAMDGPU_TARGETS=$GFX_ARCHS -DCMAKE_CXX_COMPILER=hipcc -DBUILD_HIPRAND=OFF


cmake_install rocSOLVER -DCMAKE_BUILD_TYPE=${BUILD_TYPE} -DCMAKE_INSTALL_PREFIX=${ROCM_INSTALL_DIR} \
    -DCMAKE_CXX_COMPILER=hipcc -DAMDGPU_TARGETS=$GFX_ARCHS

cmake_install rocPRIM -DCMAKE_BUILD_TYPE=${BUILD_TYPE} -DCMAKE_INSTALL_PREFIX=${ROCM_INSTALL_DIR} \
    -DCMAKE_CXX_COMPILER=hipcc -DAMDGPU_TARGETS=$GFX_ARCHS

cmake_install rocSPARSE -DCMAKE_BUILD_TYPE=${BUILD_TYPE} -DCMAKE_INSTALL_PREFIX=${ROCM_INSTALL_DIR} \
    -DCMAKE_CXX_COMPILER=hipcc  -DCMAKE_FC_COMPILER=gfortran -DAMDGPU_TARGETS=$GFX_ARCHS -DBUILD_CLIENTS_SAMPLES=OFF


cmake_install rocALUTION -DCMAKE_BUILD_TYPE=${BUILD_TYPE} -DCMAKE_INSTALL_PREFIX=${ROCM_INSTALL_DIR} \
    -DCMAKE_CXX_COMPILER=hipcc -DAMDGPU_TARGETS=$GFX_ARCHS -DBUILD_CLIENTS_SAMPLES=OFF \
    -DCMAKE_MODULE_PATH="${ROCM_INSTALL_DIR}/hip/cmake;${ROCM_INSTALL_DIR}" #  remove this last option


cmake_install hipBLAS -DCMAKE_BUILD_TYPE=${BUILD_TYPE} -DCMAKE_INSTALL_PREFIX=${ROCM_INSTALL_DIR} \
    -DCMAKE_CXX_COMPILER=hipcc -DAMDGPU_TARGETS="$GFX_ARCHS"

cmake_install hipSOLVER -DCMAKE_BUILD_TYPE=${BUILD_TYPE} -DCMAKE_INSTALL_PREFIX=${ROCM_INSTALL_DIR} \
    -DCMAKE_CXX_COMPILER=hipcc -DAMDGPU_TARGETS="$GFX_ARCHS"

cmake_install hipSPARSE -DCMAKE_BUILD_TYPE=${BUILD_TYPE} -DCMAKE_INSTALL_PREFIX=${ROCM_INSTALL_DIR} \
    -DCMAKE_CXX_COMPILER=hipcc -DAMDGPU_TARGETS="$GFX_ARCHS"

cmake_install hipCUB -DCMAKE_BUILD_TYPE=${BUILD_TYPE} -DCMAKE_INSTALL_PREFIX=${ROCM_INSTALL_DIR} \
    -DCMAKE_CXX_COMPILER=hipcc -DAMDGPU_TARGETS="$GFX_ARCHS"

cmake_install rocFFT -DCMAKE_BUILD_TYPE=${BUILD_TYPE} -DCMAKE_INSTALL_PREFIX=${ROCM_INSTALL_DIR} \
    -DCMAKE_CXX_COMPILER=hipcc -DAMDGPU_TARGETS="$GFX_ARCHS"

cmake_install hipFFT -DCMAKE_BUILD_TYPE=${BUILD_TYPE} -DCMAKE_INSTALL_PREFIX=${ROCM_INSTALL_DIR} \
    -DCMAKE_CXX_COMPILER=hipcc -DAMDGPU_TARGETS=$GFX_ARCHS \
    -DCMAKE_MODULE_PATH="${ROCM_INSTALL_DIR}/hip/cmake;${ROCM_INSTALL_DIR}"

cmake_install rocThrust -DCMAKE_BUILD_TYPE=${BUILD_TYPE} -DCMAKE_INSTALL_PREFIX=${ROCM_INSTALL_DIR} \
    -DCMAKE_CXX_COMPILER=hipcc -DAMDGPU_TARGETS="$GFX_ARCHS"

cmake_install hipfort

cmake_install rccl -DCMAKE_BUILD_TYPE=${BUILD_TYPE} -DCMAKE_INSTALL_PREFIX=${ROCM_INSTALL_DIR} \
     -DCMAKE_CXX_COMPILER=hipcc -DAMDGPU_TARGETS="$GFX_ARCHS"

cmake_install atmi -DCMAKE_INSTALL_PREFIX=${ROCM_INSTALL_DIR} -DCMAKE_BUILD_TYPE=${BUILD_TYPE} \
    -DLLVM_DIR="${ROCM_INSTALL_DIR}/llvm" -DDEVICE_LIB_DIR=${DEVICE_LIBS} -DATMI_DEVICE_RUNTIME=ON \
    -DATMI_HSA_INTEROP=ON -DROCM_DIR="${ROCM_INSTALL_DIR}/hsa"


cmake_install rocWMMA -DCMAKE_INSTALL_PREFIX=${ROCM_INSTALL_DIR} -DCMAKE_BUILD_TYPE=${BUILD_TYPE}\
    -DROCWMMA_BUILD_VALIDATION_TESTS=OFF -DCMAKE_CXX_COMPILER=clang++ -DROCWMMA_VALIDATE_WITH_ROCBLAS=OFF -DAMDGPU_TARGET=${GFX_ARCHS}

# FIXTHIS WARNING: #pragma message: cl_version.h: CL_TARGET_OPENCL_VERSION is not defined. Defaulting to 220 (OpenCL 2.2)
# cmake_install MIOpenGEMM


# # # TODO: compile tensile separately
# # export LD_LIBRARY_PATH:/lib/llvm-10/lib:$LD_LIBRARY_PATH
# # export LIBRARY_PATH:/lib/llvm-10/lib:$LIBRARY_PATH
# # run_command cd ${BUILD_FOLDER}/Tensile/Tensile/Source
# # run_command mkdir build
# # run_command cd build
# # run_command cmake -DCMAKE_BUILD_TYPE=${BUILD_TYPE} -DCMAKE_INSTALL_PREFIX=${ROCM_INSTALL_DIR} \
# #     -DTensile_CODE_OBJECT_VERSION=V3 -DCMAKE_CXX_COMPILER=hipcc -DTENSILE_GPU_ARCHS=$GFX_ARCHS ..
# # run_command make -j $NCORES

# unset PYTHONPATH
# cmake_install MIOpenTensile -DCMAKE_BUILD_TYPE=${BUILD_TYPE} -DCMAKE_INSTALL_PREFIX=${ROCM_INSTALL_DIR}\
#     -DTensile_CODE_OBJECT_VERSION=V3 -DAMDGPU_TARGETS=$GFX_ARCHS -DCMAKE_CXX_COMPILER=hipcc


# cmake_install llvm-project-mlir -DCMAKE_PREFIX_PATH=${ROCM_INSTALL_DIR} -DCMAKE_BUILD_TYPE=${BUILD_TYPE}\
#     -DBUILD_FAT_LIBMLIRMIOPEN=1 -DCMAKE_INSTALL_PREFIX=${ROCM_INSTALL_DIR}/mlir # NOT USED? -DAMDGPU_TARGETS="$GFX_ARCHS"

# # TODO investigate  MIOPEN_USE_MIOPENGEMM=ON and MIOPEN_USE_MIOPENTENSILE

# cmake_install MIOpen -DCMAKE_PREFIX_PATH=${ROCM_INSTALL_DIR} -DCMAKE_BUILD_TYPE=${BUILD_TYPE} \
#     -DCMAKE_INSTALL_PREFIX=${ROCM_INSTALL_DIR} -DAMDGPU_TARGETS=$GFX_ARCHS -DCMAKE_CXX_COMPILER=clang++\
#     -DMIOPEN_USE_MIOPENGEMM=ON