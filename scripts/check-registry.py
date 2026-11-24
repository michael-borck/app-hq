#!/usr/bin/env python3
"""Check the fleet registry against what is on disk, and against the signing list.

Drift is easy to miss when a repo is checked out under another folder name
than it has on GitHub. This asks three questions:

  1. Which Electron/Tauri apps checked out under --root are not in the
     registry (apps, services or templates)?
  2. Which repos are in apple-signing-repos.txt but not in the registry, or
     the other way round once they sign with the API key?
  3. Which registered apps are not checked out here? Reported only: they may
     live on another machine.

Run it on the machine that holds the checkouts. It exits 1 when there is
drift. See registry/apps.yaml and runbooks/signing.md.

Only PyYAML-free: the registry is deliberately flat (sections of lists whose
items are plain scalars), so anything else in the file stops the check rather
than being misread.
"""

from __future__ import annotations

import argparse
import json
import os
import re
import subprocess
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
OWNERS = {"michael-borck", "retroverse-studios"}  # keep in step with check-remotes.py
SKIP = {
    "node_modules", ".venv", "venv", ".git", "dist", "build", "target", "__pycache__",
    ".next", ".nuxt", "out", "release", ".cache", ".tox", ".mypy_cache", ".pytest_cache",
    "site-packages", ".angular", ".svelte-kit", "coverage", ".turbo", ".parcel-cache",
    ".vite", ".cargo",
}


def git(cwd: Path, *args: str) -> str:
    return subprocess.run(
        ["git", "-C", str(cwd), *args], capture_output=True, text=True, check=False
    ).stdout.strip()


def slug_of(root: Path) -> str | None:
    """owner/repo from the origin remote, or None without one."""
    match = re.search(r"[:/]([^/:]+/([^/]+?))(?:\.git)?/?$", git(root, "remote", "get-url", "origin"))
    return match.group(1).lower() if match else None


def find_apps(root: Path) -> dict[str, dict]:
    """repo slug -> {"stacks", "checkouts"} for every Electron/Tauri app under root."""
    apps: dict[str, dict] = {}
    for dirpath, dirnames, filenames in os.walk(root):
        dirnames[:] = sorted(d for d in dirnames if d not in SKIP and not d.startswith("._"))
        here = Path(dirpath)
        files = [f for f in filenames if not f.startswith("._")]
        stacks = set()
        if here.name == "src-tauri" and "tauri.conf.json" in files:
            stacks.add("tauri")
        if "package.json" in files:
            try:
                package = json.loads((here / "package.json").read_text(errors="replace"))
            except ValueError:
                package = {}
            deps = {**(package.get("dependencies") or {}), **(package.get("devDependencies") or {})}
            has_electron_dep = any("electron" in name.lower() for name in deps)
            has_builder_config = any(
                f.startswith(("electron-builder.", "forge.config")) for f in files
            )
            if has_electron_dep or has_builder_config:
                stacks.add("electron")
        if not stacks:
            continue
        top = git(here, "rev-parse", "--show-toplevel")
        checkout = Path(top) if top else here
        slug = slug_of(checkout) or f"(no remote) {checkout.relative_to(root)}"
        app = apps.setdefault(slug, {"stacks": set(), "checkouts": set()})
        app["stacks"] |= stacks
        app["checkouts"].add(str(checkout.relative_to(root)))
    return apps


def unquote(text: str) -> str:
    text = text.strip()
    if len(text) >= 2 and text[0] == text[-1] and text[0] in "\"'":
        body = text[1:-1]
        return body.replace('\\"', '"').replace("\\\\", "\\") if text[0] == '"' else body.replace("''", "'")
    return text


def without_comment(line: str, where: str) -> str:
    """Drop a trailing # comment that is outside quotes."""
    quote = None
    for index, char in enumerate(line):
        if quote:
            if char == quote:
                quote = None
        elif char in "\"'":
            quote = char
        elif char == "#" and (index == 0 or line[index - 1] in " \t"):
            return line[:index].rstrip()
    if quote:
        sys.exit(f"{where}: unterminated quote")
    return line.rstrip()


