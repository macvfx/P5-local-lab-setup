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

- `P5_LAB_MEDIA` with `scripts/create-instances.sh` (batch creation); stub
  runtime only.
- Two or more instances reading the same media folder at the same time.
- Restore of the archived media and verification against the originals.
- Media on network or removable volumes, where not already covered by the
  run above.
- Stop/start and behaviour when the media volume is unavailable at start.
- ContainerManager stack template and Docker Compose equivalents.
- Throughput or large-file performance through the read-only mount.
