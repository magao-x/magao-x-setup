#!/usr/bin/env bash
echo "Starting up the VM for MagAO-X dependencies installation..."
source ./_common.sh
if [[ -e ./output/xvm_stage1.qcow2 ]]; then
    cp ./output/xvm_stage1.qcow2 ./output/xvm.qcow2
elif [[ ! -e ./output/xvm.qcow2 ]]; then
    echo "No existing xvm.qcow2 found to use in stage 2"
    exit 1
fi
$qemuSystemCommand || exit 1 &
echo "Updating guest repo checkout"
echo "Waiting for VM to become ready..."
sleep 20
updateGuestRepoCheckout  # since the previous stage VM may be from cache
echo "Installing 3rd-party dependencies"
failure=0
ssh -p $guestPort -o "UserKnownHostsFile /dev/null" -o "StrictHostKeyChecking=no" -i ./output/xvm_key xsup@localhost 'bash -s' < ./guest_install_dependencies.sh
if [[ $? != 0 ]]; then
    failure=1
fi
# Regardless of failure, need to shut down the VM for script to exit
ssh -p $guestPort -o "UserKnownHostsFile /dev/null" -o "StrictHostKeyChecking=no" -i ./output/xvm_key xsup@localhost 'bash -s' < ./guest_shutdown.sh
# wait for the backgrounded qemu process to exit:
wait
if [[ $failure != 0 ]]; then
    echo "Failed to install dependencies"
    exit 1
fi
mv -v ./output/xvm.qcow2 ./output/xvm_stage2.qcow2
echo "Finished installing 3rd-party dependencies."
