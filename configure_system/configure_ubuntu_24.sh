#!/bin/bash
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source $DIR/../_common.sh
set -uo pipefail

log_info 'Making /etc/bash.bashrc source /etc/profile.d/*.sh, since graphical sessions appear not to for new Konsoles'
if ! grep -q profile.d /etc/bash.bashrc; then
cat <<'HERE' | $SUDO tee -a /etc/bash.bashrc || exit 1
if [ -d /etc/profile.d ]; then
  for i in /etc/profile.d/*.sh; do
    if [ -r $i ]; then
      . $i
    fi
  done
  unset i
fi
HERE
fi

if [[ $MAGAOX_ROLE == AOC ]]; then
  $SUDO mkdir -p /etc/systemd/logind.conf.d/
  cat <<'HERE' | $SUDO tee /etc/systemd/logind.conf.d/disable_power_keys.conf || exit 1
HandlePowerKey=ignore
HandleSuspendKey=ignore
HandleHibernateKey=ignore
HandleRebootKey=ignore
HERE
fi

if [[ $MAGAOX_ROLE == AOC || $MAGAOX_ROLE == ICC || $MAGAOX_ROLE == RTC || $MAGAOX_ROLE == TIC || $MAGAOX_ROLE == TOC ]]; then
    log_info "Purging cloud-init"
    $SUDO apt-get purge -y cloud-init || exit 1
    $SUDO apt autoremove -y

    log_info "Disable waiting for LAN config during boot"
    $SUDO systemctl mask systemd-networkd-wait-online.service
    
    log_info "Ensure UFW firewall is enabled"
    yes | $SUDO ufw enable
    $SUDO ufw allow ssh
    $SUDO ufw deny http
    $SUDO ufw deny https
    $SUDO ufw allow in from 192.168.0.0/24

    log_info "Use old (RHEL 7) mountpoint for cpusets"
    $SUDO mkdir -p /sys/fs/cgroup/cpuset || exit 1
    cat <<'HERE' | $SUDO tee /etc/cset.conf
mountpoint = /sys/fs/cgroup/cpuset
HERE
fi

log_info "Hush login banners"
$SUDO touch /etc/skel/.hushlogin

if [[ -d /usr/share/unattended-upgrades ]]; then
  log_info "Disable automatic upgrades"
  $SUDO cp -v /usr/share/unattended-upgrades/20auto-upgrades-disabled /etc/apt/apt.conf.d/ || exit 1
fi

log_info "Done with custom configuration for Ubuntu 22.04"
