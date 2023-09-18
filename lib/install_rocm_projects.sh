if [ -z ${ROCM_INSTALL_DIR+x} ] || [ -z ${BUILD_FOLDER+x} ]; then
    echo "one of the input variables is not set."
    exit 1
fi
INSTALL_DIR="${ROCM_INSTALL_DIR}"
export PYTHONPATH=${ROCM_INSTALL_DIR}/lib64/python${PYTHON_VERSION}/site-packages:$PYTHONPATH  
export CPATH="${ROCM_INSTALL_DIR}/rocclr/include/elf:${ROCM_INSTALL_DIR}/include/hsa:$CPATH"
echo $PYTHONPATH
ROCM_BUILD_FOLDER="${BUILD_FOLDER}/rocm-${ROCM_VERSION}-${ROCM_BASE_COMPILER_TOOLSET}"
[ -e "${ROCM_BUILD_FOLDER}" ] || mkdir - "${ROCM_BUILD_FOLDER}"

OLD_BUILD_FOLDER="${BUILD_FOLDER}"
BUILD_FOLDER="${ROCM_BUILD_FOLDER}"

cd "${BUILD_FOLDER}"
if ! [ -d hipamd ]; then # use the 'hipamd' folder presence as a flag of software already being do 
    ROCM_VERSION_BRANCH="roc-${ROCM_VERSION%.*}.x"
    echo "Downloading ROCM repositories at branch ${ROCM_VERSION_BRANCH}"
    run_command repo init -u https://github.com/RadeonOpenCompute/ROCm.git -b ${ROCM_VERSION_BRANCH}
    run_command repo sync
    run_command git clone -b rocm-${ROCM_VERSION} https://github.com/ROCmSoftwarePlatform/hipRAND.git
    # Needed for MIOpen
    # TODO: the following needs some updating
    # run_command git clone -b release/rocm-5.1 https://github.com/ROCmSoftwarePlatform/llvm-project-mlir.git
   
    run_command cd $BUILD_FOLDER
    run_command git clone --branch rocm-${ROCM_VERSION} https://github.com/ROCm-Developer-Tools/aomp-extras.git
    run_command git clone --branch rocm-${ROCM_VERSION} https://github.com/ROCm-Developer-Tools/flang.git
fi

# replace all the hardcoded /opt/rocm in CMake files. Also, disable new tags so that RPATH is used instead of RUNPATH
if ! [ -e .seddone ]; then
    find . -name CMakeLists.txt -maxdepth 5 -exec sed -i -e "s|/opt/rocm|${ROCM_INSTALL_DIR}|g" -e "s|--enable-new-dtags| |g" {} \;
    find . -name "*.cmake" -maxdepth 5 -exec sed -i -e "s|/opt/rocm|${ROCM_INSTALL_DIR}|g" -e  "s|--enable-new-dtags| |g" {} \;
    touch .seddone
fi

# Apply patches
if ! [ -e "${BUILD_FOLDER}/roctracer/.patched" ]; then
    patch "${BUILD_FOLDER}/roctracer/src/roctx/roctx.cpp" "${PATCHES_DIR}/roctracer.patch"
    patch "${BUILD_FOLDER}/llvm-project/openmp/libomptarget/src/CMakeLists.txt" "${PATCHES_DIR}/llvm-openmp.patch"
    patch "${BUILD_FOLDER}/hipamd/src/hip_intercept.cpp" "${PATCHES_DIR}/hipamd.patch"
    patch "${BUILD_FOLDER}/HIPIFY/CMakeLists.txt" "${PATCHES_DIR}/hipify.patch"
    touch "${BUILD_FOLDER}/roctracer/.patched"
fi
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

export CXX_COMPILER="CC"
export C_COMPILER="cc"
export FTN_COMPILER="ftn"

cmake_install llvm-project -DCMAKE_BUILD_TYPE="${BUILD_TYPE}" \
   -DLLVM_ENABLE_PROJECTS="llvm;clang;clang-tools-extra;lld;compiler-rt;" \
   -DCMAKE_PREFIX_PATH=${ROCM_INSTALL_DIR}\
   -DLLVM_TARGETS_TO_BUILD="AMDGPU;X86"\
   -DCMAKE_INSTALL_PREFIX="${ROCM_INSTALL_DIR}/llvm"\
   -DLLVM_EXTERNAL_DEVICE_LIBS_SOURCE_DIR="$DEVICE_LIBS"\
   -DLLVM_EXTERNAL_PROJECTS=device-libs\
   -DLLVM_ENABLE_RUNTIMES=""\
   -DCMAKE_CXX_COMPILER=CC\
   -DCMAKE_C_COMPILER=cc\
   -DCMAKE_Fortran_COMPILER=ftn\

