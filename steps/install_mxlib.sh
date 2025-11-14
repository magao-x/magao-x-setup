#!/bin/bash
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source $DIR/../_common.sh
set -uo pipefail


MXLIBROOT=/opt/MagAOX/source/mxlib

#
# mxLib
#
# Uses Software Collections package for GCC 14
if [[ -e /opt/rh/gcc-toolset-14/enable ]]; then
    source /opt/rh/gcc-toolset-14/enable
fi
MXLIB_COMMIT_ISH=magaox
orgname=jaredmales
reponame=mxlib
parentdir=/opt/MagAOX/source
clone_or_update_and_cd $orgname $reponame $parentdir || exit 1

git config core.sharedRepository group || exit 1
git checkout $MXLIB_COMMIT_ISH || exit 1
rm -rf _build
mkdir -p _build || exit 1
cd _build || exit 1
cmake -DMXLIB_USE_CUDA=OFF -DMXLIB_USE_ISIO=OFF .. || exit 1
sudo make install || exit 1
