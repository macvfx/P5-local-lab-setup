# Path C: macOS VM Tart Setup

**Status:** Written setup steps and helper scripts, not yet executed or
accepted. No golden image, clone, or P5 installation inside a Tart guest has
been run or recorded yet. This implements the Phase 0/1 steps of
[`MACOS_VM_P5_TEST_LAB_RESEARCH.md`](MACOS_VM_P5_TEST_LAB_RESEARCH.md) for the
Apple-silicon VM host; it does not add Packer, licensing, or Archive
automation.

Parallels is intentionally out of scope for this document. Keep it as the
separate vendor-reproduction lane described in the research doc.

## What is scripted and what stays manual

The deterministic, checkable parts of host setup are scripted:
tool installation, Apple-silicon and free-space gates, and pulling or cloning
each golden base image. These are safe to automate because each one either
succeeds outright or refuses clearly with a reason.

Completing Setup Assistant, installing OS updates inside a guest, and
confirming the guest agent stay manual on purpose, matching the research
doc's own phasing: "Add Packer only after both manual guests boot and have
working networking." A first-boot macOS install involves interactive Apple
ID/iCloud prompts, EULA acceptance, and licence-identity state that should be
seen and confirmed by a person before anything scripts around it. Automate
that step later, with Packer, only after this manual path has been proven on
both golden images.

## Prerequisites

Confirm before running anything:

```sh
sw_vers
df -g /
```

The Apple-silicon VM host should be on macOS 27 (for Tart's stacked-clone
storage sharing) with at least 150GB free. The preflight script re-checks
both, but review them yourself first, especially disk space, since base
images and overlays grow quickly.

## 1. Preflight

```sh
./scripts/tart-preflight.sh
```

This script:

- Confirms the host is Apple silicon.
- Reports the host macOS version and warns (without failing) if it is below
  macOS 27, since stacked clones need macOS 27 and earlier hosts will fall
  back to full-copy clones.
- Installs Homebrew non-interactively if `brew` is not already on `PATH`.
- Installs Tart with Homebrew if `tart` is not already present.
- Refuses to continue if free space on `/` is below `TART_MIN_FREE_GB`
  (default `150`; override by exporting that variable).

Re-run it any time; it is idempotent and safe to run again after it fails.

### Troubleshooting: `brew install cirruslabs/cli/tart` fails with a `depends_on`/`on_macos` error

The `cirruslabs/homebrew-cli` tap carries an unwrapped
`depends_on :macos => :ventura` line in more than one formula — confirmed in
both `tart.rb` and its own dependency `softnet.rb` on the tap's `master`
branch. Current Homebrew treats that old hash-rocket syntax as a hard error
instead of a warning, and `brew update` alone does not fix it — this is a
real bug in the tap, not a stale local cache, and patching a single formula
is not enough since the bug recurs across the tap's formulas.

The script now works around this in two steps:

1. After a plain `brew install cirruslabs/cli/tart` fails, it sweeps every
   `.rb` file in the local tap checkout, deletes that exact line wherever it
   appears, and retries the install once. That line is redundant anyway —
   each affected formula has a separate plain `depends_on :macos` with no
   version requirement. These edits are local to your Homebrew tap checkout
   and may be reverted (or skipped with a warning) the next time you run
   `brew update`; the script simply reapplies them again on its next run if
   needed.
2. If Homebrew still cannot install Tart, the script looks for an existing
   `/Applications/tart.app` or `~/Applications/tart.app` (from a manual
   release-archive install) and symlinks its binary onto `PATH` at
   `/opt/homebrew/bin/tart` instead of continuing to fight the tap.

To apply the tap fix by hand instead:

```sh
TAP_DIR=$(brew --repository cirruslabs/cli)
grep -rl 'depends_on :macos => :ventura' "$TAP_DIR"/*.rb | while read -r f; do
    sed -i '' '/depends_on :macos => :ventura/d' "$f"
done
brew install cirruslabs/cli/tart
```

If Homebrew still won't install Tart, or you'd rather skip it entirely,
install from a release archive instead:

1. Download the current release for your architecture from
   <https://github.com/cirruslabs/tart/releases/latest> (confirm the exact
   asset name there; it is not pinned in this document).
2. Extract it so `tart.app` ends up in `/Applications` (or
   `~/Applications`).
3. Symlink the binary inside the app bundle onto `PATH`:

   ```sh
   mkdir -p /opt/homebrew/bin
   ln -sf /Applications/tart.app/Contents/MacOS/tart /opt/homebrew/bin/tart
   tart --version
   ```

   Always run the binary from inside the app bundle, not a bare extracted
   binary — that path carries the embedded provisioning profile that Tart's
   Bridged networking needs.

