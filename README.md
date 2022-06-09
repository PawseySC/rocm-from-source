# ROCm from source

A set of scripts that attempt to install the ROCm framework from source, brought to you by the Pawsey Supercomputing Research Centre.

**NOTE:** this is just an internal project for now, do not share outside as it is highly unstable. For any information, contact Cristian.

## Instructions

Within the `scripts` directory, choose one of the `[arch]_install_rocm.sh` scripts to install ROCm. At the top of each script
there are a few variables one can set to personalise the installation.

To use OpenCL, the following command must be executed on every compute node:

```
mkdir -p /etc/OpenCL/vendors/
echo "libamdocl64.so" > /etc/OpenCL/vendors/amdocl64.icd
```

## TODO

1. Check that rocFFT now works
2. Try to build rocALUTION
3. Build Tensile by itself, then use it as dependency in rocblas and miopen
4. Try to figure out how to better install dependencies.
5. What about the kernel driver?

## Known issues

1. rocALUTION does not compile (https://github.com/ROCmSoftwarePlatform/rocALUTION/issues/144).
2. rocFFT (hence hipFFT) does not compile (https://github.com/ROCmSoftwarePlatform/rocFFT/issues/363).

## References

1. https://github.com/RadeonOpenCompute/ROCm_Documentation/blob/master//Installation_Guide/Using-CMake-with-AMD-ROCm.rst 