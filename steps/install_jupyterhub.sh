#!/bin/bash
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source $DIR/../_common.sh
set -o pipefail

JUPYTERHUB_GROUP=jupyterhub
JUPYTERHUB_ENV_NAME=jupyterhub

if [[ ! -d $CONDA_BASE/envs/${JUPYTERHUB_ENV_NAME} ]]; then
    sudo -H $CONDA_BASE/bin/conda create -y -p $CONDA_BASE/envs/$JUPYTERHUB_ENV_NAME python jupyterhub
fi
sudo -H $CONDA_BASE/bin/mamba env update -p $CONDA_BASE/envs/$JUPYTERHUB_ENV_NAME -f $DIR/../conda_env_jupyterhub.yml || exit_with_error "Failed to install or update packages for JupyterHub env"

# lock = disable annoying popup about jupyter news
sudo -H $CONDA_BASE/envs/${JUPYTERHUB_ENV_NAME}/bin/jupyter labextension lock "@jupyterlab/apputils-extension:announcements"

# Note that this GID is set on purpose to match
# the LDAP server at accounts.xwcl.science
createLocalFallbackGroup $JUPYTERHUB_GROUP 2003 $instrument_user || exit_with_error "Couldn't create local fallback for group $JUPYTERHUB_GROUP"

# Set up service config dir
sudo mkdir -p /etc/jupyterhub || exit_with_error "Couldn't make /etc/jupyterhub"
sudo cp -v $DIR/../jupyterhub_config_minimal.py /etc/jupyterhub/jupyterhub_config.py || exit_with_error "Couldn't copy JupyterHub config"
sudo chown -R root:root /etc/jupyterhub || exit_with_error "Couldn't normalize ownership of JupyterHub files"
scratchFile=/tmp/sudoers_jupyterhub
targetFile=/etc/sudoers.d/jupyterhub
cat <<'HERE' > $scratchFile
# Let users in the jupyterhub group logging in for the first time via JupyterHub run the init_users_data_dir.sh script
jupyterhub ALL=(%jupyterhub) NOPASSWD: /etc/profile.d/init_users_data_dir.sh
HERE
sudo visudo -cf $scratchFile || exit_with_error "visudo syntax check failed on $scratchFile"

sudo install -o root -g root $DIR/../systemd_units/jupyterhub.service /etc/systemd/system/jupyterhub.service || exit_with_error "Couldn't install SystemD unit for JupyterHub"
sudo systemctl daemon-reload || exit_with_error "SystemD reload failed"
sudo systemctl restart jupyterhub.service || exit_with_error "Couldn't enable SystemD unit for JupyterHub"
log_success "JupyterHub configured!"
