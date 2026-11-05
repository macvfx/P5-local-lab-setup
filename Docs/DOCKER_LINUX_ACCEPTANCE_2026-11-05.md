# Native Linux Docker acceptance - 2026-11-05

## Verdict

The native Intel x86-64 Linux workflow in
[`DOCKER_ALTERNATIVE.md`](DOCKER_ALTERNATIVE.md) passed its bounded acceptance
checks with Archiware P5 8.0.6. The same evidence does not accept Docker
Desktop on Apple silicon, physical tape or changer access, trial-licence host
identity stability, or multi-hour operation.

## Environment

- Host OS: Ubuntu 24.04 LTS.
- Architecture: native `x86_64`; no emulation.
- Docker: Engine 29.9.2, Compose v2, containerd v2.4.2.
- P5 source: Archiware P5 8.0.6 Linux Docker root filesystem,
  `awpst806-container.tar`.
- Vendor file: 362,757,632 bytes; MD5
  `04255bb0decabeb9571b6f8a96911da8`.
- Image: `p5-lab:8.0.6`, reported as `linux/amd64` by Docker.

## Results

| Check | Result |
| --- | --- |
| Current-release check | PASS - Archiware's download page still advertised P5 8.0.6. |
| Vendor pin | PASS - downloaded size and MD5 matched the repository pin. |
| Image import | PASS - `docker import --platform=linux/amd64` produced a `linux/amd64` image. |
| P5 start | PASS - P5 remained running for at least ten minutes. |
| Architecture | PASS - `uname -m` returned `x86_64`. |
| P5 version | PASS - `nsdchat -c srvinfo lexxvers` returned `8.0.6`. |
| HTTP and REST | PASS - the login endpoint and bounded unlicensed requests responded. |
| Fixture mount | PASS - writes below `/host_dir` appeared immediately in the dedicated host folder. |
| Stop/start | PASS - the container, P5 configuration, and fixture data survived. |
| Down/up | PASS - Compose created a fresh container while preserving the bind-mounted fixture folder. |
| Concurrency | PASS - two instances ran concurrently on ports `21000` and `21001`. |
| Cleanup | PASS - containers, image, vendor tar, and disposable fixture folders were removed. |

Each instance needed approximately 15-20 seconds for P5 startup before the
service checks were reliable. The login request returned an HTTP redirect to
P5's application login route; `curl --fail` correctly treated that redirect as
a successful response.

## Download observation

The current-release helper successfully read Archiware's official download
page. During this test, the page's `www.archiware.com/?awdl=...` link returned
HTTP 403 to a plain `curl` client. The pinned S3 root-filesystem URL used by
`scripts/download-vendor-image.sh` downloaded successfully. A normal browser
download from the vendor page was not evaluated.

The test used Linux-native file-size and checksum tools. Following this review,
`scripts/download-vendor-image.sh` was made portable across macOS and GNU/Linux
so future Linux operators can run the repository helper directly.

## Not accepted by this pass

- Docker Desktop on Apple silicon and Rosetta-based AMD64 emulation.
- Trial activation or host-ID stability after Docker lifecycle operations.
- Archive-index, plan, pool, archive, or restore workflows requiring a licence.
- Physical tape drives, changers, or `/dev/sg*` mappings.
- Multi-hour or production-load stability.
- Production use or protection of non-disposable data.
