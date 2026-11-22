# GitHub auth runbook

How git and `gh` authenticate on the dev machine, and what to do when
they stop. The decision behind this is
[ADR 0004](../adr/0004-github-identity-and-transport.md).

## Model

Two independent systems. Debugging goes wrong when they are conflated.

| System | Used by | Credential | Stored |
|---|---|---|---|
| Git transport | `git clone/fetch/push` to owned repos | SSH key `~/.ssh/id_ed25519` | `~/.ssh/`, host `github.com` in `~/.ssh/config` |
| GitHub API | `gh repo/pr/issue/...`, scripts using `gh` | PAT or OAuth token | env var `GH_TOKEN`, else macOS Keychain |

Anonymous HTTPS needs no credential and is deliberate for third-party
reference clones (`cloned-repos/`, tool checkouts).

## How the API token gets set

Precedence, highest first:

1. `GH_TOKEN` / `GITHUB_TOKEN` in the environment.
2. Keychain entry from `gh auth login` (service `gh:github.com`;
   account metadata in `~/.config/gh/hosts.yml`).

Interactive shells set level 1 automatically: `~/.zshrc.api` exports
both variables from `~/.config/gh-accounts/michael-borck.token`
(chmod 600, one file per account). `ghacct <name>` (defined in
`~/.zshrc`) re-exports them from another account's file, e.g.
`ghacct michaelborck-curtin-grading`.

Non-interactive shells (agent tools, cron, GUI-spawned processes) never
source `.zshrc`, so they see only level 2. Before a keychain login
exists, the workaround is to wrap the command so the interactive
environment loads:

```zsh
/bin/zsh -lic 'gh repo view michael-borck/some-repo'
```

A plain login shell (`zsh -lc`) is not enough: the token export lives
in `.zshrc` (via `.zshrc.api`), which only interactive shells read.

## Adding the keychain login (one-off)

`gh auth login` refuses to store credentials while `GH_TOKEN` is set:

```text
The value of the GH_TOKEN environment variable is being used for authentication.
To have GitHub CLI store credentials instead, first clear the value from the environment.
```

Clear it for that terminal (new terminals keep their normal behaviour),
then log in. There is no "keychain" menu item: on macOS `gh` stores
the secret in the Keychain automatically when it saves. What goes in
is only the token — with the browser flow, a fresh OAuth token
(`gho_…`, scopes `repo`, `read:org`, `gist`, optionally `workflow`);
with `--with-token`, the exact PAT you feed it.

```zsh
# Browser flow (preferred: narrower scopes than the legacy PAT)
unset GH_TOKEN GITHUB_TOKEN
gh auth login
#   Where do you use GitHub?            → GitHub.com
#   Preferred protocol for Git ops?     → SSH
#   Authenticate GitHub CLI?            → Login with a web browser
#   SSH key prompt                      → existing ~/.ssh/id_ed25519.pub (already uploaded)

# …or store the existing PAT instead:
env -u GH_TOKEN -u GITHUB_TOKEN gh auth login --hostname github.com \
  --with-token < ~/.config/gh-accounts/michael-borck.token
```

Skip `gh auth setup-git`: it installs an HTTPS credential helper,
which owned repos no longer use.

Note the legacy PAT in `michael-borck.token` carries very broad scopes
(`admin:*`, `delete_repo`, `workflow`, …). Prefer the browser flow for
anything non-interactive, and keep the PAT files for `ghacct` and for
tools that read `GITHUB_TOKEN` directly.

## Multi-account trap

`ghacct` changes only the API token. `git push` authenticates with the
SSH key named in `~/.ssh/config`, which is always `id_ed25519`
(account `michael-borck`) for host `github.com`. So the API account
and the pushing account can differ, silently.

An account that must push needs its own alias, like the existing
`github-social` (`id_ed25519_social`):

```text
Host github-<alias>
  HostName github.com
  IdentityFile ~/.ssh/id_ed25519_<alias>
```

with remotes written `git@github-<alias>:<owner>/<repo>.git`.

## Converting a remote to SSH

```zsh
git -C <repo> remote set-url origin git@github.com:<owner>/<repo>.git
```

Fleet-wide, use the checker (dry run by default):

```zsh
scripts/check-remotes.py            # report drift
scripts/check-remotes.py --apply    # convert owned HTTPS remotes
```

Owned means the owners listed in the script
(`michael-borck`, `retroverse-studios`). Third-party HTTPS remotes
are reported but never converted.

## Verification

```zsh
ssh -T git@github.com
# → Hi michael-borck! You've successfully authenticated…

gh auth status
# interactive shell  → Logged in … (GH_TOKEN)
env -u GH_TOKEN -u GITHUB_TOKEN gh auth status
# after keychain login → Logged in … (keyring)

git -C <repo> ls-remote origin HEAD   # transport works, no token involved
scripts/check-remotes.py              # fleet: owned repos all SSH
```
