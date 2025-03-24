#/usr/bin/env bash
function shutdownVM() {
    echo 'Shutting down VM from within guest...'
    sudo shutdown -P now
}
trap shutdownVM EXIT
set -x
export CI=1
export _skip3rdPartyDeps=1
echo 'export MAGAOX_ROLE=workstation' | sudo tee /etc/profile.d/magaox_role.sh
source /etc/profile.d/magaox_role.sh
bash -lx ~/magao-x-setup/provision.sh || exit 1
