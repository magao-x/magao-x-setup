#!/bin/bash
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source $DIR/../_common.sh
set -o pipefail

JUPYTERHUB_SUDOSPAWNER_USER=jupyterhub-spawn
JUPYTERHUB_ENV_NAME=jupyterhub

if [[ ! -d /opt/conda/envs/${JUPYTERHUB_ENV_NAME} ]]; then
    sudo -H /opt/conda/bin/mamba create -yn jupyterhub python jupyterhub
fi
sudo -H mamba env update -f $DIR/../conda_env_jupyterhub.yml || exit_with_error "Failed to install or update packages for JupyterHub env"
# lock = disable annoying popup about jupyter news
sudo -H /opt/conda/envs/${JUPYTERHUB_ENV_NAME}/bin/jupyter labextension lock "@jupyterlab/apputils-extension:announcements"


if ! getent passwd $JUPYTERHUB_SUDOSPAWNER_USER; then
    log_info "No $JUPYTERHUB_SUDOSPAWNER_USER user yet, creating..."
    sudo useradd --system --user-group --shell /sbin/nologin $JUPYTERHUB_SUDOSPAWNER_USER || exit_with_error "Could not create the JupyterHub SudoSpawner user account"
    log_info "done!"
fi

# Set up sudo to let unprivileged jupyterhub service start kernels as other users
scratchFile=/tmp/sudoers_jupyterhub
targetFile=/etc/sudoers.d/jupyterhub

SUDOSPAWNER_PATH="/opt/conda/envs/${JUPYTERHUB_ENV_NAME}/bin/sudospawner"
if [[ ! -e $SUDOSPAWNER_PATH ]]; then
    exit_with_error "sudospawner is not where we expect; bailing"
fi

cat <<"HERE" | tee -a $scratchFile
# the command(s) the Hub can run on behalf of the above users without needing a password
Cmnd_Alias JUPYTER_CMD = ${SUDOSPAWNER_PATH}
${JUPYTERHUB_SUDOSPAWNER_USER} ALL=(%jupyterhub) NOPASSWD:JUPYTER_CMD
HERE

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
