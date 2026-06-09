#!/usr/bin/env bash
set -o pipefail
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source "$DIR/../_common.sh"

roleScript=/etc/profile.d/magaox_role.sh

if [[ ! -e $roleScript && ! -z $MAGAOX_ROLE ]]; then
    echo "export MAGAOX_ROLE=$MAGAOX_ROLE" | $_REAL_SUDO tee $roleScript
fi
if [[ ! -e $roleScript ]]; then
    echo "Export \$MAGAOX_ROLE in $roleScript first"
    exit 1
fi
source $roleScript
echo "Got MAGAOX_ROLE=$MAGAOX_ROLE"
export MAGAOX_ROLE
if [[ $VM_KIND != "container" ]]; then
    currentHostname=$(hostnamectl hostname)
    if [[ $MAGAOX_ROLE == AOC && $currentHostname != exao1 ]]; then
        exit_with_error "Configure the correct hostname for AOC"
    elif [[ $MAGAOX_ROLE == RTC && $currentHostname != exao2 ]]; then
        exit_with_error "Configure the correct hostname for RTC"
    elif [[ $MAGAOX_ROLE == ICC && $currentHostname != exao3 ]]; then
        exit_with_error "Configure the correct hostname for ICC"
    fi
fi



VENDOR_SOFTWARE_BUNDLE=$DIR/../third_party_proprietary/bundle.zip
if [[ ! -e $VENDOR_SOFTWARE_BUNDLE ]]; then
    echo "Couldn't find vendor software bundle at location $(realpath $VENDOR_SOFTWARE_BUNDLE)"
    if [[ $MAGAOX_ROLE == RTC || $MAGAOX_ROLE == ICC ]]; then
        log_warn "If this instrument computer will be interfacing with the DMs or framegrabbers, you should Ctrl-C now and get the software bundle."
        read -p "If not, press enter to continue"
    fi
fi


## Install proprietary / non-public software
if [[ -e $VENDOR_SOFTWARE_BUNDLE ]]; then
    # Extract bundle
    BUNDLE_TMPDIR=/tmp/vendor_software_bundle_$(date +"%s")
    $SUDO mkdir -p $BUNDLE_TMPDIR
    $SUDO unzip -o $VENDOR_SOFTWARE_BUNDLE -d $BUNDLE_TMPDIR
    for vendorname in  alpao andor bmc libhsfw qhyccd teledyne; do
        if [[ ! -d /opt/MagAOX/vendor/$vendorname ]]; then
            $SUDO cp -R $BUNDLE_TMPDIR/bundle/$vendorname /opt/MagAOX/vendor
        else
            echo "/opt/MagAOX/vendor/$vendorname exists, not overwriting files"
            echo "(but they're in $BUNDLE_TMPDIR/bundle/$vendorname if you want them)"
        fi
    done

    if [[ $MAGAOX_ROLE == RTC ]]; then
        $SUDO bash -l "$DIR/../third_party_proprietary/install_alpao.sh" || exit_with_error "Failed to install Alpao software"
    fi
    if [[ $MAGAOX_ROLE == RTC || $MAGAOX_ROLE == TIC ]]; then
        $SUDO bash -l "$DIR/../third_party_proprietary/install_bmc.sh" || exit_with_error "Failed to install BMC software"
    fi
    if [[ $MAGAOX_ROLE == ICC || $MAGAOX_ROLE == RTC ]]; then
        $SUDO bash -l "$DIR/../third_party_proprietary/install_libhsfw.sh" || exit_with_error "Failed to install libhsfw"
    fi
    if [[ $MAGAOX_ROLE == ICC ]]; then
        $SUDO bash -l "$DIR/../third_party_proprietary/install_picam.sh" || exit_with_error "Failed to install picam"
        $SUDO bash -l "$DIR/../third_party_proprietary/install_pvcam.sh" || exit_with_error "Failed to install pvcam"
    fi
    $SUDO rm -rf $BUNDLE_TMPDIR
fi

# These steps should work as whatever user is installing, provided
# they are a member of magaox-dev and they have sudo access to install to
# /usr/local. Building as root would leave intermediate build products
# owned by root, which we probably don't want.
cd /opt/MagAOX/source

# Install first-party deps
bash -l "$DIR/../first_party/install_milk_and_cacao.sh" || exit_with_error "milk/cacao install failed"
bash -l "$DIR/../first_party/install_xrif.sh" || exit_with_error "Failed to build and install xrif"
bash -l "$DIR/../first_party/install_milkzmq.sh" || exit_with_error "milkzmq install failed"
bash -l "$DIR/../first_party/install_mxlib.sh" || exit_with_error "Failed to build and install mxlib"

# install Python libs that need special treatment (ordered after MILK so ImageStreamIO can be built)
$SUDO bash -l "$DIR/../first_party/create_instrument_conda_env.sh" || exit_with_error "Couldn't install libraries in Python env"
