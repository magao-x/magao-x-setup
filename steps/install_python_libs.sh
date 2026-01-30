#!/bin/bash
# If not started as root, sudo yourself
if [[ "$EUID" != 0 ]]; then
    sudo -H bash -l $0 "$@"
    exit $?
fi
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source $DIR/../_common.sh
set -xu

# Install the standard MagAOX user python environment
#
$MAMBA update -y mamba || exit_with_error "Mamba self update failed"
source $CONDA_BASE/bin/activate
if [[ -d /opt/conda/envs/${INSTRUMENT_CONDA_ENV} ]]; then
    conda activate ${INSTRUMENT_CONDA_ENV}
else
    mamba create -y -p $CONDA_BASE/envs/$INSTRUMENT_CONDA_ENV -f $DIR/../conda_envs/${INSTRUMENT_CONDA_ENV}.yml
fi
set +o pipefail
yes | $MAMBA env update -f $DIR/../conda_envs/${INSTRUMENT_CONDA_ENV}.yml || exit_with_error "Failed to install or update packages"
set -o pipefail
$MAMBA env export

# Make the instrument conda env activate on login
echo "export INSTRUMENT_CONDA_ENV=$INSTRUMENT_CONDA_ENV" > /etc/profile.d/conda.sh
echo "export CONDA_BASE=$CONDA_BASE" >> /etc/profile.d/conda.sh
cat <<'EOF' | tee -a /etc/profile.d/conda.sh || exit 1
if [ -f "$CONDA_BASE/etc/profile.d/conda.sh" ]; then
    . "$CONDA_BASE/etc/profile.d/conda.sh"
    CONDA_CHANGEPS1=false conda activate ${INSTRUMENT_CONDA_ENV}
else
    \export PATH="$CONDA_BASE/envs/$INSTRUMENT_CONDA_ENV/bin:$PATH"
fi
EOF
source /etc/profile.d/conda.sh

# Install the kernel for JupyterHub use
pythonExe="$CONDA_BASE/envs/$INSTRUMENT_CONDA_ENV/bin/python"
$pythonExe -m ipykernel install --prefix=/usr/local --name "$INSTRUMENT_CONDA_ENV" --display-name "MagAO-X ($INSTRUMENT_CONDA_ENV)" || exit_with_error "Failed to install kernel for Jupyter"

# Install Python-dependent packages
bash $DIR/install_lookyloo.sh || exit_with_error "Failed to install lookyloo"
bash $DIR/install_magpyx.sh || exit_with_error "Failed to install magpyx"
bash $DIR/install_purepyindi.sh || exit_with_error "Failed to install purepyindi"
bash $DIR/install_purepyindi2.sh || exit_with_error "Failed to install purepyindi2"
bash $DIR/install_xconf.sh || exit_with_error "Failed to install xconf"
if [[ $MAGAOX_ROLE != ci && $MAGAOX_ROLE != container && $MAGAOX_ROLE != workstation ]]; then
    bash $DIR/install_jupyterhub.sh || exit_with_error "Failed to install JupyterHub"
fi
if [[ $MAGAOX_ROLE == AOC ]]; then
    bash $DIR/install_sup.sh || exit_with_error "Failed to install sup"
fi

# ensure MILK ImageStreamIO gets rebuilt for the current Python
$pythonExe -m pip install /opt/MagAOX/source/milk/src/ImageStreamIO/ || exit 1
$pythonExe -c 'import ImageStreamIOWrap' || exit 1
