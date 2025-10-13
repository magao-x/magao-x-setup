#!/bin/bash
if [[ "$EUID" != 0 ]]; then
    echo "Becoming root..."
    sudo -H bash -l $0 "$USER"
    exit $?
fi
set -uo pipefail
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source $DIR/_common.sh

# Note that these GIDs are set on purpose to match
# the LDAP server at accounts.xwcl.science
createLocalFallbackGroup $instrument_group 2000 || exit_with_error "Couldn't create local fallback for group $instrument_group"
createLocalFallbackGroup $instrument_dev_group 2001 || exit_with_error "Couldn't create local fallback for group $instrument_dev_group"

createuser xsup
createuser xdev
# Defines $ID and $VERSION_ID so we can detect which distribution we're on
source /etc/os-release

if [[ $ID == ubuntu ]]; then
  sudo_group=sudo
else
  sudo_group=wheel
fi
gpasswd -a $instrument_dev_group xdev
gpasswd -a $sudo_group xdev

if [[ $MAGAOX_ROLE == AOC || $MAGAOX_ROLE == RTC || $MAGAOX_ROLE == ICC || $MAGAOX_ROLE == TIC ]]; then
  # Instrument computers should have a backup user to own the irodsfs mount
  createuser xbackup
  $SUDO passwd --lock xbackup
fi
if [[ $MAGAOX_ROLE == AOC ]]; then
  createuser guestobs
  $SUDO passwd --lock guestobs  # SSH login still possible
  $SUDO groupadd -f guestobs || exit_with_error "Couldn't add guestobs group"
  $SUDO gpasswd -d guestobs magaox || true  # prevent access for shenanigans
  $SUDO gpasswd -a guestobs guestobs || true
  $SUDO mkdir -p /data/obs
  $SUDO chown xsup:guestobs /data/obs
  $SUDO chmod u=rwX,g=rX,o=rX /data/obs/*
  link_if_necessary /data/obs /home/guestobs/obs
  if [[ -z $(groups | tr ' ' '\n' | grep 'guestobs$') ]]; then
    $SUDO gpasswd -a xsup guestobs
    log_success "Added xsup to group guestobs"
  fi
fi
if $SUDO test ! -e /home/xsup/.ssh/id_ed25519; then
  $REAL_SUDO -u xsup ssh-keygen -t ed25519 -N "" -f /home/xsup/.ssh/id_ed25519 -q
fi
if ! grep -q $instrument_dev_group /etc/pam.d/su; then
  cat <<'HERE' | $SUDO sed -i '/pam_rootok.so$/r /dev/stdin' /etc/pam.d/su
auth            [success=ignore default=1] pam_succeed_if.so user = xsup
auth            sufficient      pam_succeed_if.so use_uid user ingroup magaox-dev
HERE
  log_info "Modified /etc/pam.d/su"
else
  log_info "/etc/pam.d/su already includes reference to magaox-dev, not modifying"
fi

if [[ ! -z "$1" && getent passwd "$1" > /dev/null 2>&1 ]]; then
  interactiveUser="$1"
  if [[ -z $(groups | tr ' ' '\n' | grep 'magaox-dev$') ]]; then
    $SUDO gpasswd -a $interactiveUser $instrument_dev_group
    log_success "Added $interactiveUser to group $instrument_dev_group"
    log_warn "Note: You will need to log out and back in before this group takes effect"
  fi
  if [[ -z $(groups | tr ' ' '\n' | grep 'magaox$') ]]; then
    $SUDO gpasswd -a $interactiveUser $instrument_group
    log_success "Added $interactiveUser to group $instrument_group"
    log_warn "Note: You will need to log out and back in before this group takes effect"
  fi
fi
