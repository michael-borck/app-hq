# Static pack store with GitHub PR submissions

**Reference:** Lorekeeper Packs, Cairn Packs, Knotebook Store.

## Shape

```text
app repo        builds/consumes packs
store repo      static catalog + pack artifacts + storefront
submissions/    PR review queue (pack + submission.json)
CI              validates shape, hashes, archive contents
maintainer      reviews, signs locally, rebuilds catalog, deploys
```

- No backend, no accounts, no upload service.
- The app fetches a static `catalog.json` / `index.json`.
- Packs are content-addressed and verified (SHA-256 + signature).
- The private signing key never enters CI.
- A merged PR is not live until the maintainer signs and deploys.

## Why

- Minimal operations and attack surface.
- Git provides review history, diffs, and contributor identity.
- Static hosting is cheap and cache-friendly.
- Signing locally keeps the key off GitHub.

## Rules

- Validate submissions in CI (schema, archive, version, ID uniqueness, hashes).
- Sign the exact bytes that ship; never rebuild after signing.
- Keep the catalog and packages in a repo that can be served statically.
- Document the licence and content policy for contributors.
- The app must refuse unsigned or hash-mismatched packs.
- Do not let CI hold the signing key unless you have a proper KMS/HSM story.

## Risks

- Manual review/signing is a maintainer bottleneck.
- A static catalog has no per-user entitlement or revocation without a rebuild.
- Pack format changes need versioning and migration.
- Content safety is a policy problem, not just a technical one.
