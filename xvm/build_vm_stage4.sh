#!/usr/bin/env bash
echo "Starting up the VM for MagAO-X software installation..."
source ./_common.sh
if [[ -e ./output/xvm_stage4.qcow2 ]]; then
    echo "Stage 4 image populated from cache. Skipping stage 4."
    exit 0
fi
if [[ -e ./output/xvm_stage3.qcow2 ]]; then
    cp ./output/xvm_stage3.qcow2 ./output/xvm.qcow2
elif [[ ! -e ./output/xvm.qcow2 ]]; then
    echo "Neither stage3 vm nor existing output/xvm.qcow2 found"
    exit 1
fi

$qemuSystemCommand &
qemuPid=$!
echo "Updating guest repo checkout"
echo "Waiting for VM to become ready..."
sleep 20
if ! kill -0 $qemuPid 2>/dev/null; then
    echo "Failed - QEMU process exited unexpectedly"
    exit 1
fi
updateGuestRepoCheckout  # since the previous stage VM may be from cache
echo "Install MagAO-X software"
ssh -p $guestPort -o "UserKnownHostsFile /dev/null" -o "StrictHostKeyChecking=no" -i ./output/xvm_key xsup@localhost 'bash -s' < ./guest_install_magao-x_in_vm.sh || exit 1
# need to shut down the VM for script to exit
ssh -p $guestPort -o "UserKnownHostsFile /dev/null" -o "StrictHostKeyChecking=no" -i ./output/xvm_key xsup@localhost 'bash -s' < ./guest_shutdown.sh || exit 1
# wait for the backgrounded qemu process to exit:
wait $qemuPid
echo "Finished installing MagAO-X software."
ls -la ./output
echo "Compressing disk image through QCOW2 to QCOW2 conversion"
qemu-img convert -O qcow2 -c ./output/xvm.qcow2 ./output/xvm_compact.qcow2 || exit 1
du -hs ./output/xvm*
rm -fv ./output/xvm.qcow2 || exit 1
mv -v ./output/xvm_compact.qcow2 ./output/xvm.qcow2 || exit 1
echo "Bundling VM for distribution"
if [[ $vmArch == aarch64 ]]; then
    bash -x bundle_utm.sh || exit 1
else
    bash -x bundle_qcow2.sh || exit 1
fi
ls -la ./output/bundle/
