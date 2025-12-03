#!/bin/bash
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source $DIR/../_common.sh
set -uo pipefail
source /etc/os-release

if [[ $ID == rocky || $ID == fedora ]]; then
    nfsServiceUnit=nfs-server.service
elif [[ $ID == ubuntu ]]; then
    nfsServiceUnit=nfs-kernel-server.service
else
    exit_with_error "Amend the NFS config script to include the nfsServiceUnit value for $ID"
fi

if [[ $MAGAOX_ROLE == RTC || $MAGAOX_ROLE == ICC || $MAGAOX_ROLE == AOC ]]; then
    sudo systemctl enable --now $nfsServiceUnit || exit 1
    sudo systemctl start $nfsServiceUnit || exit 1
    if command -v ufw; then
        sudo ufw allow from 192.168.0.0/24 to any port nfs || exit 1
    fi
    # /etc/systemd/system/nfs-server.service.d/override.conf
    overridePath="/etc/systemd/system/${nfsServiceUnit}.d/override.conf"
    sudo mkdir -p "/etc/systemd/system/${nfsServiceUnit}.d/" || exit 1
    echo -e "[Service]\nTimeoutStopSec=5s" | sudo tee $overridePath || exit 1
    exportHosts=""
    for host in aoc rtc icc; do
        if [[ ${host,,} != ${MAGAOX_ROLE,,} ]]; then
            exportHosts="$host(rw,sync) $exportHosts"
        fi
    done
    if [[ $MAGAOX_ROLE == AOC ]]; then
        exportDataLine="/home      $exportHosts"
    else
        exportDataLine="/data      $exportHosts"
    fi
    if ! grep -q "$exportDataLine" /etc/exports; then
        echo "$exportDataLine" | sudo tee -a /etc/exports || exit 1
        sudo exportfs -a || exit 1
        sudo systemctl reload $nfsServiceUnit || exit 1
    fi
    if [[ $MAGAOX_ROLE == AOC ]]; then
        exportBackupsLine="/mnt/backup      $exportHosts"
        if ! grep -q "$exportBackupsLine" /etc/exports; then
            echo "$exportBackupsLine" | sudo tee -a /etc/exports || exit 1
            sudo exportfs -a || exit 1
            sudo systemctl reload $nfsServiceUnit || exit 1
        fi
    fi

    # every host mounts the other two hosts' MagAO-X data folders
    for host in aoc rtc icc; do
        for magaoxSubfolder in cacao logs rawimages telem calib; do
            if [[ ${host,,} != ${MAGAOX_ROLE,,} ]]; then

                if [[ $host == aoc ]]; then
                    hostPath=/home/data/$magaoxSubfolder
                else
                    hostPath=/data/$magaoxSubfolder
                fi
                mountPath=/srv/$host/opt/MagAOX/$magaoxSubfolder
                sudo mkdir -vp $mountPath || exit 1
                if ! grep -q "$mountPath" /etc/fstab; then
                    echo "$host:$hostPath $mountPath	nfs	rw,noauto,x-systemd.automount,nofail,x-systemd.device-timeout=10s,soft,timeo=30	0 0" | sudo tee -a /etc/fstab || exit 1
                fi
            fi
        done
    done
    if [[ $MAGAOX_ROLE != AOC ]]; then
        aocHomeMountPath=/home
        sudo mkdir -p /srv/aoc/home || exit 1
        if ! grep -q /srv/aoc/home /etc/fstab; then
            echo "aoc:/home $aocHomeMountPath	nfs	rw,noauto,x-systemd.automount,nofail,x-systemd.device-timeout=10s,soft,timeo=30	0 0" | sudo tee -a /etc/fstab || exit 1
        fi
    fi
    if [[ $MAGAOX_ROLE != AOC ]]; then
        backupsMountPath=/srv/aoc/mnt/backups
        sudo mkdir -p $backupsMountPath || exit 1
        if ! grep -q $backupsMountPath /etc/fstab; then
            echo "aoc:/mnt/backups $backupsMountPath	nfs	ro,noauto,x-systemd.automount,nofail,x-systemd.device-timeout=10s,soft,timeo=30	0 0" | sudo tee -a /etc/fstab || exit 1
        fi
    fi
fi
sudo systemctl daemon-reload || exit_with_error "SystemD couldn't reload"
