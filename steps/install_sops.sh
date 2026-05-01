#!/bin/bash
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source $DIR/../_common.sh
set -uo pipefail
cd /opt/MagAOX/vendor || exit 1
mkdir -p sops || exit 1
cd sops || exit 1
release=3.10.2
source /etc/os-release
if [[ $ID == "ubuntu" ]]; then
    downloadFile=sops_${release}_$(dpkg --print-architecture).deb
    if [[ ! -e $downloadFile ]]; then
        _cached_fetch https://github.com/getsops/sops/releases/download/v${release}/sops_${release}_$(dpkg --print-architecture).deb $downloadFile || exit 1
    fi
    if ! command -v sops; then
        $SUDO dpkg -i $downloadFile || exit 1
    fi
else
    downloadFile=sops-${release}.rpm
    if [[ ! -e $downloadFile ]]; then
        _cached_fetch https://github.com/getsops/sops/releases/download/v${release}/sops-${release}-1.$(uname -m).rpm $downloadFile || exit 1
    fi
    if ! command -v sops; then
        $SUDO rpm -i $downloadFile || exit 1
    fi
fi
