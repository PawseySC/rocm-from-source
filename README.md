# ROCm from source

A set of scripts that attempt to install the ROCm framework from source, brought to you by the Pawsey Supercomputing Research Centre.

**NOTE:** this is just an internal project for now, do not share outside as it is highly unstable. For any information, contact Cristian.

## Instructions

First, you will need to install the `amdgpu` kernel module for the system to be able to communicate with the AMD hardware. Follow the instructions in [KernelModule.md](KernelModule.md).

Within the `scripts` directory, choose one of the `[arch]_install_rocm.sh` scripts to install ROCm. At the top of each script there are a few variables one can set to personalise the installation.


## Notes

To use OpenCL, the following command must (should?) be executed on every compute node, but I haven't tested it yet.

```
mkdir -p /etc/OpenCL/vendors/
echo "libamdocl64.so" > /etc/OpenCL/vendors/amdocl64.icd
```

## TODO

1. Build Tensile by itself, then use it as dependency in rocblas and miopen
2. How to enable/handle opencl, how does it fit in ROCm?
3. Investigate `MIOPEN_USE_MIOPENGEMM=ON` and `MIOPEN_USE_MIOPENTENSILE`
4. For what concerns AOMP, the following projects should be installed: pgmath flang flang_runtime (see [here](https://github.com/ROCm-Developer-Tools/aomp/blob/aomp-dev/bin/build_aomp.sh))


## References

1. https://github.com/RadeonOpenCompute/ROCm_Documentation/blob/master//Installation_Guide/Using-CMake-with-AMD-ROCm.rst 
2. OpenMP Offloading
    - https://openmp.llvm.org/SupportAndFAQ.html#build-amdgpu-offload-capable-compiler
    - https://github.com/ROCm-Developer-Tools/aomp/blob/aomp-dev/docs/SOURCEINSTALL_PREREQUISITE.md
    - https://github.com/ROCm-Developer-Tools/aomp/blob/aomp-dev/docs/SOURCEINSTALL.md