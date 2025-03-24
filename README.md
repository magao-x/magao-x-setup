# MagAO-X Automated Setup

The scripts in this folder automate the setup of the MagAO-X software system on new hardware (to the extent it is possible to automate). This is also used to create a container environment for continuous integration testing.

For personal use, see [Running MagAO-X from your own computer](https://magao-x.org/docs/handbook/compute/remote_operation.html). For instrument setup, consult the [computer setup section](https://magao-x.org/docs/handbook/compute/computer_setup/computer_setup.html) of the [MagAO-X Handbook](https://magao-x.org/docs/handbook/).


## Building a VM locally

You will need QEMU.

```
cd xvm/
# optional: remove previous build files
rm -rf input/ output/
export vmArch=aarch64
# or, for x86_64:
export vmArch=x86_64
bash build_vm_stage1.sh
```

### stage 1

Create disk image
Generate SSH key
download rocky ISO
download open UEFI firmware files