def read_registry(path: Path) -> dict[str, list[dict[str, str]]]:
    sections: dict[str, list[dict[str, str]]] = {}
    section: list[dict[str, str]] | None = None
    item: dict[str, str] | None = None
    for number, raw in enumerate(path.read_text().splitlines(), start=1):
        line = without_comment(raw, f"{path}:{number}")
        if not line.strip():
            continue
        where = f"{path}:{number}"
        top_level = re.fullmatch(r"(\w+):", line)
        listed = re.fullmatch(r"\s*-\s+(\w+):\s*(.*)", line)
        field = re.fullmatch(r"\s+(\w+):\s*(.*)", line)
        if top_level and not line.startswith(" "):
            section = sections.setdefault(top_level.group(1), [])
            item = None
        elif listed and section is not None:
            item = {listed.group(1): unquote(listed.group(2))}
            section.append(item)
        elif field and item is not None:
            item[field.group(1)] = unquote(field.group(2))
        else:
            sys.exit(f"{where}: not a section of flat items — simplify the entry or extend read_registry")
    return sections


def read_signing_list(path: Path) -> dict[str, str]:
    """repo slug -> electron|tauri. Same file format as sync-apple-secrets.sh reads."""
    listed: dict[str, str] = {}
    for line in path.read_text().splitlines():
        words = line.split()
        if not words or words[0].startswith("#"):
            continue
        if len(words) < 2 or words[1] not in ("electron", "tauri"):
            sys.exit(f"{path}: expected 'owner/repo electron|tauri', got: {line.strip()!r}")
        listed[words[0].lower()] = words[1]
    return listed


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--root", type=Path, default=HERE.parent.parent,
                        help="folder holding the checkouts (default: the one app-hq is in)")
    parser.add_argument("--registry", type=Path, default=HERE.parent / "registry" / "apps.yaml")
    parser.add_argument("--signing-list", type=Path, default=HERE / "apple-signing-repos.txt")
    args = parser.parse_args()

    apps = find_apps(args.root)
    registry = read_registry(args.registry)
    signing = read_signing_list(args.signing_list)
    registered = {entry["repo"].lower(): entry for entry in registry.get("apps", [])}
    known = {entry["repo"].lower() for entries in registry.values() for entry in entries if "repo" in entry}

    unregistered = sorted(
        slug for slug in apps if slug.split("/")[0] in OWNERS and slug not in known
    )
    elsewhere = sorted(slug for slug in registered if slug not in apps)
    foreign = sorted(slug for slug in apps if slug.split("/")[0] not in OWNERS)
    list_only = sorted(slug for slug in signing if slug not in registered)
    api_key = {slug for slug, entry in registered.items() if entry.get("signing_workflow") == "api-key"}
    unsynced = sorted(slug for slug in api_key if slug not in signing)
    mismatched = sorted(
        f"{slug} ({registered[slug].get('stack')} in the registry, {signing[slug]} in the list)"
        for slug in api_key if slug in signing and signing[slug] != registered[slug].get("stack")
    )

    def show(title: str, lines: list[str]) -> None:
        if lines:
            print(f"\n{title}:")
            for line in lines:
                where = ", ".join(sorted(apps.get(line, {}).get("checkouts", []))) if line in apps else ""
                print(f"  {line}{'  —  ' + where if where else ''}")

    print(f"Checked {len(apps)} Electron/Tauri apps under {args.root}; "
          f"{len(known)} repos are in the registry.")
    show("Checked out but not in the registry", unregistered)
    show("In the signing list but not in the registry", list_only)
    show("Signing with the API key but not in the signing list", unsynced)
    show("Stack differs between registry and signing list", mismatched)
    show("Registered but not checked out here (informational)", elsewhere)
    show("Ignored: owned by someone else", foreign)

    problems = len(unregistered) + len(list_only) + len(unsynced) + len(mismatched)
    print(f"\n{problems} to fix." if problems else "\nRegistry and signing list agree with what is on disk.")
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main())
