# Installing the `amdgpu` Kernel Module (Driver)

For ROCm to work, the `amdgpu` Kernel Module must be installed. It is essentially the driver talking to the GPUs.

Without the driver, you get the following error when executing `rocm-smi`:

```
$ rocm-smi
cat: /sys/module/amdgpu/initstate: No such file or directory
ERROR:root:Driver not initialized (amdgpu not found in modules)
```

## Installation steps

To install and enable the `amdgpu` on Ubuntu (similar instructions apply to other OSes) follow these steps:

1. Find out your kernel version using `uname -r`.
    ```
    $ uname -r
    5.4.0-126-generic
    ```
2. Install the kernel extra modules:
    ```
    $ sudo apt install linux-modules-extra-5.4.0-126-generic
    ```
3. Install the `amdgpu-install` installer script. It facilitates the installation of the `amdgpu` module, but also the entire ROCm stack (in the default location). We will use it to install the driver only. Information about the script can be [found here](https://amdgpu-install.readthedocs.io/en/latest/install-prereq.html).

    ```
    wget https://repo.radeon.com/amdgpu-install/22.20/ubuntu/focal/amdgpu-install_22.20.50200-1_all.deb
    sudo dpkg -i amdgpu-install_22.20.50200-1_all.deb
    ```

3. Using amdgpu-install, install the `amdgpu` kernel module.
    ```
    amdgpu-install --usecase=dkms
    ```
5. Reboot the system (Is this necessary?)
4. Enable the `amdgpu` module.
    ```
    sudo modprobe amdgpu
    ```


## Testing

If the installation succeeds, `rocm-smi` should display the following (the test system has no gpus)

```
$ rocm-smi


======================= ROCm System Management Interface =======================
WARNING: No AMD GPUs specified
================================= Concise Info =================================
GPU  Temp  AvgPwr  SCLK  MCLK  Fan  Perf  PwrCap  VRAM%  GPU%  
================================================================================
============================= End of ROCm SMI Log ==============================
```

## References

1. https://amdgpu-install.readthedocs.io/en/latest/install-prereq.html
2. https://github.com/RadeonOpenCompute/ROCm/issues/738
3. https://wiki.archlinux.org/title/AMDGPU
