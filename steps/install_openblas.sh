#!/bin/bash
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source $DIR/../_common.sh
set -uo pipefail
cd /opt/MagAOX/vendor || exit 1
source /etc/os-release
log_info "Install OpenBLAS from source"
VERSION=0.3.30
DOWNLOAD_FILE=OpenBLAS-${VERSION}.tar.gz
DOWNLOAD_URL=https://github.com/xianyi/OpenBLAS/releases/download/v${VERSION}/${DOWNLOAD_FILE}
if [[ ! -e $DOWNLOAD_FILE ]]; then
    _cached_fetch $DOWNLOAD_URL $DOWNLOAD_FILE || exit 1
fi
if [[ ! -d ./OpenBLAS-${VERSION} ]]; then
    tar xf $DOWNLOAD_FILE || exit 1
fi
cd ./OpenBLAS-${VERSION} || exit 1
openblasFlags="USE_OPENMP=1"

# Check if this exact version is already installed to skip rebuild
INSTALLED_VER=$(PKG_CONFIG_PATH=/usr/local/lib/pkgconfig${PKG_CONFIG_PATH:+:$PKG_CONFIG_PATH} pkg-config --modversion openblas 2>/dev/null || true)
if [[ "$INSTALLED_VER" == "$VERSION" ]]; then
    log_info "OpenBLAS ${VERSION} already installed, skipping build"
else
  if [[ $VM_KIND != "none" ]]; then
      if [[ $ID == rocky ]]; then
          dnf install --setopt=timeout=300 --setopt=retries=10 -y openblas-devel || exit 1
      elif [[ $ID == ubuntu ]]; then
          make clean
          make $openblasFlags || exit 1
          $SUDO make install PREFIX=/usr/local $openblasFlags || exit 1
      else
          exit_with_error "No idea how to handle VM kind $VM_KIND and distro $ID"
      fi
  else
      make -j$(nproc) $openblasFlags || exit 1
      # ensure same flags get to make install
      $SUDO make install PREFIX=/usr/local $openblasFlags || exit 1
  fi
  log_info "Finished OpenBLAS source install"
fi

# OpenBLAS is built with LAPACK routines included, but does not install a lapack.pc.
# Without one, pkg-config lapack may resolve to a system LAPACK that was built against
# a different OpenBLAS, causing undefined symbol errors at link time.
# Write a lapack.pc that points to this OpenBLAS to get a consistent pair.
OPENBLAS_LIBDIR=$(PKG_CONFIG_PATH=/usr/local/lib/pkgconfig${PKG_CONFIG_PATH:+:$PKG_CONFIG_PATH} pkg-config --variable=libdir openblas 2>/dev/null)
OPENBLAS_LIBDIR="${OPENBLAS_LIBDIR:-/usr/local/lib}"
OPENBLAS_VER=$(PKG_CONFIG_PATH=/usr/local/lib/pkgconfig${PKG_CONFIG_PATH:+:$PKG_CONFIG_PATH} pkg-config --modversion openblas 2>/dev/null || echo "0")
$SUDO mkdir -p "${OPENBLAS_LIBDIR}/pkgconfig"
$SUDO tee "${OPENBLAS_LIBDIR}/pkgconfig/lapack.pc" > /dev/null << EOF
# lapack.pc — provided by OpenBLAS (includes LAPACK routines)
Name: lapack
Description: LAPACK routines provided by OpenBLAS
Version: ${OPENBLAS_VER}
Requires: openblas
Libs:
Cflags:
EOF
log_info "Wrote lapack.pc pointing to OpenBLAS at ${OPENBLAS_LIBDIR}/pkgconfig"
