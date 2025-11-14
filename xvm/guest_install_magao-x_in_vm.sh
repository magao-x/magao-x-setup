#/usr/bin/env bash
set -x
sudo chmod g+w /opt/MagAOX/source
sudo chown :magaox-dev /opt/MagAOX/source
git clone https://github.com/magao-x/MagAOX.git /opt/MagAOX/source/MagAOX
bash -lx ~/magao-x-setup/steps/install_MagAOX.sh || exit 1
# Now, try to compact the VM a bit
sudo dnf clean all -y || exit 1
sudo rm -rf /var/cache/dnf || exit 1
# Remove extra dependencies if any
sudo dnf autoremove -y || exit 1
# Limit total log size
sudo journalctl --vacuum-size=20M || exit 1
# Remove temporary files
sudo rm -rf /tmp/*
sudo rm -rf /var/tmp/*
sudo systemd-tmpfiles --clean
# Remove language translations
sudo find /usr/share/locale -mindepth 1 -maxdepth 1 ! -name 'en*' -print
sudo find /usr/share/locale -mindepth 1 -maxdepth 1 ! -name 'en*' -exec rm -rf {} +
# Make the VM image more compressible
lsblk --discard
echo "Trimming..."
sudo fstrim -av || exit 1
echo "Zeroing..."
sudo dd if=/dev/zero of=/EMPTY bs=1M; sudo rm -f /EMPTY
echo "Trimming..."
sudo fstrim -av || exit 1
