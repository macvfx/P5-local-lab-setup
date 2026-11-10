# P5 Local Lab

P5 Local Lab is a disposable local test lab for exploring multiple ways to
run and test Archiware P5 on Apple silicon Macs:

- **Path A — Linux P5 in Apple's native `container` runtime** —
  Archiware's official Linux Docker root filesystem converted to a local OCI
  image, running the Intel/AMD64 P5 build under Rosetta. Accepted; this is
  the path the walkthrough below sets up by default.
- **Path B — Linux P5 in Docker** — native Intel x86-64 (accepted) or
  Docker Desktop on Apple silicon under AMD64 emulation (experimental,
  untested). See the [Docker guide](Docs/DOCKER_ALTERNATIVE.md).
- **Path C — Native macOS P5 in a disposable Tart virtual machine** —
  golden macOS images with throwaway per-test clones, for testing P5 as it
  actually runs on macOS rather than inside a Linux container. Written and
  in progress, not yet accepted. See
  [`Docs/MACOS_VM_TART_SETUP.md`](Docs/MACOS_VM_TART_SETUP.md) and the
  [research and roadmap](Docs/MACOS_VM_P5_TEST_LAB_RESEARCH.md).

Each path is tracked and accepted independently — passing one does not imply
the others work; see each path's own acceptance record or status note.

**This is currently a reproducible automation project, not a standalone macOS
app.** Its shell scripts install no system software beyond what each path
explicitly needs: they verify the chosen runtime, download and verify P5
directly from Archiware, build or pull images, and create isolated,
disposable test instances. ContainerManager is the recommended optional
graphical interface for the Apple-container path.

The first milestone is deliberately narrow: prove that one P5 8.0.6 server can
start, expose its web, REST, and CLI/awsock interfaces on localhost, see a
dedicated fixture folder, and survive a normal stop/start cycle. An unlicensed
server can answer useful read-only REST and CLI requests such as server
version, uptime, and Archive-index discovery. A trial is needed for configured
Archive workflows and file movement, not for this initial integration testing.

That milestone passed on 2026-11-05. See
[`Docs/ACCEPTANCE_2026-11-05.md`](Docs/ACCEPTANCE_2026-11-05.md) for the exact
environment and results.

The localhost CLI/awsock mapping was added and smoke-tested on 2026-11-06. See
[`Docs/CLI_PORT_ACCEPTANCE_2026-11-06.md`](Docs/CLI_PORT_ACCEPTANCE_2026-11-06.md)
for the exact REST/CLI mappings, evidence, and remaining authenticated test.

The native Intel x86-64 Linux Docker workflow passed bounded acceptance on
Ubuntu 24.04 LTS with Docker Engine 29.9.2 and P5 8.0.6; see the
[dated Linux acceptance record](Docs/DOCKER_LINUX_ACCEPTANCE_2026-11-05.md).
Docker Desktop on Apple silicon remains experimental and untested.

## Safety boundaries

- The P5 REST and CLI ports bind to `127.0.0.1`, not every network interface.
- Only an instance-specific directory is mounted at `/host_dir`.
- An optional shared source-media folder is mounted read-only, so no P5 job
  can change or delete the originals.
- The create scripts check that both host ports are free before creating
  anything, and stop or skip rather than leave a half-made instance.
- The Mac's root filesystem is never mounted into P5.
- Vendor binaries are downloaded from Archiware and are not committed here.
- The scripts operate only on explicitly named instances.
- Deleting a container deletes P5 configuration stored in its writable layer;
  the bind-mounted fixture folders remain on the Mac.

## Path A: Apple-container setup, from a new Mac to a P5 lab

This walkthrough sets up Path A (Linux P5 under Rosetta in Apple's `container`
runtime). For Path B or Path C, see the
[Docker guide](Docs/DOCKER_ALTERNATIVE.md) or
[`Docs/MACOS_VM_TART_SETUP.md`](Docs/MACOS_VM_TART_SETUP.md).

### 1. Install Apple's container runtime

Choose **one** installation method. Do not install both the signed Apple
package and the Homebrew formula; two copies can leave the CLI and background
service on different versions.

#### Option A: Apple's signed installer (recommended)

