# Templates

Templates are intentionally incremental. Do not scaffold a full app until two or
three new apps need the same starting point.

Available:

- `electron/` — golden release workflow with API-key signing/notarization,
  `macos-15`, runner pin, `notarize-check` manual credential test, and a
  draft-release flow. Based on the batch C Lens repos.

Planned:

- `tauri/` — golden release workflow with API-key notarization + updater
- `pwa/` — static deploy workflow
- `local-server/` — FastAPI/Next local mode + Docker server mode
- `pack-store/` — static catalog, validator, PR submission template

The macOS signing/notarization composite action is still the next extraction.
The `electron/` template is the verified pattern to copy until that exists.
