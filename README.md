# ROCm from source

A set of scripts that attempt to install the ROCm framework from source, brought to you by the Pawsey Supercomputing Research Centre.

**NOTE:** this is just an internal project for now, do not share outside as it is highly unstable. For any information, contact Cristian.

## Post installation instruction

The `ROCM_PATH` environment variable must be set to the ROCm installation directory. We can do this within the module.

More info

1. https://github.com/RadeonOpenCompute/ROCm_Documentation/blob/master//Installation_Guide/Using-CMake-with-AMD-ROCm.rst 

## Error notes

We need  to execute`apt install python3.8-venv` otherwise we get this. Can we have a workaround?

```
Failing command: ['/home/ubuntu/rocm-from-source/build/rocBLAS/build/virtualenv/bin/python3', '-Im', 'ensurepip', '--upgrade', '--default-pip']

/home/ubuntu/rocm-from-source/build/rocBLAS/build/virtualenv/bin/python3 -m pip install git+https://github.com/ROCmSoftwarePlatform/Tensile.git@ea38f8661281a37cd81c96cc07868e3f07d2c4da
/home/ubuntu/rocm-from-source/build/rocBLAS/build/virtualenv/bin/python3: No module named pip
CMake Error at cmake/virtualenv.cmake:34 (message):
  1
Call Stack (most recent call first):
  CMakeLists.txt:284 (virtualenv_install)

```