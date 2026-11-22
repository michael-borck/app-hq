#!/usr/bin/env python3
"""Check the local fleet's git remotes against ADR 0004.

Owned repos (OWNERS below) must use SSH remotes
(git@github.com:<owner>/<repo>.git). Third-party reference clones stay
on anonymous HTTPS and are only reported, never converted.

Dry run by default: prints drift. Use --apply to convert owned HTTPS
remotes to SSH. See runbooks/github-auth.md.
"""

from __future__ import annotations

import argparse
import os
import re
import subprocess
import sys

OWNERS = {"michael-borck", "retroverse-studios"}
PRUNE = {
    "node_modules", ".venv", "venv", "__pycache__", ".next",
    "dist", "build", "target", "htmlcov", "test-results",
}
MAX_DEPTH = 8
HTTPS_RE = re.compile(r"https?://(?:[^@/]+@)?github\.com/([^/]+)/(.+?)(?:\.git)?/?$")
SSH_RE = re.compile(r"(?:ssh://)?(?:[^@/]+@)?([^/:]+)[:/](.+?)(?:\.git)?/?$")


def find_repos(root: str) -> list[str]:
    repos = []
    root_depth = root.count(os.sep)
    for dirpath, dirnames, filenames in os.walk(root):
        if ".git" in dirnames or ".git" in filenames:
            repos.append(dirpath)
        dirnames[:] = [
            d for d in dirnames
            if d not in PRUNE and d != ".git" and not d.startswith("._")
        ]
        if dirpath.count(os.sep) - root_depth >= MAX_DEPTH:
            dirnames[:] = []
    return sorted(set(repos))


def remotes(repo: str) -> dict[str, set[str]]:
    try:
        out = subprocess.run(
            ["git", "-C", repo, "remote", "-v"],
            capture_output=True, text=True, timeout=15,
        ).stdout
    except Exception:
        return {}
    found: dict[str, set[str]] = {}
    for line in out.splitlines():
        parts = line.split()
        if len(parts) >= 2:
            found.setdefault(parts[0], set()).add(parts[1])
    return found


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("root", nargs="?", default=os.getcwd(),
                        help="tree to scan (default: current directory)")
    parser.add_argument("--apply", action="store_true",
                        help="convert owned HTTPS remotes to SSH")
    args = parser.parse_args(argv)

    root = os.path.abspath(args.root)
    repos = find_repos(root)
    ssh = https_own = https_other = no_remote = other = 0
    drift: list[str] = []

    for repo in repos:
        rel = os.path.relpath(repo, root)
        repo_remotes = remotes(repo)
        if not repo_remotes:
            no_remote += 1
            continue
        for name, urls in sorted(repo_remotes.items()):
            for url in sorted(urls):
                m = HTTPS_RE.match(url)
                if m and m.group(1) in OWNERS:
                    https_own += 1
                    new = f"git@github.com:{m.group(1)}/{m.group(2)}.git"
                    drift.append(f"{rel}  [{name}] {url} -> {new}")
                    if args.apply:
                        subprocess.run(
                            ["git", "-C", repo, "remote", "set-url", name, new],
                            check=True,
                        )
                elif m:
                    https_other += 1
                elif SSH_RE.match(url) and "@" in url or url.startswith("ssh://"):
                    ssh += 1
                else:
                    other += 1
                    drift.append(f"{rel}  [{name}] UNUSUAL {url}")

    print(f"repos scanned: {len(repos)} under {root}")
    print(f"  ssh remotes:          {ssh}")
    print(f"  https (owned):        {https_own}{'  <- converted' if args.apply and https_own else ''}")
    print(f"  https (third-party):  {https_other}  (left alone)")
    print(f"  other/unusual:        {other}")
    print(f"  repos with no remote: {no_remote}")
    if drift:
        print("\ndrift:")
        for line in drift:
            print(f"  {line}")
    if https_own and not args.apply:
        print("\nre-run with --apply to convert the owned HTTPS remotes above")
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
