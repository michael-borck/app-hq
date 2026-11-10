# ADR 0002: PWA → Tauri → Electron → server

Status: accepted.

## Decision

Choose the simplest stack that satisfies the product:

1. PWA/web when no native integration is needed.
2. Tauri by default for local-first desktop apps.
3. Electron when Node/native modules, Chromium consistency, or an existing
   Electron codebase justify the footprint.
4. Web server when multi-user/institutional hosting is required; add Docker and,
   where practical, a local mode.

Do not maintain two desktop stacks for the same product without a concrete
reason.

## Consequences

- Most new desktop apps should be Tauri.
- Electron remains valid for existing apps and Node-heavy products.
- Signing/release docs must cover both.
- Stack changes are migrations, not experiments.
