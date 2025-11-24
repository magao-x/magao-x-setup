#!/bin/bash
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source $DIR/../_common.sh
set -uo pipefail
cd /opt/MagAOX/vendor || exit 1
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
    # If we're in a VM context, we try to build generic images
    # but also cut down the number of architectures it specializes
    # for so builds don't time out.
    if [[ $(uname -m) == "x86_64" ]]; then
        openblasFlags="TARGET=ZEN $openblasFlags"
        openblasDynamicList="SANDYBRIDGE HASWELL SKYLAKEX"
    elif [[ $(uname -m) == "aarch64" ]]; then
        openblasDynamicList="ARMV8 CORTEXA72 CORTEXA76"
    else
        exit_with_error "Unknown platform $(uname -p)"
    fi
    make -j$(nproc) DYNAMIC_ARCH=1 DYNAMIC_LIST="$openblasDynamicList" $openblasFlags || exit 1
    # ensure same flags get to make install
    sudo make install PREFIX=/usr/local DYNAMIC_ARCH=1 DYNAMIC_LIST="$openblasDynamicList" $openblasFlags || exit 1
else
    make -j$(nproc) $openblasFlags || exit 1
    # ensure same flags get to make install
    sudo make install PREFIX=/usr/local $openblasFlags || exit 1
fi


log_info "Finished OpenBLAS source install"
