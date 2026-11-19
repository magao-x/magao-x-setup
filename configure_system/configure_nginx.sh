#!/bin/bash
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source $DIR/../_common.sh
set -o pipefail

# Allow nginx to connect to local upstreams (e.g. sup on 127.0.0.1:9191)
if command -v selinuxenabled > /dev/null && selinuxenabled; then
    $SUDO setsebool -P httpd_can_network_connect 1 || exit_with_error "Couldn't set SELinux boolean httpd_can_network_connect"
fi
$SUDO systemctl enable nginx || true   # may already be
$SUDO systemctl start nginx || true   # may already be
$SUDO install -o root -g root $DIR/../nginx/upgrade_ws.conf /etc/nginx/conf.d/upgrade_ws.conf || exit_with_error "Couldn't install NGINX WebSockets config"
$SUDO install -o root -g root $DIR/../nginx/sup.conf /etc/nginx/conf.d/sup.conf || exit_with_error "Couldn't install NGINX proxy config for sup"
$SUDO nginx -t || exit_with_error "nginx config file failed syntax check"
$SUDO systemctl reload nginx
