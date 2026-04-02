#!/bin/bash
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source $DIR/../_common.sh
set -uo pipefail
RTIMV_COMMIT_ISH=magaox
orgname=jaredmales
reponame=rtimv
parentdir=/opt/MagAOX/source
# Uses Software Collections package for GCC 14
if [[ -e /opt/rh/gcc-toolset-14/enable ]]; then
    source /opt/rh/gcc-toolset-14/enable
fi
clone_or_update_and_cd $orgname $reponame $parentdir || exit 1
git checkout $RTIMV_COMMIT_ISH || exit 1
rm -rf _build
mkdir -p _build || exit 1
cmake -S . -B _build \
	-DRTIMV_SERVER_SYSTEMD_USER=xsup \
	-DRTIMV_SERVER_SYSTEMD_GROUP=xsup \
	-DRTIMV_SERVER_SYSTEMD_ARGS="-c rtimvServer.conf" \
	-DRTIMV_SERVER_SYSTEMD_UNIT_DIR=/usr/lib/systemd/system || exit 1
cmake --build _build -j$(nprocs) || exit 1
sudo cmake --install _build || exit 1
