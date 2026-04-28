# One build: create aptly repositories for Ubuntu 24.04 and 26.04 from official mirrors,
# then package them as tar.gz archives under /aptly-offline/{24.04,26.04}/.
#
# Export to the host: docker compose run --rm aptly-offline
#   or: docker build -t aptly-offline:all . && docker compose run --rm aptly-offline
#
# Build-args (optional): UBUNTU_24_TAG, UBUNTU_26_TAG (Docker Hub ubuntu tags)
# Both must be declared before any FROM so each FROM can use them.
ARG UBUNTU_24_TAG=24.04
ARG UBUNTU_26_TAG=26.04

FROM ubuntu:${UBUNTU_24_TAG} AS bundle-2404

ENV DEBIAN_FRONTEND=noninteractive
RUN mkdir -p /bundle/out/24.04 \
    && apt-get update -qq \
    && apt-get install -y -qq aptly gpg ubuntu-keyring ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Initialize GPG and import Ubuntu archive keyring for signature verification
RUN mkdir -p ~/.gnupg && chmod 700 ~/.gnupg \
    && gpg --no-default-keyring --keyring /usr/share/keyrings/ubuntu-archive-keyring.gpg --export | gpg --no-default-keyring --keyring trustedkeys.gpg --import

# Create aptly mirrors for noble (24.04) - main and universe components only
# This will download many GB and take 6+ hours
RUN echo "Starting full repository mirror - this will take 6+ hours..." \
    && aptly mirror create -architectures=amd64 ubuntu-noble-main http://archive.ubuntu.com/ubuntu noble main \
    && aptly mirror create -architectures=amd64 ubuntu-noble-universe http://archive.ubuntu.com/ubuntu noble universe \
    && aptly mirror create -architectures=amd64 ubuntu-noble-security-main http://security.ubuntu.com/ubuntu noble-security main \
    && aptly mirror create -architectures=amd64 ubuntu-noble-security-universe http://security.ubuntu.com/ubuntu noble-security universe

# Update mirrors to download packages (this is the long part - 6+ hours)
RUN echo "Downloading main repository..." \
    && aptly mirror update ubuntu-noble-main \
    && echo "Downloading universe repository..." \
    && aptly mirror update ubuntu-noble-universe \
    && echo "Downloading security main..." \
    && aptly mirror update ubuntu-noble-security-main \
    && echo "Downloading security universe..." \
    && aptly mirror update ubuntu-noble-security-universe

# Create snapshots from mirrors
RUN aptly snapshot create ubuntu-noble-main-snap from mirror ubuntu-noble-main \
    && aptly snapshot create ubuntu-noble-universe-snap from mirror ubuntu-noble-universe \
    && aptly snapshot create ubuntu-noble-security-main-snap from mirror ubuntu-noble-security-main \
    && aptly snapshot create ubuntu-noble-security-universe-snap from mirror ubuntu-noble-security-universe

# Merge snapshots and publish
RUN aptly snapshot merge ubuntu-noble-merged ubuntu-noble-main-snap ubuntu-noble-universe-snap ubuntu-noble-security-main-snap ubuntu-noble-security-universe-snap \
    && aptly publish snapshot -skip-signing ubuntu-noble-merged

# Package the repository (this will be several GB)
RUN echo "Packaging repository..." \
    && tar -czf /bundle/out/24.04/aptly-repo-24.04.tar.gz -C ~/.aptly/public . \
    && echo "24.04 repository packaged: $(du -h /bundle/out/24.04/aptly-repo-24.04.tar.gz)"

FROM ubuntu:${UBUNTU_26_TAG} AS bundle-2604

ENV DEBIAN_FRONTEND=noninteractive
RUN mkdir -p /bundle/out/26.04 \
    && apt-get update -qq \
    && apt-get install -y -qq aptly gpg ubuntu-keyring ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Initialize GPG and import Ubuntu archive keyring for signature verification
RUN mkdir -p ~/.gnupg && chmod 700 ~/.gnupg \
    && gpg --no-default-keyring --keyring /usr/share/keyrings/ubuntu-archive-keyring.gpg --export | gpg --no-default-keyring --keyring trustedkeys.gpg --import

# Create aptly mirrors for resolute (26.04) - main and universe components only
# This will download many GB and take 6+ hours
RUN echo "Starting full repository mirror - this will take 6+ hours..." \
    && aptly mirror create -architectures=amd64 ubuntu-resolute-main http://archive.ubuntu.com/ubuntu resolute main \
    && aptly mirror create -architectures=amd64 ubuntu-resolute-universe http://archive.ubuntu.com/ubuntu resolute universe \
    && aptly mirror create -architectures=amd64 ubuntu-resolute-security-main http://security.ubuntu.com/ubuntu resolute-security main \
    && aptly mirror create -architectures=amd64 ubuntu-resolute-security-universe http://security.ubuntu.com/ubuntu resolute-security universe

# Update mirrors to download packages (this is the long part - 6+ hours)
RUN echo "Downloading main repository..." \
    && aptly mirror update ubuntu-resolute-main \
    && echo "Downloading universe repository..." \
    && aptly mirror update ubuntu-resolute-universe \
    && echo "Downloading security main..." \
    && aptly mirror update ubuntu-resolute-security-main \
    && echo "Downloading security universe..." \
    && aptly mirror update ubuntu-resolute-security-universe

# Create snapshots from mirrors
RUN aptly snapshot create ubuntu-resolute-main-snap from mirror ubuntu-resolute-main \
    && aptly snapshot create ubuntu-resolute-universe-snap from mirror ubuntu-resolute-universe \
    && aptly snapshot create ubuntu-resolute-security-main-snap from mirror ubuntu-resolute-security-main \
    && aptly snapshot create ubuntu-resolute-security-universe-snap from mirror ubuntu-resolute-security-universe

# Merge snapshots and publish
RUN aptly snapshot merge ubuntu-resolute-merged ubuntu-resolute-main-snap ubuntu-resolute-universe-snap ubuntu-resolute-security-main-snap ubuntu-resolute-security-universe-snap \
    && aptly publish snapshot -skip-signing ubuntu-resolute-merged

# Package the repository (this will be several GB)
RUN echo "Packaging repository..." \
    && tar -czf /bundle/out/26.04/aptly-repo-26.04.tar.gz -C ~/.aptly/public . \
    && echo "26.04 repository packaged: $(du -h /bundle/out/26.04/aptly-repo-26.04.tar.gz)"

FROM alpine:3.21 AS export
COPY --from=bundle-2404 /bundle/out/24.04/aptly-repo-24.04.tar.gz /aptly-offline/24.04/
COPY --from=bundle-2604 /bundle/out/26.04/aptly-repo-26.04.tar.gz /aptly-offline/26.04/
COPY copy-out.sh /copy-out.sh
RUN chmod +x /copy-out.sh
ENTRYPOINT ["/bin/sh", "/copy-out.sh"]
