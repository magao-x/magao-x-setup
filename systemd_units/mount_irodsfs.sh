#!/usr/bin/env bash
source /root/irods_credentials.env
if [[ -z $IRODSFS_PASSWORD ]]; then
    echo "Missing IRODSFS_PASSWORD in /root/irods_credentials.env"
    exit 1
fi

TARGET_UID=$(getent passwd $UNIX_USER | cut -d: -f3)
TARGET_GID=$(getent group $UNIX_GROUP | cut -d: -f3)

mkdir -pv $IRODSFS_MOUNT
umount $IRODSFS_MOUNT
chown -v $TARGET_UID:$TARGET_GID $IRODSFS_MOUNT
exec irodsfs \
    --allow_other \
    --data_root /run/irodsfs \
    --log_path /run/irodsfs \
    --uid $TARGET_UID \
    --gid $TARGET_GID \
    irods://$IRODSFS_USER:$IRODSFS_PASSWORD@$IRODSFS_HOST:$IRODSFS_PORT$IRODSFS_PATH \
    $IRODSFS_MOUNT \
;