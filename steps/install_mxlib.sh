#!/bin/bash
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source $DIR/../_common.sh
set -uo pipefail


MXLIBROOT=/opt/MagAOX/source/mxlib

#
# mxLib
#

MXLIB_COMMIT_ISH=magaox
orgname=jaredmales
reponame=mxlib
parentdir=/opt/MagAOX/source
clone_or_update_and_cd $orgname $reponame $parentdir || exit 1

git config core.sharedRepository group || exit 1
git checkout $MXLIB_COMMIT_ISH || exit 1
mkdir _build
cd _build
cmake -DMXLIB_USE_CUDA=OFF -DMXLIB_USE_ISIO=OFF -DCMAKE_INSTALL_PREFIX=$CONDA_PREFIX ..
sudo make install
