#!/usr/bin/env bash
# Build aptly offline bundles (24.04 + 26.04) in one Docker build, then export
# to ../aptly-offline/ and optionally the USB (same as docker compose).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "${SCRIPT_DIR}"

APTLY_USB="${APTLY_USB:-/run/media/ori/USB DISK}"
export APTLY_USB

if [[ "${SKIP_USB:-0}" == 1 ]]; then
  echo "==> Building image and exporting to ../aptly-offline/ (SKIP_USB=1)"
  docker compose run --rm aptly-offline
else
  if [[ ! -d "${APTLY_USB}" ]]; then
    echo "ERROR: USB path is not a directory: ${APTLY_USB}" >&2
    echo "       Mount the stick, set APTLY_USB=..., or use SKIP_USB=1." >&2
    exit 1
  fi
  if [[ ! -w "${APTLY_USB}" ]]; then
    echo "ERROR: USB mount is not writable: ${APTLY_USB}" >&2
    exit 1
  fi
  echo "==> Building image, exporting to ../aptly-offline/ and ${APTLY_USB}/aptly-offline/"
  docker compose --profile usb run --rm aptly-offline-usb
fi

echo "==> Done. Packages under ${SCRIPT_DIR}/../aptly-offline/{24.04,26.04}/"
