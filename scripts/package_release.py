#!/usr/bin/env python3
"""Verify, notarize, and archive Showtime. Never commits, pushes, or publishes."""
from __future__ import annotations

import argparse
import hashlib
import json
import os
import plistlib
import subprocess
import sys
import tempfile
from pathlib import Path

sys.dont_write_bytecode = True
from showtime_version import APP_VERSION, MANIFEST

ROOT = MANIFEST.parent


def run(*command: str | Path, include_stderr: bool = False) -> str:
    result = subprocess.run([str(part) for part in command], capture_output=True, text=True)
    if result.returncode:
        raise ValueError(f"{command[0]} failed:\n{result.stdout}{result.stderr}")
    return result.stdout + (result.stderr if include_stderr else "")


def verify_app(app: Path, public: bool) -> tuple[str, str]:
    info = plistlib.loads((app / "Contents/Info.plist").read_bytes())
    if info.get("CFBundleIdentifier") != "studio.showtime.mac":
        raise ValueError("The bundle identifier must remain studio.showtime.mac.")
    if any(info.get(key) != APP_VERSION for key in ("CFBundleVersion", "CFBundleShortVersionString")):
        raise ValueError("App version does not match package.json. Rebuild before packaging.")
    if info.get("LSMinimumSystemVersion") != "14.0":
        raise ValueError("Recheck the documented minimum macOS version before packaging.")
    resources = app / "Contents/Resources"
    for name in ("Showtime.icns", "LICENSE", "Tools/showtime", "Tools/showtime_mcp.py",
                 "Tools/showtime_client.py", "Tools/showtime_cli.py", "Tools/showtime_version.py",
                 "Showtime_Showtime.bundle/ShowtimeMark.png", "Showtime_Showtime.bundle/DirectorBrowser.svg",
                 "Showtime_Showtime.bundle/Demo/index.html", "Showtime_Showtime.bundle/Scripts/orbit-launch.json"):
        if not (resources / name).is_file():
            raise ValueError(f"Missing bundled resource: {name}")
    manifest = json.loads((resources / "Tools/package.json").read_text())
    if manifest.get("version") != APP_VERSION:
        raise ValueError("The bundled agent tools have a different version.")
    if list(resources.rglob("__pycache__")):
        raise ValueError("Remove Python bytecode caches and rebuild the signed bundle.")
    architectures = set(run("lipo", "-archs", app / "Contents/MacOS/Showtime").split())
    labels = {frozenset({"arm64"}): "arm64", frozenset({"x86_64"}): "x86_64",
              frozenset({"arm64", "x86_64"}): "universal"}
    if frozenset(architectures) not in labels:
        raise ValueError(f"Unexpected executable architectures: {sorted(architectures)}")
    run("codesign", "--verify", "--deep", "--strict", "--verbose=2", app)
    signature = run("codesign", "--display", "--verbose=4", app, include_stderr=True)
    if public:
        team = os.environ.get("DEVELOPMENT_TEAM", "93WWLTN9XU")
        if "Authority=Developer ID Application:" not in signature:
            raise ValueError("Public download requires Developer ID Application signing. See docs/signing.md.")
        if f"TeamIdentifier={team}\n" not in signature:
            raise ValueError(f"Expected signing team {team}. Check DEVELOPMENT_TEAM.")
        if "(runtime)" not in signature or "Timestamp=" not in signature:
            raise ValueError("Developer ID builds require Hardened Runtime and a secure timestamp. Rebuild.")
    return labels[frozenset(architectures)], signature


