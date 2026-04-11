#!/bin/bash
set -o pipefail
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source $DIR/_common.sh
if [[ $VM_KIND != "none" ]]; then
    echo "Detected virtualization: $VM_KIND"
fi
set -x

# CentOS + devtoolset-7 aliases sudo, but breaks command line arguments for it,
# so if we need those, we must use $_REAL_SUDO.
if [[ -e /usr/bin/sudo ]]; then
  _REAL_SUDO=/usr/bin/sudo
elif [[ -e /bin/sudo ]]; then
  _REAL_SUDO=/bin/sudo
else
  if [[ -z $(command -v sudo) ]]; then
    echo "Install sudo before provisioning"
    exit 1
  else
    _REAL_SUDO=$(which sudo)
  fi
fi

# Function to refresh sudo timer
refresh_sudo_timer() {
    while true; do
        $_REAL_SUDO -v
        sleep 60
    done
}

# Clear cached credentials for sudo, if they exist, and refresh only when not root.
if [[ "$EUID" != 0 ]]; then
    $SUDO -K

    # Start refreshing sudo timer in the background
    if [[ "$($_REAL_SUDO -H -n true 2>&1)" ]]; then
        $_REAL_SUDO -v
        refresh_sudo_timer &
        SUDO_REFRESH_PID=$!

        # Kill the background process when the script exits (normal or error)
        trap 'kill "$SUDO_REFRESH_PID" 2>/dev/null' EXIT INT TERM
    fi
fi

# Defines $ID and $VERSION_ID so we can detect which distribution we're on
source /etc/os-release

log_info "Restoring original (trusting) behavior for git's safe.directory option"
git config --global --replace-all safe.directory '*'
if [[ $VM_KIND != "none" ]]; then
    $SUDO git config --global --replace-all safe.directory '*'
fi

# Install build dependencies (1st and 3rd party)
# (For container builds we don't want to redo the dependencies)
if [[ $MAGAOX_CONTAINER != 1 ]]; then
    $SUDO bash -l "$DIR/steps/install_build_deps.sh"
fi

# Install dependencies for the GUIs
if [[ $MAGAOX_ROLE == AOC || $MAGAOX_ROLE == TOC || $MAGAOX_ROLE == ROC || $MAGAOX_ROLE == workstation ]]; then
    $SUDO bash -l "$DIR/steps/install_gui_dependencies.sh"
fi

if [[ $MAGAOX_ROLE == AOC || $MAGAOX_ROLE == TOC || $MAGAOX_ROLE == workstation ]]; then
    # realtime image viewer
    bash -l "$DIR/steps/install_rtimv.sh" || exit_with_error "Could not install rtimv"
    echo "export RTIMV_CONFIG_PATH=/opt/MagAOX/config" | $SUDO tee /etc/profile.d/rtimv_config_path.sh
fi

if [[ $MAGAOX_ROLE == TIC || $MAGAOX_ROLE == TOC ]]; then
    # Initialize the config and calib repos as normal user
    bash -l "$DIR/steps/install_testbed_config.sh"
    bash -l "$DIR/steps/install_testbed_calib.sh"
else
    # Initialize the config and calib repos as normal user
    bash -l "$DIR/steps/install_magao-x_config.sh"
    bash -l "$DIR/steps/install_magao-x_calib.sh"
fi

log_info "Applying configuration tweaks for OS and services"

if [[ $USER != ubuntu ]]; then
    bash -l "$DIR/steps/configure_trusted_sudoers.sh" || exit_with_error "Could not configure trusted groups for sudoers"
fi
$SUDO bash -lx "$DIR/steps/configure_xsup_sudoers_aliases.sh" || exit_with_error "Could not configure sudoers or aliases for xsup"

if [[ $MAGAOX_ROLE == AOC || $MAGAOX_ROLE == ICC || $MAGAOX_ROLE == RTC ]]; then
    log_info "Configure hostname aliases for instrument LAN"
    $SUDO bash -l "$DIR/steps/configure_etc_hosts.sh"
    log_info "Configure NFS exports from RTC -> AOC and ICC -> AOC"
    $SUDO bash -l "$DIR/steps/configure_nfs.sh"
else
    log_info "Configure hostname aliases for VPN"
    $SUDO bash -l "$DIR/steps/configure_etc_hosts_vpn.sh"
fi

if [[ $MAGAOX_ROLE == AOC || $MAGAOX_ROLE == ICC || $MAGAOX_ROLE == RTC || $MAGAOX_ROLE == TOC || $MAGAOX_ROLE == TIC ]]; then
    log_info "Configure time syncing"
    $SUDO bash -l "$DIR/steps/configure_chrony.sh"
