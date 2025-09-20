#!/bin/bash
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source $DIR/../_common.sh
set -o pipefail

JUPYTERHUB_USER=jupyterhub
JUPYTERHUB_GROUP=jupyterhub
JUPYTERHUB_ENV_NAME=jupyterhub

if [[ ! -d /opt/conda/envs/${JUPYTERHUB_ENV_NAME} ]]; then
    sudo -H /opt/conda/bin/mamba create -yn $JUPYTERHUB_ENV_NAME python jupyterhub
fi
sudo -H mamba env update -n $JUPYTERHUB_ENV_NAME -f $DIR/../conda_env_jupyterhub.yml || exit_with_error "Failed to install or update packages for JupyterHub env"

# lock = disable annoying popup about jupyter news
sudo -H /opt/conda/envs/${JUPYTERHUB_ENV_NAME}/bin/jupyter labextension lock "@jupyterlab/apputils-extension:announcements"

# Note that this GID is set on purpose to match
# the LDAP server at accounts.xwcl.science
createLocalFallbackGroup $JUPYTERHUB_GROUP 2003 $JUPYTERHUB_USER $instrument_user || exit_with_error "Couldn't create local fallback for group $JUPYTERHUB_GROUP"
sudo gpasswd -a $instrument_user $JUPYTERHUB_GROUP || exit_with_error "Couldn't add $instrument_user to $JUPYTERHUB_GROUP"

# Set up service config dir
sudo mkdir -p /etc/jupyterhub || exit_with_error "Couldn't make /etc/jupyterhub"
sudo cp -v $DIR/../jupyterhub_config_minimal.py /etc/jupyterhub/jupyterhub_config.py || exit_with_error "Couldn't copy JupyterHub config"
sudo chown -R $JUPYTERHUB_USER:$JUPYTERHUB_GROUP /etc/jupyterhub || exit_with_error "Couldn't normalize ownership of JupyterHub files"

sudo bash $DIR/../selinux/build_and_load.sh $DIR/../selinux/jupyterhub-can-setattr.te jupyterhub-can-setattr || exit_with_error "Couldn't load SELinux policy for JupyterHub"

sudo install -o root -g root cp $DIR/../systemd_units/jupyterhub.service /etc/systemd/system/jupyterhub.service || exit_with_error "Couldn't install SystemD unit for JupyterHub"
sudo systemctl daemon-reload || exit_with_error "SystemD reload failed"
sudo systemctl enable --now /etc/systemd/system/jupyterhub.service || exit_with_error "Couldn't enable SystemD unit for JupyterHub"
log_success "JupyterHub configured!"