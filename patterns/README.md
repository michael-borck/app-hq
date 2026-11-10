# Patterns

Recurring shapes across the portfolio. Each pattern lists when to use it, the
trade-offs, and reference apps.

| Pattern | Use when | References |
|---|---|---|
| Local-first desktop | Single user, private data, offline-friendly | BookForge, Playable Lessons, most desktop apps |
| Hybrid local + central | Same product for individuals and institutions | Curriculum Curator, Feed Forward |
| Central server + private desktop wrapper | Shared engine, private practice/client mode | Feed Forward Desktop, Document Lens |
| Static PWA/player | No backend, easy updates, reading/playing content | Lorekeeper, Static lesson players |
| Static pack store | Community content with low ops burden | Lorekeeper Packs, Cairn Packs, Knotebook Store |
| Desktop wrapper + local sidecar | Python/Rust engine plus a native shell | Feed Forward Desktop, Document Lens |
| Suite of related apps | Multiple products sharing conventions | Lens, Retroverse |
| CLI + desktop shared core | Batch/automation plus interactive use | Playable Lessons |
| Template/content ecosystem | Users create and share outputs | BookForge templates, Playable Lessons |
| LMS/export interoperability | Institutions need to consume output | Curriculum Curator, Playable Lessons |

## Choosing between them

- Start with the simplest shape that satisfies privacy and offline needs.
- Add a server only when collaboration or institutional hosting is a real
  requirement.
- If you add a server, keep a local mode in the same codebase where practical.
- For community content, prefer static catalogs and PR review over a custom
  upload service.
- Extract shared code only after two or three apps need it; premature shared
  libraries become a second product.

## Anti-patterns

- A server only because “cloud” sounds modern.
- A bespoke content marketplace when a static catalog and Git PRs would do.
- Forking the engine for desktop and web so behaviour drifts.
- Per-app certificates, per-app notarization passwords, or per-repo secret
  names.
- One shared secret name that means different things in different repos.
- Assuming `macos-latest` is stable for packaging.
