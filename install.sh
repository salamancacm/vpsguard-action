#!/bin/bash
# Installs vpsguard onto the CI runner itself (not the audited hosts) so
# the later steps can run `vpsguard fleet`. Mirrors vpsguard's own
# install.sh (checksum-verified, refuses to proceed on a mismatch), with
# added support for pinning a specific version via $VPSGUARD_VERSION.
set -euo pipefail

VERSION="${VPSGUARD_VERSION:-latest}"
REPO="salamancacm/vpsguard"

if [ -n "${VPSGUARD_ACTION_BASE_URL:-}" ]; then
  # Override for testing against a local mirror; real runs always use the
  # default GitHub release URL below.
  BASE_URL="$VPSGUARD_ACTION_BASE_URL"
elif [ "$VERSION" = "latest" ]; then
  BASE_URL="https://github.com/${REPO}/releases/latest/download"
else
  BASE_URL="https://github.com/${REPO}/releases/download/${VERSION}"
fi

arch="$(uname -m)"
case "$arch" in
x86_64 | amd64) arch="amd64" ;;
aarch64 | arm64) arch="arm64" ;;
*)
  echo "::error::no prebuilt vpsguard binary for architecture '$arch'"
  exit 1
  ;;
esac

binary="vpsguard-linux-${arch}"
tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

echo "Downloading ${binary} (${VERSION})..."
curl -fsSL -o "${tmpdir}/${binary}" "${BASE_URL}/${binary}" ||
  { echo "::error::failed to download ${binary} from ${BASE_URL}"; exit 1; }
curl -fsSL -o "${tmpdir}/checksums.txt" "${BASE_URL}/checksums.txt" ||
  { echo "::error::failed to download checksums.txt from ${BASE_URL}"; exit 1; }

expected="$(grep " ${binary}\$" "${tmpdir}/checksums.txt" | awk '{print $1}')"
if [ -z "$expected" ]; then
  echo "::error::no checksum entry found for ${binary} in checksums.txt"
  exit 1
fi

actual="$(sha256sum "${tmpdir}/${binary}" | awk '{print $1}')"
if [ "$expected" != "$actual" ]; then
  echo "::error::checksum mismatch for ${binary} (expected ${expected}, got ${actual})"
  exit 1
fi

chmod +x "${tmpdir}/${binary}"
if [ -w /usr/local/bin ]; then
  mv "${tmpdir}/${binary}" /usr/local/bin/vpsguard
else
  sudo mv "${tmpdir}/${binary}" /usr/local/bin/vpsguard
fi

vpsguard --version