# The following is needed otherwise clang complains when executing hipcc
[ -e  "${ROCM_INSTALL_DIR}/amdgcn" ] || \
   run_command ln -fs "${ROCM_INSTALL_DIR}/llvm/amdgcn" "${ROCM_INSTALL_DIR}/amdgcn"

export CXX=clang++
export CC=clang
export CXX_COMPILER="clang++"
export C_COMPILER="clang"
export FTN_COMPILER="ftn"
export cmakecompilerargs="-DCMAKE_CXX_COMPILER=${CXX_COMPILER} -DCMAKE_C_COMPILER=${C_COMPILER} -DCMAKE_Fortran_COMPILER=${FTN_COMPILER}"

cmake_install ROCR-Runtime -DCMAKE_BUILD_TYPE="${BUILD_TYPE}" -DCMAKE_INSTALL_PREFIX="${ROCM_INSTALL_DIR}" \
       ${cmakecompilerargs} \
       -DBITCODE_DIR="$BITCODE_DIR"

cmake_install aomp-extras -DCMAKE_BUILD_TYPE=${BUILD_TYPE} -DCMAKE_INSTALL_PREFIX=${ROCM_INSTALL_DIR} \
    ${cmakecompilerargs} \
    -DROCM_DIR=${ROCM_INSTALL_DIR} -DLLVM_DIR=${ROCM_INSTALL_DIR}/llvm \
    -DAOMP_VERSION_STRING="${ROCM_VERSION}" 

# the openmp module is compiled separately
cmake_install llvm-project/openmp -DCMAKE_BUILD_TYPE="${BUILD_TYPE}" \
    -DCMAKE_PREFIX_PATH="${ROCM_INSTALL_DIR}/llvm;${ROCM_INSTALL_DIR}/include/hsa"\
    -DLLVM_DIR=${ROCM_INSTALL_DIR}/llvm\
    ${cmakecomilerargs}\
    -DLIBOMPTARGET_AMDGCN_GFXLIST=${GFX_ARCHS}\
    -DDEVICELIBS_ROOT=${DEVICE_LIBS}\
    -DCMAKE_INSTALL_PREFIX="${ROCM_INSTALL_DIR}/llvm"\
    -DOPENMP_ENABLE_LIBOMPTARGET=1\
    -DLIBOMP_COPY_EXPORTS=OFF\
    -DLIBOMPTARGET_ENABLE_DEBUG=ON\
    -DLLVM_INSTALL_PREFIX=$ROCM_INSTALL_DIR/llvm\
    -DLLVM_MAIN_INCLUDE_DIR=$BUILD_FOLDER/llvm-project/llvm/include\
    -DLIBOMPTARGET_LLVM_INCLUDE_DIRS=$BUILD_FOLDER/llvm-project/llvm/include


# Install AMD ROCm flang
COMP_INC_DIR=${BUILD_FOLDER}/flang/runtime/libpgmath/lib/common
export CPATH="$COMP_INC_DIR:$CPATH"
cmake_install flang/runtime/libpgmath\
       -DLLVM_CONFIG="${ROCM_INSTALL_DIR}/llvm/bin/llvm-config" \
       ${cmakecompilerargs}\
       -DLLVM_TARGETS_TO_BUILD="AMDGPU;X86"\
       -DCMAKE_INSTALL_PREFIX="${ROCM_INSTALL_DIR}/llvm"\
       -DLLVM_INSTALL_TOOLCHAIN_ONLY=ON \
       -DFLANG_INCLUDE_TESTS=OFF


cmake_install flang -DLLVM_ENABLE_ASSERTIONS=ON -DCMAKE_BUILD_TYPE="${BUILD_TYPE}" \
    -DLLVM_CONFIG="${ROCM_INSTALL_DIR}/llvm/bin/llvm-config" \
    ${cmakecompilerargs}\
    -DLLVM_TARGETS_TO_BUILD="AMDGPU;X86"\
    -DCMAKE_INSTALL_PREFIX="${ROCM_INSTALL_DIR}/llvm"\
    -DFLANG_OPENMP_GPU_AMD=ON\
    -DFLANG_OPENMP_GPU_NVIDIA=ON\
    -DLLVM_INSTALL_TOOLCHAIN_ONLY=ON \
    -DFLANG_INCLUDE_TESTS=OFF\
    -DCMAKE_C_FLAGS=-I$COMP_INC_DIR -DCMAKE_CXX_FLAGS=-I$COMP_INC_DIR

