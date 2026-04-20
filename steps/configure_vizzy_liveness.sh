#!/usr/bin/env bash
SUDO="${SUDO:-sudo}"
if [[ "$EUID" != 0 ]]; then
    $SUDO bash $0 "$@"
    exit $?
fi
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source $DIR/../_common.sh

UNIT_PATH=/etc/systemd/system
for service_unit in vizzy-liveness.service vizzy-liveness.timer vizzy-notify-power-state.service; do
    cp -v $DIR/../systemd_units/$service_unit $UNIT_PATH/$service_unit || exit 1
    log_success "Installed $service_unit to $UNIT_PATH"
    systemctl daemon-reload || exit 1
    systemctl enable --now $service_unit || true
done

cp -v $DIR/../systemd_units/vizzy-liveness.sh /usr/local/bin/
chmod u=rwx,g=rx,o=rx /usr/local/bin/vizzy-liveness.sh
