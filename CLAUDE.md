# Repo conventions

- Commit as `Magzhan Esentaev <magzhan@higgsfield.ai>` (the identity linked
  to the GitHub account this repo publishes under). Never add
  `Co-Authored-By` trailers for AI tools — the public history carries a
  single human author. If one sneaks in, strip it before pushing.
- Bump `manifest.json`'s `version` with every user-visible change.
- Before pushing: `node --test test/model.test.js` and
  `python3 test/test_scripts.py` must pass; new Python goes through
  `python3 -m py_compile`.
- The plugin id `higgsfield-omagotchi` names the data dir, IPC target,
  serviceFor lookups, and layer-shell namespaces — a change to one is a
  change to all of them, plus a data-dir migration.
- QML runs without `QML_XHR_ALLOW_FILE_READ`: never read files
  synchronously; use a `cat` Process like atlas/care/media restore do.
- Service.qml is keepLoaded: hot reloads do not restart it, so service
  changes need `omarchy-restart-shell` on the test box.
