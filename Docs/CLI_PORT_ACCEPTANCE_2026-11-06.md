# P5 Local Lab CLI port acceptance - 2026-11-06

## Scope

This addendum verifies the new host-side mapping for P5's CLI/awsock service.
It supplements rather than rewrites the original
[`ACCEPTANCE_2026-11-05.md`](ACCEPTANCE_2026-11-05.md) record.

## Environment

- Apple silicon test Mac; exact private host inventory is intentionally omitted.
- Apple `container` client and server 1.6.1.
- Archiware P5 8.0.6 using the repository's verified AMD64 vendor image.
- Rebuilt local image `p5-lab:8.0.6`, wrapper revision 2.
- Managed instance `p5-lab-01` recreated from the rebuilt image.
- The existing bind-mounted fixture directory was preserved; the old
  container's writable P5 configuration layer was removed.

## Published ports

- `127.0.0.1:20000` to container REST/web port `8000/tcp`.
- `127.0.0.1:29001` to container CLI/awsock port `9001/tcp`.

Both mappings remain restricted to localhost.

## Results

- PASS - the recreated container ran as `linux/amd64` under Rosetta.
- PASS - the existing host-visible fixture marker remained available through
  the dedicated `/host_dir` mount.
- PASS - internal `nsdchat -c srvinfo lexxvers` returned `8.0.6`.
- PASS - the P5 login endpoint responded on host port `20000`.
- PASS - a host-side TCP probe connected to CLI/awsock host port `29001`.
- PASS - image metadata declares both `8000/tcp` and `9001/tcp` and identifies
  wrapper revision 2.

## Remaining checks

- An authenticated remote `nsdchat` command through host port `29001` was not
  placed in the automated smoke test because credentials must not appear in
  repository fixtures or command output.
- P5 Command Lab should be tested with host `127.0.0.1`, REST port `20000`,
  nsdchat port `29001`, and **Remote over awsock** selected.
- The updated ContainerManager template was JSON-validated but not imported
  through the ContainerManager UI in this pass.
- The updated Docker Compose mapping was statically validated but not run on
  native Linux or Docker Desktop in this pass.
