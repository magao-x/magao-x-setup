#!/bin/bash
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source $DIR/../_common.sh
set -uo pipefail
source /etc/os-release
if [[ -e /etc/chrony/chrony.conf ]]; then
    CHRONYCONF_PATH=/etc/chrony/chrony.conf
elif [[ -e /etc/chrony.conf ]]; then
    CHRONYCONF_PATH=/etc/chrony.conf
else
    log_error "Can't find chrony.conf. Is chrony installed?"
    exit 1
fi

if [[ $MAGAOX_ROLE == RTC ]]; then
    log_info "Configuring chronyd as a time master for $MAGAOX_ROLE"
    sudo tee $CHRONYCONF_PATH <<'HERE'
# chrony.conf installed by MagAO-X
# for time master
ratelimit interval -5
server lbtntp.as.arizona.edu iburst
server ntp1.lco.cl iburst
server ntp2.lco.cl iburst
pool 0.rocky.pool.ntp.org iburst
# rack lan
allow 192.168.0.0/24
# telescopes 200.x
allow 200.28.147.0/24
# lco-science wifi
allow 10.8.10.0/24
# icc over 1-to-1
allow 192.168.2.3
driftfile /var/lib/chrony/drift
makestep 1.0 3
rtcsync
HERE
    if [[ ! $? ]]; then
        exit_with_error "Couldn't create $CHRONYCONF_PATH"
    fi
elif [[ $MAGAOX_ROLE == ICC ]]; then
    log_info "Configuring chronyd for ICC as a time minion over direct point-to-point to RTC"
    sudo tee $CHRONYCONF_PATH <<'HERE'
# chrony.conf installed by MagAO-X
# for time minion
server rtc-from-icc iburst minpoll -4 maxpoll -4 xleave
driftfile /var/lib/chrony/drift
makestep 1.0 3
rtcsync
HERE
    if [[ ! $? ]]; then
        exit_with_error "Couldn't create $CHRONYCONF_PATH"
    fi
elif [[ $MAGAOX_ROLE == AOC ]]; then
    log_info "Configuring chronyd for AOC as a time minion to RTC"
    sudo tee $CHRONYCONF_PATH <<'HERE'
# chrony.conf installed by MagAO-X
# for time minion
server rtc iburst iburst minpoll -4 maxpoll -4 xleave
driftfile /var/lib/chrony/drift
makestep 1.0 3
rtcsync
HERE
    if [[ ! $? ]]; then
        exit_with_error "Couldn't create $CHRONYCONF_PATH"
    fi
elif [[ $MAGAOX_ROLE == TIC ]]; then
    log_info "Configuring chronyd as a time master for $MAGAOX_ROLE"
    sudo tee $CHRONYCONF_PATH <<'HERE'
# chrony.conf installed by MagAO-X
# for time master
ratelimit interval -5
server lbtntp.as.arizona.edu iburst
pool 0.rocky.pool.ntp.org iburst
allow 192.168.1.0/24
driftfile /var/lib/chrony/drift
makestep 1.0 3
rtcsync
HERE
    if [[ ! $? ]]; then
        exit_with_error "Couldn't create $CHRONYCONF_PATH"
    fi
elif [[ $MAGAOX_ROLE == TOC ]]; then
    log_info "Configuring chronyd for $MAGAOX_ROLE as a time minion to tic"
    sudo tee $CHRONYCONF_PATH <<'HERE'
# chrony.conf installed by MagAO-X
# for time minion
server tic iburst minpoll -4 maxpoll -4 xleave
driftfile /var/lib/chrony/drift
makestep 1.0 3
rtcsync
HERE
    if [[ ! $? ]]; then
        exit_with_error "Couldn't create $CHRONYCONF_PATH"
    fi
else
    log_info "Skipping chronyd setup because this isn't an instrument computer"
    exit 0
fi
if [[ $ID == "ubuntu" ]]; then
	sudo systemctl enable chrony || exit 1
else
	sudo systemctl enable chronyd || exit 1
fi
log_info "chronyd enabled"
if [[ $ID == "ubuntu" ]]; then
	sudo systemctl restart chrony || exit 1
	systemctl status chrony | cat || exit 1
else
	sudo systemctl restart chronyd || exit 1
	systemctl status chronyd | cat || exit 1
fi
log_info "chronyd started, waiting 5 sec..."
sleep 5
chronyc sources || exit 1
sudo chronyc makestep || exit 1
log_info "forced time sync"
