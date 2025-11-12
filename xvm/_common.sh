#!/usr/bin/env bash
if [[ -z $vmArch ]]; then
    echo "Set vmArch environment variable to aarch64 or x86_64"
    exit 1
fi
if [[ $vmArch == "aarch64" && $(uname -m) == "arm" ]]; then
    qemuMachineFlags="-machine type=virt,highmem=on -cpu host"
elif [[ $vmArch == "aarch64" ]]; then
    qemuMachineFlags="-machine type=virt -cpu max"
elif [[ $vmArch == "x86_64" && $(uname -m) == "x86_64" && -z $CI ]]; then
    qemuMachineFlags="-machine q35 -cpu host"
elif [[ $vmArch == "x86_64" ]]; then
    qemuMachineFlags="-machine q35 -cpu max"
else
    qemuMachineFlags="-machine type=virt -cpu max"
fi
export qemuMachineFlags

qemuDisplay=${qemuDisplay:-}
if [[ ! -z $qemuDisplay ]]; then
    ioFlag="-display $qemuDisplay -serial vc"
else
    ioFlag='-display none'
fi
export ioFlag

# nproc is unavailable on macOS, but GitHub Actions macOS ARM
# runners have 3 CPUs visible so that's as good a default
# as any
nCpus=$(nproc 2>/dev/null || echo '3')
ramMB=8192

#
if [[ -n "$CI" ]]; then
    guestPort=$(python -c 'import socket; s=socket.socket(); s.bind(("", 0)); print(s.getsockname()[1]); s.close()')
else
    guestPort=2201
fi

if [[ -n "$CI" ]]; then
    qemuAccelFlags="-accel tcg,thread=multi"
else
    qemuAccelFlags="-accel kvm -accel hvf -accel tcg,thread=multi"
fi

if [[ $vmArch == aarch64 ]]; then
    qemuSystemCommand="qemu-system-${vmArch} \
        -name xvm \
        -netdev user,id=user.0,hostfwd=tcp::${guestPort}-:22 \
        -smp $nCpus \
        $qemuAccelFlags \
        $qemuMachineFlags \
        -drive if=pflash,format=raw,id=ovmf_code,readonly=on,file=./output/firmware_code.fd \
        -drive if=pflash,format=raw,id=ovmf_vars,file=./output/firmware_vars.fd \
        -drive file=output/xvm.qcow2,format=qcow2 \
        -device virtio-gpu-pci \
        -device virtio-net-pci,netdev=user.0 \
        -device qemu-xhci \
        -device usb-kbd \
        -device usb-mouse \
        -m ${ramMB}M \
        $ioFlag "
elif [[ $vmArch == x86_64 ]]; then
    qemuSystemCommand="qemu-system-${vmArch} \
        -name xvm \
        -netdev user,id=user.0,hostfwd=tcp::${guestPort}-:22 \
        -smp $nCpus \
        $qemuAccelFlags \
        $qemuMachineFlags \
        -drive file=output/xvm.qcow2,format=qcow2 \
        -device virtio-net-pci,netdev=user.0 \
        -m ${ramMB}M \
        $ioFlag "
else
    echo 'set $vmArch'
    exit 1
fi
export qemuSystemCommand

export rockyVersion=${rockyVersion:-9.6}

function updateGuestRepoCheckout() {
    echo "Syncing repo in guest..."
    count=0
    success=0
    while [ "$count" -lt 10 ]; do
        rsync \
            --progress -a --exclude xvm/output --exclude xvm/input \
            --exclude .git \
            -e "ssh -p ${guestPort} -o 'UserKnownHostsFile /dev/null' -o 'StrictHostKeyChecking=no' -i ./output/xvm_key" \
            ../ xsup@localhost:magao-x-setup/ \
            && success=1 && break
        ((count++))
        echo "Retrying in 10 sec..."
        sleep 10
    done
    if [ "$success" -eq 0 ]; then
        echo "Failed to rsync the updated setup scripts into the guest VM"
        exit 1
    else
        echo "Finished updating checkout in guest"
    fi
}
