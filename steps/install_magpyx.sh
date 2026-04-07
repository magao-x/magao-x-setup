#!/bin/bash
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source $DIR/../_common.sh
set -uo pipefail

MAGPYX_COMMIT_ISH=master
orgname=magao-x
reponame=magpyx
parentdir=/opt/MagAOX/source
clone_or_update_and_cd $orgname $reponame $parentdir || exit 1
git checkout $MAGPYX_COMMIT_ISH || exit 1

if command -v nvidia-smi 2>&1; then
    $SUDO $CONDA_BASE/bin/mamba install -c conda-forge cupy || exit_with_error "Need CuPy to run Kyle's stuff fast, better investigate"
fi

$SUDO $CONDA_BASE/envs/${INSTRUMENT_CONDA_ENV}/bin/pip install -e . || exit 1
python -c 'import magpyx' || exit 1
