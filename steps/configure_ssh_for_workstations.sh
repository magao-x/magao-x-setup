#!/bin/bash
if [[ "$EUID" != 0 ]]; then
    sudo -H bash $0 "$@"
    exit $?
fi
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source $DIR/../_common.sh
set -uo pipefail
USERS=""
if getent passwd $instrument_user > /dev/null 2>&1; then
  USERS="$instrument_user $USERS"
fi
if [[ $USER != xdev ]]; then
    if getent passwd xdev > /dev/null 2>&1; then
        USERS="xdev $USERS"
    fi
fi
#
# Pre-populate known hosts and hostname aliases for SSH tunneling from the VM
#
for userName in $USERS; do
    touch /home/$userName/.hushlogin || exit 1
    mkdir -p /home/$userName/.ssh || exit 1
    if [[ ! -e /home/$userName/.ssh/known_hosts ]]; then
        cat <<'HERE' | tee /home/$userName/.ssh/known_hosts
rtc ecdsa-sha2-nistp256 AAAAE2VjZHNhLXNoYTItbmlzdHAyNTYAAAAIbmlzdHAyNTYAAABBBFmgoTzcAVYXDZjPFNLfpPz/T/0DQvrXSe9XOly9SD7NcjwN/fRTk+DhrWzdPN5aBsDnnmMS8lFGIcRwnlhUN6o=
icc ecdsa-sha2-nistp256 AAAAE2VjZHNhLXNoYTItbmlzdHAyNTYAAAAIbmlzdHAyNTYAAABBBNpRRN65o8TcP2DnkXHdzIqAJ9CAoiz2guLSXjobx7L4meAtphb30nSx5pQqOeysU+otN9PEJH6TWr8KUXBDw6I=
exao1.magao-x.org ecdsa-sha2-nistp256 AAAAE2VjZHNhLXNoYTItbmlzdHAyNTYAAAAIbmlzdHAyNTYAAABBBMsOYTn6tlmcatxt1pDfowTtBTsmJ77OMSPl3rNl8+OBKhmpVpX+iBUMKsBDwwVIlqEAa9BfJPbSrpWEWZABv3s=
HERE
    if [[ ! $? ]]; then
        exit_with_error "Couldn't prepopulate /home/$userName/.ssh/known_hosts"
    fi
    else
        log_info "/home/$userName/.ssh/known_hosts exists, not overwriting"
    fi
    if [[ ! -e /home/$userName/.ssh/config ]]; then
    cat << "HERE" | tee /home/$userName/.ssh/config
Host aoc exao1
HostName exao1.magao-x.org
Host rtc exao2
HostName rtc
ProxyJump aoc
Host icc exao3
HostName icc
ProxyJump aoc
Host *
User YOURMAGAOXUSERNAME
HERE
    if [[ ! $? ]]; then
        exit_with_error "Couldn't prepopulate /home/$userName/.ssh/config"
    fi
    else
        log_info "/home/$userName/.ssh/config exists, not overwriting"
    fi
    chmod -R u=rwX,g=,o= /home/$userName/.ssh/ || exit 1
done
