#!/bin/bash
# If not started as root, sudo yourself
if [[ "$EUID" != 0 ]]; then
    sudo -H bash -l $0 "$@"
    exit $?
fi
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source $DIR/../_common.sh
set -xu

if [[ ! -d /opt/conda/envs/${INSTRUMENT_CONDA_ENV} || ! -d /opt/conda/envs/${JUPYTERHUB_ENV_NAME} ]]; then
    exit_with_error "Couldn't find instrument conda environment or JupyterHub environment for Jupyter kernel install"
fi

# The default `python3` kernel should be pointed at the instrument environment
# when running through JupyterHub
rsync -rtv $DIR/../jupyterhub/kernel/ /opt/conda/envs/${JUPYTERHUB_ENV_NAME}/share/jupyter/kernels/python3/
cat /opt/conda/envs/${JUPYTERHUB_ENV_NAME}/share/jupyter/kernels/python3/kernel.json.template | \
    envsubst > /opt/conda/envs/${JUPYTERHUB_ENV_NAME}/share/jupyter/kernels/python3/kernel.json
rm /opt/conda/envs/${JUPYTERHUB_ENV_NAME}/share/jupyter/kernels/python3/kernel.json.template
