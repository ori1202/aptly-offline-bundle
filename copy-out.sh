#!/bin/sh
# Copy bundled .deb trees to bind-mounted /export (and /usb when mounted).
set -eu

for d in 24.04 26.04; do
  mkdir -p "/export/$d"
  find "/export/$d" -maxdepth 1 -name '*.deb' -delete 2>/dev/null || true
  cp -a "/aptly-offline/$d/." "/export/$d/"
done

if [ -d /usb ] && [ -w /usb ]; then
  for d in 24.04 26.04; do
    mkdir -p "/usb/$d"
    find "/usb/$d" -maxdepth 1 -name '*.deb' -delete 2>/dev/null || true
    cp -a "/aptly-offline/$d/." "/usb/$d/"
  done
fi
