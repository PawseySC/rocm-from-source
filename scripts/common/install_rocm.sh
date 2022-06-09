# ============================================================================================================
#                                       BUILD ENVIRONMENT SETUP
# ============================================================================================================
export CPATH="${ROCM_INSTALL_DIR}/rocclr/include/elf:${ROCM_INSTALL_DIR}/include/hsa:$CPATH"

if [ -d "${BUILD_FOLDER}" ] && [ $CLEAN_BUILD -eq 1 ]; then
    echo "Cleaning up previous build."
    run_command rm -rf "${BUILD_FOLDER}"
fi
[ -d "${BUILD_FOLDER}" ] || mkdir -p "${BUILD_FOLDER}/build-deps/bin"
export_vars "${BUILD_FOLDER}/build-deps"

# we need "python" and "pip" executables
[ -e  ${BUILD_FOLDER}/build-deps/bin/python ] || \
    run_command ln -s `which python3` ${BUILD_FOLDER}/build-deps/bin/python;
[ -e  ${BUILD_FOLDER}/build-deps/bin/pip ] || \
    run_command ln -s `which pip3` ${BUILD_FOLDER}/build-deps/bin/pip;

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
    run_command git clone git://sourceware.org/git/elfutils.git
    run_command wget https://gmplib.org/download/gmp/gmp-6.2.1.tar.xz
    run_command tar -xf gmp-6.2.1.tar.xz
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

run_command cd ${BUILD_FOLDER}/elfutils
run_command autoreconf -i -f
run_command ./configure --enable-maintainer-mode --disable-libdebuginfod --disable-debuginfod --prefix="${ROCM_INSTALL_DIR}"
run_command make -j $NCORES install
run_command cd ${BUILD_FOLDER}/gmp-6.2.1
run_command ./configure --prefix=${ROCM_INSTALL_DIR}
run_command make -j $NCORES
run_command make install

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
run_command ln -s "${ROCM_INSTALL_DIR}/llvm/amdgcn" "${ROCM_INSTALL_DIR}/amdgcn"

cmake_install ROCR-Runtime -DCMAKE_BUILD_TYPE="${BUILD_TYPE}" -DCMAKE_INSTALL_PREFIX="${ROCM_INSTALL_DIR}"\
    -DBITCODE_DIR="$BITCODE_DIR"

cmake_install rocm-cmake
cmake_install clang-ocl -DCMAKE_BUILD_TYPE="${BUILD_TYPE}" -DROCM_DIR="${ROCM_INSTALL_DIR}" \
    -DCMAKE_INSTALL_PREFIX="${ROCM_INSTALL_DIR}"

cmake_install ROCm-CompilerSupport
cmake_install rocm_smi_lib
cmake_install rocminfo

# install opencl runtime
ROCM_OPENCL_RUNTIME_SRC="${BUILD_FOLDER}/ROCm-OpenCL-Runtime"
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

# ROCgdb is a bit different
run_command cd "${BUILD_FOLDER}/ROCgdb"
[ -d build ] || mkdir build
cd build
run_command ../configure  MAKEINFO=false --program-prefix=roc --prefix="${ROCM_INSTALL_DIR}" \
  --enable-64-bit-bfd --enable-targets="x86_64-linux-gnu,amdgcn-amd-amdhsa" \
  --disable-ld --disable-gas --disable-gdbserver --disable-sim \
  --disable-gdbtk --disable-shared --with-expat --with-system-zlib \
  --without-guile --with-lzma --with-python=python3 --with-rocm-dbgapi="${ROCM_INSTALL_DIR}"
run_command make -j $NCORES
run_command make -j $NCORES install

cmake_install rocm_bandwidth_test
cmake_install half

SAVE_PYTHONPATH=$PYTHONPATH
unset PYTHONPATH
cmake_install rocBLAS -DCMAKE_PREFIX_PATH="${ROCM_INSTALL_DIR}/llvm;${ROCM_INSTALL_DIR};${ROCM_INSTALL_DIR}/hip" \
     -DRUN_HEADER_TESTING=OFF -DBUILD_TESTING=OFF \
     -DTensile_CODE_OBJECT_VERSION=V3 -DCMAKE_INSTALL_PREFIX=${ROCM_INSTALL_DIR} -DAMDGPU_TARGETS="$GFX_ARCHS" \
     -DCMAKE_BUILD_TYPE=${BUILD_TYPE} -DCMAKE_TOOLCHAIN_FILE=../toolchain-linux.cmake
export PYTHONPATH=$SAVE_PYTHONPATH

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

unset PYTHONPATH
cmake_install MIOpenTensile -DCMAKE_BUILD_TYPE=${BUILD_TYPE} -DCMAKE_INSTALL_PREFIX=${ROCM_INSTALL_DIR}\
    -DTensile_CODE_OBJECT_VERSION=V3 -DAMDGPU_TARGETS=$GFX_ARCHS -DCMAKE_CXX_COMPILER=hipcc


cmake_install llvm-project-mlir -DCMAKE_PREFIX_PATH=${ROCM_INSTALL_DIR} -DCMAKE_BUILD_TYPE=${BUILD_TYPE}\
    -DBUILD_FAT_LIBMLIRMIOPEN=1 -DCMAKE_INSTALL_PREFIX=${ROCM_INSTALL_DIR}/mlir # NOT USED? -DAMDGPU_TARGETS="$GFX_ARCHS"

# TODO investigate  MIOPEN_USE_MIOPENGEMM=ON and MIOPEN_USE_MIOPENTENSILE

cmake_install MIOpen -DCMAKE_PREFIX_PATH=${ROCM_INSTALL_DIR} -DCMAKE_BUILD_TYPE=${BUILD_TYPE} \
    -DCMAKE_INSTALL_PREFIX=${ROCM_INSTALL_DIR} -DAMDGPU_TARGETS=$GFX_ARCHS -DCMAKE_CXX_COMPILER=clang++\
    -DMIOPEN_USE_MIOPENGEMM=ON

cmake_install atmi -DCMAKE_INSTALL_PREFIX=${ROCM_INSTALL_DIR} -DCMAKE_BUILD_TYPE=${BUILD_TYPE} \
    -DLLVM_DIR="${ROCM_INSTALL_DIR}/llvm" -DDEVICE_LIB_DIR=${DEVICE_LIBS} -DATMI_DEVICE_RUNTIME=ON \
    -DATMI_HSA_INTEROP=ON -DROCM_DIR="${ROCM_INSTALL_DIR}/hsa"