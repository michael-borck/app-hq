# Local-first desktop

**Reference apps:** BookForge, Playable Lessons, most of the portfolio.

## Shape

- Tauri or Electron shell with the UI bundled locally.
- Data in project folders, SQLite, or IndexedDB/JSON; no account required.
- BYOK AI providers with a local Ollama fallback; no telemetry.
- Optional import/export to open formats.
- Updates via signed installers and GitHub Releases.

## Why

- Privacy is a feature, not a disclaimer.
- Works offline (or fully air-gapped with local models).
- No operational burden, no server costs, no account support.
- Users own their data and can back it up by copying a folder.

## Risks

- Support burden for local environments and native packaging.
- Distribution/signing per platform.
- Hard to add collaboration later if the data model assumes one user.
- Local backups are the user’s responsibility; provide export/import.

## Checklist

- [ ] No telemetry, no hidden network calls beyond the chosen provider.
- [ ] Provider abstraction with local fallback.
- [ ] Data stored in a documented folder/file format.
- [ ] Export path that does not require the app.
- [ ] Signed and notarized macOS build; signed Windows build where possible.
- [ ] Clear “where is my data?” documentation.
