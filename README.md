# Higgsfield Omagotchi

A tiny 8-bit you, living on your desktop.

He walks along the bottom of whatever window you're working in, perks up
while you work, naps when the desktop goes quiet, and dances when your
music plays. Feed
him, wash him, drag him around — drop him from too high and he takes a
tumble, dusts himself off, and sulks until you clean him up. Click to pet,
double-click to flop.

The plugin ships with a default avatar, so he's on your desktop the moment you
install — no account, no setup. When you're ready, one photo turns him into
*you*: Higgsfield draws a full 8-bit sprite sheet of your likeness — walking,
sleeping, dancing, collapsing — and every avatar you generate stays in a
carousel you can switch between anytime.

## Install

```sh
omarchy plugin add git@github.com:higgsfield-ai/omagotchi.git --enable
omarchy-restart-shell
```

Update later with:

```sh
omarchy plugin update higgsfield-omagotchi --yes
```

The Higgsfield logo appears as a chip on the right of the bar; if it does
not, add **Higgsfield Omagotchi** from Omarchy's bar settings — the plugin
never edits the shell configuration itself.

Nothing is downloaded at install or load time. The first time you press
**Use photo** or **Generate**, the plugin fetches one pinned Higgsfield CLI
release (its sha256 ships in this repository) and hash-locked Python image
libraries into `~/.local/share/higgsfield-omagotchi`. Omarchy already has
`ffmpeg`.

## Living with him

Click the Higgsfield logo to open the panel. The **Avatar** tab is home: care actions
(**Feed / Wash / Play**), an activity dial (**Stand / Walk / Run**), his
vitals — hunger, hygiene, mood, energy and friends, each with its own bar —
and **Release / Hide** to let him roam the desktop or tuck him away in the
panel. Neglect shows: stats drift down over time, and a scruffy, hungry avatar
acts like one.

He also has a life of his own. He walks as windows come and go, sleeps
when the desktop goes quiet, dances when media plays, watches a tiny laptop
while your generations run, and announces the results in a speech bubble.

## Making him you

1. On the **Avatar** tab, press **+** next to the avatar. The camera opens.
2. **Capture** a frame — or **Upload** a photo instead.
3. Press **Use photo**. The first time, a browser opens to log in to
   Higgsfield; log in and press **Use photo** again.
4. Watch the progress in the panel (or close it — the bar chip counts
   along). A full run renders 18 short video clips and takes a few minutes.

When it's done, the new avatar takes over and the old one — including the
original default avatar — waits in the carousel. Flick through with the side
thumbnails and **›**.

If a run fails, the panel says why in plain words (out of credits, plan
limits, a bad frame streak) and **Retry** restarts the whole flow. Logs live
at `~/.local/share/higgsfield-omagotchi/generate.log`.

## The Generate tab

A pocket-sized Higgsfield studio: pick **Image** or **Video**, a ratio, a
duration, type a prompt, optionally pin reference images (up to 50), and
generate. The price in credits sits right on the button. The result lands in
`~/.local/share/higgsfield-omagotchi/media`, and clicking the preview opens
that folder. Your avatar works the laptop while the job runs.

## Privacy & security

Omarchy plugins run unsandboxed, so here is exactly what this one touches:

- **Nothing runs or installs on load** — the CLI and Python libraries are
  fetched only after you explicitly start a generation.
- **Network** — GitHub releases (one pinned CLI version, verified against a
  sha256 that ships in this repository, https-only with capped, atomically
  published downloads) and the Higgsfield API through that CLI. Python
  packages install with `--require-hashes`. Nothing else.
- **Webcam** — only while the panel's camera view is open; the viewfinder
  unloads the moment the panel closes.
- **Input devices** — never touched. Desktop activity is inferred from
  focused-window changes the shell already reports; no group membership, no
  raw input access, no keys read.
- **Storage** — everything lives in `~/.local/share/higgsfield-omagotchi/`,
  created owner-only (0700), files 0600. Signed result URLs are never
  persisted; log lines have URL query strings stripped. Delete the directory
  and the plugin leaves no trace.
- **Auth** — login happens in your browser via the official CLI; the plugin
  never reads, stores, or asks for the token (the login probe accepts only
  non-secret account-status JSON).
- **IPC** — the shell-visible surface is care actions and toggles only;
  camera, file paths, login, and paid generation are reachable exclusively
  from the panel UI.

## Develop

```sh
omarchy plugin validate .
qmllint -I "$OMARCHY_PATH/shell" Service.qml Overlay.qml BarWidget.qml Panel.qml
node --test test/model.test.js
python3 test/test_scripts.py
```

To rehearse the first-run experience, move `~/.local/share/higgsfield-omagotchi`
aside and restart the shell — the plugin only ever runs its own bundled,
digest-verified CLI, never one found on `PATH`.

The pipeline: `scripts/runtime.py` (CLI + deps) → `scripts/generate-sprite.py`
(base sprite → 16 poses → 16 clips) → `skill/sprite-sheet-8bit/scripts/postprocess.py`
(chroma key, crop, pixelize, sheet). The full recipe with every hard-won
prompt rule lives in `skill/sprite-sheet-8bit/SKILL.md`.

Iterating from a Mac:

```sh
brew install fswatch
cp .env.example .env   # set OMARCHY_HOST
./dev/sync.sh --validate
./dev/watch.sh
```

## Remove

```sh
./scripts/uninstall.sh   # deletes ~/.local/share/higgsfield-omagotchi (asks first)
omarchy plugin remove higgsfield-omagotchi
```
