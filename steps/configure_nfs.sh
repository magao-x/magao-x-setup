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

if [[ $MAGAOX_ROLE == RTC || $MAGAOX_ROLE == ICC || $MAGAOX_ROLE == AOC || $MAGAOX_ROLE == TIC || $MAGAOX_ROLE == TOC ]]; then
    $SUDO systemctl enable --now $nfsServiceUnit || exit 1
    $SUDO systemctl start $nfsServiceUnit || exit 1

    # /etc/systemd/system/nfs-server.service.d/override.conf
    overridePath="/etc/systemd/system/${nfsServiceUnit}.d/override.conf"
    $SUDO mkdir -p "/etc/systemd/system/${nfsServiceUnit}.d/" || exit 1
    echo -e "[Service]\nTimeoutStopSec=5s" | $SUDO tee $overridePath || exit 1
fi

# MagAO-X only (CACTI below)
if [[ $MAGAOX_ROLE == RTC || $MAGAOX_ROLE == ICC || $MAGAOX_ROLE == AOC ]]; then
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
        echo "$exportDataLine" | $SUDO tee -a /etc/exports || exit 1
        $SUDO exportfs -a || exit 1
        $SUDO systemctl reload $nfsServiceUnit || exit 1
    fi
    if [[ $MAGAOX_ROLE == AOC ]]; then
        exportBackupsLine="/mnt/backup      $exportHosts"
        if ! grep -q "$exportBackupsLine" /etc/exports; then
            echo "$exportBackupsLine" | $SUDO tee -a /etc/exports || exit 1
            $SUDO exportfs -a || exit 1
            $SUDO systemctl reload $nfsServiceUnit || exit 1
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
                $SUDO mkdir -vp $mountPath || exit 1
                if ! grep -q "$mountPath" /etc/fstab; then
                    echo "$host:$hostPath $mountPath	nfs	rw,noauto,x-systemd.automount,nofail,soft,timeo=30	0 0" | $SUDO tee -a /etc/fstab || exit 1
                fi
            fi
        done
    done
    if [[ $MAGAOX_ROLE != AOC ]]; then
        aocHomeMountPath=/home
        $SUDO mkdir -p /srv/aoc/home || exit 1
        if ! grep -q /srv/aoc/home /etc/fstab; then
            echo "aoc:/home $aocHomeMountPath	nfs	rw,noauto,x-systemd.automount,nofail,soft,timeo=30	0 0" | $SUDO tee -a /etc/fstab || exit 1
        fi
    fi
    if [[ $MAGAOX_ROLE != AOC ]]; then
        backupsMountPath=/srv/aoc/mnt/backups
        $SUDO mkdir -p $backupsMountPath || exit 1
        if ! grep -q $backupsMountPath /etc/fstab; then
            echo "aoc:/mnt/backups $backupsMountPath	nfs	ro,noauto,x-systemd.automount,nofail,soft,timeo=30	0 0" | $SUDO tee -a /etc/fstab || exit 1
        fi
    fi
fi
# CACTI
if [[ $MAGAOX_ROLE == TIC || $MAGAOX_ROLE == TOC ]]; then
    exportHosts=""
    for host in tic toc; do
        if [[ ${host,,} != ${MAGAOX_ROLE,,} ]]; then
            exportHosts="$host(rw,sync) $exportHosts"
        fi
    done
    if [[ $MAGAOX_ROLE == TIC ]]; then
        exportDataLine="/home      $exportHosts"
    else
        exportDataLine="/data      $exportHosts"
    fi
    if ! grep -q "$exportDataLine" /etc/exports; then
        echo "$exportDataLine" | $SUDO tee -a /etc/exports || exit 1
        $SUDO exportfs -a || exit 1
        $SUDO systemctl reload $nfsServiceUnit || exit 1
    fi

    # every host mounts the other hosts' data folders
    for host in tic toc; do
        for magaoxSubfolder in cacao logs rawimages telem calib; do
            if [[ ${host,,} != ${MAGAOX_ROLE,,} ]]; then
                if [[ $host == aoc ]]; then
                    hostPath=/home/data/$magaoxSubfolder
                else
                    hostPath=/data/$magaoxSubfolder
                fi
                mountPath=/srv/$host/opt/MagAOX/$magaoxSubfolder
                $SUDO mkdir -vp $mountPath || exit 1
                if ! grep -q "$mountPath" /etc/fstab; then
                    echo "$host:$hostPath $mountPath	nfs	rw,noauto,x-systemd.automount,nofail,soft,timeo=30	0 0" | $SUDO tee -a /etc/fstab || exit 1
                fi
            fi
        done
    done
fi
$SUDO systemctl daemon-reload || exit_with_error "SystemD couldn't reload"
