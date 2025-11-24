#!/bin/bash
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source $DIR/../_common.sh
set -uo pipefail

# needed for (at least) git:
dnf group install -y development-tools || exit 1

# Search /usr/local/lib by default for dynamic library loading
echo "/usr/local/lib" | tee /etc/ld.so.conf.d/local.conf || exit 1
ldconfig -v || exit 1

# Install build tools and utilities
dnf install -y \
    util-linux-user \
    kernel-devel \
    kernel-modules-extra \
    gcc-gfortran \
    gcc-g++ \
    which \
    openssh \
    cmake3 \
    vim \
    nano \
    wget \
    plocate \
    htop \
    zlib-devel \
    libudev-devel \
    ncurses-devel \
    nmap-ncat \
    lm_sensors \
    hddtemp \
    readline-devel \
    pkgconfig \
    bison \
    flex \
    dialog \
    autossh \
    check-devel \
    subunit-devel \
    pciutils \
    libusb-compat-0.1-devel \
    libusbx-devel \
    usbutils \
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
    strace \
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
    flexiblas-openblas-serial \
    age \
|| exit 1

if [[ $(uname -m) == "x86_64" ]]; then
    yum install -y fftw-libs-quad || exit 1
else
    log_info "libfftw3-quad not available on $(uname -m) host"
fi


# For some reason, pkg-config doesn't automatically look here?
mkdir -p /etc/profile.d/ || exit 1
echo "export PKG_CONFIG_PATH=\${PKG_CONFIG_PATH-}:/usr/local/lib/pkgconfig" > /etc/profile.d/99-pkg-config.sh || exit 1
export PKG_CONFIG_PATH=/usr/local/lib/pkgconfig

if [[ $MAGAOX_ROLE == TIC || $MAGAOX_ROLE == TOC || $MAGAOX_ROLE == ICC || $MAGAOX_ROLE == RTC || $MAGAOX_ROLE == AOC ]]; then
    if ! command -v tailscale; then
        dnf config-manager addrepo --from-repofile=https://pkgs.tailscale.com/stable/fedora/tailscale.repo || exit 1
        dnf install -y tailscale || exit 1
        systemctl enable --now tailscaled || exit 1
    fi
fi

# set up the postgresql server
if [[ $MAGAOX_ROLE == AOC && ! -e /var/lib/pgsql ]]; then
    # install postgresql
    dnf install -y postgresql-server postgresql-contrib || exit 1
    systemctl enable --now postgresql || exit 1
    postgresql-setup --initdb --unit postgresql  || exit 1
fi
