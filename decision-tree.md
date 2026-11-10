# Stack and deployment decision tree

Answer in order. Stop at the first option that fits the product, not the one that
is most interesting.

## 1. Does it need to run locally at all?

**No, and it is inherently collaborative/multi-user**
→ **Web app** (Next.js, React, or server-rendered Python/FastHTML). Add Docker
for self-hosting if institutions or teams need to run it themselves.

**No, but it is a single-player utility**
→ **PWA**. Prefer this when file-system access, background services, and deep OS
integration are not needed. It updates instantly and has no signing burden.

**Yes** → continue.

## 2. Does it need deep OS integration?

Examples: watching files, local model runtimes, native menus/tray, background
agents, spawning a local server, managing a local database, working fully offline
with local assets.

**No**
→ Reconsider PWA. If you still want a desktop shell, choose Tauri for footprint.

**Yes** → continue.

## 3. Which desktop stack?

Choose **Tauri** by default.

- Small binaries, low memory, Rust backend, strong security posture.
- Good for local-first apps, native file access, sidecars, and offline work.
- Tauri v2 supports macOS signing/notarization with Apple ID or App Store Connect
  API key; updater keys are per app.

Choose **Electron** when:

- You depend on Node native modules or the Chromium/Node ecosystem.
- You need maximum rendering/plugin compatibility or an existing Electron
  codebase.
- You accept the larger binary and memory footprint.
- Prefer a known-good Electron version and pin the macOS runner (`macos-15` at the
  time of writing; `macos-latest` moved to macOS 26 and broke electron-builder
  24's keychain import).

Do not maintain both stacks for the same product unless there is a concrete
reason.

## 4. Does it need a centralised mode?

**No**
→ local-only desktop/PWA. Keep the data layer replaceable in case central sync is
added later.

**Yes, institutional/team hosting**
→ one shared core with two deployment modes:

- **Local mode:** SQLite, no auth, single user, optional offline/Ollama.
- **Server mode:** Docker, auth (JWT/session), roles, server-held keys or BYOK,
  SQLite/Postgres, rate limiting.

Curriculum Curator is the reference: `LOCAL_MODE=true` flips the same codebase
into the personal/offline mode. Feed Forward is the reference for a central
server with a separate private desktop practice wrapper sharing the same engine.

## 5. Does the app need a content ecosystem?

**No**
→ stop.

**Yes, packs/templates/lessons**
→ use the static pack-store pattern:

- app consumes a static catalog;
- submissions are GitHub PRs with a validator in CI;
- maintainers review, sign locally, rebuild the catalog;
- the app verifies hashes/signatures before install.

Lorekeeper, Cairn Packs, and Knotebook Store are the reference implementations.
No backend, no upload service, signing key never enters CI.

## 6. Does it need automation or batch use?

**Yes**
→ expose a CLI that shares the same engine as the desktop/web UI. Playable
Lessons is the reference (one pipeline, CLI + desktop + self-hosted web).

## 7. Data and AI defaults

- **Desktop/PWA:** project folders + JSON/Markdown, or IndexedDB for static apps.
- **Local server:** SQLite is the default; one file, easy backup.
- **Multi-user server:** SQLite until it genuinely hurts; then Postgres.
- **AI:** provider abstraction, BYOK, Ollama/local fallback, no telemetry.
  Managed keys only for institutional deployments, and then only server-side.
- **Exports:** prefer open/interoperable formats (Markdown, PDF, DOCX, EPUB,
  SCORM, H5P, Common Cartridge) over proprietary silos.

## 8. Security baseline

All stacks:

- no telemetry by default
- secrets in OS keychain / encrypted store, never in project files
- strict IPC/API validation
- CSP + context isolation for desktop shells
- sandbox user-supplied content
- signed release artifacts

## 9. Signing and release

- Apple: one Developer ID certificate + one App Store Connect API key for the
  whole team; see [runbooks/signing.md](runbooks/signing.md).
- Windows: prefer Azure Trusted Signing with OIDC; SignPath for OSS.
- Linux: unsigned AppImage/snap is normal unless you have a distribution
  requirement.
- Pin runner versions for Electron macOS builds; do not rely on
  `macos-latest` for packaging.

## 10. New app checklist

If you got here, open [checklists/new-app.md](checklists/new-app.md). It turns
these decisions into a one-page plan.
