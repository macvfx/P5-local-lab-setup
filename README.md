# P5 Local Lab

P5 Local Lab is a disposable local test environment for Archiware P5 on Apple
silicon Macs. It converts Archiware's official Linux Docker root filesystem
into a local OCI image and runs the Intel/AMD64 P5 build with Apple's Rosetta
container support.

The first milestone is deliberately narrow: prove that one P5 8.0.6 server can
start, expose its web and REST interface on localhost, see a dedicated fixture
folder, and survive a normal stop/start cycle. It does not configure a trial
license, create P5 plans, or expose physical tape devices.

That milestone passed on 2026-11-05. See
[`Docs/ACCEPTANCE_2026-11-05.md`](Docs/ACCEPTANCE_2026-11-05.md) for the exact
environment and results.

## Safety boundaries

- The P5 port binds to `127.0.0.1`, not every network interface.
- Only an instance-specific directory is mounted at `/host_dir`.
- The Mac's root filesystem is never mounted into P5.
- Vendor binaries are downloaded from Archiware and are not committed here.
- The scripts operate only on explicitly named instances.
- Deleting a container deletes P5 configuration stored in its writable layer;
  the bind-mounted fixture folders remain on the Mac.

## Requirements

- Apple silicon Mac running macOS 26 or later.
- Apple `container` CLI and services.
- Rosetta support for `linux/amd64` containers.
- ContainerManager is optional but supported through
  `P5-Local-Lab.containerstack`.
- Review and accept Archiware's software licence before using P5. Trial
  activation remains a manual action inside P5.

## Quick start

Run each step from this directory:

```sh
./scripts/preflight.sh
./scripts/download-vendor-image.sh
./scripts/build-image.sh
./scripts/create-instance.sh p5-lab-01 20000
./scripts/smoke-test.sh p5-lab-01 20000
./scripts/status.sh p5-lab-01
```

Then open <http://127.0.0.1:20000/login> and complete the vendor's first-run
steps. Do not clone or commit an activated P5 installation: Archiware licensing
uses a host identity.

Stop and restart the instance without deleting its writable filesystem:

```sh
./scripts/stop-instance.sh p5-lab-01
./scripts/start-instance.sh p5-lab-01
```

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

## Vendor source

The pinned source is Archiware P5 8.0.6:

- Root filesystem: `https://p5-downloads.s3.amazonaws.com/awpst806-container.tar`
- Expected size: `362757632` bytes
- Expected MD5/S3 ETag: `04255bb0decabeb9571b6f8a96911da8`
- Observed SHA-256: `be4bd961f578370c3cbc0b42aae267b1d13b5fb947eb405dafd449e3a84c467b`

The download script uses HTTPS and refuses an unexpected size or digest. These
values identify the file observed on 2026-11-05; they are not a substitute for
a vendor-published cryptographic checksum.

