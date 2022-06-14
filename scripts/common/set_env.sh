# Needed at build time and runtime
LIBRARY_PATH=/usr/lib
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

export GFXLIST="${GFX_ARCHS}"