#!/usr/bin/env bash
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source $DIR/../_common.sh
set -uo pipefail

sudo dnf install -y sssd sssd-tools oddjob-mkhomedir || exit_with_error "Unable to install OS packages for LDAP authentication"
sudo systemctl enable --now oddjobd || true
sudo authselect select sssd --force mkhomedir || exit_with_error "Unable to select SSSD for auth"
sudo sssctl config-check || exit_with_error "Config check failed for SSSD"
sudo systemctl enable --now sssd || true
log_info "Configured LDAP authentication"
