#/usr/bin/env bash
function shutdownVM() {
    echo 'Shutting down VM from within guest...'
    sudo shutdown -P now
}
trap shutdownVM EXIT
set -x
sudo chmod g+w /opt/MagAOX/source
sudo chown :magaox-dev /opt/MagAOX/source
git clone https://github.com/magao-x/MagAOX.git /opt/MagAOX/source/MagAOX
bash -lx /opt/MagAOX/source/MagAOX/setup/steps/install_MagAOX.sh || exit 1
