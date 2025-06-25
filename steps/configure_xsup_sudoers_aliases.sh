#!/usr/bin/env bash
if [[ "$EUID" != 0 ]]; then
    sudo -H bash $0 "$@"
    exit $?
fi
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source $DIR/../_common.sh
set -o pipefail

echo "alias teldump='logdump --dir=/opt/MagAOX/telem --ext=.bintel'" | sudo tee /etc/profile.d/teldump.sh
scratchFile=/tmp/sudoers_xsup
targetFile=/etc/sudoers.d/xsup
cat <<'HERE' > $scratchFile
# keep MAGAOX_ROLE set for any sudo'd command
Defaults env_keep += "MAGAOX_ROLE"
# keep entire environment when becoming xsup
Defaults>xsup !env_reset
Defaults>xsup !secure_path
# disable password authentication to become xsup
%magaox ALL = (xsup) NOPASSWD: ALL
%magaox ALL = (root) NOPASSWD: /opt/MagAOX/bin/magaox_pidfile
HERE
visudo -cf $scratchFile || exit_with_error "visudo syntax check failed on $scratchFile"

sudo install \
    --owner=root \
    --group=root \
    --mode=u=r--g=r--o=--- \
    $scratchFile \
    $targetFile \
|| exit_with_error "Could not install drop-in file to $targetFile"


cat <<'HERE' | sudo tee /etc/profile.d/xsupify.sh || exit 1
#!/usr/bin/env bash
alias xsupify="/usr/bin/sudo -u xsup -i"
alias xsupdo="/usr/bin/sudo -u xsup"
HERE