def archive(app: Path, output: Path) -> None:
    run("ditto", "-c", "-k", "--sequesterRsrc", "--keepParent", app, output)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--app", type=Path, default=ROOT / "dist/Showtime.app")
    parser.add_argument("--output-dir", type=Path, default=ROOT / f"dist/release-v{APP_VERSION}")
    parser.add_argument("--notary-profile", default=os.environ.get("SHOWTIME_NOTARY_PROFILE"),
                        help="Existing notarytool keychain profile; credentials stay in the keychain")
    parser.add_argument("--local-preview", action="store_true", help="Make an explicitly local-only archive without public signing")
    parser.add_argument("--unnotarized", action="store_true",
                        help="Explicitly package an unnotarized release; requires a first-open notice in release notes")
    args = parser.parse_args()
    if sum(bool(value) for value in (args.local_preview, args.unnotarized, args.notary_profile)) != 1:
        parser.error("Choose --notary-profile, --local-preview, or explicit --unnotarized packaging.")
    app = args.app.resolve()
    public = not args.local_preview
    notarize = bool(args.notary_profile)
    architecture, signature = verify_app(app, notarize)
    output_dir = args.output_dir.resolve()
    suffix = "" if public else "-local-preview"
    name = f"Showtime-{APP_VERSION}-macos-{architecture}{suffix}"
    output = output_dir / f"{name}.zip"
    checksum = output_dir / f"{name}.sha256"
    report = output_dir / f"{name}.verification.json"
    if any(path.exists() for path in (output, checksum, report)):
        raise ValueError("An archive or verification record already exists. Choose a new output directory.")
    output_dir.mkdir(parents=True, exist_ok=True)
    notary = None
    gatekeeper = None
    with tempfile.TemporaryDirectory(prefix="showtime-package-") as staging:
        staged = Path(staging)
        if notarize:
            submission = staged / "Showtime-notary.zip"
            archive(app, submission)
            print("Submitting Developer ID build to Apple notarization…", flush=True)
            notary = json.loads(run("xcrun", "notarytool", "submit", submission, "--keychain-profile",
                                    args.notary_profile, "--wait", "--output-format", "json"))
            (output_dir / f"{name}.notary.json").write_text(json.dumps(notary, indent=2) + "\n")
            if notary.get("status") != "Accepted":
                raise ValueError(f"Apple notarization was not accepted. Check submission {notary.get('id')} with notarytool log.")
            run("xcrun", "stapler", "staple", app)
            run("xcrun", "stapler", "validate", app)
            run("spctl", "--assess", "--type", "execute", "--verbose=2", app)
        staged_archive = staged / output.name
        archive(app, staged_archive)
        # Check the exact archive users will download, including resources and signatures.
        extracted = staged / "download"
        run("ditto", "-x", "-k", staged_archive, extracted)
        installed = extracted / "Showtime.app"
        verify_app(installed, notarize)
        if notarize:
            run("xcrun", "stapler", "validate", installed)
            run("spctl", "--assess", "--type", "execute", "--verbose=2", installed)
            gatekeeper = {"accepted": True, "source": "Notarized Developer ID"}
        elif args.unnotarized:
            assessment = subprocess.run(["spctl", "--assess", "--type", "execute", "--verbose=2", str(installed)],
                                        capture_output=True, text=True)
            gatekeeper = {"accepted": assessment.returncode == 0, "details": assessment.stdout + assessment.stderr}
        cli_version = run(sys.executable, installed / "Contents/Resources/Tools/showtime", "--version").strip()
        if cli_version != f"showtime {APP_VERSION}":
            raise ValueError(f"Unexpected bundled CLI version: {cli_version}")
        # Exercising the tools must not mutate or invalidate the app signature.
        run("codesign", "--verify", "--deep", "--strict", installed)
        staged_archive.replace(output)
    digest = hashlib.sha256(output.read_bytes()).hexdigest()
    checksum.write_text(f"{digest}  {output.name}\n")
    report.write_text(json.dumps({"version": APP_VERSION, "architecture": architecture,
                                 "minimumMacOS": "14.0", "publicDistribution": public,
                                 "archive": output.name, "sha256": digest, "signature": signature,
                                 "notarized": notarize, "notarization": notary, "gatekeeper": gatekeeper,
                                 "archiveVerified": True}, indent=2) + "\n")
    if args.unnotarized:
        print("UNNOTARIZED RELEASE: disclose this signing status and macOS first-open confirmation in the release notes.")
    print(f"{'Public release archive' if public else 'LOCAL PREVIEW ONLY'}: {output}")
    print(f"SHA-256: {digest}")


if __name__ == "__main__":
    try:
        main()
    except (OSError, ValueError, plistlib.InvalidFileException) as error:
        print(str(error), file=sys.stderr)
        sys.exit(1)
