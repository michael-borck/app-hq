# Templates

Templates are intentionally incremental. Do not scaffold a full app until two or
three new apps need the same starting point.

Available:

- `electron/` — golden release workflow with API-key signing/notarization,
  `macos-15`, runner pin, `notarize-check` manual credential test, and a
  draft-release flow. Based on the batch C Lens repos.
- `tauri/` — shared reusable release workflow:
  <https://github.com/michael-borck/actions>. Tag push → preflight → macOS
  arm64/Intel, Ubuntu 22.04, Windows → API-key signing/notarization → draft →
  publish. Manual dispatch → notarize-check only.

Planned:

- `pwa/` — static deploy workflow
- `local-server/` — FastAPI/Next local mode + Docker server mode
- `pack-store/` — static catalog, validator, PR submission template

The macOS signing/notarization composite action now lives in
`michael-borck/actions/.github/actions/apple-signing`. `electron/` remains the
Electron-specific template; `tauri/` points at the shared workflow.
