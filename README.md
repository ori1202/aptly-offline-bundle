# Aptly offline `.deb` bundle (Ubuntu 24.04 + 26.04 amd64)

One **multi-stage Dockerfile** builds both Ubuntu releases and packs **`/aptly-offline/{24.04,26.04}/`** into image **`aptly-offline:all`**. A short **`copy-out.sh`** entrypoint copies those trees to bind-mounted **`/export`** (and **`/usb`** when you use the USB profile).

```text
dockers/
  aptly-offline/
    24.04/                 # *.deb (exported here)
    26.04/
  aptly-offline-bundle/
    Dockerfile             # multi-stage: bundle-2404, bundle-2604, export
    docker-compose.yml
    copy-out.sh
    build-debs.sh          # thin wrapper around compose + USB checks
    README.md
    .dockerignore
```

## One command (Docker Compose)

From **`aptly-offline-bundle`**:

```bash
docker compose run --rm aptly-offline
```

This **builds** (if needed) and writes **`../aptly-offline/24.04/`** and **`../aptly-offline/26.04/`**.

### USB as well (plug the stick first)

```bash
docker compose --profile usb run --rm aptly-offline-usb
```

Mirrors the same trees to **`${APTLY_USB:-/run/media/ori/USB DISK}/aptly-offline/{24.04,26.04}/`**.

If the default path has spaces, set the base mount explicitly:

```bash
export APTLY_USB='/run/media/ori/USB DISK'
docker compose --profile usb run --rm aptly-offline-usb
```

### Wrapper script (same as Compose)

```bash
./build-debs.sh              # local + USB (fails if USB missing)
SKIP_USB=1 ./build-debs.sh   # only ../aptly-offline/
```

## Plain Docker (no Compose)

```bash
docker build -t aptly-offline:all .
docker run --rm -v "$(pwd)/../aptly-offline:/export" aptly-offline:all
```

With USB:

```bash
docker run --rm \
  -v "$(pwd)/../aptly-offline:/export" \
  -v "/run/media/ori/USB DISK/aptly-offline:/usb" \
  aptly-offline:all
```

## Pin Ubuntu image tags

Compose passes build-args from the environment:

```bash
UBUNTU_24_TAG=noble-20250416 UBUNTU_26_TAG=26.04 docker compose build
UBUNTU_24_TAG=noble-20250416 docker compose run --rm aptly-offline
```

Plain Docker:

```bash
docker build \
  --build-arg UBUNTU_24_TAG=noble-20250416 \
  --build-arg UBUNTU_26_TAG=26.04 \
  -t aptly-offline:all .
```

(Use tags that exist on [Docker Hub — ubuntu](https://hub.docker.com/_/ubuntu).)

## Environment reference

| Variable | Default | Used by |
|----------|---------|---------|
| `UBUNTU_24_TAG` | `24.04` | `docker compose build` / `docker build` |
| `UBUNTU_26_TAG` | `26.04` | same |
| `APTLY_USB` | `/run/media/ori/USB DISK` | `aptly-offline-usb` volume source (base path; `aptly-offline` is appended) |
| `SKIP_USB` | unset | **`build-debs.sh` only** — `1` runs local export only |

## What the Dockerfile does

1. **Stage `bundle-2404`** — `FROM ubuntu:${UBUNTU_24_TAG}`, `apt-get install -y -d aptly`, copy `*.deb` to `/bundle/out/24.04/`.
2. **Stage `bundle-2604`** — same for 26.04 → `/bundle/out/26.04/`.
3. **Stage `export`** — Alpine image with both trees under `/aptly-offline/24.04` and `/aptly-offline/26.04`, **`ENTRYPOINT`** runs **`copy-out.sh`** to **`/export`** and optionally **`/usb`**.

Download-only install resolves **virtual** packages (unlike `apt-rdepends | xargs apt download`).

## Offline install

On a host **matching that Ubuntu release and amd64**:

```bash
cd /path/to/aptly-offline/24.04   # or 26.04
sudo dpkg -i *.deb
sudo apt-get install -f -y   # if dpkg reports missing deps
```

## Interactive shell (inspect the export image)

```bash
docker run --rm -it --entrypoint /bin/sh aptly-offline:all
# ls /aptly-offline/24.04
```
