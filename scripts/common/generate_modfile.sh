#!/bin/bash

function export_vars {
    echo "prepend_path(\"LD_LIBRARY_PATH\", \"$1/lib:$1/lib64\")"
    echo "prepend_path(\"LIBRARY_PATH\", \"$1/lib:$1/lib64\")"
    echo "prepend_path(\"PATH\", \"$1/bin\")"
    echo "prepend_path(\"CPATH\", \"$1/include:$1/inc\")"
}

echo  "if (mode() ~= \"whatis\") then"

export_vars "${ROCM_INSTALL_DIR}/opencl"
export_vars "${ROCM_INSTALL_DIR}/llvm"
export_vars "${ROCM_INSTALL_DIR}/hipcub"
export_vars "${ROCM_INSTALL_DIR}/mlir"
export_vars "${ROCM_INSTALL_DIR}/hip"
export_vars "${ROCM_INSTALL_DIR}"
export_vars "${ROCM_DEPS_INSTALL_DIR}"


echo "setenv(\"HIP_PATH\", \"${ROCM_INSTALL_DIR}/hip\")"
echo "setenv(\"HSA_PATH\", \"${ROCM_INSTALL_DIR}/hsa\")"
echo "setenv(\"HIP_CLANG_PATH\", \"${ROCM_INSTALL_DIR}/llvm/bin\")"
echo "setenv(\"ROCM_PATH\", \"${ROCM_INSTALL_DIR}\")"
echo "setenv(\"HIP_ROCCLR_HOME\", \"${ROCM_INSTALL_DIR}/hip/rocclr\")"
echo "setenv(\"HIP_RUNTIME\", \"rocclr\")"
echo "end"