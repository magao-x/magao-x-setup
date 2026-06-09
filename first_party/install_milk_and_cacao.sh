#!/bin/bash
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source $DIR/../_common.sh
set -xo pipefail

COMMIT_ISH=magaox
orgname=xwcl
reponame=milk
parentdir=/opt/MagAOX/source
noUpdatesThanks=$parentdir/$reponame/NO_UPDATES_THANKS

export CACAO_REPOSITORY='https://github.com/jaredmales/cacao.git'
export CACAO_BRANCH='magaox'

if [[ -e $noUpdatesThanks ]]; then
  log_info "Lock file at $noUpdatesThanks indicates it's all good, no updates thanks"
  cd $parentdir/$reponame || exit 1
else
  clone_or_update_and_cd $orgname $reponame $parentdir || exit 1
  git checkout $COMMIT_ISH || exit 1
  bash -x ./fetch_cacao_dev.sh || exit 1
fi
$SUDO rm -rf _build src/config.h src/milk_config.h || exit 1
mkdir -p _build || exit 1
cd _build || exit 1

milkCmakeArgs="-DCMAKE_INSTALL_PREFIX=/usr/local -Dbuild_python_module=OFF"

if [[ $MAGAOX_ROLE == TIC || $MAGAOX_ROLE == ICC || $MAGAOX_ROLE == RTC || $MAGAOX_ROLE == AOC ]]; then
    milkCmakeArgs="-DUSE_CUDA=ON ${milkCmakeArgs}"
fi

# Workaround for strictness change in GCC >= 15
export CFLAGS="-std=gnu17 $CFLAGS"
# (set once here, but cached for future builds
# until build dir is recreated and cmake rerun)

cmake .. $milkCmakeArgs || exit 1
make -j$(nproc) || exit 1
$SUDO make install || exit 1

milkSuffix=bin/milk
milkBinary=$(grep -e "${milkSuffix}$" ./install_manifest.txt)
milkPath=${milkBinary/${milkSuffix}/}

if command -v milk; then
    log_warn "Found existing milk binary at $(command -v milk)"
fi
link_if_necessary $milkPath /usr/local/milk || exit 1
echo "/usr/local/milk/lib" | $SUDO tee /etc/ld.so.conf.d/milk.conf || exit 1
$SUDO ldconfig || exit 1
echo "export PATH=\"\$PATH:/usr/local/milk/bin\"" | $SUDO tee /etc/profile.d/milk.sh || exit 1
echo "export PKG_CONFIG_PATH=\$PKG_CONFIG_PATH:/usr/local/milk/lib/pkgconfig" | $SUDO tee -a /etc/profile.d/milk.sh || exit 1
echo "export MILK_SHM_DIR=/milk/shm" | $SUDO tee -a /etc/profile.d/milk.sh || exit 1
echo "export MILK_ROOT=/opt/MagAOX/source/milk" | $SUDO tee -a /etc/profile.d/milk.sh || exit 1
echo "export MILK_INSTALLDIR=/usr/local/milk" | $SUDO tee -a /etc/profile.d/milk.sh || exit 1

$SUDO mkdir -p /milk/shm || exit 1
if [[ "$MAGAOX_ROLE" != ci && "$MAGAOX_ROLE" != container && -z $MAGAOX_CONTAINER ]]; then
  if ! grep -q "/milk/shm" /etc/fstab; then
    echo "tmpfs /milk/shm tmpfs rw,nosuid,nodev,uid=$instrument_user,gid=$instrument_group,mode=3775 0 0" | $SUDO tee -a /etc/fstab || exit 1
    log_success "Created /milk/shm tmpfs mountpoint"
    $SUDO mount /milk/shm || exit 1
    log_success "Mounted /milk/shm"
  else
    log_info "Skipping /milk/shm mount setup because the mount point is present in /etc/fstab already"
  fi
fi
if [[ $MAGAOX_ROLE == ICC || $MAGAOX_ROLE == RTC ]]; then
  clone_or_update_and_cd magao-x "cacao-${MAGAOX_ROLE,,}" /data || exit 1
  link_if_necessary "/data/cacao-${MAGAOX_ROLE,,}" /opt/MagAOX/cacao || exit 1
else
  make_on_data_array "cacao-${MAGAOX_ROLE,,}" /opt/MagAOX || exit 1
  $SUDO ln -sf "/opt/MagAOX/cacao-${MAGAOX_ROLE,,}" /opt/MagAOX/cacao || exit 1
fi
log_info "Making /opt/MagAOX/cacao/ owned by $instrument_user:$instrument_group"
$SUDO chown -R $instrument_user:$instrument_group /opt/MagAOX/cacao/ || exit 1
if [[ $MAGAOX_CONTAINER == 1 ]]; then
    log_info "Try to get some space back..."
    $SUDO rm -rf _build || exit 1
fi
