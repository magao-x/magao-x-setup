#!/usr/bin/env bash
if [[ -z $vmArch ]]; then
    vmArch=$(uname -m)
fi
ls -lah
mkdir -p ./output/bundle/ || exit 1
mv ./output/xvm.qcow2 ./output/bundle/xvm.qcow2 || exit 1
cp ./output/xvm_key ./output/xvm_key.pub ./output/bundle/ || exit 1
cd ./output/bundle/ || exit 1
ls -lah
tar -cvf - ./* | xz -9 -T0 > ./MagAO-X_VM_${vmArch}.tar.gz || exit 1
