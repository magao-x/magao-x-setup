#!/usr/bin/env bash
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source $DIR/../_common.sh
set -uo pipefail
mkdir -p /opt/MagAOX/vendor/irodsfs
cd /opt/MagAOX/vendor/irodsfs || exit 1
IRODSFS_VERSION="v0.12.3"
PREFIX=/opt/irodsfs
if [[ ! -e ./irodsfs ]]; then
    _cached_fetch https://github.com/cyverse/irodsfs/releases/download/$IRODSFS_VERSION/irodsfs-$IRODSFS_VERSION-linux-amd64.tar.gz irodsfs-$IRODSFS_VERSION-linux-amd64.tar.gz
    tar xzf irodsfs-$IRODSFS_VERSION-linux-amd64.tar.gz || exit 1
fi
sudo umount /srv/cyverse
sudo mkdir -p $PREFIX/bin $PREFIX/etc || exit 1
sudo install ./irodsfs $PREFIX/bin/irodsfs || exit 1
sudo install -m 600 $DIR/../systemd_units/mount_irodsfs.service /etc/systemd/system/mount_irodsfs.service || exit 1
sudo install -m 700 $DIR/../systemd_units/mount_irodsfs.sh $PREFIX/bin/mount_irodsfs.sh || exit 1

CREDS_FILE=/root/irods_credentials.env
if sudo test -e $CREDS_FILE; then
    log_info "Making a template credentials file in $CREDS_FILE"
    cat <<'HERE' | sudo tee $CREDS_FILE || exit 1
IRODSFS_USER=exao_dap
IRODSFS_PASSWORD=
IRODSFS_HOST=data.cyverse.org
IRODSFS_PORT=1247
IRODSFS_PATH=/iplant/home/exao_dap
IRODSFS_MOUNT=/srv/cyverse
UNIX_USER=xbackup
UNIX_GROUP=magaox
HERE
    log_info "Don't forget to fill in IRODSFS_PASSWORD!"
else
    log_info "$CREDS_FILE already exists, not overwriting"
fi
sudo chmod -v 0600 $CREDS_FILE
sudo chown -v root:root $CREDS_FILE
sudo systemctl daemon-reload
sudo systemctl enable mount_irodsfs.service
