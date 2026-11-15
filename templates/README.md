# Templates

Templates are intentionally incremental. Do not scaffold a full app until two or
three new apps need the same starting point.

Available:

- `electron/` — thin caller for the shared Electron release workflow
  (`.github/workflows/electron-release.yml`), plus the `notarize.js` afterSign
  hook and electron-builder settings. Tag push → matrix → sign/notarize →
  draft → publish; manual dispatch → notarize-check only.
- `tauri/` — thin caller for the shared reusable release workflow in this repo
  (`.github/workflows/tauri-release.yml`). Tag push → preflight → macOS
  arm64/Intel, Ubuntu 22.04, Windows → API-key signing/notarization → draft →
  publish. Manual dispatch → notarize-check only.

Planned:

- `pwa/` — static deploy workflow
- `local-server/` — FastAPI/Next local mode + Docker server mode
- `pack-store/` — static catalog, validator, PR submission template

The macOS signing/notarization composite action lives in
`.github/actions/apple-signing`; it also writes `APPLE_API_KEY_PATH` for the
Electron `notarize.js` hook. `electron/` and `tauri/` are caller templates for
their shared workflows.
