#!/usr/bin/env bash
source ./_common.sh
set -xe
if [[ -e ./input/iso/Rocky-${rockyVersion}-${vmArch}-unattended.iso &&
      -e ./output/firmware_vars.fd &&
      -e ./output/firmware_code.fd &&
      -e ./output/xvm_key &&
      -e ./output/xvm_key.pub
]]; then
    echo "Stage 0 populated from cache. Skipping stage 0."
    exit 0
fi
mkdir -p output input

echo "create SSH key and kickstart file"
bash create_kickstart.sh

echo "download ISO and insert kickstart file"
bash download_rocky_iso.sh


du -hs ./input/iso/Rocky-${rockyVersion}-${vmArch}-unattended.iso \
    ./output/xvm_key \
    ./output/xvm_key.pub

echo "Finished creating the unattended Rocky install ISO and SSH keypair"
