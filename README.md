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

Reset an instance to a fresh P5 server:

```sh
./scripts/destroy-instance.sh p5-lab-02 --confirm
./scripts/create-instance.sh p5-lab-02 20001 29002
```

The destroy command refuses containers that are not labelled as P5 Local Lab
resources. It removes the container and its P5 configuration but deliberately
keeps the instance's bind-mounted source, archive, restore, and export folders.

## ContainerManager

Build the image first with `scripts/build-image.sh`. In ContainerManager choose
Stacks, add a stack, and import `P5-Local-Lab.containerstack`. Select a new,
empty instance directory such as `instances/p5-lab-01` for the lab data folder.

ContainerManager imports Compose-like definitions but is not a complete Docker
Compose implementation. This project therefore builds the image separately and
uses a small native `.containerstack` definition for runtime configuration.

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

Apple's runtime presented the writable root as a thin-provisioned 504 GB
filesystem during acceptance. That is not a reserved 504 GB allocation: its
real growth is limited by free storage on the Mac. Use a bounded sparse image
or another explicitly limited backing store when a test needs deterministic
"disk full" behaviour.

## Storage for Archive testing (plan, not yet run)

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

### Shared storage across instances (to test)

Worth testing separately: pointing two running instances at the *same* host
folder, to exercise P5 against shared storage rather than storage private to
one container. `create-instance.sh` hard-codes each instance's mount to its
own `instances/<name>` folder, so this isn't available through the script as
written — it would need either a manual `container run` invocation with an
extra `--volume <shared-host-path>:<container-path>` added, or a small
script change to accept an optional shared-mount argument. Not yet
implemented; do the per-instance local-folder setup first and come back to
shared storage as its own test once Archive configuration is working on at
least one instance.

## Vendor source

Start at Archiware's canonical
[P5 download page](https://www.archiware.com/download-p5/) and locate
**Synology 7+ or Linux Docker > New Install**. The helper below prints the
current link advertised by that page without downloading it:

```sh
./scripts/check-current-p5-download.sh
```

This project deliberately does not follow the newest P5 release automatically.
Its accepted and reproducible pin remains Archiware P5 8.0.6:

- Vendor package link used for discovery:
  `https://www.archiware.com/?awdl=Linux_Docker_awspst806.zip&awpf=synology`
- Root filesystem: `https://p5-downloads.s3.amazonaws.com/awpst806-container.tar`
- Expected size: `362757632` bytes
- Expected MD5/S3 ETag: `04255bb0decabeb9571b6f8a96911da8`
- Observed SHA-256: `be4bd961f578370c3cbc0b42aae267b1d13b5fb947eb405dafd449e3a84c467b`

The download script uses HTTPS and refuses an unexpected size or digest. These
values identify the file observed on 2026-11-05; they are not a substitute for
a vendor-published cryptographic checksum.

When Archiware publishes a newer P5 version, treat it as a new lab target. Test
the vendor package first, then update the source URL, expected size and digest,
image tag, Dockerfile label, Compose/ContainerManager references, documentation,
and dated acceptance record together. Keeping the old pin available is useful
when P5 Command Lab or another client needs regression testing against more
than one server version.

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

