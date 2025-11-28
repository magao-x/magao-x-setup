#!/usr/bin/env bash
dnf --setopt=timeout=300 --setopt=retries=10 -y install lorax
pwd
exec mkksiso "$@"
