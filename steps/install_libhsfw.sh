#!/bin/bash
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source $DIR/../_common.sh
set -uo pipefail
cd /opt/MagAOX/vendor/libhsfw || exit 1
sudo make clean || exit 1
sudo make -j$(nproc) install || exit 1
