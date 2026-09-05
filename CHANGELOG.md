# Changelog

## 0.67.1 — result downloads bound to Higgsfield hosts

- Generated-media downloads now validate the hostname of the initial URL and
  of every redirect hop against a documented allowlist — `higgsfield.ai` (and
  subdomains) plus Higgsfield's two CloudFront distributions — with IP-literal
  destinations rejected and redirects capped at three hops. A URL outside the
  set fails closed before any request is made. The CLI downloader applies the
  same per-hop revalidation against its GitHub allowlist.

## 0.67.0 — security hardening (marketplace review)

- Nothing installs at load time: the pinned CLI release (sha256 embedded in
  the repo) and hash-locked Python deps download only after an explicit
  generation action, https-only, size-capped, atomically published, with
  strict tar filtering and no PATH fallback — only the verified bundled
  binary ever runs.
- No input-device access: the evdev key-watcher and its `input`-group
  requirement are gone; activity comes from focused-window changes.
- No shell-config edits: the bar-chip self-registration is removed; the
  widget is added from Omarchy's own bar settings.
- Login probe reads non-secret account-status JSON; the token never enters
  the plugin process. Workspace selection is never guessed across multiple
  workspaces.
- IPC surface reduced to care actions and toggles; camera, file paths,
  login, and paid generation are panel-only.
- Data at rest: 0700 data dir, 0600 files, symlink refusal, no persisted
  signed URLs, query strings stripped from logs.

## 0.66.x

- Throw physics: fling the avatar and he flies with your hand's velocity,
  bounces off walls and floor, and lands facing his travel.
- Plugin id renamed to `higgsfield-omagotchi`; the data directory migrates
  itself on first start and stale stored paths heal on every launch.
- The avatar archive repoints atlases at the sheet beside them, so moving
  the data directory can never blank the carousel again.
- A clean install finishes starting up: the last call to the long-removed
  readJsonFile aborted startup partway, so a fresh machine never installed
  the CLI it needs and got no data directory at all.
- Being logged out is recognised as being logged out. The probe read the
  CLI's help text as a session, so a machine with no credentials offered to
  generate instead of offering to log in.

## 0.65.0

- Script test suite (`test/test_scripts.py`): background-repair guards and
  the avatar archive, wired into CI alongside the model tests.
- `scripts/uninstall.sh` removes everything the plugin ever wrote.
- Widget search aliases (pet, tamagotchi, omagotchi).

## 0.64.x

- The bundled default pet is a permanent carousel entry — generating a
  custom avatar no longer makes him unreachable.
- Renamed to **Higgsfield Omagotchi**.
- First-run rehearsal hook (`ignore-system-cli`) for machines that already
  have the Higgsfield CLI.
- Degraded states surfaced honestly: CLI install narrates progress, failed
  installs land in the error text, login/setup no longer masquerades as
  generation, media errors are classified like avatar errors.
- Dead code sweep: dialog fallback files, write-only members, orphan helpers.

## 0.63.x

- Uniform wrong-color backgrounds (black/gray/pink) are flood-repaired to
  the chroma key instead of burning rerolls; collisions and gradients still
  reroll. The base sprite is repaired before scale guards measure it.
- Repo polish: single source of truth for media references, wrapped prompt
  placeholder, README caught up with the tabbed panel.

## 0.62.x

- Dropdown redesigned around the tabbed mock: Pet tab with avatar carousel,
  tiered stat bars, pixel-icon control bar, Release/Hide pills; Generate tab
  with per-type ratio/duration, multi-reference dropzone, and price on the
  button.
- Video previews render from a hidden thumbnail dir so the media folder
  holds only actual creations.

## Earlier

- Avatar archive with switching, in-flow frame regeneration with retry
  coaching, live webcam viewfinder, generate-media with credits and price,
  care stats, drag/fall physics, music dancing, and the original
  photo-to-sprite-sheet pipeline.
