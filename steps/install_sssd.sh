#!/usr/bin/env bash
if [[ "$EUID" != 0 ]]; then
    sudo -H bash $0 "$@"
    exit $?
fi
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source $DIR/../_common.sh

log_info "Installing SSSD for authentication with remote LDAP server..."
dnf --setopt=timeout=300 --setopt=retries=10 -y install sssd oddjob-mkhomedir sssd-tools || exit_with_error "Failed to install distro packages for SSSD or mkhomedir"
log_info "Selecting SSSD as the auth backend"
authselect select sssd --force with-mkhomedir || exit_with_error "Failed to select SSSD with authselect"
log_success "SSSD selected!"
systemctl enable --now sssd || exit_with_error "Couldn't enable/start SSSD"
systemctl enable --now oddjobd.service || exit_with_error "Couldn't enable/start oddjobd"
log_success "oddjobd enabled!"
cat <<'HERE' | tee /etc/ssh/sshd_config.d/60-keys-from-directory.conf
AuthorizedKeysCommand /usr/bin/sss_ssh_authorizedkeys
AuthorizedKeysCommandUser nobody
HERE
systemctl reload sshd || exit_with_error "Couldn't reload sshd"
