#!/bin/bash
# If not started as root, sudo yourself
if [[ "$EUID" != 0 ]]; then
    sudo -H bash -l $0 "$@"
    exit $?
fi
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source $DIR/../_common.sh
set -xu

MINIFORGE3_VERSION="25.9.1-0"
MINIFORGE3_INSTALLER="Miniforge3-$MINIFORGE3_VERSION-Linux-$(uname -m).sh"
MINIFORGE3_URL="https://github.com/conda-forge/miniforge/releases/download/$MINIFORGE3_VERSION/$MINIFORGE3_INSTALLER"
#
# conda
#
# n.b. CONDA_BASE is defined in _common.sh
cd /opt/MagAOX/vendor || exit 1
if [[ ! -d $CONDA_BASE ]]; then
    _cached_fetch "$MINIFORGE3_URL" $MINIFORGE3_INSTALLER || exit 1
    bash $MINIFORGE3_INSTALLER -b -p $CONDA_BASE || exit 1
	# Ensure magaox-dev can write to $CONDA_BASE or env creation will fail
	chown -R :$instrument_dev_group $CONDA_BASE || exit 1
    # set group and permissions such that only magaox-dev has write access
    chmod -R g=rwX $CONDA_BASE || exit 1
    find $CONDA_BASE -type d -exec sudo chmod g+rwxs {} \; || exit 1

    cat << 'EOF' | tee $CONDA_BASE/.condarc || exit 1
channels:
  - conda-forge
changeps1: false
disallowed_packages: [ qt ]
EOF
fi

if [[ ! -e $MAMBA ]]; then
  echo "mamba not found; installing with conda"
  $CONDA install -c conda-forge mamba
fi

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
# Install the kernel for JupyterHub use
if [[ -z $CONDA_BASE || -z $INSTRUMENT_CONDA_ENV ]]; then
    exit_with_error "No CONDA_BASE in env"
fi
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
if [[ $MAGAOX_ROLE == AOC || $MAGAOX_ROLE == workstation ]]; then
    bash $DIR/install_sup.sh || exit_with_error "Failed to install sup"
fi

# If being run after initial provisioning, ensure MILK ImageStreamIO gets rebuilt for the new Python
if [[ -e /opt/MagAOX/source/milk/src/ImageStreamIO ]]; then
    $pythonExe -m pip install /opt/MagAOX/source/milk/src/ImageStreamIO/ || exit 1
    $pythonExe -c 'import ImageStreamIOWrap' || exit 1
fi
