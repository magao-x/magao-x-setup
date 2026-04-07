#!/bin/bash
SUDO="${SUDO:-sudo}"
# If not started as root, sudo yourself
if [[ "$EUID" != 0 ]]; then
    $SUDO bash -l $0 "$@"
    exit $?
fi
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
export BUILDING_KERNEL_STUFF=1  # disable loading devtoolset-7 for agreement w/ kernel gcc
source $DIR/../_common.sh
set -uo pipefail
cd /opt/MagAOX/vendor/alpao || exit 1
log_info "Began Alpao install with $(which gcc)"
$SUDO patch -Np2 < alpao_build_fix.patch || true
# option 2 - "Install ASDK and Interface Corp. PEX-292144 support"
echo 2 | $SUDO bash Linux/InstallASDK.sh || exit 1
# The Alpao installer (and PEX sub-installer) doesn't explicitly set permissions on its libs
for libFilename in libgpg2x72c.so.2.2.5 libgpgconf.so.1.5.6 libait_pex292144.so libasdk.so; do
    $SUDO chmod -v u=rwx,g=rx,o=rx /usr/lib/$libFilename || true
    $SUDO chmod -v u=rwx,g=rx,o=rx /usr/lib64/$libFilename || true
done

echo "export ACECFG=/opt/MagAOX/config/alpao" | $SUDO tee /etc/profile.d/alpao.sh || exit 1
log_info "Added /etc/profile.d/alpao.sh"

# Install systemd unit to init alpao on boot
UNIT_PATH=/etc/systemd/system/
cp /opt/MagAOX/config/initialize_alpao.service $UNIT_PATH/initialize_alpao.service || exit 1
$SUDO systemctl enable initialize_alpao || true
log_info "Finished Alpao install"
