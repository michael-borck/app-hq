# ADR 0004: GitHub identity and git transport

Status: accepted.

## Decision

Separate the two GitHub identity systems and standardise each:

- **Git transport** (clone, fetch, push) uses **SSH** for every repo we
  own (`michael-borck/*`, `retroverse-studios/*`):
  `git@github.com:<owner>/<repo>.git`, key `~/.ssh/id_ed25519`.
  Third-party reference clones (under `cloned-repos/`, tool checkouts)
  stay on anonymous **HTTPS**: we cannot push to them, and HTTPS needs
  no credential at all.
- **GitHub API identity** (`gh` commands) is a token, separate from
  transport. Per-account tokens live in
  `~/.config/gh-accounts/<name>.token` (chmod 600); the interactive
  shell exports `GH_TOKEN`/`GITHUB_TOKEN` from the default account's
  file (`~/.zshrc.api`), and `ghacct <name>` (`~/.zshrc`) swaps
  accounts at runtime. A keychain-stored login (`gh auth login`) may
  exist as the fallback for non-interactive shells, which never source
  `.zshrc`.
- When `gh` creates repos or clones, its git protocol is SSH
  (`git_protocol: ssh`), so new remotes are born SSH and never need
  converting.

Fleet state at acceptance (2026-11-22): 734 local repos audited, 176
owned remotes converted HTTPS → SSH, 518 already SSH, 35 third-party
clones left on HTTPS, 5 local fixtures with no remote. Drift is
checked by `scripts/check-remotes.py`; operations live in
`runbooks/github-auth.md`.

## Consequences

- Pushes work from any shell (including agent/non-interactive shells)
  with no token in the environment. The failure mode "gh works in my
  terminal but not in the tool" is confined to `gh` API commands.
- `GH_TOKEN` in the environment always wins over the keychain. The
  API account (`ghacct`) and the pushing account (SSH key) can
  therefore differ; nothing warns when they do. A second account that
  must *push* needs its own SSH host alias and key (the existing
  `github-social` alias is the pattern), not just a token file.
- New machines need: the SSH key (or a new one uploaded), the token
  files, and `~/.zshrc.api`. No per-repo credential setup.
- Repos created while authenticated only by token come out with HTTPS
  remotes unless `gh` is configured for SSH; `check-remotes.py`
  catches these.
