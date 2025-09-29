#!/bin/bash
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source $DIR/../_common.sh
set -uo pipefail

log_info "Make Extra Packages for Enterprise Linux available in /etc/yum.repos.d/"
if ! dnf config-manager -h >/dev/null; then
    dnf install -y 'dnf-command(config-manager)' || exit 1
fi
log_info "Enabling CRB"
dnf config-manager --set-enabled crb || exit 1
log_info "Enabling EPEL repository"
dnf install -y epel-release || exit 1
log_info "Clearing dnf cache"
dnf clean all || exit 1
log_info "Checking dnf for errors"
dnf check || exit 1
log_info "Checking dnf for updates"
dnf check-update
log_info "Updating dnf packages"
dnf update -y || exit 1
log_info "Done updating dnf packages"

# needed for (at least) git:
log_info "Installing Development Tools group"
dnf groupinstall -y 'Development Tools' || exit 1

# Search /usr/local/lib by default for dynamic library loading
echo "/usr/local/lib" | tee /etc/ld.so.conf.d/local.conf || exit 1
ldconfig -v || exit 1

# Install build tools and utilities

if [[ "$VM_KIND" != *container* ]]; then
    log_info "Installing packages not needed in containers"
    # mlocate needs a background service that won't run in a container
    # age is used for secrets management but containers won't ship secrets
    yum install -y \
        kernel-devel \
        kernel-modules-extra \
        mlocate \
        pciutils \
        lm_sensors \
        hddtemp \
        libusb-devel \
        libusbx-devel \
        usbutils \
        age \
    || exit 1
fi
# For some reason (mirror sync?) some packages from EPEL will occasionally fail to install
yum install -y \
    gcc-gfortran \
    which \
    util-linux-user \
    passwd \
    openssh \
    cmake3 \
    vim \
    nano \
    wget \
    htop \
    zlib-devel \
    libudev-devel \
    ncurses-devel \
    nmap-ncat \
    readline-devel \
    pkgconfig \
    bison \
    flex \
    dialog \
    autossh \
    check-devel \
    subunit-devel \
    tmux \
    boost-devel \
    gsl \
    gsl-devel \
    bc \
    chrony \
    gdb \
    yum-utils \
    ntfs-3g \
    screen \
    which \
    sudo \
    sysstat \
    fuse \
    psmisc \
    podman \
    nethogs \
    shadow-utils \
    nfs-utils \
    rsync \
    lapack-devel \
    python \
    fftw \
    fftw-devel \
    fftw-libs \
    fftw-libs-double \
    fftw-libs-single \
    fftw-libs-long \
    fftw-static \
|| exit 1

if [[ $(uname -p) == "x86_64" ]]; then
    yum install -y fftw-libs-quad || exit 1
else
    log_info "libfftw3-quad not available on $(uname -p) host"
fi


# For some reason, pkg-config doesn't automatically look here?
mkdir -p /etc/profile.d/ || exit 1
echo "export PKG_CONFIG_PATH=\${PKG_CONFIG_PATH-}:/usr/local/lib/pkgconfig" > /etc/profile.d/99-pkg-config.sh || exit 1
export PKG_CONFIG_PATH=/usr/local/lib/pkgconfig

if [[ "$VM_KIND" != *container* ]]; then
    dnf config-manager --add-repo https://pkgs.tailscale.com/stable/rhel/9/tailscale.repo -y || exit 1
    dnf install tailscale || exit 1
    systemctl enable --now tailscaled || exit 1
fi

# install postgresql 15 client for RHEL 9
dnf module install -y postgresql:15/client || exit 1

# set up the postgresql server
if [[ $MAGAOX_ROLE == AOC && ! -e /var/lib/pgsql ]]; then
    dnf module install -y postgresql:15/server || exit 1
    postgresql-setup --initdb || exit 1
fi