1. Confirm the Mac has Apple silicon and macOS 26 or 27.
2. Download the latest signed installer from
   [apple/container releases](https://github.com/apple/container/releases).
3. Run the package installer. It installs under `/usr/local` and asks for an
   administrator password.
4. Start the service:

   ```sh
   container system start
   ```

#### Option B: Homebrew

```sh
brew install container
brew services start container
container system kernel set --recommended
```

The kernel command is required because the Homebrew service does not install a
kernel automatically.

Verify either installation before continuing:

```sh
container --version
container system status
container run --rm alpine echo hello
```

The client and server versions in `container system status` must match.

Prefer Docker instead? See the [Docker alternative](Docs/DOCKER_ALTERNATIVE.md).
The native Intel x86-64 Linux path is accepted for bounded testing on the
recorded Ubuntu and Docker versions. The Docker Desktop/Apple-silicon path is
included as an experimental community test route, not as an accepted result of
this project.

### 2. Optionally install ContainerManager

Download the latest build from
[bartreardon/ContainerManager-App](https://github.com/bartreardon/ContainerManager-App/releases/latest),
move it to Applications, and launch it after Apple's container service is
running. ContainerManager 1.1.2 accepted this project's stack template during
validation. The project can also be used entirely from Terminal.

### 3. Obtain this project

Clone the public repository:

```sh
git clone https://github.com/macvfx/P5-local-lab-setup.git
cd P5-local-lab-setup
```

Alternatively, unpack a project archive created with
`scripts/package-project.sh`. The archive intentionally excludes the
proprietary P5 download, instance data, host IDs, licences, and credentials.

If the unpacked folder has a version suffix, change into that directory before
running the scripts, for example:

```sh
cd P5-Local-Lab-0.1.6
```

### 4. Check the host and build the P5 image

Run:

```sh
./scripts/preflight.sh
./scripts/check-current-p5-download.sh
./scripts/download-vendor-image.sh
./scripts/build-image.sh
```

The check prints Archiware's official download page, its current Linux Docker
package, and the 8.0.6 release tested by this project. It does not download or
change anything. The first vendor-image download is approximately 346 MiB.
The build creates the local `p5-lab:8.0.6` AMD64 image. It does not start P5 or
activate a licence. The same image can be reused by multiple independent test
instances.

### 5. Create the first instance

Choose either the CLI workflow or ContainerManager.

#### CLI workflow

```sh
./scripts/create-instance.sh p5-lab-01 20000 29001
./scripts/smoke-test.sh p5-lab-01 20000 29001
./scripts/status.sh p5-lab-01
```

To give the instance a folder of real source media as well, mounted
read-only, use `create-instance-with-media.sh` in place of the first command;
see
[Creating an instance with read-only source media](#creating-an-instance-with-read-only-source-media).
A mount has to be chosen when the instance is created; it cannot be added
later.

#### ContainerManager workflow

1. Prepare the dedicated folder:

   ```sh
   ./scripts/prepare-instance-folder.sh p5-lab-01
   ```

2. Open **Stacks**.
3. Choose **New Stack > Import Template** and select
   `P5-Local-Lab.containerstack`.
4. Enter a unique instance name plus unique localhost REST and CLI ports.
5. Choose the prepared `instances/p5-lab-01` folder for `/host_dir`.
6. Create the stack and use **Open in Browser** when P5 is ready.

Do not create a ContainerManager stack with the same name or either port as an
instance already created by the CLI.

### 6. Connect and test

Open <http://127.0.0.1:20000/login>. An unlicensed server can already answer
read-only REST and CLI requests.

For P5 Command Lab, create a live server profile using:

- Scheme: `http`
- Host: `127.0.0.1`
- REST port: `20000`
- nsdchat port: `29001`
- Username and password: the credentials configured in this P5 instance
- CLI connection: **Remote over awsock**

The lab uses Remote over awsock even though its address is localhost: P5 runs
inside the container, not in the Mac's local P5 service. Host port `29001`
maps to P5's container port `9001` and avoids a possible conflict with a local
P5 installation already listening on host port `9001`.

Start with server version and uptime, followed by Archive-index discovery. A
trial is optional until the test requires index creation, plans, archiving, or
restores.

## Requirements summary

- Apple silicon Mac running macOS 26 or 27. Apple's runtime requires macOS 26;
  this Intel Linux P5 image was also proven under Rosetta on a compatible test
  host. Later macOS releases remain unverified for this project.
- Native macOS P5 compatibility is a separate question from the Linux
  container host requirement. Archiware's current P5 8.0.6 download page lists
  Intel macOS `10.9–15.x` and Apple M-series macOS `11.x–26.5.x (Tahoe)`.
  Project testing has also observed native P5 working on macOS `27.2`, outside
  that published vendor-tested range. Check the
  [current Archiware download page](https://www.archiware.com/download-p5/)
  before choosing a native macOS test target.
- Apple `container` CLI and services.
- Rosetta support for `linux/amd64` containers.
- ContainerManager is optional but supported through
  `P5-Local-Lab.containerstack`.
- Review Archiware's software licence and trial terms. Trial activation remains
  a manual, optional action inside P5.

## Condensed quick start

Run each step from this directory:

```sh
./scripts/preflight.sh
./scripts/check-current-p5-download.sh
./scripts/download-vendor-image.sh
./scripts/build-image.sh
./scripts/create-instance.sh p5-lab-01 20000 29001
./scripts/smoke-test.sh p5-lab-01 20000 29001
./scripts/status.sh p5-lab-01
```

To start with a read-only folder of source media, replace the
`create-instance.sh` line with:

```sh
./scripts/create-instance-with-media.sh /path/to/media p5-lab-01 20000 29001
```

Then open <http://127.0.0.1:20000/login>. The unlicensed server is sufficient
for initial P5 Command Lab REST and CLI tests. Do not clone or commit an
activated P5 installation: Archiware licensing uses a host identity.

## Unlicensed and trial testing

Without a P5 licence, the lab can still exercise read-only integration paths,
including:

- Server version and uptime.
- Basic server and service information.
- Archive-index and other collection discovery where supported by P5.
- `nsdchat` connectivity and command construction.
- REST authentication, response decoding, error handling, and presentation.

To test index creation, Archive plans, storage pools, archiving files, or
restores, request a trial in the P5 web interface under **Home > License
Manager > Get Trial License**. P5 offers a fully functional trial lasting 5 or
30 days and forwards the operator to the Archiware Portal with the instance's
host ID.

The trial is connected to that host ID. Treat an activated container as a
stateful test server: stop/start it normally, and do not assume its licence will
remain valid after deleting and recreating the container. Never put a host ID,
licence file, portal response, or credentials into this repository.

Stop and restart the instance without deleting its writable filesystem:

```sh
./scripts/stop-instance.sh p5-lab-01
./scripts/start-instance.sh p5-lab-01
```

Create another isolated instance by choosing another name and two unused
ports. It reuses the existing image but receives an independent writable
container filesystem:

```sh
./scripts/create-instance.sh p5-lab-02 20001 29002
./scripts/smoke-test.sh p5-lab-02 20001 29002
```

### Creating several instances at once

```sh
./scripts/create-instances.sh <count> [version] [name-prefix]
```

Scans `instances/` for the highest existing `<prefix>-NN` instance, then
creates `<count>` more starting from the next number, incrementing REST and
CLI ports by one per instance the same way manual naming already does.
Defaults to the `p5-lab` prefix and the current pinned version. For
example, with `p5-lab-01` already created:

```sh
./scripts/create-instances.sh 3
```

creates `p5-lab-02`, `p5-lab-03`, and `p5-lab-04` with their ports following
the same `REST 20000+N / CLI 29001+N` pattern, and prints the matching
`smoke-test.sh` command for each. To create instances on a non-current
pinned version instead:

```sh
./scripts/create-instances.sh 2 8.0.5
```

### Port checks before creation

Before creating anything, the create scripts check that both host ports
are free:

- `create-instance.sh` and `create-instance-with-media.sh` stop with a
  message naming the busy port and an `lsof` command to find what holds it.
  No instance folder or container is created.
- `create-instances.sh` skips an instance number whose REST or CLI port is
  already in use and moves to the next one, so names and ports stay paired.
  It stops after 20 skipped numbers.

A port is typically busy because of a running container outside the
`<prefix>-NN` numbering (for example `p5-lab-04-media`), a ContainerManager
stack, or another app. For example, with `p5-lab-01` to `p5-lab-04` present
and a differently named container holding REST port `20004`:

```text
Highest existing p5-lab-NN instance: 4
Skipping p5-lab-05: host port 20004 or 29005 is already in use.
Creating instance 1 of 2: p5-lab-06 (REST 20005, CLI 29006)
```

The check sees live listeners only. A stopped container does not hold its
ports, so its numbers can be handed to a new instance; the two then cannot
run at the same time. To avoid gaps and clashes, give one-off instances a
plain `<prefix>-NN` name, or a different prefix with ports well away from
the `20000` and `29001` ranges. The check uses `nc`, which macOS includes.

Each instance is still created one at a time through `create-instance.sh`,
so the same name-collision guard and per-instance folder setup apply; this
script only automates picking names and ports.

### Creating an instance with read-only source media

```sh
./scripts/create-instance-with-media.sh <media-folder> [instance-name] [rest-port] [cli-port] [version]
```

Creates one instance the same way `create-instance.sh` does, and adds a
second bind mount: an existing folder of source media on the Mac, mounted
**read-only** inside the container at `/media`. For example:

```sh
./scripts/create-instance-with-media.sh /Volumes/Media/TestFootage p5-lab-03 20002 29003
./scripts/smoke-test.sh p5-lab-03 20002 29003
```

The same media folder can be given to any number of instances, so one copy
of the footage serves the whole lab. Each instance keeps its own writable
`instances/<name>` folder at `/host_dir` for `archive/`, `restore/`, and
`exports/`. Because the mount is read-only, no P5 job can modify or delete
the originals.

After creating the container the script confirms that `/media` is visible
and that a write to it fails; it stops with an error if the mount turned out
to be writable. Set `P5_LAB_MEDIA_TARGET` to use a container path other than
`/media`.

A mount cannot be added to a container that already exists. Giving an
existing instance this mount means destroying and recreating it, which
discards its P5 configuration and any activated trial licence. To keep such
an instance, clone the media into its own `source/` folder instead
(`cp -Rc` uses no extra space on the same APFS volume).

To give a whole batch the same media folder, set `P5_LAB_MEDIA` when
calling `create-instances.sh`:

```sh
P5_LAB_MEDIA=/Volumes/Media/TestFootage ./scripts/create-instances.sh 3
```

Without `P5_LAB_MEDIA` the batch script behaves exactly as before.

Status: the single-instance script, the `P5_LAB_MEDIA` batch option, and
the port checks all passed operator-reported runs on Apple's `container`
runtime on 2026-11-09; see
[`Docs/MEDIA_MOUNT_ACCEPTANCE_2026-11-09.md`](Docs/MEDIA_MOUNT_ACCEPTANCE_2026-11-09.md)
for what was and was not covered.

Reset an instance to a fresh P5 server:

```sh
./scripts/destroy-instance.sh p5-lab-02 --confirm
./scripts/create-instance.sh p5-lab-02 20001 29002
```

The destroy command refuses containers that are not labelled as P5 Local Lab
resources. It removes the container and its P5 configuration but deliberately
keeps the instance's bind-mounted source, archive, restore, and export folders.

## Script reference

All scripts live in `scripts/` and are run from the project directory.

| Script | Purpose |
| --- | --- |
| `preflight.sh` | Checks the Mac, macOS version, and Apple `container` client/server versions. |
| `check-current-p5-download.sh` | Compares the pinned P5 version with Archiware's download page. Downloads nothing. |
| `download-vendor-image.sh [version]` | Downloads the pinned P5 root filesystem and verifies its size and digest. |
| `build-image.sh [version]` | Builds the local `p5-lab:<version>` image. |
| `create-instance.sh [name] [rest-port] [cli-port] [version]` | Creates one instance with its own `/host_dir` folder. Checks ports first. |
| `create-instance-with-media.sh <media-folder> [name] [rest-port] [cli-port] [version]` | As above, plus a host media folder mounted read-only at `/media`. Checks ports first, then verifies the mount is visible and rejects writes. |
| `create-instances.sh <count> [version] [name-prefix]` | Creates several numbered instances. Skips numbers whose ports are busy. Set `P5_LAB_MEDIA` to mount one media folder read-only in all of them. |
| `smoke-test.sh [name] [rest-port] [cli-port]` | Checks architecture, the `/host_dir` mount, the P5 CLI, the login page, and the CLI port. |
| `status.sh [name]` | Shows container details, P5 version, filesystems, and resource use. |
| `stop-instance.sh` / `start-instance.sh [name]` | Stops or starts an instance, keeping its P5 configuration. |
| `destroy-instance.sh <name> --confirm` | Deletes a lab container and its P5 configuration; keeps the instance folder. |
| `prepare-instance-folder.sh [name]` | Creates the `instances/<name>` folder layout without creating a container. |
| `list-p5-versions.sh` / `add-p5-version.sh` | Lists pinned P5 versions, or pins a new one. |
| `package-project.sh` | Builds a distributable ZIP of the project without vendor software. |
| `tart-preflight.sh` / `tart-pull-golden-image.sh` | Path C (macOS guests in Tart) helpers. |

Environment variables:

| Variable | Used by | Effect |
| --- | --- | --- |
| `P5_LAB_MEDIA` | `create-instances.sh` | Host media folder to mount read-only in every instance of the batch. |
| `P5_LAB_MEDIA_TARGET` | `create-instance-with-media.sh` | Container path for the media mount. Default `/media`. |
| `P5_CONTAINER_BIN` | All Apple-container scripts | Path to the `container` CLI when it is not in the default locations. |

## ContainerManager

Build the image first with `scripts/build-image.sh`. In ContainerManager choose
Stacks, add a stack, and import `P5-Local-Lab.containerstack`. Select a new,
empty instance directory such as `instances/p5-lab-01` for the lab data folder.

ContainerManager imports Compose-like definitions but is not a complete Docker
Compose implementation. This project therefore builds the image separately and
uses a small native `.containerstack` definition for runtime configuration.

The stack template mounts only the instance folder at `/host_dir`. It does
not add the read-only media mount and does not run the port checks; use the
CLI scripts for those. ContainerManager can still manage an instance the CLI
scripts created.

## Instance folders

`create-instance.sh` creates this layout:

```text
instances/p5-lab-01/
├── source/       Files presented to P5 for archive or backup tests
├── archive/      Disposable disk archive target
├── restore/      Restore destination
└── exports/      Reports and exported test data
```

Inside P5 these appear below `/host_dir`. P5's application, configuration,
logs, and default indexes initially remain in the container's writable layer.

An instance created with `create-instance-with-media.sh` has the same layout
plus the chosen media folder at `/media`, outside `/host_dir` and read-only.
Use `/media` as the Archive plan source and keep `archive/` and `restore/`
as the writable targets.

Apple's runtime presented the writable root as a thin-provisioned 504 GB
filesystem during acceptance. That is not a reserved 504 GB allocation: its
real growth is limited by free storage on the Mac. Use a bounded sparse image
or another explicitly limited backing store when a test needs deterministic
"disk full" behaviour.

## Storage for Archive testing

Testing notes before configuring Archive plans on multiple instances, so
storage choices stay consistent across `p5-lab-01`, `p5-lab-02`, and later
instances.

### Local folders (default; already provided)

Each instance's `archive/`, `source/`, and `restore/` folders (above) are
already isolated per instance and bind-mounted individually — no extra setup
needed. Use these directly as the Disk Pool target, plan source, and restore
destination for Archive configuration on each instance, same fictional
naming as the Tart path (`Example-Archive` / `Example-Plan` / `TEST-POOL`),
so results are directly comparable between the container and VM paths.

### Shared read-only source media across instances

Several instances can read the same host folder of source media. Create
each with `create-instance-with-media.sh`, or a whole batch with
`P5_LAB_MEDIA=<folder> ./scripts/create-instances.sh <count>`; see
[Creating an instance with read-only source media](#creating-an-instance-with-read-only-source-media).
The mount is read-only in every instance, so the instances cannot interfere
with each other through it.

One instance has archived from the shared mount. Two instances archiving
from it at the same time, and a restore verified against the originals, are
not yet tested.

### Shared writable storage across instances (to test)

Pointing two running instances at the same *writable* host folder, for
example a shared Disk Pool target, is a separate test and is not available
through the scripts. It would need a manual `container run` with an extra
`--volume <shared-host-path>:<container-path>`. Not yet implemented or run.

Research on which parts of Archive configuration (index/pool/plan creation
vs. submitting and monitoring jobs against ones that already exist) can be
automated via the P5 REST API, versus which stay manual per container, is in
[`Docs/REST_API_AUTOMATION_NOTES.md`](Docs/REST_API_AUTOMATION_NOTES.md).

## Multiple P5 versions

Every pinned P5 version lives as a small file under `versions/<version>.env`
(vendor source URL, vendor package filename, expected size, and a checksum),
plus `versions/CURRENT`, which names which pin `scripts/download-vendor-image.sh`,
`scripts/build-image.sh`, and `scripts/create-instance.sh` use by default
when no version is given explicitly. Every one of those scripts also takes
an explicit version as an extra argument to work with a non-current pin
instead.

### See what's pinned

```sh
./scripts/list-p5-versions.sh
```

Reports each pinned version, whether it's the current default, and whether
its vendor tar is already downloaded locally.

### Pin a new or historical version from a URL

```sh
./scripts/add-p5-version.sh <version> <url> [image-tag]
```

Downloads the given URL (a `.tar` or a `.zip` containing one, matching
either the direct S3-style link this project already pins for 8.0.6 or the
`?awdl=...` package link from Archiware's download page or its Version
Archive for older major lines), computes its size and SHA-256, and writes
`versions/<version>.env`. It refuses to overwrite an existing pin. It does
**not** change `versions/CURRENT` — build and use the new pin explicitly
until you decide to make it the default:

```sh
./scripts/build-image.sh <version>
./scripts/create-instance.sh <name> <rest-port> <cli-port> <version>
```

If the checksum this script records came from a vendor-published value, note
that separately in the `.env` file — by default it's **observed from that
one download, not vendor-published**, since Archiware does not publish
per-patch checksums the way this project's own 8.0.6 pin has one confirmed
against the vendor's S3 ETag.

### Policy: pin forward, don't try to backfill history

This project's working policy is to pin each P5 version **at the moment it
becomes current**, and never rely on being able to recover an older Docker
package later. This isn't a theoretical caution — it's confirmed. Archiware's
Version Archive page links to a `7.4.8` Linux Docker package, but fetching it
(both through the archived link and by resolving its real URL in a browser)
returned `AccessDenied` from the backing S3 object: the link exists, the file
behind it does not. Combined with a separate stray checksum/installer
mismatch already observed on the current download page, treat Archiware's
retention of old Docker packages as unreliable in general, not just in this
one case.

Practical effect: `scripts/add-p5-version.sh` still works and still accepts
a URL or a local file for whatever a historical link happens to resolve to,
but don't plan around successfully backfilling a version you didn't already
pin when it was current. The real workflow is:

```sh
./scripts/check-current-p5-download.sh
```

Run this periodically. It compares the live download page against whichever
version `versions/CURRENT` names, and prints the `add-p5-version.sh` command
to pin the new release the moment they differ. Keep the old pin's `.env`
file, vendor tar, and built image around afterward — the lab is explicitly
designed to run multiple pinned versions side by side for regression
testing, not to replace one with the next. Only update `versions/CURRENT`
once the new pin is downloaded, verified, and built.

## Backlog

- **Regular Linux installer instead of the Docker-specific package.**
  Archiware's standard RPM/DEB-style Linux installer may be retained more
  reliably than the Docker-specific export (worth checking when picked up).
  This would need a real base-OS `Dockerfile` (`FROM ubuntu:22.04` or
  similar, installer run during the build) alongside the current
  `FROM scratch` + root-filesystem-`ADD` one, not a replacement for it — the
  two packaging types would coexist. All current and historical builds seen
  so far are Intel/AMD64 only, so this doesn't add a new architecture to
  support, just a second packaging path. Not started.

## Vendor source

Start at Archiware's canonical
[P5 download page](https://www.archiware.com/download-p5/) and locate
**Synology 7+ or Linux Docker > New Install**. The helper below prints the
current link advertised by that page without downloading it:

```sh
./scripts/check-current-p5-download.sh
```

This project deliberately does not follow the newest P5 release automatically.
Its accepted and reproducible pin remains Archiware P5 8.0.6, recorded in
[`versions/8.0.6.env`](versions/8.0.6.env):

- Vendor package link used for discovery:
  `https://www.archiware.com/?awdl=Linux_Docker_awspst806.zip&awpf=synology`
- Root filesystem: `https://p5-downloads.s3.amazonaws.com/awpst806-container.tar`
- Expected size: `362757632` bytes
- Expected MD5/S3 ETag: `04255bb0decabeb9571b6f8a96911da8`
- Observed SHA-256: `be4bd961f578370c3cbc0b42aae267b1d13b5fb947eb405dafd449e3a84c467b`

The download script uses HTTPS and refuses an unexpected size or digest. These
values identify the file observed on 2026-11-05; they are not a substitute for
a vendor-published cryptographic checksum.

When Archiware publishes a newer P5 version, see
[Multiple P5 versions](#multiple-p5-versions) above — pin it alongside 8.0.6
rather than replacing it, since this project treats more than one pinned
version as a normal, supported state, not a migration to perform.

## Sharing the lab project

After committing changes, create a clean distributable archive with:

```sh
./scripts/package-project.sh
```

The resulting ZIP and SHA-256 checksum are written under `dist/`. Each tester
downloads P5 from Archiware using the included script, so the project archive
never redistributes vendor software or a configured/licensed server.

## License

P5 Local Lab is available under the [MIT License](LICENSE), matching P5 Command
Lab. Archiware P5 itself remains proprietary vendor software and is not covered
by this repository's MIT license.

