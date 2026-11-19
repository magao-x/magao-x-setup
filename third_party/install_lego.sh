#!/bin/bash
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source $DIR/../_common.sh
set -o pipefail
LEGO_VERSION=v5.6.0
LEGO_ARCHIVE=lego_${LEGO_VERSION}_linux_amd64.tar.gz
LEGO_FOLDER=/opt/MagAOX/vendor/lego_$LEGO_VERSION
mkdir -p $LEGO_FOLDER || exit 1
cd $LEGO_FOLDER || exit 1
if [[ ! -e lego ]]; then
    _cached_fetch https://github.com/go-acme/lego/releases/download/$LEGO_VERSION/$LEGO_ARCHIVE $LEGO_ARCHIVE || exit 1
    tar xf $LEGO_ARCHIVE || exit 1
fi
$SUDO ln -sfv $(realpath ./lego) /usr/local/bin/lego || exit 1
legoDataPath=/etc/pki/lego
$SUDO mkdir -p $legoDataPath || exit 1
$SUDO chown -R root:root $legoDataPath || exit 1
$SUDO chmod -R u=rwX,g=rwX,o=x $legoDataPath || exit 1
$SUDO restorecon -Rv /etc/pki/lego
