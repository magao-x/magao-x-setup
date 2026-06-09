#!/usr/bin/env bash
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source $DIR/_common.sh
set -uo pipefail
clone_or_update_and_cd xwcl hush-hush /opt/MagAOX/source/ || exit 1
bash -l ./deploy-local.sh $(hostnamectl hostname) || exit 1
log_info "Deployed secrets"
