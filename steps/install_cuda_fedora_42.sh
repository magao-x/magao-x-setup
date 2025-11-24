#!/bin/bash
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source $DIR/../_common.sh
set -exuo pipefail
sudo mkdir -p /opt/MagAOX/vendor/cuda_rpm
sudo chown :magaox-dev /opt/MagAOX/vendor/cuda_rpm
sudo chmod g+ws /opt/MagAOX/vendor/cuda_rpm
cd /opt/MagAOX/vendor/cuda_rpm
rpmFile=cuda-repo-fedora42-13-0-local-13.0.2_580.95.05-1.x86_64
rpmVers=13.0.2
package=cuda-toolkit-13-0
_cached_fetch https://developer.download.nvidia.com/compute/cuda/$rpmVers/local_installers/$rpmFile.rpm $rpmFile.rpm
if ! rpm -q $rpmFile; then
    sudo rpm -i $rpmFile.rpm
fi
sudo dnf clean all
sudo dnf -y install $package
sudo dnf -y module install nvidia-driver:open-dkms
