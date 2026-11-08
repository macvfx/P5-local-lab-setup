# P5 REST API automation: what's manual, what's automatable

**Status:** Research notes, not yet automated. The core question — can
archive indexes, pools, and plans be *created* via REST, not just used once
someone sets them up by hand? — is answered from Archiware's own official
OpenAPI spec, and the one remaining piece (DISK pool storage) is confirmed
by a live test against a real running container, not just read from the
spec.

Sources, both first-party:

- The user's own [`macvfx/p5ArchiveManager`](https://github.com/macvfx/p5ArchiveManager)
  REST API guide (`docs/P5-REST-API-GUIDE.md`) — documents real, working
  usage against a live P5 server for checking archived status and
  submitting jobs.
- Archiware's official OpenAPI 3.0 spec for **P5 REST API v8.0.0**, fetched
  from <https://www.archiware.com/blog/redoc/p5_rest_api/P5_openapi.json>
  (the page at `.../awp5api.html` is a ReDoc viewer that loads this file;
  `blog.archiware.com`, the subdomain the manuals page links to, is not
  reachable from this session, but the same content is also served under
  `www.archiware.com/blog/...`, which is). A copy is saved at
  [`Docs/reference/P5_openapi_v8.0.0.json`](reference/P5_openapi_v8.0.0.json)
  so this doesn't depend on that URL staying up — 69 paths, 30 `POST`, 20
  `PUT`, 17 `DELETE` operations across archive, backup, backup2go, general,
  license, object-synchronize, restore, and synchronize resource groups.

## REST API basics (confirmed)

- **Base URL:** `http://<host>:<port>/rest/v1/...` (the spec's own server
  template: `http://{p5address}/rest/{version}`, version defaulting to
  `v1`). The path version does not track the server version — confirmed
  directly in the spec's `info.version: "8.0.0"` alongside `v1` paths.
- **Auth:** HTTP Basic (a P5 user's username/password).
- **Format:** JSON bodies; most resources also take header parameters for
  some fields (see Pool below) rather than everything living in the body.

## The open question, resolved: yes, plans/pools/indexes can be created via REST

Confirmed directly in the official spec:

| Resource | Create endpoint | Required fields |
| --- | --- | --- |
| Archive index | `POST /archive/indexes` | body: `name`, `description` (both required) |
| Archive plan | `POST /archive/plans` | body: `description` (required, must be unique), plus `database` (existing index name), `pool` (existing pool name), `enabled`, `deletefiles`, `deleteall` |
| Media pool | `POST /general/pools` | header: `name` (required); body: `usage` (`Archive`/`Backup`), `mediatype` (`OPTICAL`/`TAPE`/`DISK`), `blocksize`, `drivecount` |
| Client | `POST /general/clients` | body: `name` (use `"localhost"` for the local client), `hostname`, `port`, plus auth/encryption options — but P5 likely already registers a `localhost` client by default, so this may not even be needed for same-host archiving |

Real example from the spec itself for index creation:

```json
POST /archive/indexes
{
  "name": "Cloud-Archive",
  "description": "external file archive"
}
```

So the intended creation order for a from-scratch Archive setup is: pool →
index → plan (the plan references the other two by name), matching exactly
the roadmap's fictional naming (`TEST-POOL` / `Example-Archive` /
`Example-Plan`).

## Confirmed, empirically: a DISK pool's storage can't be attached via REST

Tested directly against a live `p5-lab-03` container (P5 8.0.6):

```
$ curl -u admin:admin -X POST "http://127.0.0.1:20002/rest/v1/general/pools" \
    -H "name: TEST-DISK-POOL-DELETEME" -H "Content-Type: application/json" \
    -d '{"usage":"Archive","mediatype":"DISK"}'
{"ID": "TEST-DISK-POOL-DELETEME", "links": [...]}

$ curl -u admin:admin "http://127.0.0.1:20002/rest/v1/general/pools/TEST-DISK-POOL-DELETEME"
{"mediatype": "DISK", "usage": "Archive", "usedsize": 0, "totalsize": 0,
 "enabled": true, "drivecount": 1}

$ curl -u admin:admin ".../pools/TEST-DISK-POOL-DELETEME/volumes"
[]  (empty)
```

The pool's `ID` is literally the `name` you gave it, not a separate opaque
identifier. `totalsize: 0` and an empty volume list confirm this isn't a
display quirk — the pool genuinely has zero storage attached, no path
field anywhere in its representation, and `PoolCreate`'s body schema
(`usage`, `mediatype`, `blocksize`, `drivecount`) has no path/directory
field to begin with. Combined with there being no `POST /general/volumes`
to create a volume from scratch (confirmed earlier from the static spec),
this settles it: **creating a `DISK` pool via REST registers the pool
object, but does not and cannot make it usable for archiving.** Attaching
a real filesystem directory to it needs the P5 web GUI (or possibly the
CLI) — this is not a gap in the research, it's how the API actually works.

