#!/bin/bash
set -euo pipefail

POLICY_FILE="$1"
MODULE_NAME="$2"
if [[ -z $POLICY_FILE || -z $MODULE_NAME ]]; then
    echo "Usage: $0 POLICY_FILE MODULE_NAME"
    exit 1
fi

# Compile the .te file into a .mod file
checkmodule -M -m -o ${MODULE_NAME}.mod ${POLICY_FILE}

# Package the .mod file into a .pp module package
semodule_package -o ${MODULE_NAME}.pp -m ${MODULE_NAME}.mod

# Load the module into SELinux
semodule -i ${MODULE_NAME}.pp

echo "SELinux module '${MODULE_NAME}' installed successfully."
