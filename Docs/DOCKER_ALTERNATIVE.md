# Docker Alternative for P5 Local Lab

**Status:** Accepted on native Intel x86-64 Linux; Docker Desktop on Apple
silicon remains experimental and untested

## Purpose and capability boundary

This is an alternative to the accepted Apple `container` workflow in the main
[README](../README.md). It describes two different Docker situations:

1. **Intel x86-64 Linux:** Archiware's documented target for the P5 Docker
   package. The bounded workflow below passed on Ubuntu 24.04 LTS with Docker
   Engine 29.9.2, Compose v2, and P5 8.0.6.
2. **Docker Desktop on an Apple-silicon Mac:** A plausible development path
   using `linux/amd64` emulation. The files and commands below are supplied for
   testing, but this project has not run or accepted them.

The native-Linux result proves only the checks in the dated
[acceptance record](DOCKER_LINUX_ACCEPTANCE_2026-11-05.md). Do not treat it as
proof of production correctness, performance, licence-identity stability,
multi-hour operation, or tape-device support. Do not use this workflow for
production data.

## Roles and evidence

| Stage | Tool or owner | Input | Required evidence |
| --- | --- | --- | --- |
| Runtime | Operator/Docker | Docker Engine or Docker Desktop | `docker version` succeeds |
| AMD64 gate | Docker Desktop | Small `linux/amd64` image | `uname -m` returns `x86_64` |
| P5 image | `docker import` | Verified Archiware P5 8.0.6 tar | Local `p5-lab:8.0.6` image |
| Instance | Docker Compose | Dedicated fixture folder and REST/CLI ports | Container remains running |
| Service | P5 | Localhost port mappings | Login URL and CLI TCP port respond |
| CLI | `nsdchat` inside P5 plus host port probe | Read-only version query | P5 returns `8.0.6`; mapped port accepts TCP |

## Option A: Intel x86-64 Linux Docker

