# Read-only source media mount acceptance - 2026-11-09

## Verdict

`scripts/create-instance-with-media.sh` passed its first run on Apple's
`container` runtime. One instance was created with a host media folder
mounted read-only, the smoke test passed, P5 showed the media directory, and
an Archive job was run against it.

This record is **operator-reported**: the results below were reported by the
operator after the run. Command output, runtime versions, and job details
were not captured, so the Environment section is incomplete. Fill it in, or
repeat the run and capture evidence, before treating this as equal to the
dated records that include exact versions.

## Environment

- Host: Apple silicon Mac running Apple's `container` runtime (Path A).
- Script: `scripts/create-instance-with-media.sh` as merged in pull request
  #12.
- Not recorded: macOS version, `container` client/server version, P5
  version and image tag, instance name and ports, media folder location
  (internal or external volume), and container mount target (default
  `/media` unless `P5_LAB_MEDIA_TARGET` was set).

## Results

| Check | Result |
| --- | --- |
| Instance creation with media folder | PASS - the script completed. |
| Mount visible in the container | PASS - the script's built-in check passed. |
| Mount read-only | PASS - the script's built-in write probe was rejected; the script exits with an error otherwise. |
| Smoke test | PASS - `scripts/smoke-test.sh` passed for the instance. |
| P5 sees the media | PASS - P5 showed the source media directory. |
| Archive job | PASS - an Archive job was tested with the mounted media. |

## Not accepted by this pass

- Smoke tests and Archive jobs on the batch-created instances (see the
  addendum below); only their creation was reported.
- Two or more instances reading the same media folder at the same time.
- Restore of the archived media and verification against the originals.
- Media on network or removable volumes, where not already covered by the
  run above.
- Stop/start and behaviour when the media volume is unavailable at start.
- ContainerManager stack template and Docker Compose equivalents.
- Throughput or large-file performance through the read-only mount.

## Addendum: batch creation and port checks (2026-11-09)

Also operator-reported, on the same host, later the same day.

- FAIL (before the fix) - `P5_LAB_MEDIA=<folder> ./scripts/create-instances.sh 2`
  with `p5-lab-01` to `p5-lab-04` present chose `p5-lab-05` on REST `20004`
  and CLI `29005`. A running instance outside the numbering,
  `p5-lab-04-media`, already held those ports. `container run` failed with
  `Address already in use (errno: 48)`. No container was left behind, but
  the empty `instances/p5-lab-05` folders were.
- Fix - the create scripts now check both host ports before preparing the
  instance folder, and the batch script skips a number whose port is busy.
- PASS (after the fix) - the same command completed and created the
  requested instances on the next free ports, each with the media folder
  mounted read-only. The script's built-in visibility and write-probe checks
  run for every instance and stop the batch on failure.

Not recorded: the names and ports of the instances created, and whether
`scripts/smoke-test.sh` was run against them.

## Addendum: `--help`, `--next` and stopped-container ports (2026-11-09)

Also operator-reported, on the same host.

- Host state at the time, from `container list --all`: `p5-lab-01`,
  `p5-lab-04-media`, `p5-lab-06` and `p5-lab-07` running; `p5-lab-02`,
  `p5-lab-03` and `p5-lab-04` stopped; no `p5-lab-05`.
- PASS - `container inspect p5-lab-01` reports ports as
  `"hostPort" : <number>` under `publishedPorts` and the state as
  `"state" : "running"` under `status`, which are the fields
  `scripts/common.sh` reads. `container list --all` reports the other state
  as `stopped`.
- PASS - `./scripts/create-instance.sh --next` created the next instance
  with the correct name and ports.
- PASS - `./scripts/create-instance-with-media.sh <folder> --next` did the
  same, with the media folder mounted read-only.

Not recorded: the `--help` table as displayed, the names and ports of the
two instances created, and their smoke-test results. Refusal of explicit
ports that belong to a stopped container was exercised against a stub
runtime only.
