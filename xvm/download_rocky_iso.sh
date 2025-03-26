#!/usr/bin/env bash
source ./_common.sh
mkdir -p ./input/iso
cd ./input/iso
if [[ ! -e Rocky-9-latest-${vmArch}-minimal.iso ]]; then
    curl --no-progress-meter -f -L https://download.rockylinux.org/pub/rocky/9/isos/${vmArch}/Rocky-9-latest-${vmArch}-minimal.iso > Rocky-9-latest-${vmArch}-minimal.iso.part || exit 1
    mv Rocky-9-latest-${vmArch}-minimal.iso.part Rocky-9-latest-${vmArch}-minimal.iso
    curl --no-progress-meter -f -L https://download.rockylinux.org/pub/rocky/9/isos/${vmArch}/Rocky-9-latest-${vmArch}-minimal.iso.CHECKSUM > Rocky-9-latest-${vmArch}-minimal.iso.CHECKSUM || exit 1
    cat Rocky-9-latest-${vmArch}-minimal.iso.CHECKSUM
    du Rocky-9-latest-${vmArch}-minimal.iso
    sha256sum Rocky-9-latest-${vmArch}-minimal.iso
else
    echo "Rocky Linux ${vmArch} minimal ISO already downloaded."
fi
