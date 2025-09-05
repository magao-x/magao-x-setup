#/usr/bin/env bash
function shutdownVM() {
    echo 'Shutting down VM from within guest...'
    sudo shutdown -P now
}
trap shutdownVM EXIT
set -x
sudo mkdir -p /etc/profile.d || exit 1
echo 'export MAGAOX_ROLE=workstation' | sudo tee /etc/profile.d/magaox.sh || exit 1
export CI=1
bash -lx ~/magao-x-setup/setup_users_and_groups.sh || (echo 'Failed to create users and groups' && exit 1)
echo 'Created users and groups'
