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
if [[ $VM_KIND != "none" ]]; then
    arch=$(uname -a)
    if [[ $arch == aarch64 ]]; then
        extraCmakeArgs='-DMXLIB_CXXFLAGS="-march=armv8.2-a+crypto+crc -mtune=generic" -DMXLIB_CFLAGS="-march=armv8.2-a+crypto+crc -mtune=generic"'
    else
        extraCmakeArgs='-DMXLIB_CXXFLAGS="-march=x86-64-v2 -mtune=generic" -DMXLIB_CFLAGS="-march=x86-64-v2 -mtune=generic"'
    fi
else
    extraCmakeArgs='-DMXLIB_CXXFLAGS="-march=native" -DMXLIB_CFLAGS="-march=native"'
fi
cmake $extraCmakeArgs .. || exit 1
sudo make install || exit 1
