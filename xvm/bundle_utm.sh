#!/usr/bin/env bash
if [[ -z $vmArch ]]; then
    vmArch=$(uname -m)
fi
ls -lah
mkdir -p ./output/bundle/
ls -R ./utm
cp -vR ./utm ./output/bundle/MagAO-X.utm
ls -R ./output/bundle/MagAO-X.utm
mv ./output/xvm.qcow2 ./output/bundle/MagAO-X.utm/Data/xvm.qcow2
cp ./output/xvm_key ./output/xvm_key.pub ./output/bundle/
cd ./output/bundle/
if [[ $(uname -o) == Darwin ]]; then
    nCpu=$(sysctl -n hw.ncpu)
else
    nCpu=$(nproc)
fi
tar -cvf - ./* | pigz -7 -p $nCpu > ./MagAO-X_UTM_${vmArch}.tar.gz
