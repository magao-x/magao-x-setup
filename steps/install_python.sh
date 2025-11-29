#!/bin/bash
# If not started as root, sudo yourself
if [[ "$EUID" != 0 ]]; then
    sudo -H bash -l $0 "$@"
    exit $?
fi
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source $DIR/../_common.sh
set -xuo pipefail

MINIFORGE3_VERSION="25.9.1-0"
MINIFORGE3_INSTALLER="Miniforge3-$MINIFORGE3_VERSION-Linux-$(uname -m).sh"
MINIFORGE3_URL="https://github.com/conda-forge/miniforge/releases/download/$MINIFORGE3_VERSION/$MINIFORGE3_INSTALLER"
#
# conda
#
cd /opt/MagAOX/vendor || exit 1
if [[ ! -d $CONDA_BASE ]]; then
    _cached_fetch "$MINIFORGE3_URL" $MINIFORGE3_INSTALLER || exit 1
    bash $MINIFORGE3_INSTALLER -b -p $CONDA_BASE || exit 1
	# Ensure magaox-dev can write to $CONDA_BASE or env creation will fail
	chown -R :$instrument_dev_group $CONDA_BASE || exit 1
    # set group and permissions such that only magaox-dev has write access
    chmod -R g=rwX $CONDA_BASE || exit 1
    find $CONDA_BASE -type d -exec sudo chmod g+rwxs {} \; || exit 1
    # Set environment variables for conda
    cat << 'EOF' | tee /etc/profile.d/conda.sh || exit 1
if [ -f "$CONDA_BASE/etc/profile.d/conda.sh" ]; then
    . "$CONDA_BASE/etc/profile.d/conda.sh"
    CONDA_CHANGEPS1=false conda activate base
else
    \export PATH="$CONDA_BASE/bin:$PATH"
fi
EOF
    cat << 'EOF' | tee $CONDA_BASE/.condarc || exit 1
channels:
  - conda-forge
changeps1: false
disallowed_packages: [ qt ]
EOF
fi

if [[ ! -e $MAMBA ]]; then
  echo "mamba not found; installing with conda"
  $CONDA install -c conda-forge mamba
fi
