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

# Set up unprivileged service user
if ! getent passwd $JUPYTERHUB_USER; then
    log_info "No $JUPYTERHUB_USER user yet, creating..."
    sudo useradd --system --no-user-group --shell /sbin/nologin $JUPYTERHUB_USER || exit_with_error "Could not create the JupyterHub service account"
    log_info "done!"
fi

# Note that this GID is set on purpose to match
# the LDAP server at accounts.xwcl.science
createLocalFallbackGroup $JUPYTERHUB_GROUP 2003 $JUPYTERHUB_USER $instrument_user || exit_with_error "Couldn't create local fallback for group $JUPYTERHUB_GROUP"

# Set up service config dir
sudo mkdir -p /etc/jupyterhub || exit_with_error "Couldn't make /etc/jupyterhub"
sudo cp -v $DIR/../jupyterhub_config_minimal.py /etc/jupyterhub/jupyterhub_config.py || exit_with_error "Couldn't copy JupyterHub config"
sudo chown -R $JUPYTERHUB_USER:$JUPYTERHUB_GROUP /etc/jupyterhub || exit_with_error "Couldn't normalize ownership of JupyterHub files"

sudo bash $DIR/../selinux/build_and_load.sh $DIR/../selinux/jupyterhub-audit2allow.te || exit_with_error "Couldn't load SELinux policy for JupyterHub"

