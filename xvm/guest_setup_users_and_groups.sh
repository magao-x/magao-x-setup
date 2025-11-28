#/usr/bin/env bash
set -x
sudo mkdir -p /etc/profile.d || exit 1
echo 'export MAGAOX_ROLE=workstation' | sudo tee /etc/profile.d/magaox.sh || exit 1
export CI=1
bash -lx ~/magao-x-setup/setup_users_and_groups.sh || (echo 'Failed to create users and groups' && exit 1)
echo 'Created users and groups'

echo 'Installing cloud-init for compatibility with Multipass and others'
sudo dnf --setopt=timeout=300 --setopt=retries=10 -y install cloud-init || exit 1
