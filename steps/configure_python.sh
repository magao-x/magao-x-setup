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
conda env update -f $DIR/../conda_env_base.yml || exit_with_error "Failed to install or update packages"
conda env export

# Install the kernel for JupyterHub use
sudo /opt/conda/bin/python -m ipykernel install --prefix=/usr/local --name 'MagAO-X'
