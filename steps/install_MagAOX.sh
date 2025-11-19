#!/bin/bash
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source $DIR/../_common.sh
set -uo pipefail

# Uses Software Collections package for GCC 14
if [[ -e /opt/rh/gcc-toolset-14/enable ]]; then
    source /opt/rh/gcc-toolset-14/enable
fi

cd /opt/MagAOX/source/MagAOX || exit 1
log_info "Building flatlogs"
cd flatlogs/src || exit 1
make || exit 1
make install || exit 1

log_info "Building MagAOX"
cd ../.. || exit 1
make setup || exit 1
if [[ $VM_KIND != none || $MAGAOX_ROLE == TOC ]]; then
    if ! grep 'NEED_CUDA = no' local/common.mk; then
        echo 'NEED_CUDA = no' >> local/common.mk || exit 1
    fi
fi

make -j$(nproc) all || exit 1
make install || exit 1
