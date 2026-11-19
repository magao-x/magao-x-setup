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

make install SUP_ENV=$CONDA_BASE/envs/sup  # builds as non-root user, installs as root with sudo in Makefile
cd
$CONDA_BASE/envs/sup/bin/python -c 'import sup' || exit 1  # verify sup is on PYTHONPATH

# Install service units
UNIT_PATH=/etc/systemd/system/
if [[ $MAGAOX_ROLE == AOC ]]; then
    for name in sup sup-stream; do
        $SUDO cp $DIR/../systemd_units/${name}.service $UNIT_PATH/${name}.service
        OVERRIDE_PATH=$UNIT_PATH/${name}.service.d/
        $SUDO mkdir -p $OVERRIDE_PATH
        echo "[Service]" | $SUDO tee $OVERRIDE_PATH/override.conf
        echo "Environment=\"MAGAOX_ROLE=$MAGAOX_ROLE\"" | $SUDO tee -a $OVERRIDE_PATH/override.conf
        $SUDO systemctl enable ${name}.service || true
        $SUDO systemctl restart ${name}.service || true
    done
fi