# flang runtime
cmake_install flang -DCMAKE_BUILD_TYPE=$BUILD_TYPE -DCMAKE_INSTALL_PREFIX="${ROCM_INSTALL_DIR}/llvm"\
    -DLLVM_ENABLE_ASSERTIONS=ON \
    -DCMAKE_CXX_COMPILER=${CXX_COMPILER} \
    -DLLVM_CONFIG="${ROCM_INSTALL_DIR}/llvm/bin/llvm-config" \
    -DCMAKE_C_COMPILER=clang -DCMAKE_Fortran_COMPILER=flang\
    -DLLVM_TARGETS_TO_BUILD="AMDGPU;X86"\
    -DLLVM_INSTALL_RUNTIME=ON -DFLANG_BUILD_RUNTIME=ON -DOPENMP_BUILD_DIR=${ROCM_INSTALL_DIR}/llvm/lib\
    -DFLANG_INCLUDE_TESTS=OFF -DCMAKE_C_FLAGS=-I$COMP_INC_DIR -DCMAKE_CXX_FLAGS=-I$COMP_INC_DIR


cmake_install rocm-cmake
cmake_install clang-ocl -DCMAKE_BUILD_TYPE="${BUILD_TYPE}" -DROCM_DIR="${ROCM_INSTALL_DIR}" \
    -DCMAKE_INSTALL_PREFIX="${ROCM_INSTALL_DIR}"

cmake_install ROCm-CompilerSupport  -DCMAKE_BUILD_TYPE="${BUILD_TYPE}" -DCMAKE_INSTALL_PREFIX="${ROCM_INSTALL_DIR}"\
      ${cmakecompilerargs}
cmake_install rocm_smi_lib  -DCMAKE_BUILD_TYPE="${BUILD_TYPE}" -DCMAKE_INSTALL_PREFIX="${ROCM_INSTALL_DIR}" \
      ${cmakecompilerargs}
cmake_install rocminfo  -DCMAKE_BUILD_TYPE="${BUILD_TYPE}" -DCMAKE_INSTALL_PREFIX="${ROCM_INSTALL_DIR}" \
      ${cmakecompilerargs}

# install opencl runtime
ROCM_OPENCL_RUNTIME_SRC="${BUILD_FOLDER}/ROCm-OpenCL-Runtime"
cmake_install ROCm-OpenCL-Runtime -DCMAKE_BUILD_TYPE="${BUILD_TYPE}" -DUSE_COMGR_LIBRARY=ON \
    -DROCM_PATH="${ROCM_INSTALL_DIR}" -DCMAKE_INSTALL_PREFIX="${ROCM_INSTALL_DIR}/opencl"


# install a fake rocm_agent_enumerator - the original does not work
run_command cd "${ROCM_INSTALL_DIR}/bin"
run_command mv rocm_agent_enumerator rocm_agent_enumerator.old
echo "#!/bin/bash" > rocm_agent_enumerator
for gfx in `echo ${GFX_ARCHS} | tr \; " "`;
do
    echo "echo $gfx" >> rocm_agent_enumerator
done
run_command chmod 0755 rocm_agent_enumerator

# HIP
COMMON_HIP="${BUILD_FOLDER}/HIP"
ROCCLR_DIR="${BUILD_FOLDER}/ROCclr"

cmake_install hipamd -DCMAKE_BUILD_TYPE=${BUILD_TYPE} -DHIP_COMMON_DIR=$COMMON_HIP \
    ${cmakecompilerargs} \
    -DCMAKE_PREFIX_PATH="${BUILD_FOLDER}/rocclr;${ROCM_INSTALL_DIR}" -DROCM_PATH=${ROCM_INSTALL_DIR} \
    -DCMAKE_INSTALL_PREFIX="${ROCM_INSTALL_DIR}" -DHSA_PATH=${ROCM_INSTALL_DIR}/hsa \
    -DROCCLR_PATH=${ROCCLR_DIR} -DAMD_OPENCL_PATH=$ROCM_OPENCL_RUNTIME_SRC \
    -DCMAKE_HIP_ARCHITECTURES=$GFX_ARCHS -DHIP_LLVM_ROOT="${ROCM_INSTALL_DIR}/llvm"

