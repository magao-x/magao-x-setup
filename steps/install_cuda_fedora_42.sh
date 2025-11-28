#!/bin/bash
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source $DIR/../_common.sh
set -exuo pipefail
sudo dnf clean all
sudo dnf --setopt=timeout=300 --setopt=retries=10 -y install https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm \
    https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm || exit 1

latestKernel=$(dnf repoquery --latest-limit=1 --qf '%{VERSION}-%{RELEASE}.%{ARCH}' kernel)
currentKernel=$(uname -r)
if [[ "$currentKernel" != "$latestKernel" ]]; then
    exit_with_error "Upgrade kernel $currentKernel -> $latestKernel (latest) before installing NVIDIA drivers"
fi
sudo dnf --setopt=timeout=300 --setopt=retries=10 -y install akmod-nvidia xorg-x11-drv-nvidia-cuda || exit 1
log_success "Finished installing repackaged NVIDIA driver from RPMFusion"
log_info "Getting the CUDA libraries from NVIDIA's own packages..."
sudo mkdir -p /opt/MagAOX/vendor/cuda_rpm
sudo chown :magaox-dev /opt/MagAOX/vendor/cuda_rpm
sudo chmod g+ws /opt/MagAOX/vendor/cuda_rpm
cd /opt/MagAOX/vendor/cuda_rpm
rpmFile=cuda-repo-fedora42-13-0-local-13.0.2_580.95.05-1.x86_64
rpmVers=13.0.2
_cached_fetch https://developer.download.nvidia.com/compute/cuda/$rpmVers/local_installers/$rpmFile.rpm $rpmFile.rpm
if ! rpm -q $rpmFile; then
    sudo rpm -i $rpmFile.rpm
fi
if [[ $MAGAOX_ROLE == AOC || $MAGAOX_ROLE == ROC || $MAGAOX_ROLE == COC ]]; then
    sudo dnf -y install cuda-toolkit-13 || exit 1
else
    sudo dnf -y install cuda-compiler-13-0 cuda-libraries-13-0 cuda-libraries-dev-13-0 || exit 1
fi
log_success "Installed CUDA libraries!"
