#!/usr/bin/env bash
source ./_common.sh
set -xe
if [[ -e ./output/xvm_stage1.qcow2 ]]; then
    echo "Stage one image populated from cache. Skipping stage one."
    exit 0
fi
mkdir -p output input
# make disk drive image
qemu-img create -f qcow2 output/xvm.qcow2 64G
# make ssh key pair
if [[ ! -e ./output/xvm_key ]]; then
    ssh-keygen -q -t ed25519 -f ./output/xvm_key -N '' -C 'xvm'
fi
# create oemdrv disk image for kickstart files and key
bash create_oemdrv.sh
bash download_rocky_iso.sh
bash download_firmware.sh

if [[ $vmArch == aarch64 ]]; then
    cp ./input/firmware/usr/share/AAVMF/AAVMF_VARS.fd ./output/firmware_vars.fd
    cp ./input/firmware/usr/share/AAVMF/AAVMF_CODE.fd ./output/firmware_code.fd
else
    cp ./input/firmware/usr/share/edk2/ovmf/OVMF_VARS.fd ./output/firmware_vars.fd
    cp ./input/firmware/usr/share/edk2/ovmf/OVMF_CODE.fd ./output/firmware_code.fd
fi

echo "Starting VM installation process..."
python wrap_qemu_stage1.py $qemuSystemCommand \
    -cdrom ./input/iso/Rocky-9-latest-${vmArch}-minimal.iso \
    -drive file=input/oemdrv.qcow2,format=qcow2 \
    -serial stdio
echo "Created VM and installed Rocky Linux"

echo "Starting up the VM for MagAO-X 3rd party dependencies installation..."
$qemuSystemCommand -serial stdio || exit 1 &
sleep 60
updateGuestRepoCheckout
ssh -p 2201 -o "UserKnownHostsFile /dev/null" -o "StrictHostKeyChecking=no" -i ./output/xvm_key xsup@localhost 'bash -s' < ./guest_install_dependencies.sh
# wait for the backgrounded qemu process to exit:
wait
mv -v ./output/xvm.qcow2 ./output/xvm_stage1.qcow2
echo "Finished installing MagAO-X dependencies."
