#!/bin/sh

export_vars () {
    echo "export LD_LIBRARY_PATH=$1/lib:$1/lib64:\$LD_LIBRARY_PATH"
    echo "export LIBRARY_PATH=$1/lib:$1/lib64:\$LIBRARY_PATH"
    echo "export PATH=$1/bin:\$PATH"
    echo "export CPATH=$1/include:\$PATH"
}


export_vars "${ROCM_INSTALL_DIR}/opencl"
export_vars "${ROCM_INSTALL_DIR}/llvm"
export_vars "${ROCM_INSTALL_DIR}/hipcub"
export_vars "${ROCM_INSTALL_DIR}/mlir"
export_vars "${ROCM_INSTALL_DIR}/hip"
export_vars "${ROCM_INSTALL_DIR}"
export_vars "${ROCM_DEPS_INSTALL_DIR}"


echo "export HIP_PATH=${ROCM_INSTALL_DIR}/hip"
echo "export HSA_PATH=${ROCM_INSTALL_DIR}/hsa"
echo "export HIP_CLANG_PATH=${ROCM_INSTALL_DIR}/llvm/bin"
echo "export ROCM_PATH=${ROCM_INSTALL_DIR}"
echo "export HIP_ROCCLR_HOME=${ROCM_INSTALL_DIR}/hip/rocclr"
echo "export HIP_RUNTIME=rocclr"
