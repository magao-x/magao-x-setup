#!/bin/bash
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source $DIR/../_common.sh
set -o pipefail

if [[ -z "$MAGAOX_CONTAINER" ]]; then
    exit_with_error "Really shouldn't give $instrument_user passwordless sudo"
fi

# Defines $ID and $VERSION_ID so we can detect which distribution we're on
source /etc/os-release

scratchFile=/tmp/sudoers_container
targetFile=/etc/sudoers.d/container

rm -f $scratchFile
touch $scratchFile
chmod u=rw,g=,o= $scratchFile
echo '# file automatically created by configure_container_sudoers.sh, do not edit' > $scratchFile || exit_with_error "Could not create $scratchFile"

cat <<'HERE' | tee -a $scratchFile
# passwordless sudo for the default container user
# as an escape hatch
xsup    ALL=(ALL)       ALL
HERE

visudo -cf $scratchFile || exit_with_error "visudo syntax check failed on $scratchFile"
$SUDO install \
    --owner=root \
    --group=root \
    --mode=440 \
    $scratchFile \
    $targetFile \
|| exit_with_error "Could not install drop-in file to $targetFile"
$SUDO ls -la /etc/sudoers.d/
