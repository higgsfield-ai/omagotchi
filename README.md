# 37signals

A random [37signals](https://37signals.com) principle for Omarchy, plus prebuilt Higgsfield clips of DHH on commit, fail, and idle.

On reveal or idle, the plugin writes an essay to `~/.config/omarchy/branding/screensaver.txt` and plays the landscape screensaver clip once (fullscreen). The first write copies your previous branding file to `screensaver.txt.higgsfield-bak`. `Super + Esc` still launches stock `ttfx` with that essay.

**Commit** and **fail** play as a centered floating overlay: one play (~5s), then the window closes. They do not generate video at runtime — the clips ship in `clips/`.

This cannot draw on the PAM lock screen. When `idle.lock` fires, the lock takes over.

## Install

```sh
omarchy plugin remove higgsfield.pet
omarchy plugin add git@github.com:higgsfield-ai/omarchy-pet.git --enable
omarchy-restart-shell
```

Leave the stock screensaver **on**. This plugin writes essays into it and plays its own clips on idle.

Idle timings stay in `~/.config/omarchy/shell.json` (`idle.screensaver`, then `idle.lock`). Kind changes need `omarchy plugin update … --yes` then `omarchy-restart-shell`.

## Usage

```sh
omarchy-shell higgsfield.signals reveal
omarchy-shell higgsfield.signals next
omarchy-shell higgsfield.signals close
omarchy-shell higgsfield.signals ping
omarchy-shell higgsfield.signals event commit
omarchy-shell higgsfield.signals event fail
omarchy-shell higgsfield.signals event screensaver
```

`reveal` / `next` pick a random essay, write it to `screensaver.txt`, and play the screensaver clip. Commit and fail debounce for 8 seconds so a burst of hooks does not stack windows.

### Trigger each clip

| Clip | How to play it |
|---|---|
| **1. commit** (centered overlay, once) | `omarchy-shell higgsfield.signals event commit` — or copy `hooks/post-commit` into a repo’s `.git/hooks/post-commit`, then `git commit`. |
| **2. fail** (centered overlay, once) | `omarchy-shell higgsfield.signals event fail` — or call that from a test/CI wrapper on non-zero exit. |
| **3. screensaver** (fullscreen, once) | Wait for Omarchy idle, or `omarchy-shell higgsfield.signals reveal`. Stock ASCII is still `Super + Esc`. |

Need `mpv` on the path (Omarchy ships it). Overlay clips need Hyprland so the player can float and pin; they do not steal keyboard focus.

If IPC returns `commit` / `screensaver` but nothing appears:

```sh
omarchy-shell higgsfield.signals event commit
omarchy-shell higgsfield.signals playLog
cat /tmp/higgsfield-signals-play.log
ls -l ~/.config/omarchy/plugins/higgsfield.signals/clips/
```

A plain `git commit` does nothing until the hook is installed in that repo:

```sh
PLUGIN=$(ls -d ~/.local/share/omarchy/plugins/higgsfield.signals \
             ~/.config/omarchy/plugins/higgsfield.signals 2>/dev/null | head -1)
cp "$PLUGIN/hooks/post-commit" .git/hooks/post-commit
chmod +x .git/hooks/post-commit
```

## Develop

Follow [Develop a Plugin](https://omarchyplugins.com/develop.html). This plugin is a keepLoaded `service`.

```sh
omarchy plugin validate .
qmllint -I "$OMARCHY_PATH/shell" Service.qml
node --test test/model.test.js
```

Manifest kind changes need `omarchy plugin update … --yes` then `omarchy-restart-shell`.

## Iterate from a Mac

QML only loads inside `omarchy-shell` on the HP. Keep git on the Mac; push files over SSH. Do **not** symlink the plugin directory.

```sh
brew install fswatch
cp .env.example .env   # set OMARCHY_HOST=omarchy-hp
./scripts/sync.sh --validate
./scripts/watch.sh
```

On the HP, first time only:

```sh
omarchy plugin enable higgsfield.signals
omarchy-restart-shell
```

## Remove

```sh
omarchy plugin remove higgsfield.signals
```

To restore the previous ASCII logo:

```sh
mv ~/.config/omarchy/branding/screensaver.txt.higgsfield-bak \
   ~/.config/omarchy/branding/screensaver.txt
```
