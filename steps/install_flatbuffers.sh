#!/bin/bash
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source $DIR/../_common.sh
set -uo pipefail
FLATBUFFERS_VERSION="23.5.26"
MIN_RAM_BYTES=$((4 * 1024 * 1024 * 1024))
#
# Flatbuffers
#

# Compiling flatbuffers can OOM on low-memory Podman machines.
memTotalKb=$(awk '/MemTotal:/ {print $2}' /proc/meminfo)
if [[ -z "$memTotalKb" ]]; then
    exit_with_error "Could not determine system memory from /proc/meminfo"
fi
availableBytes=$((memTotalKb * 1024))

# Respect container memory limits when present (cgroup v2).
if [[ -r /sys/fs/cgroup/memory.max ]]; then
    cgroupLimit=$(cat /sys/fs/cgroup/memory.max)
    if [[ "$cgroupLimit" != "max" && "$cgroupLimit" =~ ^[0-9]+$ && "$cgroupLimit" -lt "$availableBytes" ]]; then
        availableBytes=$cgroupLimit
    fi
fi

if [[ "$availableBytes" -lt "$MIN_RAM_BYTES" ]]; then
    availableMb=$((availableBytes / 1024 / 1024))
    exit_with_error "Flatbuffers build requires at least 4096 MB RAM; detected ${availableMb} MB. Increase Podman machine memory (e.g. to 8192 MB)."
fi

cd /opt/MagAOX/vendor || exit 1
FLATBUFFERS_DIR="flatbuffers-$FLATBUFFERS_VERSION"
if [[ ! -d $FLATBUFFERS_DIR ]]; then
    _cached_fetch https://github.com/google/flatbuffers/archive/v$FLATBUFFERS_VERSION.tar.gz $FLATBUFFERS_DIR.tar.gz || exit 1
    tar xzf $FLATBUFFERS_DIR.tar.gz || exit 1
fi
cd $FLATBUFFERS_DIR || exit 1
cmake -G "Unix Makefiles" -DCMAKE_BUILD_TYPE=Release || exit 1
make -j$(nproc) || exit 1
$SUDO make install || exit 1
