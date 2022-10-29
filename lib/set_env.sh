# Needed by ROCm projects.
export HIP_PATH="${ROCM_INSTALL_DIR}/hip"
export HSA_PATH="${ROCM_INSTALL_DIR}/hsa"
export HIP_CLANG_PATH="${ROCM_INSTALL_DIR}/llvm/bin"
export ROCM_PATH="${ROCM_INSTALL_DIR}"
export HIP_ROCCLR_HOME=${ROCM_INSTALL_DIR}/hip/rocclr
export HIP_RUNTIME=rocclr
export GFXLIST="${GFX_ARCHS}"

# Needed at build time and runtime
export_vars "${ROCM_INSTALL_DIR}/opencl"
export_vars "${ROCM_INSTALL_DIR}/llvm"
export_vars "${ROCM_INSTALL_DIR}"
export_vars "${ROCM_DEPS_INSTALL_DIR}"

# LLVM OpenMP offloading will always use the system paths first to search for libraries. If you have your own compiler
# with your own libstdc++, make sure to add it in LDFLAGS.
if [ -n ${COMPILER_LIBDIR} ]; then
    echo "Adding compiler library path to LDFLAGS.."
    LDFLAGS="-L${COMPILER_LIBDIR} -Wl,-rpath=${COMPILER_LIBDIR} $LDFLAGS"
fi
export LDFLAGS="-Wl,--disable-new-dtags $LDFLAGS"
# -fPIE gives issue with libffi + llvm_project/openmp
export CFLAGS="-fPIC"
export CXXFLAGS="-fPIC"
export CXX=g++
export CC=gcc
export FC=gfortran
export FCFLAGS="-fPIC"
