#!/bin/bash
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source $DIR/../_common.sh
set -exuo pipefail
sudo dnf clean all
sudo dnf install -y https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm \
    https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm || exit 1

latestKernel=$(dnf repoquery --latest-limit=1 --qf '%{VERSION}-%{RELEASE}.%{ARCH}' kernel)
currentKernel=$(uname -r)
if [[ "$currentKernel" != "$latestKernel" ]]; then
    exit_with_error "Upgrade kernel $currentKernel -> $latestKernel (latest) before installing NVIDIA drivers"
fi
sudo dnf install -y akmod-nvidia || exit 1
log_success "Finished installing repackaged NVIDIA driver from RPMFusion"
log_info "Getting the CUDA libraries from NVIDIA's own packages..."
sudo mkdir -p /opt/MagAOX/vendor/cuda_rpm
sudo chown :magaox-dev /opt/MagAOX/vendor/cuda_rpm
sudo chmod g+ws /opt/MagAOX/vendor/cuda_rpm
cd /opt/MagAOX/vendor/cuda_rpm
rpmFile=cuda-repo-fedora42-13-0-local-13.0.2_580.95.05-1.x86_64
rpmVers=13.0.2
package=cuda-toolkit-13
_cached_fetch https://developer.download.nvidia.com/compute/cuda/$rpmVers/local_installers/$rpmFile.rpm $rpmFile.rpm
if ! rpm -q $rpmFile; then
    sudo rpm -i $rpmFile.rpm
fi
sudo dnf -y install $package || exit 1
log_success "Installed CUDA libraries!"
