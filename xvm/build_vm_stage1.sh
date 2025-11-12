#!/usr/bin/env bash
source ./_common.sh
set -xe
if [[ -e ./output/xvm_stage1.qcow2 ]]; then
    echo "Stage one image populated from cache. Skipping stage one."
    exit 0
fi

# make disk drive image
qemu-img create -f qcow2 output/xvm.qcow2 64G

echo "download firmware for EFI boot"
bash download_firmware.sh

if [[ $vmArch == aarch64 ]]; then
    echo "Using AAVMF (ARM) firmware"
    cp ./input/firmware/usr/share/AAVMF/AAVMF_VARS.fd ./output/firmware_vars.fd
    cp ./input/firmware/usr/share/AAVMF/AAVMF_CODE.fd ./output/firmware_code.fd
else
    echo "Using OVMF (x86_64) firmware"
    cp ./input/firmware/usr/share/edk2/ovmf/OVMF_VARS.fd ./output/firmware_vars.fd
    cp ./input/firmware/usr/share/edk2/ovmf/OVMF_CODE.fd ./output/firmware_code.fd
fi

echo "Starting VM installation process..."
python ./wrap_qemu_stage1.py $qemuSystemCommand \
    -cdrom output/Rocky-${rockyVersion}-${vmArch}-unattended.iso \
    -serial stdio
echo "Created VM and installed Rocky Linux"

echo "Starting up the VM to add users and groups..."
$qemuSystemCommand -serial stdio || exit 1 &
echo "Updating guest repo checkout"
echo "Waiting for VM to become ready..."
sleep 20
updateGuestRepoCheckout
ssh -p 2201 -o "UserKnownHostsFile /dev/null" -o "StrictHostKeyChecking=no" -i ./output/xvm_key xsup@localhost 'bash -s' < ./guest_setup_users_and_groups.sh
# wait for the backgrounded qemu process to exit:
wait
mv -v ./output/xvm.qcow2 ./output/xvm_stage1.qcow2
echo "Finished creating initial Rocky VM"
