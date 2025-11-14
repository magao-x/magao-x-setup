#!/usr/bin/env bash
echo "Starting up the VM for MagAO-X dependencies installation..."
source ./_common.sh
if [[ -e ./output/xvm_stage2.qcow2 ]]; then
    echo "Stage 2 image populated from cache. Skipping stage 2."
    exit 0
fi
if [[ -e ./output/xvm_stage1.qcow2 ]]; then
    if [[ -z $CI ]]; then
        cp ./output/xvm_stage1.qcow2 ./output/xvm.qcow2
    else
        mv ./output/xvm_stage1.qcow2 ./output/xvm.qcow2
    fi
elif [[ ! -e ./output/xvm.qcow2 ]]; then
    echo "No existing xvm.qcow2 found to use in stage 2"
    exit 1
fi
$qemuSystemCommand &
qemuPid=$?
echo "Updating guest repo checkout"
echo "Waiting for VM to become ready..."
sleep 20
if ! kill -0 $qemuPid 2>/dev/null; then
    echo "Failed - QEMU process exited unexpectedly"
    exit 1
fi
updateGuestRepoCheckout  # since the previous stage VM may be from cache
echo "Installing 3rd-party dependencies"
ssh -p $guestPort -o "UserKnownHostsFile /dev/null" -o "StrictHostKeyChecking=no" -i ./output/xvm_key xsup@localhost 'bash -s' < ./guest_install_dependencies.sh || exit 1
# need to shut down the VM for script to exit
ssh -p $guestPort -o "UserKnownHostsFile /dev/null" -o "StrictHostKeyChecking=no" -i ./output/xvm_key xsup@localhost 'bash -s' < ./guest_shutdown.sh || exit 1
# wait for the backgrounded qemu process to exit:
wait $qemuPid
mv -v ./output/xvm.qcow2 ./output/xvm_stage2.qcow2
echo "Finished installing 3rd-party dependencies."