fi

if [[ -z $MAGAOX_CONTAINER ]]; then
    log_info "Increase inotify watches (e.g. for VSCode remote users)"
    $SUDO bash -l "$DIR/steps/increase_fs_watcher_limits.sh"
fi

if [[ $MAGAOX_ROLE == AOC ]]; then
    bash -l "$DIR/configure_certificate_renewal.sh"
fi

if [[ $MAGAOX_ROLE == AOC ]]; then
    # Configure a tablespace to store postgres data on the /data array
    # and user accounts for the system to use
    bash -l "$DIR/steps/configure_postgresql.sh"
    # Install and enable the service for grafana
    bash -l "$DIR/steps/install_grafana.sh"
fi
# All MagAO-X computers may use the password to connect to the main db
bash -l "$DIR/steps/configure_postgresql_pass.sh"

if [[ $MAGAOX_ROLE == workstation && $MAGAOX_CONTAINER != 1 ]]; then
    if [[ $VM_KIND != "wsl" ]]; then
        # Enable forwarding MagAO-X GUIs to the host for VMs
        $SUDO bash -l "$DIR/steps/enable_vm_x11_forwarding.sh"
    fi
    # Install a config in ~/.ssh/config for the vm user
    # to make it easier to make tunnels work
    bash -l "$DIR/steps/configure_ssh_for_workstations.sh" || exit_with_error "Failed to pre-populate SSH config"
fi

if [[ $MAGAOX_ROLE == ICC || $MAGAOX_ROLE == RTC || $MAGAOX_ROLE == AOC ]]; then
    echo "export CGROUPS1_CPUSET_MOUNTPOINT=/opt/MagAOX/cpuset" | $SUDO tee /etc/profile.d/cgroups1_cpuset_mountpoint.sh
fi

if [[ $MAGAOX_ROLE == AOC || $MAGAOX_ROLE == RTC || $MAGAOX_ROLE == ICC ]]; then
    $SUDO bash -l "$DIR/steps/add_init_users_data_dir_script.sh" || exit_with_error "Couldn't add /etc/profile.d/init_users_data_dir.sh"
fi

if [[ $MAGAOX_ROLE != "workstation" && "$VM_KIND" == none ]]; then
    $SUDO bash -l "$DIR/steps/configure_vizzy_liveness.sh" || exit_with_error "Couldn't add basic availability monitoring with vizzybot"
fi

## Clone sources to /opt/MagAOX/source/MagAOX unless building in CI or building the container
if [[ -z $CI && ! -e /opt/MagAOX/source/MagAOX ]]; then
    git clone https://github.com/magao-x/MagAOX.git /opt/MagAOX/source/MagAOX || exit_with_error "Could not clone MagAOX"
    normalize_git_checkout /opt/MagAOX/source/MagAOX || exit_with_error "Could not normalize permissions on MagAOX checkout"
fi

## Build the MagAOX instrument software, unless this is a container build or CI process (where we can invoke it as a separate stage)
if [[ -z $CI && "$VM_KIND" != *container* ]]; then
    cd /opt/MagAOX/source/MagAOX
    bash -l "$DIR/steps/install_MagAOX.sh" || exit 1
fi

if [[ "$VM_KIND" == "none" ]]; then
    $SUDO bash -l "$DIR/steps/configure_startup_services.sh"
    log_info "Generating subuid and subgid files, may need to run podman system migrate"
    $SUDO python "$DIR/generate_subuid_subgid.py" || exit_with_error "Generating subuid/subgid files for podman failed"
    $SUDO podman system migrate || exit_with_error "Could not run podman system migrate"
fi

log_success "Provisioning complete"

if [[ $MAGAOX_CONTAINER == 1 ]]; then
    exit 0
elif [[ -z "$(groups | grep magaox)" ]]; then
    log_info "You now need to log out and back in for group changes to take effect"
else
    log_info "You'll probably want to run"
    log_info "    source /etc/profile.d/*.sh"
    log_info "to get all the new environment variables set."
fi

if [[ $MAGAOX_ROLE == AOC || $MAGAOX_ROLE == RTC || $MAGAOX_ROLE == ICC || $MAGAOX_ROLE == COC || $MAGAOX_ROLE == ROC ]]; then
    log_warn "NOTE: MagAO-X computers require secrets, and getting secrets requires manual intervention."
    log_info "See https://github.com/xwcl/hush-hush for documentation."
    log_info "The server public key you will need (/etc/ssh/ssh_host_ed25519_key.pub) is:"
    echo
    log_info "$(cat /etc/ssh/ssh_host_ed25519_key.pub)"
    echo
fi
