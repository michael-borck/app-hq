# Templates

Templates are intentionally incremental. Do not scaffold a full app until two or
three new apps need the same starting point.

Planned:

- `electron/` — golden release workflow with signing, notarization, runner pin
- `tauri/` — golden release workflow with API-key notarization + updater
- `pwa/` — static deploy workflow
- `local-server/` — FastAPI/Next local mode + Docker server mode
- `pack-store/` — static catalog, validator, PR submission template

The first extraction should be the macOS signing/notarization composite action,
because that is the highest-friction, most frequently repeated piece.
