# Aptly Repository Generator (Ubuntu 24.04 + 26.04 amd64)

**⚠️ IMPORTANT: This generates FULL Ubuntu repository mirrors. Expect 6+ hours build time and several GB per release.**

One **multi-stage Dockerfile** creates complete Ubuntu repository mirrors for both 24.04 and 26.04 releases, downloading full `main` and `universe` components plus security updates from official Ubuntu repositories (`http://archive.ubuntu.com/ubuntu` and `http://security.ubuntu.com/ubuntu`). The result is packaged as **`aptly-repo-<version>.tar.gz`** archives containing complete `dists/` and `pool/` directories that can be served as full APT repositories. A short **`copy-out.sh`** entrypoint copies those archives to bind-mounted **`/export`** (and **`/usb`** when you use the USB profile).

```text
dockers/
  aptly-offline/
    24.04/                 # aptly-repo-24.04.tar.gz (exported here)
    26.04/                 # aptly-repo-26.04.tar.gz
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

This **builds** (if needed) and writes **`../aptly-offline/24.04/aptly-repo-24.04.tar.gz`** and **`../aptly-offline/26.04/aptly-repo-26.04.tar.gz`**.

### USB as well (plug the stick first)

```bash
docker compose --profile usb run --rm aptly-offline-usb
```

Mirrors the same repository archives to **`${APTLY_USB:-/run/media/ori/USB DISK1}/aptly-offline/{24.04,26.04}/`**.

If the default path has spaces, set the base mount explicitly:

```bash
export APTLY_USB='/run/media/ori/USB DISK1'
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
  -v "/run/media/ori/USB DISK1/aptly-offline:/usb" \
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
| `APTLY_USB` | `/run/media/ori/USB DISK1` | `aptly-offline-usb` volume source (base path; `aptly-offline` is appended) |
| `SKIP_USB` | unset | **`build-debs.sh` only** — `1` runs local export only |

## What the Dockerfile does

1. **Stage `bundle-2404`** — `FROM ubuntu:${UBUNTU_24_TAG}`, installs `aptly`, creates mirrors from `http://archive.ubuntu.com/ubuntu` and `http://security.ubuntu.com/ubuntu` for the noble distribution, updates mirrors, creates and merges snapshots, publishes the repository, and packages it as `aptly-repo-24.04.tar.gz`.
2. **Stage `bundle-2604`** — same process for 26.04 (resolute distribution) → `aptly-repo-26.04.tar.gz`.
3. **Stage `export`** — Alpine image with both repository archives under `/aptly-offline/{24.04,26.04}/`, **`ENTRYPOINT`** runs **`copy-out.sh`** to copy archives to **`/export`** and optionally **`/usb`**.

The resulting `.tar.gz` files contain complete Debian repository structures with `dists/` and `pool/` directories that can be served as APT repositories.

### What's included:
- **main** component (officially supported packages)
- **universe** component (community-maintained packages)  
- **security** updates for both components
- **Architecture**: amd64 only
- **Size**: ~3-5GB per release when compressed

### What's NOT included:
- **restricted** and **multiverse** components
- Source packages (only binary packages)
- Other architectures (arm64, i386, etc.)

## Using the offline repository

Extract and serve the repository archive on a host **matching that Ubuntu release and amd64**:

```bash
cd /path/to/aptly-offline/24.04   # or 26.04
tar -xzf aptly-repo-24.04.tar.gz
# This creates dists/ and pool/ directories

# Serve via HTTP (example with Python)
python3 -m http.server 8080
# Add to /etc/apt/sources.list on target machines:
# deb http://your-server-ip:8080/ noble main universe
# deb http://your-server-ip:8080/ noble-security main universe
```

Or copy the extracted repository to `/var/www/html/` or similar web server document root.

## Interactive shell (inspect the export image)

```bash
docker run --rm -it --entrypoint /bin/sh aptly-offline:all
# ls /aptly-offline/24.04
# tar -tzf /aptly-offline/24.04/aptly-repo-24.04.tar.gz | head -20
```
