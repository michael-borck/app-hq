# New app checklist

One page. Answer before writing code.

## Product shape

- [ ] Who is it for: individual, team, institution, public?
- [ ] Local-only, centralised, or hybrid?
- [ ] Does it need offline use? Local models? Native OS integration?
- [ ] Does it need collaboration, accounts, or roles?
- [ ] Does it need a content/template ecosystem?
- [ ] Does it need a CLI or batch mode?

## Stack

- [ ] PWA, Tauri, Electron, web server, or hybrid?
- [ ] Why this stack instead of the simpler option?
- [ ] If desktop: Tauri unless Node/native ecosystem requires Electron.
- [ ] If server: can a local mode share the same core?
- [ ] If content store: static catalog + PR review considered?

## Data and AI

- [ ] Local data format documented (folder/JSON/SQLite/IndexedDB).
- [ ] Backup/export path that does not require the app.
- [ ] AI provider abstraction with BYOK and local fallback.
- [ ] No telemetry by default; document any outbound calls.
- [ ] Managed keys only for institutional mode, server-side.

## Security

- [ ] Secrets in OS keychain/encrypted store, never project files.
- [ ] IPC/API validation at trust boundaries.
- [ ] CSP and context isolation if desktop.
- [ ] User-supplied content sandboxed.
- [ ] Dependency and supply-chain checks.

## Release

- [ ] GitHub repo created with an SSH remote (`git@github.com:…`);
      package name checked and reserved early (PyPI/npm placeholder
      release) ([runbooks/github-auth.md](../runbooks/github-auth.md)).
- [ ] Signing/notarization plan ([runbooks/signing.md](../runbooks/signing.md)).
- [ ] Runner choices recorded.
- [ ] Update mechanism chosen (GitHub Releases / updater / static deploy).
- [ ] Version/tag procedure.
- [ ] Landing page / download page.

## Operations

- [ ] Where does data live? How is it backed up?
- [ ] What breaks offline?
- [ ] What happens on provider failure?
- [ ] What is the support/debug story?
- [ ] What gets logged, and what must never be logged?

## Documentation

- [ ] README states privacy posture and deployment modes.
- [ ] User guide covers data location and export.
- [ ] Architecture/ADR records the stack decision.
- [ ] Signing/secrets documented, never committed.
