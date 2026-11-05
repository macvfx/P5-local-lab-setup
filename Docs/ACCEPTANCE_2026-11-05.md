# P5 Local Lab acceptance - 2026-11-05

## Environment

- Host: Apple silicon, macOS 27.2 (build 26B123), 8 logical CPUs.
- Apple `container`: client and server 1.6.1, commit
  `aa8d76b44a834eee3ebf6a0bc577e376f65f6361`.
- ContainerManager: 1.1.2 (build 4).
- Archiware P5: official 8.0.6 Linux Docker root filesystem.
- Vendor file: 362,757,632 bytes; MD5
  `04255bb0decabeb9571b6f8a96911da8`; SHA-256
  `be4bd961f578370c3cbc0b42aae267b1d13b5fb947eb405dafd449e3a84c467b`.
- Local OCI image: `p5-lab:8.0.6`, `linux/amd64`, manifest-list digest
  `sha256:31d4e0d01471ed7a737e24f23e0ff07114a134efe12852be4ff5a280e7fdf853`.

## Instance

- Name: `p5-lab-01`.
- Published endpoint: `127.0.0.1:20000` to container port `8000`.
- Resources: 4 CPUs, 4 GiB memory limit.
- Host mount: only `instances/p5-lab-01` at `/host_dir`.
- Platform: `linux/amd64` with Rosetta enabled.
- No tape devices, Mac root mount, trial activation, or P5 login was used.
  A licence is not required for the read-only REST and CLI checks targeted by
  this first milestone.

## Results

- PASS - P5 started under Rosetta and `uname -m` returned `x86_64`.
- PASS - `/usr/local/aw/bin/nsdchat -c srvinfo lexxvers` returned `8.0.6`.
- PASS - <http://127.0.0.1:20000/login> responded.
- PASS - A host fixture in `/host_dir/source` was visible inside P5's
  container.
- PASS - A marker in the container's `/usr/local/aw` writable layer survived a
  graceful stop and restart.
- PASS - The login service returned after restart.
- PASS - ContainerManager imported and retained the
  `P5-Local-Lab.containerstack` template. Creation was cancelled, so no
  duplicate stack or container was made.

## Storage observation

The running container reported:

```text
Filesystem      Size  Used Avail Use% Mounted on
/dev/vdb        504G  360M  504G   1% /
/dev/vdb        504G  360M  504G   1% /usr/local/aw
virtiofs        927G  877G   50G  95% /host_dir
```

The 504 GB root is thin-provisioned rather than a reserved fixed-size lab disk.
At the time of the test, P5 used about 231 MB of its 4 GiB memory limit. A
separate bounded backing store is still required for deterministic capacity and
disk-full tests.

## Not yet accepted

- Manual P5 sign-in and password change.
- REST authentication and unlicensed read-only recipes from P5 Command Lab.
- Optional 5- or 30-day trial request through **Home > License Manager > Get
  Trial License**. The trial is fully functional and bound to the container's
  displayed host ID.
- Creation of Archive indexes, plans, pools, or disk volumes.
- Archive and restore of fixture data.
- Two simultaneous P5 instances.
- Reset/delete/recreate workflow.
- Physical tape or changer access.
