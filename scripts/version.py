#!/usr/bin/env python3
"""Keep native app metadata in sync with package.json; never commits or publishes."""
from __future__ import annotations

import argparse
import json
import plistlib
import re
import subprocess
import sys
import time
from pathlib import Path

from showtime_version import MANIFEST, read_version

ROOT = MANIFEST.parent


def generated_files(version: str) -> dict[Path, bytes]:
    swift = ('// Generated from package.json by scripts/version.py. Do not edit directly.\n'
             'enum AppVersion {\n'
             f'    static let number = "{version}"\n'
             '    static let display = "v\\(number)"\n'
             '}\n')
    plist_path = ROOT / "scripts/Info.plist"
    info = plistlib.loads(plist_path.read_bytes())
    info["CFBundleShortVersionString"] = version
    info["CFBundleVersion"] = version
    return {
        ROOT / "Sources/Showtime/App/AppVersion.swift": swift.encode(),
        plist_path: plistlib.dumps(info, sort_keys=False),
    }


def sync(version: str, check: bool = False) -> None:
    stale = []
    for path, expected in generated_files(version).items():
        if not path.exists() or path.read_bytes() != expected:
            stale.append(str(path.relative_to(ROOT)))
            if not check:
                path.write_bytes(expected)
    if check and stale:
        raise ValueError("Version metadata is out of sync: " + ", ".join(stale) + ". Run scripts/version.py sync.")


def git(*arguments: str) -> str:
    result = subprocess.run(["git", *arguments], cwd=ROOT, text=True, capture_output=True)
    return result.stdout.strip() if result.returncode == 0 else ""


def automatic_revision() -> tuple[str, str]:
    previous = git("describe", "--tags", "--abbrev=0", "--match", "v[0-9]*")
    if not previous:
        return "patch", "no earlier version tag; default patch"
    changed = 0
    for line in git("diff", "--numstat", previous).splitlines():
        added, removed, _ = line.split("\t", 2)
        if added.isdigit() and removed.isdigit():
            changed += int(added) + int(removed)
    for name in git("ls-files", "--others", "--exclude-standard", "-z").split("\0"):
        if name:
            try:
                changed += len((ROOT / name).read_text().splitlines())
            except (UnicodeError, OSError):
                pass
    timestamp = git("log", "-1", "--format=%ct", previous)
    age = (time.time() - int(timestamp)) / 86400 if timestamp.isdigit() else 0
    if changed > 500 or age > 3:
        return "minor", f"{changed} changed lines, {age:.1f} days since {previous}"
    return "patch", f"{changed} changed lines, {age:.1f} days since {previous}"


def next_version(current: str, revision: str) -> str:
    major, minor, patch = map(int, current.split("."))
    if revision == "patch":
        return f"{major}.{minor}.{patch + 1}"
    if revision == "minor":
        return f"{major}.{minor + 1}.0"
    if revision == "major":
        return f"{major + 1}.0.0"
    if not re.fullmatch(r"(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)", revision):
        raise ValueError("Choose auto, patch, minor, major, or an explicit X.Y.Z version.")
    if tuple(map(int, revision.split("."))) <= (major, minor, patch):
        raise ValueError("The new version must be greater than the current version.")
    return revision


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("action", choices=["show", "check", "sync", "bump"], nargs="?", default="show")
    parser.add_argument("revision", nargs="?", default="auto")
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()
    if args.dry_run and args.action != "bump":
        parser.error("--dry-run applies to bump only; use check to verify without writing.")
    if args.revision != "auto" and args.action != "bump":
        parser.error("A revision can only be supplied to bump.")
    version = read_version()
    if args.action in ("check", "sync"):
        sync(version, check=args.action == "check")
        print(f"Version metadata {'verified' if args.action == 'check' else 'synced'}: v{version}")
    elif args.action == "bump":
        revision, reason = automatic_revision() if args.revision == "auto" else (args.revision, "explicit choice")
        new = next_version(version, revision)
        print(f"v{version} → v{new} ({reason})")
        if not args.dry_run:
            # Validate the generated metadata before changing the source manifest.
            generated_files(new)
            manifest = json.loads(MANIFEST.read_text())
            manifest["version"] = new
            MANIFEST.write_text(json.dumps(manifest, indent=2, ensure_ascii=False) + "\n")
            sync(new)
            print("Update CHANGELOG.md, verify, then commit and publish the matching tag and GitHub Release.")
    else:
        print(f"v{version}")


if __name__ == "__main__":
    try:
        main()
    except (ValueError, OSError, KeyError, plistlib.InvalidFileException) as error:
        print(str(error), file=sys.stderr)
        sys.exit(1)
