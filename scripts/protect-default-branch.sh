#!/usr/bin/env bash
# Apply the portfolio's branch-protection baseline to one or more repos.
#
# Dry run by default: prints the protection JSON it would send. Pass --apply to
# write it. See patterns/git-workflow.md.
#
# Usage:
#   scripts/protect-default-branch.sh [options] <owner/repo> [<owner/repo> ...]
#
# Options:
#   --apply          Actually apply (default: dry run)
#   --branch NAME    Branch to protect (default: main)
#   --checks "a,b"   Required status-check contexts (default: auto-detect)
#   --no-checks      Require no status checks (e.g. docs-only repos)
#   -h, --help       Show this help
set -euo pipefail

APPLY=0
BRANCH="main"
CHECKS_OVERRIDE=""
NO_CHECKS=0
REPOS=()

usage() {
  sed -n '2,15p' "$0" | sed 's/^# \{0,1\}//'
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --apply) APPLY=1; shift ;;
    --branch) BRANCH="${2:?--branch needs a value}"; shift 2 ;;
    --checks) CHECKS_OVERRIDE="${2:?--checks needs a value}"; shift 2 ;;
    --no-checks) NO_CHECKS=1; shift ;;
    -h|--help) usage; exit 0 ;;
    -*) echo "unknown option: $1" >&2; exit 2 ;;
    *) REPOS+=("$1"); shift ;;
  esac
done

if [[ ${#REPOS[@]} -eq 0 ]]; then
  usage >&2
  exit 2
fi

# Auto-detect required checks from the default branch's latest CI run. Drop
# release-only contexts that never run on pull requests (the portfolio's shared
# release workflows prefix these with "release /"; older per-app workflows used
# plain "build"/"deploy").
detect_checks() {
  local repo="$1"
  gh api "repos/$repo/commits/$BRANCH/check-runs" --paginate \
    --jq '.check_runs[].name' 2>/dev/null \
    | sort -u \
    | grep -vE '^(release /|build|deploy|report-build-status)' \
    | paste -sd, - || true
}

build_body() {
  python3 - "$1" <<'PY'
import json
import sys

checks = json.loads(sys.argv[1])
body = {
    "required_status_checks": None if checks is None else {"strict": False, "contexts": checks},
    "enforce_admins": True,
    "required_pull_request_reviews": {
        "required_approving_review_count": 0,
        "dismiss_stale_reviews": False,
        "require_code_owner_reviews": False,
    },
    "restrictions": None,
    "allow_force_pushes": False,
    "allow_deletions": False,
    "required_linear_history": True,
    "required_conversation_resolution": False,
}
print(json.dumps(body))
PY
}

for repo in "${REPOS[@]}"; do
  if [[ "$NO_CHECKS" -eq 1 ]]; then
    checks_json="null"
    checks_desc="(none)"
  else
    checks="${CHECKS_OVERRIDE:-$(detect_checks "$repo")}"
    if [[ -z "$checks" ]]; then
      checks_json="null"
      checks_desc="(none detected; pass --checks or --no-checks)"
    else
      checks_json=$(printf '%s' "$checks" | python3 -c 'import json,sys; print(json.dumps(sys.stdin.read().split(",")))')
      checks_desc="$checks"
    fi
  fi

  body=$(build_body "$checks_json")

  echo "=== $repo ($BRANCH) ==="
  echo "  required checks: $checks_desc"
  if [[ "$APPLY" -eq 1 ]]; then
    printf '%s' "$body" | gh api -X PUT "repos/$repo/branches/$BRANCH/protection" --input - >/dev/null
    echo "  applied"
  else
    echo "  dry run; body:"
    printf '%s\n' "$body" | python3 -m json.tool | sed 's/^/    /'
  fi
done

if [[ "$APPLY" -eq 0 ]]; then
  echo
  echo "Dry run only. Re-run with --apply to write these settings."
fi