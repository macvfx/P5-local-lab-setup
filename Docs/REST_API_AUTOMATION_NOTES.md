# P5 REST API automation: what's manual, what's automatable

**Status:** Research notes, not yet implemented. Grounded in the user's own
first-party [`macvfx/p5ArchiveManager`](https://github.com/macvfx/p5ArchiveManager)
REST API guide (`docs/P5-REST-API-GUIDE.md`), which documents real, working
usage against a live P5 server — not guessed or invented endpoints, per the
caution already stated in
[`MACOS_VM_P5_TEST_LAB_RESEARCH.md`](MACOS_VM_P5_TEST_LAB_RESEARCH.md).
One real gap remains open: see "Unconfirmed" below.

## REST API basics (confirmed)

- **Base URL:** `http://<host>:<port>/rest/v1/...`. The path version (`v1`)
  does not track the server version — a P5 8.x server still uses `v1`.
- **Auth:** HTTP Basic (a P5 user's username/password).
- **Format:** JSON bodies. List endpoints generally also take an `/{id}`
  suffix for a single item.
- **Read vs. write:** almost everything useful for a client app is `GET`
  (browsing indexes, clients, plans, jobs). The one write pattern
  `p5ArchiveManager` actually uses is submitting an archive job against an
  **already-configured** plan — it does not create plans, pools, or
  indexes from scratch.

This matches exactly what a demo of **P5 Command Lab** needs at the basic
level: Basic auth against `http://<lab-instance-ip>:<rest-port>/rest/v1/`,
read the configured clients/plans/indexes to show real data, and — if the
demo calls for it — submit one real archive job live and poll it to
completion.

## For each freshly created P5 container: manual vs. automatable

| Step | Manual or automatable? | Notes |
| --- | --- | --- |
| Local storage folders (source/archive/restore) | **Already automated** | `prepare-instance-folder.sh` already creates these at container-creation time; not a P5 REST concern at all. |
| First login with the default admin account | Manual, for now | Default credentials exist, but whether P5 exposes a REST path usable *before* any password change is unconfirmed — see below. |
| Changing the admin password | Manual, for now | No endpoint for this appears in `p5ArchiveManager`'s guide; that app never needed to change a password, so absence here isn't proof it doesn't exist — just unconfirmed. |
| Demo/trial license activation | **Manual by project policy**, regardless of REST feasibility | `MACOS_VM_P5_TEST_LAB_RESEARCH.md` already states this explicitly: "confirm the trial-licence rules... before automating any licensed clone lifecycle." Keep this a human-confirmed step even if a licensing endpoint exists. |
| Creating an archive index | **Unconfirmed** | Not covered by `p5ArchiveManager`'s guide (it only lists/queries existing indexes). See "Unconfirmed" below. |
| Creating a disk storage pool | **Unconfirmed** | No mention of pools anywhere in that app's docs at all — it only reads a plan's `pool` attribute as a name, never creates one. |
| Creating an archive plan | **Unconfirmed** | Same gap — the guide lists/reads plans, never creates one. |
| Creating metadata keys on an *existing* index | **Automatable, confirmed** | `POST /archive/indexes/{index}/keys` — but this presumes the index already exists. |
| Listing clients, plans, indexes, jobs | **Automatable, confirmed** | All plain `GET`, no side effects. |
| Submitting an archive job against an existing plan | **Automatable, confirmed** | `POST /archive/plans/{planID}/archiveselections` — see the quick reference below. |
| Monitoring a submitted job | **Automatable, confirmed** | `GET /general/jobs/{id}` (+ `/report`, `/protocol`, `/inventory`). |
| Checking whether a given file is already archived | **Automatable, confirmed** | Walk `GET /archive/indexes/{index}/inventory/{path}` for the local path in question; no cross-index search endpoint exists. |

## Unconfirmed: can plans/pools/indexes be created via REST at all?

This is the one real open question, and it matters a lot for the "automate
setting up a bunch of P5 containers" goal — if the answer is no, archive
index/pool/plan creation stays a one-time manual step per container
regardless of how much else gets automated.

`p5ArchiveManager`'s guide doesn't answer this because that app was built
to *use* already-configured plans, not provision them — the absence of a
create endpoint in its guide is not evidence the API lacks one. The
authoritative source is Archiware's own published reference:

<https://blog.archiware.com/redoc/p5_rest_api/awp5api.html>

This session could not reach `blog.archiware.com` to check it directly —
that host isn't on this cloud session's allowed network list. Check it
directly (or allow that host in this session's settings and ask again) for
whether `POST /archive/indexes`, `POST /archive/plans`, or an equivalent
pool-creation endpoint exists before assuming index/pool/plan setup can be
scripted.

## Quick reference (from `p5ArchiveManager`'s guide)

| Purpose | Method & endpoint |
| --- | --- |
| List archive indexes | `GET /archive/indexes` |
| Browse an index's inventory | `GET /archive/indexes/{index}/inventory/{path}` |
| Resolve a volume (label, barcode, location) | `GET /general/volumes/{id}` |
| List clients | `GET /general/clients` (+ `/{id}`) |
| List archive plans | `GET /archive/plans` (+ `/{id}`) |
| Submit an archive job | `POST /archive/plans/{planID}/archiveselections` |
| Job status | `GET /general/jobs/{id}` |
| Job report (text) | `GET /general/jobs/{id}/report` |
| Job protocol (json/xml) | `GET /general/jobs/{id}/protocol` |
| Job inventory (file list) | `GET /general/jobs/{id}/inventory` |
| Create index metadata keys | `GET`/`POST /archive/indexes/{index}/keys` |

One quirk worth carrying over for any lab automation that compares names:
P5 encodes certain special characters in archived names/paths as
**caret + two hex digits** (`^XX`) — the REST API returns the encoded
form, while the web GUI decodes it for display. Decode `^XX` sequences
before comparing API-returned names against names on disk.

## What this means for the lab, right now

- Container storage setup is already automated (step 1 of the registry
  work applies here too — nothing new needed).
- Login, password change, and license activation stay manual per
  container until the open question above is resolved — and license
  activation stays manual regardless, by existing project policy.
- Once a plan/index/pool exist on a container (by whatever means), the
  actual archive-job submission, monitoring, and archived-status checking
  are already provably automatable, using exactly the endpoints
  `p5ArchiveManager` already relies on in production.
- For demoing **P5 Command Lab** specifically: point it at a lab
  container's REST port with Basic auth, same as any other client — the
  lab containers created so far (via `create-instance.sh` /
  `create-instances.sh`) are already suitable REST targets once a plan
  exists on each.