Archiware lists **Synology 7 or Linux Docker** with an Intel x86-64 CPU as a
supported download target. Obtain the current **New Install** package from the
[official P5 download page](https://www.archiware.com/download-p5/) and follow
the included version-specific instructions.

From this repository, print Archiware's current Linux Docker link and compare
it with the tested pin before downloading anything:

```sh
./scripts/check-current-p5-download.sh
```

The Docker workflow remains pinned to P5 8.0.6 until a newer vendor package is
tested and the digest, image references, documentation, and acceptance evidence
are updated together.

The native-Linux workflow passed on Ubuntu 24.04 LTS with Docker Engine 29.9.2,
Compose v2, and containerd v2.4.2. See the
[dated acceptance record](DOCKER_LINUX_ACCEPTANCE_2026-11-05.md) for the exact
scope and remaining exclusions.

The P5 8.0.6 vendor launcher observed during this project:

- Imports Archiware's root filesystem tar into Docker.
- Publishes host port `20000` to P5 port `8000`.
- Mounts the entire Linux host root at `/host_dir`.
- Passes `/dev/sg*` devices into the container when present.

Review that script before running it. The whole-root mount is useful for a NAS
server but broader than a disposable application test requires. Prefer a
dedicated test-data directory mounted at `/host_dir` where vendor support and
the intended storage workflow permit it.

Physical tape and changer testing belongs on a suitable x86-64 Linux host with
carefully reviewed device mappings. It is outside the Docker Desktop procedure
below.

Verify a native Linux host before continuing:

```sh
uname -m
docker version
docker compose version
```

Hold unless `uname -m` prints `x86_64`. Then continue with the shared workflow
at **Download and verify P5** below.

## Option B: Docker Desktop on Apple silicon

### 1. Install and configure Docker Desktop

Install the Apple-silicon build by following Docker's
[Mac installation guide](https://docs.docker.com/desktop/setup/install/mac-install/).
Review Docker Desktop's licence terms for the organization using it.

In Docker Desktop settings, use the Apple Virtualization framework and enable
**Use Rosetta for x86_64/amd64 emulation on Apple Silicon**. Docker's own VMM
does not currently support Rosetta, so do not select it for this experiment.

Verify Docker and AMD64 emulation:

```sh
docker version
docker compose version
docker run --rm --platform linux/amd64 ubuntu:24.04 uname -m
```

Hold here unless the last command prints `x86_64`.

## Shared Docker workflow

The following steps passed on the accepted native-Linux environment. They are
still proposed rather than accepted for Docker Desktop on Apple silicon.

### 2. Download and verify P5

From the P5 Local Lab project directory:

```sh
./scripts/download-vendor-image.sh
```

This macOS- and GNU/Linux-compatible helper downloads P5 directly from
Archiware's pinned S3 source over HTTPS and verifies the pinned size and digest.
It does not require Apple's `container` CLI. The human-facing download link
printed by `check-current-p5-download.sh` may reject a plain `curl` client; the
pinned root-filesystem URL used by this helper passed on native Linux.

### 3. Import the P5 filesystem into Docker

```sh
docker import --platform=linux/amd64 \
  vendor/awpst806-container.tar p5-lab:8.0.6
docker image inspect --format '{{.Os}}/{{.Architecture}}' p5-lab:8.0.6
```

Unlike the Apple-runtime Dockerfile, this uses Docker's native root-filesystem
import operation. The inspect command must print `linux/amd64`. The startup
command is supplied by Compose in the next step.

### 4. Prepare an isolated instance

```sh
./scripts/prepare-instance-folder.sh p5-docker-01
export P5_DOCKER_NAME=p5-docker-01
export P5_DOCKER_PORT=21000
export P5_DOCKER_CLI_PORT=29011
export P5_DOCKER_DATA="$PWD/instances/p5-docker-01"
```

Use REST and CLI ports that differ from any Apple-runtime instance already
using `20000` and `29001`.

### 5. Start P5 with Compose

Review [`docker/compose.yaml`](../docker/compose.yaml), then run:

```sh
docker compose -f docker/compose.yaml up -d
docker compose -f docker/compose.yaml ps
```

The Compose definition:

- Forces `linux/amd64`.
- Binds P5 REST only to `127.0.0.1:21000` by default.
- Binds P5 CLI/awsock only to `127.0.0.1:29011` by default.
- Mounts only the chosen instance directory at `/host_dir`.
- Does not expose the Mac root or physical devices.

### 6. Run bounded checks

```sh
docker exec p5-docker-01 uname -m
docker exec p5-docker-01 /usr/local/aw/bin/nsdchat -c srvinfo lexxvers
curl --fail http://127.0.0.1:21000/login >/dev/null
nc -z -w 5 127.0.0.1 29011
docker logs --tail 100 p5-docker-01
```

Expected evidence is `x86_64`, P5 version `8.0.6`, a successful HTTP response,
and a successful TCP connection to the mapped CLI port. A passing result should
still be recorded as Docker-specific test evidence; it does not inherit the
Apple-runtime acceptance result.

Allow approximately 15-20 seconds after container creation for P5 to finish
starting before treating an HTTP or CLI failure as significant.

Open <http://127.0.0.1:21000/login> or point P5 Command Lab at host
`127.0.0.1`, REST port `21000`, nsdchat port `29011`, and the credentials
configured for this instance. Select **Remote over awsock** for CLI recipes;
the P5 server is inside Docker even though the published address is localhost.

### Remote Docker or Synology host

The supplied Compose file deliberately binds both ports to `127.0.0.1` for a
lab running on the same computer as P5 Command Lab. For a separately managed
Docker or Synology host, configure equivalent TCP mappings in that platform's
container interface:

- host REST port `20000` to container port `8000/tcp`;
- host CLI port `29001` to container port `9001/tcp`.

Bind those ports only to the intended LAN interface where the platform allows
it, and restrict them to trusted clients with the host firewall. Do not expose
either service to the public internet or assume that the vendor CLI socket is
encrypted.

In P5 Command Lab use the Docker or NAS hostname, REST port `20000`, nsdchat
port `29001`, and **Remote over awsock**. A non-loopback profile automatically
enforces Remote in P5 Command Lab 0.5.0 and later.

## Lifecycle and reset

Stop and restart while preserving the container's writable P5 configuration:

```sh
docker compose -f docker/compose.yaml stop
docker compose -f docker/compose.yaml start
```

Delete and recreate the container for a fresh P5 configuration layer:

```sh
docker compose -f docker/compose.yaml down
docker compose -f docker/compose.yaml up -d
```

The bind-mounted `instances/p5-docker-01` fixture folder remains on the Mac.
Do not recreate an activated trial container unless losing that container's
host-ID-bound licence is acceptable.

## Stop and investigate when

- AMD64 verification does not return `x86_64`.
- P5 exits or repeatedly restarts.
- The login endpoint does not respond after two minutes.
- `nsdchat` cannot return the installed version.
- P5 cannot see the dedicated `/host_dir` fixture folder.
- Docker requests a broader file share or device permission than the test
  requires.

Retain `docker version`, `docker compose version`, `docker inspect
p5-docker-01`, and `docker logs p5-docker-01` output before changing the setup.

## Acceptance status

Native Intel x86-64 Linux passed the following on the environment recorded in
the [acceptance record](DOCKER_LINUX_ACCEPTANCE_2026-11-05.md):

- [x] Native execution returns `x86_64`.
- [x] P5 8.0.6 remains running for at least ten minutes.
- [x] Login URL and bounded unlicensed REST requests respond.
- [x] `nsdchat` version and uptime queries respond.
- [x] Dedicated bind-mounted fixtures are readable and writable.
- [x] P5 configuration survives Compose stop/start.
- [x] Compose down/up produces the documented fresh-server behavior.
- [x] Two instances operate concurrently on distinct ports.
- [x] Documentation records exact accepted versions and limitations.

Docker Desktop on Apple silicon remains unaccepted until these checks are
repeated under its AMD64 emulation. Licence identity stability, multi-hour
operation, archive/restore workflows, and tape or changer access remain outside
the accepted scope on both Docker paths.
