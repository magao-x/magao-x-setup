#!/bin/bash
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source $DIR/../_common.sh
set -o pipefail

$SUDO systemctl enable nginx || true   # may already be
$SUDO systemctl start nginx || true   # may already be
$SUDO install -o root -g root $DIR/../nginx/upgrade_ws.conf /etc/nginx/conf.d/upgrade_ws.conf || exit_with_error "Couldn't install NGINX WebSockets config"
$SUDO install -o root -g root $DIR/../nginx/sup.conf /etc/nginx/conf.d/sup.conf || exit_with_error "Couldn't install NGINX proxy config for sup"
$SUDO nginx -t || exit_with_error "nginx config file failed syntax check"
$SUDO systemctl reload nginx
