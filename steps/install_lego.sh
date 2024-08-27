#!/bin/bash
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source $DIR/../_common.sh
set -o pipefail
LEGO_VERSION=v4.9.0
LEGO_ARCHIVE=lego_${LEGO_VERSION}_linux_amd64.tar.gz
LEGO_FOLDER=/opt/MagAOX/vendor/lego_$LEGO_VERSION
mkdir -p $LEGO_FOLDER || exit 1
cd $LEGO_FOLDER || exit 1
if [[ ! -e lego ]]; then
    _cached_fetch https://github.com/go-acme/lego/releases/download/v4.9.0/$LEGO_ARCHIVE $LEGO_ARCHIVE || exit 1
    tar xf $LEGO_ARCHIVE || exit 1
fi
sudo ln -sfv $(realpath ./lego) /usr/local/bin/lego || exit 1
sudo mkdir -p /opt/lego || exit 1
sudo chown :$instrument_dev_group /opt/lego || exit 1
sudo chmod -R u=rwX,g=rwX,o=x /opt/lego || exit 1
setgid_all /opt/lego || exit 1