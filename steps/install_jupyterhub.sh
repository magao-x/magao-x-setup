#!/bin/bash
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source $DIR/../_common.sh
set -o pipefail

JUPYTERHUB_GROUP=jupyterhub

if [[ ! -d $CONDA_BASE/envs/${JUPYTERHUB_ENV_NAME} ]]; then
    $SUDO $CONDA_BASE/bin/conda create -y -p $CONDA_BASE/envs/$JUPYTERHUB_ENV_NAME python jupyterhub
fi

set +o pipefail
yes | $SUDO $CONDA_BASE/bin/mamba env update -p $CONDA_BASE/envs/$JUPYTERHUB_ENV_NAME -f $DIR/../conda_envs/jupyterhub.yml || exit_with_error "Failed to install or update packages for JupyterHub env"
set -o pipefail

$SUDO $DIR/configure_jupyter_kernel.sh || exit_with_error "Failed to install Jupyter kernel for MagAO-X environment"

# lock = disable annoying popup about jupyter news
$SUDO $CONDA_BASE/envs/${JUPYTERHUB_ENV_NAME}/bin/jupyter labextension disable "@jupyterlab/apputils-extension:announcements"
$SUDO $CONDA_BASE/envs/${JUPYTERHUB_ENV_NAME}/bin/jupyter labextension lock "@jupyterlab/apputils-extension:announcements"

# Note that this GID is set on purpose to match
# the LDAP server at accounts.xwcl.science
createLocalFallbackGroup $JUPYTERHUB_GROUP 2003 $instrument_user || exit_with_error "Couldn't create local fallback for group $JUPYTERHUB_GROUP"

# Set up service config dir
$SUDO mkdir -p /etc/jupyterhub || exit_with_error "Couldn't make /etc/jupyterhub"
$SUDO cp -v $DIR/../jupyterhub/jupyterhub_config_minimal.py /etc/jupyterhub/jupyterhub_config.py || exit_with_error "Couldn't copy JupyterHub config"
$SUDO chown -R root:root /etc/jupyterhub || exit_with_error "Couldn't normalize ownership of JupyterHub files"

$SUDO install -o root -g root $DIR/../jupyterhub/jupyterhub_pam /etc/pam.d/jupyterhub || exit_with_error "Couldn't install PAM config for JupyterHub"
$SUDO install -o root -g root $DIR/../jupyterhub/jupyterhub.service /etc/systemd/system/jupyterhub.service || exit_with_error "Couldn't install SystemD unit for JupyterHub"
$SUDO systemctl daemon-reload || exit_with_error "SystemD reload failed"
$SUDO systemctl restart jupyterhub.service || exit_with_error "Couldn't enable SystemD unit for JupyterHub"
log_success "JupyterHub configured!"
