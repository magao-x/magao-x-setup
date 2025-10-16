#!/bin/bash
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source $DIR/../_common.sh
set -o pipefail
# Uses Software Collections package for GCC 14
if [[ -e /opt/rh/gcc-toolset-14/enable ]]; then
    source /opt/rh/gcc-toolset-14/enable
fi
# install milkzmq
MILKZMQ_COMMIT_ISH=master
orgname=jaredmales
reponame=milkzmq
parentdir=/opt/MagAOX/source
clone_or_update_and_cd $orgname $reponame $parentdir || exit 1

git checkout $MILKZMQ_COMMIT_ISH || exit 1
make || exit 1
sudo make install || exit 1
