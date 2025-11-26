#!/usr/bin/env bash
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source $DIR/../_common.sh

# install postgresql
dnf install -y postgresql-server postgresql-contrib || exit 1
# make sure permissions and SELinux context are correct
mkdir -p /var/lib/pgsql
/sbin/restorecon -Rv /var/lib/pgsql
chown postgres:postgres /var/lib/pgsql
chmod u=rwx,g=,o= /var/lib/pgsql
if [[ ! -e /var/lib/pgsql/data ]]; then
    # initialize db
    postgresql-setup --initdb || exit 1
fi
# start postgresql server
systemctl enable --now postgresql || exit 1

sudo sed -i "s/^#*listen_addresses.*/listen_addresses = '*'/" /var/lib/pgsql/data/postgresql.conf
log_info "Bound to all listen addresses in /var/lib/pgsql/data/postgresql.conf"

if [[ ! -e /var/lib/pgsql/data/pg_hba.conf.dist ]]; then
    sudo cp /var/lib/pgsql/data/pg_hba.conf /var/lib/pgsql/data/pg_hba.conf.dist
sudo tee /var/lib/pgsql/data/pg_hba.conf <<EOF
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

sudo systemctl enable --now postgresql.service || exit_with_error "Could not create/enable postgresql service"
sudo systemctl restart postgresql.service || exit_with_error "Could not start postgresql service"

dataArrayPath=/home/data/postgres
bindMountPath=/var/lib/pgsql/extdata
sudo mkdir -p $dataArrayPath $bindMountPath || exit_with_error "Could not make $dataArrayPath"
sudo chown -R postgres:postgres $dataArrayPath $bindMountPath || exit_with_error "Could not set ownership of $dataArrayPath"
sudo chmod u=rwx,g=,o= $dataArrayPath $bindMountPath || exit_with_error "Could not set ownership of $dataArrayPath"

sudo tee /etc/systemd/system/var-lib-pgsql-extdata.mount <<EOF
[Unit]
Description=Bind Mount for /var/lib/pgsql/extdata
Before=postgresql.service

[Mount]
What=/home/data/postgres/tablespace
Where=/var/lib/pgsql/extdata
Type=none
Options=bind

[Install]
WantedBy=multi-user.target

[Service]
ExecStart=/sbin/restorecon -Rv /var/lib/pgsql/extdata
EOF

sudo tee /etc/systemd/system/var-lib-pgsql-extdata.automount <<EOF
[Unit]
Description=Automount for /var/lib/pgsql/extdata

[Automount]
Where=/var/lib/pgsql/extdata
TimeoutIdleSec=10

[Install]
WantedBy=multi-user.target
EOF

sudo semanage fcontext -a -t postgresql_db_t "${bindMountPath}(/.*)?" || exit_with_error "Could not adjust SELinux context for ${bindMountPath}"
sudo restorecon -R ${bindMountPath} || exit_with_error "Could not restorecon the SELinux context on ${bindMountPath}"
sudo -u postgres psql < $DIR/../sql/setup_users.sql || exit_with_error "Could not create database users"
sudo -u postgres psql -c "CREATE TABLESPACE data_array LOCATION '$bindMountPath'" || true
sudo -u postgres psql -c "CREATE DATABASE xtelem WITH OWNER = xtelem TABLESPACE = data_array" || true
sudo -u postgres psql < $DIR/../sql/setup_permissions.sql || exit_with_error "Could not grant database permissions"
