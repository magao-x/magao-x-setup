#!/bin/bash
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source $DIR/../_common.sh
set -o pipefail

JUPYTERHUB_USER=jupyterhub
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
    sudo useradd --system --user-group --shell /sbin/nologin $JUPYTERHUB_USER || exit_with_error "Could not create the JupyterHub SudoSpawner user account"
    log_info "done!"
fi

# Set up service config dir
sudo mkdir -p /etc/jupyterhub || exit_with_error "Couldn't make /etc/jupyterhub"
sudo cp -v $DIR/../jupyterhub_config_minimal.py /etc/jupyterhub/jupyterhub_config.py || exit_with_error "Couldn't copy JupyterHub config"
sudo chown -R $JUPYTERHUB_USER /etc/jupyterhub || exit_with_error "Couldn't normalize ownership of JupyterHub files"

# Set up sudo to let unprivileged jupyterhub service start kernels as other users
scratchFile=/tmp/sudoers_jupyterhub
targetFile=/etc/sudoers.d/jupyterhub

SUDOSPAWNER_PATH="/opt/conda/envs/${JUPYTERHUB_ENV_NAME}/bin/sudospawner"
if [[ ! -e $SUDOSPAWNER_PATH ]]; then
    exit_with_error "sudospawner is not where we expect; bailing"
fi

touch $scratchFile
chmod 600 $scratchFile
export SUDOSPAWNER_PATH
export JUPYTERHUB_USER
cat $DIR/install_jupyterhub_sudoers.template | \
    envsubst '$SUDOSPAWNER_PATH $JUPYTERHUB_USER' | \
    tee $scratchFile
cat $scratchFile
visudo -cf $scratchFile || exit_with_error "visudo syntax check failed on $scratchFile"
sudo install \
    --owner=root \
    --group=root \
    --mode=440 \
    $scratchFile \
    $targetFile \
|| exit_with_error "Could not install drop-in file to $targetFile"
sudo ls -la /etc/sudoers.d/
sudo stat $targetFile
