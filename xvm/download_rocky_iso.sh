#!/usr/bin/env bash
source ./_common.sh
mkdir -p ./input/iso
cd ./input/iso
ISO_FILE=Rocky-9-latest-${vmArch}-minimal.iso
if [[ ! -e ${ISO_FILE} ]]; then
    curl --no-progress-meter -f -L https://download.rockylinux.org/pub/rocky/9/isos/${vmArch}/${ISO_FILE} > ${ISO_FILE}.part || exit 1
    mv ${ISO_FILE}.part ${ISO_FILE}
    curl --no-progress-meter -f -L https://download.rockylinux.org/pub/rocky/9/isos/${vmArch}/${ISO_FILE}.CHECKSUM > ${ISO_FILE}.CHECKSUM || exit 1
    cat ${ISO_FILE}.CHECKSUM
    du ${ISO_FILE}
    if [[ $(uname -o) == Darwin ]]; then
        shasum -a 256 ${ISO_FILE}
    else
        sha256sum ${ISO_FILE}
    fi
else
    echo "Rocky Linux ${vmArch} minimal ISO already downloaded."
fi
../../repack_rocky_iso.sh ./${ISO_FILE}
