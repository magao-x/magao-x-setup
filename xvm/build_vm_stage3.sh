#!/usr/bin/env bash
echo "Starting up the VM for MagAO-X software installation..."
source ./_common.sh
if [[ -e ./output/xvm_stage2.qcow2 ]]; then
    cp ./output/xvm_stage2.qcow2 ./output/xvm.qcow2
elif [[ ! -e ./output/xvm.qcow2 ]]; then
    echo "No xvm.qcow2 found for stage 4"
    exit 1
fi

$qemuSystemCommand || exit 1 &
sleep 60
updateGuestRepoCheckout  # since the previous stage VM may be from cache
ssh -p 2201 -o "UserKnownHostsFile /dev/null" -o "StrictHostKeyChecking=no" -i ./output/xvm_key xdev@localhost 'bash -s' < ./guest_install_magao-x_in_vm.sh
# wait for the backgrounded qemu process to exit:
wait
echo "Finished installing MagAO-X software."

echo "Bundling VM for distribution"
bash -x bundle_utm.sh
ls -la ./output/bundle/