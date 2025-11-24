#!/bin/bash
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source $DIR/../_common.sh
set -uo pipefail
cd /opt/MagAOX/vendor || exit 1
mkdir -p sops || exit 1
cd sops || exit 1
release=3.10.2
downloadFile=sops-${release}.rpm
if [[ ! -e $downloadFile ]]; then
    _cached_fetch https://github.com/getsops/sops/releases/download/v${release}/sops-${release}-1.$(uname -m).rpm $downloadFile || exit 1
fi
if ! rpm -q $downloadFile; then
    sudo rpm -i $downloadFile || exit 1
fi
