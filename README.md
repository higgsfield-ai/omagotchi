# Higgsfield Pet

A Tamagotchi on the Omarchy Quattro bar. It plays modes from a local sprite atlas (`atlas.png` + `atlas.json`). Higgsfield generation is not wired yet — the bundled sheet is a color-row placeholder so the plugin can be tested without the API.

This repo is the plugin. Omarchy installs third-party plugins by cloning a git repo with `manifest.json` at the root. Do not put a symlink in the plugin folder; Quattro refuses those.

## Install

On an Omarchy machine:

```sh
omarchy plugin add git@github.com:higgsfield-ai/omarchy-pet.git --enable
omarchy bar move higgsfield.pet --section right
```

## Usage

- Left-click the pet to open the debug panel.
- The **bar chip** is the settings dropdown. The **overlay pet** is a separate layer-shell window (like the OSD), not a Hyprland tiled window.
- **Follow focused window** (default): the overlay sits on the bottom-right of the active Hyprland window — the terminal you are typing in. Click-through so typing still works. This is not the text caret.
- **Follow pointer**: sits next to the mouse.
- **Pin on desktop**: stops following. Drag the overlay pet. Click the bar chip for settings.
- Wave and angry play once, then return to sensor mode (idle until sensors exist).

```sh
omarchy-shell higgsfield.pet setMode dance
omarchy-shell higgsfield.pet setPlacement focus
omarchy-shell higgsfield.pet setPlacement pointer
omarchy-shell higgsfield.pet pinHere
omarchy-shell higgsfield.pet setDesktopVisible false
omarchy-shell higgsfield.pet clearOverride
omarchy-shell shell summon higgsfield.pet '{}'
omarchy-shell shell hide higgsfield.pet
```

Placeholder rows: gray idle, orange hurry, green dance, blue sleep, gold happy, red angry, white wave. Brightness walks across each row so the loop is visible.

## Develop

Follow [Develop a Plugin](https://omarchyplugins.com/develop.html). This plugin matches the clock contract: one `bar-widget`, `BarWidget.qml` loads `Panel.qml`, same `moduleName` in both.

```sh
omarchy plugin validate .
qmllint -I "$OMARCHY_PATH/shell" BarWidget.qml Panel.qml Pet.qml
node --test test/model.test.js
python3 scripts/make-placeholder-atlas.py
```

Saved files under `~/.config/omarchy/plugins/` reload automatically.

## Iterate from a Mac

QML only loads inside `omarchy-shell` on the HP. Keep git on the Mac; push files over SSH. Do **not** symlink the plugin directory.

**Fastest for UI:** Cursor Remote SSH, open `~/.config/omarchy/plugins/higgsfield.pet` on the HP. Save → bar reloads. Use this when you are in the QML loop.

**Fastest while git stays on the Mac:** one-time SSH, then watch + rsync.

`~/.ssh/config`:

```
Host omarchy-hp
  HostName 192.168.x.x
  User <hp-user>
  ControlMaster auto
  ControlPath ~/.ssh/cm-%r@%h:%p
  ControlPersist 10m
```

```sh
brew install fswatch
cp .env.example .env   # set OMARCHY_HOST=omarchy-hp
./scripts/sync.sh --validate
./scripts/watch.sh
```

On the HP, first time only:

```sh
omarchy plugin enable higgsfield.pet
omarchy bar move higgsfield.pet --section right
```

This plugin declares `bar-widget`, `panel`, and `service` kinds. The overlay is the keepLoaded `panel` entry (`DesktopPet.qml`). A PanelWindow nested in the bar chip will not appear on the desktop.

After updating, restart the shell once so the new kinds load:

```sh
omarchy plugin update higgsfield.pet --yes
omarchy-restart-shell
```

If the overlay is still missing, look for a pink-bordered square (placeholder). Logs:

```sh
qs log -p "$OMARCHY_PATH/shell" --tail 100
```

If QML errors, on the HP: `qs log -p "$OMARCHY_PATH/shell" --tail 100`. Manifest-only changes need the rescan that `sync.sh` already runs. A wedged shell: `omarchy-restart-shell`.

## Atlas contract

`atlas.json` is the only layout the player reads. A future generator only overwrites `atlas.png` and this file:

```json
{
  "cell": 64,
  "columns": 8,
  "fps": 8,
  "modes": {
    "idle": 0,
    "hurry": 1,
    "dance": 2,
    "sleep": 3,
    "happy": 4,
    "angry": 5,
    "wave": 6
  }
}
```

One mode per row, eight frames. Appearance does not change at runtime.

## Remove

```sh
omarchy plugin remove higgsfield.pet
```
