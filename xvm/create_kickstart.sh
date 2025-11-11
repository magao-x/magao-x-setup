#!/usr/bin/env bash
set -euo pipefail
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source $DIR/_common.sh

mkdir -p input/kickstart input/oemdrv output

echo "Generating SSH key pair for local SSH login to VM"
if [[ ! -e ./output/xvm_key ]]; then
    ssh-keygen -q -t ed25519 -f ./output/xvm_key -N '' -C 'xvm'
fi

echo "Make our new key accessible within the installer"
cp ./output/xvm_key.pub ./input/oemdrv/authorized_keys

echo "Remove and recreate oemdrv (in case key is new)"
rm -fv ./input/oemdrv.{dmg,qcow2}

echo "Generate kickstart (./input/kickstart/ks.cfg) from template"
cat ./kickstart/ks.cfg.template | envsubst '$vmArch $rockyVersion' > ./input/kickstart/ks.cfg

if [[ $(uname) == "Darwin" ]]; then
    hdiutil create -srcfolder ./input/oemdrv -format UDRO -volname "OEMDRV" -fs "MS-DOS FAT32" ./input/oemdrv.dmg
    qemu-img convert -f dmg -O qcow2 ./input/oemdrv.dmg ./input/oemdrv.qcow2
else
    qemu-img create -f raw oemdrv.img 10M
    sudo parted oemdrv.img --script -- mklabel msdos
    sudo parted oemdrv.img --script -- mkpart primary fat32 1MiB 100%
    sudo mkfs.fat -n OEMDRV -F 32 oemdrv.img
    sudo mkdir -p /mnt/oemdrv
    sudo mount -o loop oemdrv.img /mnt/oemdrv
    sudo cp -R ./input/kickstart/* /mnt/oemdrv/
    sudo umount /mnt/oemdrv
    qemu-img convert -f raw -O qcow2 oemdrv.img ./input/oemdrv.qcow2
fi
