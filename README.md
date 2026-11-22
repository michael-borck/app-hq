# app-hq

Engineering playbook for the app portfolio: how we choose a stack, shape a
product, sign and release it, and avoid repeating the same mistakes 30 times.

This is not a monorepo and not a business plan. App code stays in its own repos.
`borck-hq` is the business HQ; this is the engineering HQ.

## Start here

- **New app?** [checklists/new-app.md](checklists/new-app.md) then
  [decision-tree.md](decision-tree.md)
- **Shipping a release?** [checklists/release.md](checklists/release.md) and
  [runbooks/release.md](runbooks/release.md)
- **Releasing a Tauri app?** [templates/tauri/release.yml](templates/tauri/release.yml)
- **Signing broken?** [runbooks/signing.md](runbooks/signing.md)
- **GitHub auth broken?** [runbooks/github-auth.md](runbooks/github-auth.md)
- **Looking for an existing pattern?** [patterns/](patterns/)
- **What apps exist and how are they built?** [registry/apps.yaml](registry/apps.yaml)

## Principles

1. **Local-first by default.** BYOK, no telemetry, local data, offline-capable
   where practical.
2. **Centralised is a deployment option, not the default.** If a product needs a
   server, ship a local mode from the same codebase where possible.
3. **One engine, multiple surfaces.** CLI, desktop, and web should share the core
   rather than fork behaviour.
4. **Static-first for content ecosystems.** A static catalog + GitHub PR review
   beats a bespoke backend for small pack stores.
5. **One identity, one signing credential.** One Developer ID certificate and one
   notarization key cover the whole portfolio.
6. **Automate the fleet, not each app.** Shared workflows and scripts for the
   things that are genuinely identical.
7. **Write down the decision once.** If it recurs, it belongs in an ADR or a
   pattern, not in a chat thread.

## Repository map

```text
.github/             shared reusable workflows and composite actions
decision-tree.md
patterns/            recurring product and architecture shapes
runbooks/            signing, release operations
checklists/          new app, release
adr/                 decisions with lasting consequences
registry/apps.yaml   the fleet inventory
templates/           starter templates (incremental)
scripts/             fleet automation
```

## Scope

In scope: stack choice, local/central patterns, content stores, AI provider
strategy, data storage, security baseline, packaging, signing, release,
observability, and maintenance.

Out of scope: business strategy, marketing, finance, app-specific product plans.
No secrets, credentials, or private keys belong in this repo.
