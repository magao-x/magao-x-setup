#!/usr/bin/env bash
source ./_common.sh
set -x
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
$qemuSystemCommand \
    -cdrom output/Rocky-${rockyVersion}-${vmArch}-unattended.iso \
    -serial stdio || exit 1
echo "Created VM and installed Rocky Linux"

echo "Starting up the VM to add users and groups..."
# start up the VM and put it in the background, or exit on error

$qemuSystemCommand -serial stdio &
qemuPid=$!
echo "Updating guest repo checkout"
echo "Waiting for VM to become ready..."
sleep 20
if ! kill -0 $qemuPid 2>/dev/null; then
    echo "Failed - QEMU process exited unexpectedly"
    exit 1
fi
updateGuestRepoCheckout || exit 1
ssh -p $guestPort -o "UserKnownHostsFile /dev/null" -o "StrictHostKeyChecking=no" -i ./output/xvm_key xsup@localhost 'bash -s' < ./guest_setup_users_and_groups.sh || exit 1
# need to shut down the VM for script to exit
ssh -p $guestPort -o "UserKnownHostsFile /dev/null" -o "StrictHostKeyChecking=no" -i ./output/xvm_key xsup@localhost 'bash -s' < ./guest_shutdown.sh || exit 1
# wait for the backgrounded qemu process to exit:
wait $qemuPid
mv -v ./output/xvm.qcow2 ./output/xvm_stage1.qcow2 || exit 1
echo "Finished creating initial Rocky VM"
