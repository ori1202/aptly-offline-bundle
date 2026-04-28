#!/bin/sh
# Copy bundled repository archives to bind-mounted /export (and /usb when mounted).
set -eu

for d in 24.04 26.04; do
  mkdir -p "/export/$d"
  # Clean old files (both .deb and .tar.gz)
  find "/export/$d" -maxdepth 1 \( -name '*.deb' -o -name '*.tar.gz' \) -delete 2>/dev/null || true
  cp -a "/aptly-offline/$d/." "/export/$d/"
done

if [ -d /usb ] && [ -w /usb ]; then
  for d in 24.04 26.04; do
    mkdir -p "/usb/$d"
    # Clean old files (both .deb and .tar.gz)
    find "/usb/$d" -maxdepth 1 \( -name '*.deb' -o -name '*.tar.gz' \) -delete 2>/dev/null || true
    cp -a "/aptly-offline/$d/." "/usb/$d/"
  done
fi
