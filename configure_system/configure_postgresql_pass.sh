#!/usr/bin/env bash
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source $DIR/../_common.sh
if ! $SUDO stat /opt/MagAOX/secrets/xtelemdb_password &> /dev/null; then
    $SUDO rm -f /opt/MagAOX/secrets/xtelemdb_password
    $SUDO touch /opt/MagAOX/secrets/xtelemdb_password
    $SUDO chown xsup:magaox /opt/MagAOX/secrets/xtelemdb_password
    $SUDO chmod u=r,g=,o= /opt/MagAOX/secrets/xtelemdb_password
    echo 'extremeAO!' | $SUDO tee -a /opt/MagAOX/secrets/xtelemdb_password
    log_info "Default xtelem database password written to /opt/MagAOX/secrets. Update and synchronize with other MagAO-X instrument computers."
else
    log_info "/opt/MagAOX/secrets/xtelemdb_password exists, not modifying"
fi
