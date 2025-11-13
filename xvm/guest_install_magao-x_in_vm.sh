#/usr/bin/env bash
set -x
sudo chmod g+w /opt/MagAOX/source
sudo chown :magaox-dev /opt/MagAOX/source
git clone https://github.com/magao-x/MagAOX.git /opt/MagAOX/source/MagAOX
bash -lx ~/magao-x-setup/steps/install_MagAOX.sh || exit 1
