#/usr/bin/env bash
set -x
sudo mkdir -p /etc/profile.d || exit 1
echo 'export MAGAOX_ROLE=workstation' | sudo tee /etc/profile.d/magaox.sh || exit 1
export CI=1
sudo bash -lx ~/magao-x-setup/steps/ensure_dirs_and_perms.sh || exit 1
sudo bash -lx ~/magao-x-setup/install_third_party_deps.sh || exit 1
echo 'Installed third-party dependencies'
