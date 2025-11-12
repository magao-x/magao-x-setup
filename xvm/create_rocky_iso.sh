#!/usr/bin/env bash
set -exuo pipefail
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source $DIR/_common.sh

mkdir -p ./input/iso ./input/kickstart
ISO_FILE=Rocky-9-latest-${vmArch}-minimal.iso
if [[ ! -e ./input/iso/${ISO_FILE} ]]; then
    curl --no-progress-meter -f -L https://download.rockylinux.org/pub/rocky/9/isos/${vmArch}/${ISO_FILE} > ./input/iso/${ISO_FILE}.part || exit 1
    mv ./input/iso/${ISO_FILE}.part ./input/iso/${ISO_FILE}
    du -h ./input/iso/${ISO_FILE}
else
    echo "Rocky Linux ${vmArch} minimal ISO already downloaded."
fi

if [[ ! -e ./input/iso/${ISO_FILE}.CHECKSUM ]]; then
    curl --no-progress-meter -f -L https://download.rockylinux.org/pub/rocky/9/isos/${vmArch}/${ISO_FILE}.CHECKSUM > ./input/iso/${ISO_FILE}.CHECKSUM || exit 1
    cat ./input/iso/${ISO_FILE}.CHECKSUM
    if [[ $(uname -o) == Darwin ]]; then
        shasum -a 256 ./input/iso/${ISO_FILE}
    else
        sha256sum ./input/iso/${ISO_FILE}
    fi
else
    echo "Rocky Linux ${vmArch} minimal ISO checksum already downloaded."
fi


rebuildDest=./input/iso/Rocky-${rockyVersion}-${vmArch}-unattended.iso
rm -f $rebuildDest
echo "Rebuild the ISO so that it includes the kickstart file"
if [[ $(uname -o) == Darwin ]]; then
    podman run \
        -v "${DIR}/:/xvm" \
        -it rockylinux:$rockyVersion \
        bash /xvm/mkksisowrap.sh \
        --ks /xvm/input/kickstart/ks.cfg \
        --cmdline 'inst.cmdline' \
        /xvm/input/iso/${ISO_FILE} \
        /xvm/$rebuildDest
else
    mkksiso \
        --ks ./input/kickstart/ks.cfg \
        --cmdline 'inst.cmdline' \
        ./input/iso/${ISO_FILE} \
        $rebuildDest
fi
du -h $rebuildDest
