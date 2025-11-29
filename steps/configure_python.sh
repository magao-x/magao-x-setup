#!/bin/bash
# If not started as root, sudo yourself
if [[ "$EUID" != 0 ]]; then
  sudo -H bash -l $0 "$@"
  exit $?
fi
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source $DIR/../_common.sh
set -uo pipefail
set -x

#
# Install the standard MagAOX user python environment
#
$MAMBA update -y mamba || exit_with_error "Mamba self update failed"
set +o pipefail
yes | $MAMBA env update -f $DIR/../conda_env_base.yml || exit_with_error "Failed to install or update packages"
set -o pipefail
$MAMBA env export

# Install the kernel for JupyterHub use
if [[ -z $CONDA_BASE ]]; then
    exit_with_error "No CONDA_BASE in env"
fi
$CONDA_BASE/bin/python -m ipykernel install --prefix=/usr/local --name 'MagAO-X'
