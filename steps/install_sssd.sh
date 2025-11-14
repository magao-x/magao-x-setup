#!/usr/bin/env bash
if [[ "$EUID" != 0 ]]; then
    sudo -H bash $0 "$@"
    exit $?
fi
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source $DIR/../_common.sh

log_info "Installing SSSD for authentication with remote LDAP server..."
dnf install -y sssd oddjob-mkhomedir || exit_with_error "Failed to install distro packages for SSSD or mkhomedir"
log_info "Selecting SSSD as the auth backend"
authselect select sssd --force with-mkhomedir || exit_with_error "Failed to select SSSD with authselect"
log_success "SSSD selected!"
systemctl enable --now oddjobd.service || exit_with_error "Couldn't enable/start oddjobd"
log_success "oddjobd enabled!"