## 2. Pull or clone the golden base images

Confirm the exact image reference against Cirrus Labs' current registry
listing before pulling — tags change between releases and should not be
assumed from this document.

```sh
./scripts/tart-pull-golden-image.sh macos15-golden ghcr.io/cirruslabs/macos-sequoia-base:latest
./scripts/tart-pull-golden-image.sh macos26-golden ghcr.io/cirruslabs/macos-tahoe-base:latest
```

The script refuses to run if a VM already exists under that golden name
(checked via `~/.tart/vms/<name>`), so it will not silently overwrite a
golden image you already built or hardened.

If no suitable prebuilt base exists for your target release, build one from
an IPSW instead and skip straight to step 3:

```sh
tart create --from-ipsw=latest macos15-golden
```

## 3. Finish each golden image manually

The pull/clone script prints these steps; they are repeated here for
reference. Run this once per golden image:

```sh
tart run macos15-golden
```

While it boots:

1. Complete Setup Assistant using a dedicated, fictional automation account —
   never a production Apple ID or real identity.
2. Install current OS updates for that release, disk space and update
   personalization permitting (see the known limitation below).
3. Confirm the Tart guest agent is present and responding.
4. Do **not** install P5, an activated licence, or any credential into this
   image. It stays unlicensed and clean, per the research doc's warning
   against ever activating or cloning an activated golden image.

```sh
tart stop macos15-golden
```

Repeat for `macos26-golden`. From this point, treat both golden images as
read-only: never boot them directly for a test again, only clone from them.

### Known limitation: `macos15-golden` is pinned at 15.7.7

In-place Software Update from 15.7.7 to 15.8.2 repeatedly failed on this
guest with "Failed to personalize the software update," including after
clearing `/Library/Updates`, confirming guest clock accuracy, and fetching
the full installer instead of the incremental OTA delta. This was accepted
as a known limitation rather than pursued further, since in-place updates on
a virtualized macOS guest carry a real risk of leaving the guest
non-bootable, and `macos15-golden` already had real configuration work done
on it (admin password change, new standard user, time zone). A
pre-update clone was kept and restored to recover a known-good state after
the failed attempts.

Before relying on `macos15-golden` for anything OS-version-sensitive, check
whether Cirrus Labs has republished `macos-sequoia-base` at a newer patch
level (`tart pull ghcr.io/cirruslabs/macos-sequoia-base:latest` and compare
versions) or rebuild the golden image directly from a current IPSW
(`tart create --from-ipsw=latest`) rather than attempting another in-place
update on this image.

```sh
tart list
```

Confirm both `macos15-golden` and `macos26-golden` appear.

### Known limitation: no Tart guest agent in these base images; use SSH instead

`tart exec` failed against a clone of `macos26-golden` with exit code `125`
(an RPC-connection failure, not a command-not-found error from inside the
guest). Tart's own documentation notes the guest agent ships only in
"non-vanilla" Cirrus Labs images; `macos-sequoia-base` and
`macos-tahoe-base` do not appear to include it, and there is no host-side
command to install it retroactively.

This does not block testing. Remote Login (SSH) is pre-enabled on both
golden images, so use SSH instead of `tart exec` for any scripted
interaction with a clone:

```sh
tart ip p5-test-clone-01
ssh <username>@<ip-from-above>
```

`tart ip` does not depend on the guest agent, only `tart exec` does.

## 4. Disposable test clone lifecycle

Not yet wrapped in a script, since this is where P5 installation and the
milestone's acceptance checks attach. Repeat per test run:

```sh
tart clone macos15-golden p5-test-clone-01
tart run p5-test-clone-01 &
tart ip p5-test-clone-01
tart exec p5-test-clone-01 -- sw_vers
tart stop p5-test-clone-01
tart delete p5-test-clone-01
```

On a macOS 27 host with a local base already pulled, the clone is a stacked
overlay: it shares the golden base's blocks and only grows with what the
clone itself writes, so this cycle is cheap to repeat.

## Next steps, not yet done

- Wrap the clone/test/delete cycle in a script once P5 installation and the
  milestone's REST/CLI checks are defined for a Tart guest.
- Add Packer only after both golden images have booted cleanly and networking
  has been confirmed manually, per the research doc.
- Record a dated acceptance result (environment, Tart version, image
  references, pass/fail) once the first clone successfully runs P5, mirroring
  [`ACCEPTANCE_2026-11-05.md`](ACCEPTANCE_2026-11-05.md).
