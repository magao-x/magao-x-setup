#!/bin/bash
if [[ "$EUID" != 0 ]]; then
    echo "Becoming root..."
    sudo -H bash -l $0 "$USER"
    exit $?
fi
set -o pipefail
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source $DIR/_common.sh

# Note that these GIDs are set on purpose to match
# the LDAP server at accounts.xwcl.science
createLocalFallbackGroup $instrument_group $instrument_group_gid || exit_with_error "Couldn't create local fallback for group $instrument_group"
createLocalFallbackGroup $instrument_dev_group $instrument_dev_group_gid || exit_with_error "Couldn't create local fallback for group $instrument_dev_group"

# Not an error if they already exist:
createuser $instrument_user
createuser xdev
# Set their *primary* group
usermod -g $instrument_group $instrument_user
usermod -g $instrument_dev_group xdev

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
  $SUDO mkdir -p /home/guestobs/obs
  $SUDO chown ${instrument_user}:guestobs /home/guestobs/obs
  $SUDO chmod u=rwX,g=rX,o=rX /home/guestobs
  if [[ -z $(groups | tr ' ' '\n' | grep 'guestobs$') ]]; then
    $SUDO gpasswd -a $instrument_user guestobs
    log_success "Added $instrument_user to group guestobs"
  fi
fi
if $SUDO test ! -e /home/${instrument_user}/.ssh/id_ed25519; then
  $REAL_SUDO -u $instrument_user ssh-keygen -t ed25519 -N "" -f /home/${instrument_user}/.ssh/id_ed25519 -q
fi

if [[ -n "$1" ]] && getent passwd "$1" > /dev/null 2>&1; then
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
