#!/bin/bash
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source $DIR/../_common.sh
set -o pipefail

$SUDO systemctl enable --now nginx || exit_with_error "Couldn't enable or start nginx"
$SUDO install -o root -g root $DIR/../nginx/upgrade_ws.conf /etc/nginx/default.d/upgrade_ws.conf || exit_with_error "Couldn't install NGINX WebSockets config"
$SUDO install -o root -g root $DIR/../nginx/sup.conf /etc/nginx/conf.d/sup.conf || exit_with_error "Couldn't install NGINX proxy config for sup"
$SUDO systemctl reload nginx
