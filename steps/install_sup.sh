#!/bin/bash
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source $DIR/../_common.sh
set -o pipefail
# set -u  # apparently makes conda angry, so just be careful about unset variables
SUP_COMMIT_ISH=main
orgname=magao-x
reponame=sup
parentdir=/opt/MagAOX/source
clone_or_update_and_cd $orgname $reponame $parentdir
git checkout $SUP_COMMIT_ISH

if [[ ! -d $CONDA_BASE/envs/sup ]]; then
    $SUDO $CONDA_BASE/bin/conda create -yn sup python=3.13 pip numpy
fi
source $CONDA_BASE/bin/activate
conda activate sup
set +o pipefail
yes | $SUDO $CONDA_BASE/bin/mamba env update -qf $DIR/../conda_envs/sup.yml
set -o pipefail
$SUDO $CONDA_BASE/envs/sup/bin/pip install -e /opt/MagAOX/source/purepyindi2[all]
$SUDO $CONDA_BASE/envs/sup/bin/pip install -e /opt/MagAOX/source/magpyx
# sudo -H $CONDA_BASE/envs/sup/bin/pip install /opt/MagAOX/source/milk/src/ImageStreamIO # milk not cloned yet, in install_milk_and_cacao.sh instead

# $CONDA_BASE/envs/sup/bin/python -c 'import ImageStreamIOWrap' || exit 1 # milk not cloned yet, in install_milk_and_cacao.sh instead

make  # installs Python module in editable mode, builds all js (needs node/yarn)
$SUDO $CONDA_BASE/envs/sup/bin/pip install -e /opt/MagAOX/source/sup   # because only root can write to site-packages
cd
$CONDA_BASE/envs/sup/bin/python -c 'import sup' || exit 1  # verify sup is on PYTHONPATH

# Install service units
UNIT_PATH=/etc/systemd/system/
if [[ $MAGAOX_ROLE == AOC ]]; then
    $SUDO cp $DIR/../systemd_units/sup.service $UNIT_PATH/sup.service
    OVERRIDE_PATH=$UNIT_PATH/sup.service.d/
    $SUDO mkdir -p $OVERRIDE_PATH
    echo "[Service]" | $SUDO tee $OVERRIDE_PATH/override.conf
    echo "Environment=\"UVICORN_HOST=0.0.0.0\"" | $SUDO tee -a $OVERRIDE_PATH/override.conf
    echo "Environment=\"UVICORN_PORT=4433\"" | $SUDO tee -a $OVERRIDE_PATH/override.conf
    echo "Environment=\"MAGAOX_ROLE=$MAGAOX_ROLE\"" | $SUDO tee -a $OVERRIDE_PATH/override.conf
    echo "Environment=\"UVICORN_SSL_KEYFILE=/home/xsup/.lego/certificates/exao1.magao-x.org.key\"" | $SUDO tee -a $OVERRIDE_PATH/override.conf
    echo "Environment=\"UVICORN_SSL_CERTFILE=/home/xsup/.lego/certificates/exao1.magao-x.org.crt\"" | $SUDO tee -a $OVERRIDE_PATH/override.conf
    echo "Environment=\"UVICORN_CA_CERTS=/home/xsup/.lego/certificates/exao1.magao-x.org.issuer.crt\"" | $SUDO tee -a $OVERRIDE_PATH/override.conf
    $SUDO firewall-cmd --add-forward-port=port=443:proto=tcp:toport=4433 --permanent
    $SUDO firewall-cmd --permanent --zone=public --add-service=https
    $SUDO systemctl enable sup.service || true
    $SUDO systemctl restart sup.service || true
fi

# Install localhost-only service
$SUDO cp $DIR/../systemd_units/sup.service $UNIT_PATH/sup-local.service
OVERRIDE_PATH=$UNIT_PATH/sup-local.service.d/
$SUDO mkdir -p $OVERRIDE_PATH
echo "[Service]" | $SUDO tee $OVERRIDE_PATH/override.conf
echo "Environment=\"MAGAOX_ROLE=$MAGAOX_ROLE\"" | $SUDO tee -a $OVERRIDE_PATH/override.conf

if [[ $VM_KIND != "none" ]]; then
    echo "Environment=\"UVICORN_HOST=0.0.0.0\"" | $SUDO tee -a $OVERRIDE_PATH/override.conf
fi
if [[ $instrument_user != xsup ]]; then
    echo "User=$instrument_user" | $SUDO tee -a $OVERRIDE_PATH/override.conf
    echo "WorkingDirectory=/home/$instrument_user" | $SUDO tee -a $OVERRIDE_PATH/override.conf
fi
$SUDO systemctl enable sup-local.service || true
$SUDO systemctl restart sup-local.service || true
