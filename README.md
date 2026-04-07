# MagAO-X Automated Setup

The scripts in this folder are runnable documentation for the setup of the MagAO-X software system on new hardware (to the extent it is possible to automate).

For instrument computer setup, consult the [computer setup section](https://magao-x.org/docs/handbook/compute/computer_setup/computer_setup.html) of the [MagAO-X Handbook](https://magao-x.org/docs/handbook/).

## Container Build Memory

Container builds compile several large C/C++ dependencies, including flatbuffers. If the Podman machine has less than 4 GB RAM, the build may be killed by the OOM killer.

Set Podman machine memory to at least 4096 MB; 8192 MB is recommended:

```bash
podman machine set --memory 8192
```
