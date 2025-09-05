#!/usr/bin/env bash
echo "Starting up the VM for MagAO-X software installation..."
source ./_common.sh
if [[ -e ./output/xvm_stage3.qcow2 ]]; then
    cp ./output/xvm_stage3.qcow2 ./output/xvm.qcow2
elif [[ ! -e ./output/xvm.qcow2 ]]; then
    echo "Neither stage3 vm nor existing output/xvm.qcow2 found"
    exit 1
fi

$qemuSystemCommand || exit 1 &
echo "Updating guest repo checkout"
echo "Waiting for VM to become ready..."
sleep 20
updateGuestRepoCheckout  # since the previous stage VM may be from cache
echo "Install MagAO-X software"
ssh -p 2201 -o "UserKnownHostsFile /dev/null" -o "StrictHostKeyChecking=no" -i ./output/xvm_key xsup@localhost 'bash -s' < ./guest_install_magao-x_in_vm.sh
# wait for the backgrounded qemu process to exit:
wait
echo "Finished installing MagAO-X software."

echo "Bundling VM for distribution"
bash -x bundle_utm.sh
ls -la ./output/bundle/
