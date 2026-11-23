# Trunk-based, PR-gated git workflow

**Reference apps:** the Lens repos (assessment-lens, assessment-bench, the three
desktop apps), 2026-11.

## Shape

- `main` is always releasable.
- Work happens on short-lived branches (hours, not weeks).
- Every change merges through a pull request with required CI.
- Merge with **squash** so history stays linear and readable.
- Tags come from `main` only.

## The loop

```bash
git switch main && git pull
git switch -c <type>/<short-slug>      # feat/, fix/, chore/, docs/, refactor/
# edit, then:
git commit -am "fix: ..."
git push -u origin <type>/<short-slug>
gh pr create --fill
# wait for the required checks; if red, fix on the same branch and push
gh pr merge --squash --delete-branch
git switch main && git pull
```

## Branch protection baseline

Every `main` has:

| Setting | Value | Why |
|---|---|---|
| Pull request required | yes, 0 approvals | Solo-friendly; no fake review, but no direct pushes |
| Required status checks | repo CI (e.g. `validate`, `test (3.11)`) | CI is the gate |
| Linear history | yes | Merge commits rejected; squash/rebase only |
| Force pushes | blocked | History stays auditable |
| Branch deletion | blocked | Nothing disappears silently |
| Admins can bypass | no | The rules apply to the owner too |

Apply with `scripts/protect-default-branch.sh <owner/repo> ...` (dry run by
default; `--apply` to write).

## When to use

- Any app with more than one contributor, or a solo app that ships releases.
- Any repo where `main` is deployed, tagged, or consumed by other repos.
- Any repo that benefits from CI as a gate.

## Rules

- Keep PRs small and single-purpose; split refactors from behaviour changes.
- Commit subject: imperative, one line, no trailing period.
- The PR title becomes the squash commit on `main` — write it for a reader of
  the log.
- Fix CI on the branch; never merge red or disable protection to get a merge out.
- If CI is flaky, fix or quarantine the test — do not weaken the gate.

## Risks

- Too much process for a throwaway spike: branch protection is overkill for
  sandboxes and reference clones. Apply it to owned, shipping repos.
- A single required check that does not run on every PR will block unrelated
  changes. Scope required checks to what actually runs on pull requests.
- Squash loses granular history on `main`; keep the detail in the PR.

## Solo-developer notes

- The discipline is the branch + PR, not a second reviewer. The check is CI.
- The overhead is seconds; the payoff is a clean `main`, a changelog from PR
  titles, and a revert unit per change.