#!/bin/bash
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source $DIR/../_common.sh
set -uo pipefail

$SUDO sed -E -i 's/#?X11UseLocalhost\s+yes//g' /etc/ssh/sshd_config || exit 1
if ! $SUDO grep -q 'X11UseLocalhost no' /etc/ssh/sshd_config; then
    echo 'X11UseLocalhost no' | $SUDO tee -a /etc/ssh/sshd_config || exit 1
fi
$SUDO sed -E -i 's/#?X11Forwarding\s+no//g' /etc/ssh/sshd_config || exit 1
if ! $SUDO grep -q 'X11Forwarding no' /etc/ssh/sshd_config; then
    echo 'X11Forwarding no' | $SUDO tee -a /etc/ssh/sshd_config || exit 1
fi
$SUDO systemctl restart sshd || exit 1