One side effect worth noting: that test pool now exists for real on
`p5-lab-03` and can't be removed via REST (no `DELETE /general/pools/...`
in the spec). Either leave it — it's harmless and costs nothing — or
`destroy-instance.sh p5-lab-03 --confirm` and recreate it if a clean state
matters for that instance.

The manual step this leaves isn't "set up storage from nothing," though —
every container already has `/host_dir/archive` bind-mounted and ready,
from `prepare-instance-folder.sh`/`create-instance.sh`. The one manual step
per pool is pointing the DISK pool's volume at that already-existing path
in the P5 GUI, not creating storage itself.

## Confirmed: license activation and user/password management are not REST operations at all

- **License:** the `license` tag has exactly two operations, both `GET`
  (`/license/resources`, `/license/resources/{resourceID}`) — no `POST`,
  `PUT`, or `DELETE` anywhere under `license`. This isn't just this
  project's policy of keeping licensing manual (stated already in
  `MACOS_VM_P5_TEST_LAB_RESEARCH.md`) — the API genuinely has no write
  operation for it.
- **Users/passwords:** there is no `user`-tagged resource group, and no
  path containing `password` anywhere in the 69 paths, except as a field
  *on a client* (`GeneralClientCreateRequest.newpassword` — that's the
  client's own password for P5 to reach it, not the P5 admin account's
  login). Initial login and changing the P5 admin password stay manual;
  this API doesn't expose that at all, as far as this spec shows.

## For each freshly created P5 container: manual vs. automatable (updated)

| Step | Manual or automatable? | Notes |
| --- | --- | --- |
| Local storage folders (source/archive/restore) | **Already automated** | `prepare-instance-folder.sh`, no P5 REST involved. |
| First login with the default admin account | **Manual — confirmed, not a REST gap** | No user/session-login endpoint exists in the spec at all. |
| Changing the admin password | **Manual — confirmed, not a REST gap** | Same; no endpoint. |
| Demo/trial license activation | **Manual — confirmed, not a REST gap, and project policy either way** | `license` is read-only in the spec. |
| Creating a media pool's parameters | **Automatable, confirmed** | `POST /general/pools` — tested live, works. |
| Attaching real disk storage to that pool | **Manual — confirmed empirically, not a research gap** | Tested live: the created pool has `totalsize: 0` and an empty volume list; no REST path exists to attach a directory or create a volume. GUI/CLI only. |
| Creating an archive index | **Automatable, confirmed** | `POST /archive/indexes` — `name` + `description`. |
| Creating an archive plan | **Automatable, confirmed** | `POST /archive/plans` — references the pool and index by name. |
| Creating metadata keys on an index | **Automatable, confirmed** | `POST /archive/indexes/{index}/keys`. |
| Listing clients, plans, indexes, jobs | **Automatable, confirmed** | Plain `GET`, no side effects. |
| Submitting an archive job | **Automatable, confirmed** | `POST /archive/plans/{planID}/archiveselections`. |
| Monitoring a submitted job | **Automatable, confirmed** | `GET /general/jobs/{id}` (+ `/report`, `/protocol`, `/inventory`). |
| Checking whether a file is already archived | **Automatable, confirmed** | Walk `GET /archive/indexes/{index}/inventory/{path}`. |

## Quick reference

| Purpose | Method & endpoint |
| --- | --- |
| Create a media pool | `POST /general/pools` (header `name`) |
| Create an archive index | `POST /archive/indexes` |
| Create an archive plan | `POST /archive/plans` |
| Create index metadata keys | `POST /archive/indexes/{index}/keys` |
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

One quirk worth carrying over for any lab automation that compares names
(from `p5ArchiveManager`'s guide, not the OpenAPI spec): P5 encodes certain
special characters in archived names/paths as **caret + two hex digits**
(`^XX`) — the REST API returns the encoded form, while the web GUI decodes
it for display. Decode `^XX` sequences before comparing API-returned names
against names on disk.

## What this means for the lab, right now

- Container storage setup is already automated.
- Login, password change, and license activation are confirmed-manual —
  not because of missing research, but because the API genuinely has no
  operations for them.
- Pool → index → plan creation is confirmed automatable via REST, except
  attaching a `DISK` pool's actual storage directory — confirmed manual by
  live test against a real container, not just absent from the static
  spec. That one step points the pool at a path (e.g. `/host_dir/archive`)
  that the container tooling already provisions; it isn't "set up storage
  from nothing."
- Once a plan/index/pool exist, archive-job submission, monitoring, and
  archived-status checking are all provably automatable, using exactly the
  endpoints `p5ArchiveManager` already relies on in production.
- For demoing **P5 Command Lab**: point it at a lab container's REST port
  with Basic auth, same as any other client — the lab containers created so
  far (via `create-instance.sh` / `create-instances.sh`) are already
  suitable targets once a plan exists on each, and that plan/pool/index
  setup is now a scriptable step rather than a GUI-only one (modulo the
  disk-path gap above).
