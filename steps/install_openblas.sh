#!/bin/bash
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source $DIR/../_common.sh
set -uo pipefail
cd /opt/MagAOX/vendor || exit 1
source /etc/os-release
log_info "Install OpenBLAS from source"
VERSION=0.3.30
DOWNLOAD_FILE=OpenBLAS-${VERSION}.tar.gz
DOWNLOAD_URL=https://github.com/xianyi/OpenBLAS/releases/download/v${VERSION}/${DOWNLOAD_FILE}
if [[ ! -e $DOWNLOAD_FILE ]]; then
    _cached_fetch $DOWNLOAD_URL $DOWNLOAD_FILE || exit 1
fi
if [[ ! -d ./OpenBLAS-${VERSION} ]]; then
    tar xf $DOWNLOAD_FILE || exit 1
fi
cd ./OpenBLAS-${VERSION} || exit 1
openblasFlags="USE_OPENMP=1"

if [[ $VM_KIND != "none" ]]; then
    if [[ $ID == rocky ]]; then
        dnf install --setopt=timeout=300 --setopt=retries=10 -y openblas-devel || exit 1
    else
        exit_with_error "No idea how to handle VM kind $VM_KIND and distro $ID"
    fi
else
    make -j$(nproc) $openblasFlags || exit 1
    # ensure same flags get to make install
    sudo make install PREFIX=/usr/local $openblasFlags || exit 1
fi

log_info "Finished OpenBLAS source install"
