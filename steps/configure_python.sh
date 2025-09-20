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
mamba env update -f $DIR/../conda_env_base.yml || exit_with_error "Failed to install or update packages"
mamba env export
# mamba env update -f $DIR/../conda_env_pinned_$(uname -i).yml || exit_with_error "Failed to install or update packages using pinned versions. Update the env manually with the base specification and update the pinned versions if possible."
source /etc/os-release
