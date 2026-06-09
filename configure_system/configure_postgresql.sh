#!/usr/bin/env bash
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source $DIR/../_common.sh

# install postgresql
$SUDO dnf install --setopt=timeout=300 --setopt=retries=10 -y postgresql16 postgresql16-server || exit 1

# make sure permissions and SELinux context are correct
$SUDO mkdir -p /var/lib/pgsql
$SUDO /sbin/restorecon -Rv /var/lib/pgsql
$SUDO chown postgres:postgres /var/lib/pgsql
$SUDO chmod u=rwx,g=,o= /var/lib/pgsql

# initialize db, but it's not an error (and we can't detect) if the folder exists
$SUDO postgresql-setup --initdb || log_info "it's not an error, we just can't detect if the folder already exists"

# start postgresql server
$SUDO systemctl enable --now postgresql || exit 1

$SUDO sed -i "s/^#*listen_addresses.*/listen_addresses = '*'/" /var/lib/pgsql/data/postgresql.conf
log_info "Bound to all listen addresses in /var/lib/pgsql/data/postgresql.conf"

if [[ ! -e /var/lib/pgsql/data/pg_hba.conf.dist ]]; then
    $SUDO cp /var/lib/pgsql/data/pg_hba.conf /var/lib/pgsql/data/pg_hba.conf.dist
$SUDO tee /var/lib/pgsql/data/pg_hba.conf <<EOF
# TYPE  DATABASE        USER            ADDRESS                 METHOD

# "local" is for Unix domain socket connections only
local   all             all                                     peer
# IPv4 local connections:
# host    all             all             127.0.0.1/32            scram-sha-256
# IPv6 local connections:
# host    all             all             ::1/128                 scram-sha-256
# Allow replication connections from localhost, by a user with the
# replication privilege.
local   replication     all                                     peer
host    replication     all             127.0.0.1/32            scram-sha-256
host    replication     all             ::1/128                 scram-sha-256
host    all             all             192.168.0.0/16          scram-sha-256
host    all             all             ::1/128                 scram-sha-256
host    all             all             127.0.0.1/32            scram-sha-256
EOF
fi

$SUDO systemctl enable --now postgresql.service || exit_with_error "Could not create/enable postgresql service"
$SUDO systemctl restart postgresql.service || exit_with_error "Could not start postgresql service"

dataArrayPath=/home/data/postgres
bindMountPath=/var/lib/pgsql/extdata
$SUDO mkdir -p $dataArrayPath $bindMountPath || exit_with_error "Could not make $dataArrayPath"
$SUDO chown -R postgres:postgres $dataArrayPath $bindMountPath || exit_with_error "Could not set ownership of $dataArrayPath"
$SUDO chmod u=rwx,g=,o= $dataArrayPath $bindMountPath || exit_with_error "Could not set ownership of $dataArrayPath"

$SUDO tee /etc/systemd/system/var-lib-pgsql-extdata.mount <<EOF
[Unit]
Description=Bind Mount for /var/lib/pgsql/extdata
Before=postgresql.service

[Mount]
What=/home/data/postgres
Where=/var/lib/pgsql/extdata
Type=none
Options=bind

[Install]
WantedBy=multi-user.target
EOF

$SUDO tee /etc/systemd/system/var-lib-pgsql-extdata.automount <<EOF
[Unit]
Description=Automount for /var/lib/pgsql/extdata

[Automount]
Where=/var/lib/pgsql/extdata
TimeoutIdleSec=10

[Install]
WantedBy=multi-user.target
EOF

$SUDO semanage fcontext -a -t postgresql_db_t "${bindMountPath}(/.*)?" || exit_with_error "Could not adjust SELinux context for ${bindMountPath}"
$SUDO restorecon -R ${bindMountPath} || exit_with_error "Could not restorecon the SELinux context on ${bindMountPath}"
$SUDO -u postgres psql < $DIR/../sql/setup_users.sql || exit_with_error "Could not create database users"
$SUDO -u postgres psql -c "CREATE TABLESPACE data_array LOCATION '$bindMountPath'" || true
$SUDO -u postgres psql -c "CREATE DATABASE xtelem WITH OWNER = xtelem TABLESPACE = data_array" || true
$SUDO -u postgres psql < $DIR/../sql/setup_permissions.sql || exit_with_error "Could not grant database permissions"
