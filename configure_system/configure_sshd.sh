#!/bin/bash
SUDO="${SUDO:-sudo}"
if [[ "$EUID" != 0 ]]; then
    $SUDO bash $0 "$@"
    exit $?
fi
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source $DIR/../_common.sh
mkdir -p /etc/ssh/authorized_keys
chmod u=rx,g=x,o=x /etc/ssh/authorized_keys
chmod a=r /etc/ssh/authorized_keys/*
cat <<'HERE' | tee /etc/ssh/sshd_config.d/50-disable-passwords.conf
PasswordAuthentication no
# Perhaps redundant, but:
PermitRootLogin prohibit-password
HERE
cat <<'HERE' | tee /etc/ssh/sshd_config.d/50-limit-authorized-keys.conf
AuthorizedKeysFile /etc/ssh/authorized_keys/%u
HERE
for username in $instrument_user $dev_user; do
    if [[ ! -e /etc/ssh/authorized_keys/$username ]]; then
        if [[ -e /home/$username/.ssh/authorized_keys ]]; then
            cp /home/$username/.ssh/authorized_keys /etc/ssh/authorized_keys/$username
        else
            exit_with_error "Ensure you place $username's authorized keys in /etc/ssh/authorized_keys/$username and chmod a=r /etc/ssh/authorized_keys/$username before reloading sshd"
        fi
    fi
done
chmod -v a=r /etc/ssh/authorized_keys/*
systemctl reload sshd || exit_with_error "Couldn't reload sshd"
