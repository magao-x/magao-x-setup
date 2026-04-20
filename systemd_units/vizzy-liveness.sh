#!/usr/bin/env bash
set -euo pipefail

uptime=$(cut -d' ' -f1 /proc/uptime)
hostname=$(hostname)

curl -X POST \
  -H "Content-Type: application/json" \
  -d "{\"hostname\": \"${hostname}\", \"uptime\": ${uptime}}" \
  https://vizzy.xwcl.science/api/liveness
