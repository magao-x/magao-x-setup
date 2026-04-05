#!/bin/bash
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source $DIR/../_common.sh
set -xuo pipefail

# Install Grafana
# Check if Grafana is already installed
if ! command -v grafana-server &> /dev/null; then
    # Import Grafana GPG key
    wget -q -O /tmp/gpg.key https://rpm.grafana.com/gpg.key || exit 1
    sudo rpm --import /tmp/gpg.key || exit 1

    # Add Grafana repository
    sudo tee /etc/yum.repos.d/grafana.repo <<EOF || exit 1
[grafana]
name=grafana
baseurl=https://packages.grafana.com/oss/rpm
repo_gpgcheck=1
enabled=1
gpgcheck=1
gpgkey=https://packages.grafana.com/gpg.key
sslverify=1
sslcacert=/etc/pki/tls/certs/ca-bundle.crt
EOF
    # Install Grafana
    sudo dnf --setopt=timeout=300 --setopt=retries=10 -y install grafana || exit 1
    sudo cp /etc/grafana/grafana.ini /etc/grafana/grafana.ini.dist
    sudo cp /etc/grafana/ldap.toml /etc/grafana/ldap.toml.dist
fi

sudo mkdir -p /etc/grafana || exit 1
# If it's running, it will get mad when the permissions change
sudo systemctl stop grafana-server || true  # but if it's not installed yet, no problem

sudo rsync -rtv $DIR/../grafana/ /etc/grafana/
sudo chown -Rv root:grafana /etc/grafana || exit 1
sudo chmod -Rv u=rwX,g=rwX,o= /etc/grafana || exit 1

orgname=magao-x
reponame=dashboards
parentdir=/opt/MagAOX/source/
clone_or_update_and_cd $orgname $reponame $parentdir || exit 1
sudo tee /etc/grafana/grafana.ini <<EOF || exit 1
[paths]
provisioning = /opt/MagAOX/source/MagAOX/setup/grafana
[security]
admin_user = vizzy
admin_password = extremeAO!
[users]
allow_sign_up = false
[auth.anonymous]
enabled = true
[date_formats]
default_timezone = UTC
[auth.ldap]
enabled = true
EOF
sudo tee /etc/grafana/ldap.toml <<EOF || exit 1
[[servers]]
host = "accounts.xwcl.science"
port = 636
use_ssl = true
bind_dn = "cn=%s,ou=people,dc=xwcl,dc=science"
EOF

# Enable Grafana service to start on boot
sudo systemctl enable grafana-server || exit 1

# Start Grafana service
sudo systemctl start grafana-server || exit 1
