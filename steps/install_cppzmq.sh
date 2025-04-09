#!/bin/bash
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source $DIR/../_common.sh
set -uo pipefail
cd /opt/MagAOX/vendor || exit 1

# install cppzmq (dependency of milkzmq)
CPPZMQ_VERSION=4.10.0
if [[ ! -d ./cppzmq-$CPPZMQ_VERSION ]]; then
    _cached_fetch https://github.com/zeromq/cppzmq/archive/refs/tags/v$CPPZMQ_VERSION.tar.gz cppzmq-$CPPZMQ_VERSION.tar.gz
    tar xzf cppzmq-$CPPZMQ_VERSION.tar.gz || exit 1
fi
cd ./cppzmq-$CPPZMQ_VERSION || exit 1
sudo cp *.hpp /usr/local/include/ || exit 1
