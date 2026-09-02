# Changelog

## 0.66.x

- Throw physics: fling the avatar and he flies with your hand's velocity,
  bounces off walls and floor, and lands facing his travel.
- Plugin id renamed to `higgsfield-omagotchi`; the data directory migrates
  itself on first start and stale stored paths heal on every launch.
- The avatar archive repoints atlases at the sheet beside them, so moving
  the data directory can never blank the carousel again.

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
