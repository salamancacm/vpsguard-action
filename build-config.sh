#!/bin/bash
# Builds a minimal vpsguard config.yaml from the 'hosts'/'ssh-user'/
# 'ssh-port' inputs, for the common case that doesn't need a full
# checked-in config (disabled_checks, thresholds, per-host overrides).
set -euo pipefail

if [ -z "${HOSTS:-}" ]; then
  echo "::error::either the 'hosts' input or the 'config' input must be set"
  exit 1
fi

mkdir -p /tmp/vpsguard-action
config_path=/tmp/vpsguard-action/config.yaml

{
  echo "hosts:"
  IFS=',' read -ra hostlist <<<"$HOSTS"
  for h in "${hostlist[@]}"; do
    # trim whitespace so "a, b, c" and "a,b,c" both work
    h_trimmed="$(echo "$h" | xargs)"
    [ -z "$h_trimmed" ] && continue
    echo "  - name: ${h_trimmed}"
    echo "    addr: ${h_trimmed}"
    echo "    user: ${SSH_USER:-root}"
    echo "    port: ${SSH_PORT:-22}"
  done
} >"$config_path"

echo "VPSGUARD_ACTION_CONFIG=$config_path" >>"$GITHUB_ENV"