# The following fixes a bug in the installation process (I guess)
[ -e $ROCM_INSTALL_DIR/hip/lib/cmake/hip/hip-targets.cmake ] || \
    run_command ln -s $ROCM_INSTALL_DIR/lib/cmake/hip/hip-targets.cmake $ROCM_INSTALL_DIR/hip/lib/cmake/hip/hip-targets.cmake
[ -e $ROCM_INSTALL_DIR/hip/lib/cmake/hip/hip-targets-release.cmake ] || \
    run_command ln -s $ROCM_INSTALL_DIR/lib/cmake/hip/hip-targets-release.cmake $ROCM_INSTALL_DIR/hip/lib/cmake/hip/hip-targets-release.cmake

# There seems to be a circular dependency between rocprofiler and roctracer. Roctracer needs rocprof headers,
# but rocprof needs roctracer to build.
run_command mkdir -p $BUILD_FOLDER/roctracer/inc/rocprofiler
run_command cp ${BUILD_FOLDER}/rocprofiler/src/core/*.h ${BUILD_FOLDER}/roctracer/inc/rocprofiler
run_command cp ${BUILD_FOLDER}/rocprofiler/inc/* ${BUILD_FOLDER}/roctracer/inc/rocprofiler

cmake_install roctracer -DCMAKE_MODULE_PATH=$ROCM_INSTALL_DIR/lib64/cmake/hip -DCMAKE_BUILD_TYPE=${BUILD_TYPE} \
	${cmakecompilerargs} \
	-DHIP_VDI=1 -DCMAKE_INSTALL_PREFIX="${ROCM_INSTALL_DIR}" 
cmake_install rocprofiler -DCMAKE_BUILD_TYPE=${BUILD_TYPE} -DCMAKE_INSTALL_PREFIX="${ROCM_INSTALL_DIR}" \
	${cmakecompilerargs} \
        -DCMAKE_PREFIX_PATH="${ROCM_INSTALL_DIR}/roctracer"
cmake_install HIPIFY -DCMAKE_BUILD_TYPE=${BUILD_TYPE} -DCMAKE_INSTALL_PREFIX=${ROCM_INSTALL_DIR}/hipify \
	${cmakecompilerargs} 
cmake_install ROCdbgapi -DCMAKE_BUILD_TYPE=${BUILD_TYPE} -DCMAKE_INSTALL_PREFIX="${ROCM_INSTALL_DIR}" \
       	${cmakecompilerargs} 
cmake_install rocr_debug_agent -DCMAKE_MODULE_PATH=${ROCM_INSTALL_DIR}/hip/cmake \
	-DCMAKE_BUILD_TYPE=${BUILD_TYPE} \
	-DCMAKE_INSTALL_PREFIX=${ROCM_INSTALL_DIR} \
	${cmakecompilerargs} \
	-DCMAKE_PREFIX_PATH=${ROCM_DEPS_INSTALL_DIR} -DCMAKE_HIP_ARCHITECTURES="$GFX_ARCHS"

# ROCgdb is a bit different
# it has an older more brittle build that might need to use gdb as a basis and use gcc/g++
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
    run_command ../configure CC=gcc CXX=g++ CXXFLAGS='' CFLAGS='' LDFLAGS='' MAKEINFO=false --program-prefix=roc --prefix="${ROCM_INSTALL_DIR}" \
    --enable-64-bit-bfd --enable-targets="x86_64-linux-gnu,amdgcn-amd-amdhsa" \
    --disable-ld --disable-gas --disable-gdbserver --disable-sim \
    --disable-gdbtk  --disable-gprofng --disable-shared --with-expat --with-system-zlib \
    --without-guile --with-rocm-dbgapi="${ROCM_INSTALL_DIR}" 
    run_command make -j $NCORES
    run_command make -j $NCORES install
    run_command touch ../rfs_installed
fi

# rocm_bandwidth_test does not take into account env variables..
if ! [ -e "${BUILD_FOLDER}/rocm_bandwidth_test/.patched" ]; then
    CMAKE_LINE="set(CMAKE_EXE_LINKER_FLAGS \" ${LDFLAGS} \${CMAKE_EXE_LINKER_FLAGS}\")"
    sed -i "82 a${CMAKE_LINE}" ${BUILD_FOLDER}/rocm_bandwidth_test/CMakeLists.txt
    touch "${BUILD_FOLDER}/rocm_bandwidth_test/.patched" 
fi
cmake_install rocm_bandwidth_test -DCMAKE_BUILD_TYPE="${BUILD_TYPE}" -DCMAKE_INSTALL_PREFIX="${ROCM_INSTALL_DIR}" \
       ${cmakecompilerargs}

cmake_install half  -DCMAKE_BUILD_TYPE="${BUILD_TYPE}" -DCMAKE_INSTALL_PREFIX="${ROCM_INSTALL_DIR}" \
       ${cmakecompilerargs}

if ! [ -e "${BUILD_FOLDER}/rocBLAS/.patched" ]; then
    CMAKE_LINE="set(CMAKE_EXE_LINKER_FLAGS \" ${LDFLAGS} \${CMAKE_EXE_LINKER_FLAGS}\")"
    sed -i "34 a${CMAKE_LINE}" ${BUILD_FOLDER}/rocBLAS/CMakeLists.txt
    touch "${BUILD_FOLDER}/rocBLAS/.patched" 
fi

export PYTHONPATH=${BUILD_FOLDER}/rocBLAS/build/virtualenv/lib/python${PYTHON_VERSION}/site-packages:$PYTHONPATH

# now building stuff that will use hipcc as the cxx compiler
cmake_install rocBLAS -DCMAKE_PREFIX_PATH="${ROCM_INSTALL_DIR}/llvm;${ROCM_INSTALL_DIR};" \
     -DRUN_HEADER_TESTING=OFF -DBUILD_TESTING=OFF \
     -DCMAKE_CXX_COMPILER=hipcc\
     -DTensile_CODE_OBJECT_VERSION=V3 -DCMAKE_INSTALL_PREFIX=${ROCM_INSTALL_DIR} -DAMDGPU_TARGETS="$GFX_ARCHS" \
     -DCMAKE_BUILD_TYPE=${BUILD_TYPE} -DBUILD_FILE_REORG_BACKWARD_COMPATIBILITY=ON -DTensile_TEST_LOCAL_PATH=${BUILD_FOLDER}/Tensile  -DCMAKE_TOOLCHAIN_FILE=../toolchain-linux.cmake

cmake_install rocRAND -DCMAKE_BUILD_TYPE=${BUILD_TYPE} -DCMAKE_INSTALL_PREFIX=${ROCM_INSTALL_DIR} \
    -DAMDGPU_TARGETS=$GFX_ARCHS -DCMAKE_CXX_COMPILER=hipcc -DBUILD_HIPRAND=OFF


cmake_install rocSOLVER -DCMAKE_BUILD_TYPE=${BUILD_TYPE} -DCMAKE_INSTALL_PREFIX=${ROCM_INSTALL_DIR} \
    -DCMAKE_CXX_COMPILER=hipcc -DAMDGPU_TARGETS=$GFX_ARCHS

cmake_install rocPRIM -DCMAKE_BUILD_TYPE=${BUILD_TYPE} -DCMAKE_INSTALL_PREFIX=${ROCM_INSTALL_DIR} \
    -DCMAKE_CXX_COMPILER=hipcc -DAMDGPU_TARGETS=$GFX_ARCHS

cmake_install rocSPARSE -DCMAKE_BUILD_TYPE=${BUILD_TYPE} -DCMAKE_INSTALL_PREFIX=${ROCM_INSTALL_DIR} \
    -DCMAKE_CXX_COMPILER=hipcc  -DCMAKE_FC_COMPILER=${FTN_COMPILER} \
    -DAMDGPU_TARGETS=${GFX_ARCHS} \
    -DBUILD_CLIENTS_SAMPLES=OFF


cmake_install rocALUTION -DCMAKE_BUILD_TYPE=${BUILD_TYPE} -DCMAKE_INSTALL_PREFIX=${ROCM_INSTALL_DIR} \
    -DCMAKE_CXX_COMPILER=hipcc \
    -DAMDGPU_TARGETS=${GFX_ARCHS} \
    -DBUILD_CLIENTS_SAMPLES=OFF \
    -DCMAKE_MODULE_PATH="${ROCM_INSTALL_DIR}/hip/cmake;${ROCM_INSTALL_DIR}" #  remove this last option


cmake_install hipBLAS -DCMAKE_BUILD_TYPE=${BUILD_TYPE} -DCMAKE_INSTALL_PREFIX=${ROCM_INSTALL_DIR} \
    -DCMAKE_CXX_COMPILER=hipcc \
    -DAMDGPU_TARGETS="${GFX_ARCHS}"

cmake_install hipSOLVER -DCMAKE_BUILD_TYPE=${BUILD_TYPE} -DCMAKE_INSTALL_PREFIX=${ROCM_INSTALL_DIR} \
    -DCMAKE_CXX_COMPILER=hipcc \
    -DAMDGPU_TARGETS="${GFX_ARCHS}"

cmake_install hipSPARSE -DCMAKE_BUILD_TYPE=${BUILD_TYPE} -DBUILD_CLIENTS_SAMPLES=OFF -DCMAKE_INSTALL_PREFIX=${ROCM_INSTALL_DIR} \
    -DHIP_PATH=${HIP_PATH} -DROCM_PATH=${ROCM_INSTALL_DIR} \
    -DCMAKE_CXX_COMPILER=hipcc \
    -DAMDGPU_TARGETS="$GFX_ARCHS"

cmake_install hipCUB -DCMAKE_BUILD_TYPE=${BUILD_TYPE} -DCMAKE_INSTALL_PREFIX=${ROCM_INSTALL_DIR} \
    -DCMAKE_CXX_COMPILER=hipcc \
    -DAMDGPU_TARGETS="$GFX_ARCHS"

cmake_install rocFFT -DCMAKE_BUILD_TYPE=${BUILD_TYPE} -DCMAKE_INSTALL_PREFIX=${ROCM_INSTALL_DIR} \
    -DCMAKE_CXX_COMPILER=hipcc \
    -DAMDGPU_TARGETS="$GFX_ARCHS"

cmake_install hipFFT -DCMAKE_BUILD_TYPE=${BUILD_TYPE} -DCMAKE_INSTALL_PREFIX=${ROCM_INSTALL_DIR} \
    -DCMAKE_CXX_COMPILER=hipcc \
    -DAMDGPU_TARGETS=$GFX_ARCHS \
    -DCMAKE_MODULE_PATH="${ROCM_INSTALL_DIR}/hip/cmake;${ROCM_INSTALL_DIR}"

cmake_install rocThrust -DCMAKE_BUILD_TYPE=${BUILD_TYPE} -DCMAKE_INSTALL_PREFIX=${ROCM_INSTALL_DIR} \
    -DCMAKE_CXX_COMPILER=hipcc \
    -DAMDGPU_TARGETS="$GFX_ARCHS"

# why is hipfort hard coded for gcc and g++, etc. why not just use clang, clang++, and the ftn compiler
cmake_install hipfort -DCMAKE_BUILD_TYPE=${BUILD_TYPE} -DCMAKE_INSTALL_PREFIX=${ROCM_INSTALL_DIR} \
	-DCMAKE_CXX_COMPILER=${CXX_COMPILER} -DCMAKE_C_COMPILER=${C_COMPILER}  -DHIPFORT_COMPILER=${FTN_COMPILER} \
	-DHIPFORT_AR=ar

cmake_install rccl -DCMAKE_EXE_LINKER_FLAGS="'$LDFLAGS'" -DCMAKE_BUILD_TYPE=${BUILD_TYPE} -DCMAKE_INSTALL_PREFIX=${ROCM_INSTALL_DIR} \
     -DCMAKE_CXX_COMPILER=hipcc \
     -DAMDGPU_TARGETS="$GFX_ARCHS"

cmake_install atmi -DCMAKE_INSTALL_PREFIX=${ROCM_INSTALL_DIR} -DCMAKE_BUILD_TYPE=${BUILD_TYPE} \
    -DLLVM_DIR="${ROCM_INSTALL_DIR}/llvm" -DDEVICE_LIB_DIR=${DEVICE_LIBS} -DATMI_DEVICE_RUNTIME=ON \
    -DATMI_HSA_INTEROP=ON -DROCM_DIR="${ROCM_INSTALL_DIR}/hsa" \
    ${cmakecompilerargs} 

cmake_install rocWMMA -DROCWMMA_BUILD_TESTS=OFF -DROCWMMA_BUILD_SAMPLES=OFF -DCMAKE_INSTALL_PREFIX=${ROCM_INSTALL_DIR} -DCMAKE_BUILD_TYPE=${BUILD_TYPE}\
    -DROCWMMA_BUILD_VALIDATION_TESTS=OFF -DROCWMMA_VALIDATE_WITH_ROCBLAS=OFF -DAMDGPU_TARGETS=${GFX_ARCHS} \
    ${cmakecompilerargs}

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


BUILD_FOLDER="${OLD_BUILD_FOLDER}"
