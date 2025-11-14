#!/usr/bin/env bash
if [[ "$EUID" != 0 ]]; then
    sudo -H bash $0 "$@"
    exit $?
fi
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source $DIR/../_common.sh

log_info "Installing SSSD for authentication with remote LDAP server..."
dnf install -y sssd || exit 1
log_info "Selecting SSSD as the auth backend"
authselect select sssd --force with-mkhomedir || exit 1
log_success "SSSD selected!"
