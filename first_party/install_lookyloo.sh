#!/bin/bash
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source $DIR/../_common.sh
set -uo pipefail

commit_ish=main
orgname=magao-x
reponame=lookyloo
parentdir=/opt/MagAOX/source
clone_or_update_and_cd $orgname $reponame $parentdir || exit 1
git checkout $commit_ish || exit 1

cd $parentdir/$reponame || exit 1
$SUDO "$CONDA_BASE/envs/${INSTRUMENT_CONDA_ENV}/bin/pip" install -e . || exit_with_error "Could not pip install $reponame"
"$CONDA_BASE/envs/${INSTRUMENT_CONDA_ENV}/bin/lookyloo" -h 2>&1 > /dev/null || exit_with_error "'lookyloo -h' command exited with an error, or was not found"
UNIT_PATH=/etc/systemd/system/
if [[ $MAGAOX_ROLE == AOC ]]; then
    $SUDO cp $DIR/../systemd_units/lookyloo.service $UNIT_PATH/lookyloo.service || exit 1
    log_success "Installed lookyloo.service to $UNIT_PATH"

    $SUDO systemctl daemon-reload || exit 1
    $SUDO systemctl enable lookyloo || exit 1
    log_success "Enabled lookyloo service"
    $SUDO systemctl start lookyloo || exit 1
    log_success "Started lookyloo service"
fi
