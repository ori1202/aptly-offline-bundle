# One build: aptly + deps for Ubuntu 24.04 and 26.04, then a small image that
# holds both trees under /aptly-offline/{24.04,26.04}/.
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
RUN mkdir -p /bundle/archives /bundle/out/24.04 \
    && apt-get update -qq \
    && apt-get install -y -qq -d \
        -o Dir::Cache::Archives=/bundle/archives \
        aptly \
    && cp /bundle/archives/*.deb /bundle/out/24.04/ \
    && rm -rf /bundle/archives \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

FROM ubuntu:${UBUNTU_26_TAG} AS bundle-2604

ENV DEBIAN_FRONTEND=noninteractive
RUN mkdir -p /bundle/archives /bundle/out/26.04 \
    && apt-get update -qq \
    && apt-get install -y -qq -d \
        -o Dir::Cache::Archives=/bundle/archives \
        aptly \
    && cp /bundle/archives/*.deb /bundle/out/26.04/ \
    && rm -rf /bundle/archives \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

FROM alpine:3.21 AS export
COPY --from=bundle-2404 /bundle/out/24.04 /aptly-offline/24.04
COPY --from=bundle-2604 /bundle/out/26.04 /aptly-offline/26.04
COPY copy-out.sh /copy-out.sh
RUN chmod +x /copy-out.sh
ENTRYPOINT ["/bin/sh", "/copy-out.sh"]
