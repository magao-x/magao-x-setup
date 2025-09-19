#!/bin/bash
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source $DIR/../_common.sh
set -o pipefail

# Defines $ID and $VERSION_ID so we can detect which distribution we're on
source /etc/os-release

scratchFile=/tmp/sudoers_trusted
targetFile=/etc/sudoers.d/trusted

echo '# file automatically created by configure_trusted_sudoers.sh, do not edit' > $scratchFile || exit_with_error "Could not create $scratchFile"
trustedGroups="%xwcl-admin, %xwcl-dev"
if [[ $ID == rocky || $ID == fedora ]]; then
    echo "User_Alias TRUSTED = $trustedGroups, %wheel" > $scratchFile
elif [[ $ID == ubuntu ]]; then
    echo "User_Alias TRUSTED = $trustedGroups, %sudo" > $scratchFile
else
    exit_with_error "Got ID=$ID, only know rocky and ubuntu"
fi

cat <<'HERE' | tee -a $scratchFile
Defaults:TRUSTED !env_reset
Defaults:TRUSTED !secure_path
# LDAP group for admins
%xwcl-admin    ALL=(ALL)       ALL
# local and LDAP group for developers that should have sudo
%magaox-dev    ALL=(ALL)       ALL
HERE

visudo -cf $scratchFile || exit_with_error "visudo syntax check failed on $scratchFile"
sudo install \
    --owner=root \
    --group=root \
    --mode=440 \
    $scratchFile \
    $targetFile \
|| exit_with_error "Could not install drop-in file to $targetFile"
sudo ls -la /etc/sudoers.d/
