# ROCm from source

A set of `sh` scripts whose objective is to install the AMD ROCm programming framework from source, brought to you by the Pawsey Supercomputing Research Centre.

**NOTE:** this is just an internal project for now, do not share outside as it is quite unstable. For any information, contact Cristian.

## Why?

While you can install precompiled binaries of ROCm on a workstation with the help of a packet manager, it is not desirable to do on a supercomputing infrastructure. Here is a list of reasons:

1. The installation path is not reconfigurable. All the scientific software of a Pawsey supercomputer sits on a distributed filesystem mounted on all nodes, rather than being installed on every single node's local filesystem. This allows for a faster and more reliable installation.
2. Not all packages are presents in the precompiled binaries, such as `rocWMMA` (at the time of writing, at least).
3. Having immediate access to the latest version.
4. Compilation is optimized for the target architecture.
5. ..do you really need more reasons? 😉


## Instructions

**NOTE:** Start the installation from a clean state, if possible. That is, make sure that ROCm is not installed systemwide (under `/usr/bin`, `/bin`), and that is a "hard no", nor under the default ROCm paths `/opt/rocm/rocm-xxx`, if possible. Those installations will interfere with the build process.

Firstly you will need to install the `amdgpu` kernel module for the system to be able to communicate with the AMD hardware. Follow the instructions in [KernelModule.md](KernelModule.md).

After having installed the kernel module, choose the most appropriate `[arch]_install_rocm.sh` scripts within the `scripts` directory to install ROCm. At the top of each script there are a few variables one can set to personalise the installation. Once you have completed the configuration, simply execute the script. A modulefile (Cray) and/or a shell script (`${ROCM_INSTALL_DIR}/rocm_setup.sh`, to be sourced) are created for you, following a successful installation, to set the correct environment variables in order to use the newly installed ROCm.

## Configurable parameters

- TODO

## Containers

You can also build a singularity container based on Ubuntu using the `singularity_install_rocm.def` recipe.


## How it works

The project is structured such that the core installation instructions are shared across the various platforms. The major difference between systems are whether a dependency is already there, and if not, how to install it. For this reason and to have a more reproducible build these scripts install most dependencies from source too.


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