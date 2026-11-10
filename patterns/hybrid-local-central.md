# Hybrid local + central

**Reference apps:** Curriculum Curator, Feed Forward.

## Shape

One product, two deployment modes:

- **Local/personal:** desktop app or local Docker, SQLite, no auth, BYOK or
  Ollama. Single user.
- **Institutional/team:** server deployment with accounts, roles, shared or
  server-held keys, rate limiting, backups.

Use a single flag (e.g. `LOCAL_MODE=true`) or separate entry points around a
shared core. Do not fork the domain logic.

## When to use

- Educators, teams, or institutions need shared data and accounts.
- Individuals still need a private/offline path.
- The core workflow is identical; only auth, storage location, and operations
  differ.

## Design rules

- Keep auth and tenancy at the edges; the core engine should not know about
  sessions.
- Use SQLite for both modes where possible; Postgres only when concurrency or
  scale demands it.
- Keys: local mode = user keys in keychain; server mode = server-held keys or
  per-user keys, never exposed to the browser.
- The local mode must remain installable without Docker for non-technical users.
- Document which mode a feature supports; avoid silent feature drift.

## Risks

- Two deployment modes double the test matrix.
- Security review must cover the server mode even if most users are local.
- Backup/migration paths differ between modes.
