#!/bin/bash
SUDO="${SUDO:-sudo}"
if [[ "$EUID" != 0 ]]; then
    $SUDO bash $0 "$@"
    exit $?
fi
set -uo pipefail
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source $DIR/../_common.sh

echo "user.max_user_namespaces=10000" > /etc/sysctl.d/42-rootless.conf || exit 1
sysctl --system || exit 1
