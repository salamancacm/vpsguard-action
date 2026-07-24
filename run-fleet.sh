#!/bin/bash
# Runs 'vpsguard fleet', writes a job summary, sets outputs, and fails the
# job per the 'fail-on' input. Requires jq (preinstalled on GitHub-hosted
# runners; self-hosted runners need it too).
set -euo pipefail

if [ -n "${CONFIG_PATH:-}" ]; then
  config="${GITHUB_WORKSPACE}/${CONFIG_PATH}"
else
  config="${VPSGUARD_ACTION_CONFIG:-/tmp/vpsguard-action/config.yaml}"
fi

echo "Using config: $config"

results=/tmp/vpsguard-action/results.json
set +e
vpsguard fleet --config "$config" --json >"$results"
set -e

# Human-readable copy in the log too, for anyone reading the run directly.
vpsguard fleet --config "$config" || true

crit=$(jq '[.[].findings[]? | select(.severity=="CRIT")] | length' "$results")
warn=$(jq '[.[].findings[]? | select(.severity=="WARN")] | length' "$results")
unreachable=$(jq '[.[] | select(.error != null)] | length' "$results")

{
  echo "crit-count=$crit"
  echo "warn-count=$warn"
  echo "unreachable-count=$unreachable"
} >>"$GITHUB_OUTPUT"

{
  echo "## vpsguard fleet audit"
  echo ""
  echo "| Metric | Count |"
  echo "|---|---|"
  echo "| CRIT | $crit |"
  echo "| WARN | $warn |"
  echo "| Unreachable hosts | $unreachable |"
} >>"$GITHUB_STEP_SUMMARY"

case "${FAIL_ON:-CRIT}" in
CRIT)
  if [ "$crit" -gt 0 ]; then
    echo "::error::vpsguard found $crit CRIT finding(s)"
    exit 1
  fi
  ;;
WARN)
  if [ "$crit" -gt 0 ] || [ "$warn" -gt 0 ]; then
    echo "::error::vpsguard found $crit CRIT and $warn WARN finding(s)"
    exit 1
  fi
  ;;
NONE) ;;
*)
  echo "::error::invalid fail-on value '${FAIL_ON}' (expected CRIT, WARN, or NONE)"
  exit 1
  ;;
esac
