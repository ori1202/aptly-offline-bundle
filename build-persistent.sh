#!/bin/bash
set -euo pipefail

UBUNTU_TAG="${UBUNTU_TAG:-24.04}"

echo "==> Starting aptly build with persistent storage (${UBUNTU_TAG})"
echo "==> Aptly workspace: /root/.aptly (mounted from host)"

# Determine distribution name based on tag
if [[ "$UBUNTU_TAG" == "24.04"* ]]; then
    DIST="noble"
elif [[ "$UBUNTU_TAG" == "26.04"* ]]; then
    DIST="resolute"
else
    DIST="noble"  # fallback
fi

echo "==> Building for Ubuntu $UBUNTU_TAG ($DIST)"

# Create mirrors (only if they don't exist)
echo "==> Creating mirrors..."
aptly mirror list | grep "${DIST}-main" || aptly mirror create -architectures=amd64 ${DIST}-main http://archive.ubuntu.com/ubuntu ${DIST} main
aptly mirror list | grep "${DIST}-universe" || aptly mirror create -architectures=amd64 ${DIST}-universe http://archive.ubuntu.com/ubuntu ${DIST} universe
aptly mirror list | grep "${DIST}-security-main" || aptly mirror create -architectures=amd64 ${DIST}-security-main http://security.ubuntu.com/ubuntu ${DIST}-security main
aptly mirror list | grep "${DIST}-security-universe" || aptly mirror create -architectures=amd64 ${DIST}-security-universe http://security.ubuntu.com/ubuntu ${DIST}-security universe

# Update mirrors (resume if interrupted)
echo "==> Updating ${DIST}-main..."
aptly mirror update ${DIST}-main
echo "==> Updating ${DIST}-universe..."
aptly mirror update ${DIST}-universe
echo "==> Updating ${DIST}-security-main..."
aptly mirror update ${DIST}-security-main
echo "==> Updating ${DIST}-security-universe..."
aptly mirror update ${DIST}-security-universe

# Create snapshots
echo "==> Creating snapshots..."
aptly snapshot create ${DIST}-main-snap from mirror ${DIST}-main
aptly snapshot create ${DIST}-universe-snap from mirror ${DIST}-universe
aptly snapshot create ${DIST}-security-main-snap from mirror ${DIST}-security-main
aptly snapshot create ${DIST}-security-universe-snap from mirror ${DIST}-security-universe

# Merge and publish
echo "==> Merging snapshots..."
aptly snapshot merge ${DIST}-merged ${DIST}-main-snap ${DIST}-universe-snap ${DIST}-security-main-snap ${DIST}-security-universe-snap

echo "==> Publishing repository..."
aptly publish snapshot -skip-signing ${DIST}-merged

# Package and export
echo "==> Packaging repository..."
tar -czf /export/aptly-repo-${UBUNTU_TAG}.tar.gz -C ~/.aptly/public .

# Copy to USB if available
if [[ -d /usb && -w /usb ]]; then
    echo "==> Copying to USB..."
    cp /export/aptly-repo-${UBUNTU_TAG}.tar.gz /usb/
fi

echo "==> Build complete!"
echo "==> Repository size: $(du -h /export/aptly-repo-${UBUNTU_TAG}.tar.gz)"
echo "==> Aptly workspace preserved in host folder"