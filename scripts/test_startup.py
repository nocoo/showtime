#!/usr/bin/env python3
"""Check Orbit startup and removal of the previous-website preference."""
from __future__ import annotations

import argparse
import json
import subprocess
import tempfile
import time
from pathlib import Path
from urllib.parse import urlparse

from showtime_client import Client, ShowtimeError
from showtime_version import APP_VERSION


def close_app():
    try:
        client = Client()
        state = client.status()
    except ShowtimeError:
        return
    assert not any(state[key] for key in ("playing", "recording", "preparing", "finishing")), "Finish the current take first."
    client.request("POST", "/v1/app/quit", {})
    deadline = time.monotonic() + 10
    while time.monotonic() < deadline:
        try:
            client.status()
        except ShowtimeError:
            return
        time.sleep(0.1)
    raise AssertionError("Showtime did not quit.")


def launch(app: Path) -> Client:
    subprocess.run(["open", "-n", str(app)], check=True)
    deadline = time.monotonic() + 20
    while time.monotonic() < deadline:
        try:
            client = Client()
            state = client.status()
            if state["ready"]:
                assert state["appVersion"] == APP_VERSION, "Rebuild the app before testing."
                assert urlparse(state["url"]).path == "/demo/", "Startup must open Orbit."
                assert urlparse(state["url"]).hostname == "localhost"
                assert "Orbit" in state["title"]
                client.act({"action": "waitFor", "selector": "#new-project"})
                return client
        except ShowtimeError:
            pass
        time.sleep(0.1)
    raise AssertionError("Showtime did not become ready.")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--app", type=Path, default=Path(__file__).resolve().parent.parent / "dist/Showtime.app")
    parser.add_argument("--output-dir", type=Path)
    args = parser.parse_args()
    app = args.app.resolve()
    assert (app / "Contents/MacOS/Showtime").is_file(), "Build Showtime.app first."
    output = args.output_dir or Path(tempfile.mkdtemp(prefix="showtime-startup-"))
    if args.output_dir:
        output.mkdir(parents=True, exist_ok=False)
    output = output.resolve()
    close_app()
    subprocess.run(["defaults", "write", "studio.showtime.mac", "lastWebsite", "https://example.com/previous-session"], check=True)
    client = launch(app)
    assert subprocess.run(["defaults", "read", "studio.showtime.mac", "lastWebsite"], capture_output=True).returncode != 0
    first_launch = client.status()
    client.act({"action": "click", "selector": "#new-project", "duration": 0.2})
    client.act({"action": "assert", "script": "!!document.querySelector('#project-name') && window.__inputLog.some(e=>e.kind==='click' && e.trusted && e.target==='new-project')"})
    client.act({"action": "key", "key": "escape"})
    other_page = output / "other-page.html"
    other_page.write_text("<!doctype html><title>Another website</title><h1>Another website</h1>\n")
    client.act({"action": "open", "url": other_page.as_uri()})
    assert client.status()["url"] == other_page.as_uri()
    assert subprocess.run(["defaults", "read", "studio.showtime.mac", "lastWebsite"], capture_output=True).returncode != 0
    close_app()
    client = launch(app)
    assert subprocess.run(["defaults", "read", "studio.showtime.mac", "lastWebsite"], capture_output=True).returncode != 0
    client.act({"action": "wait", "duration": 0.8, "label": "Let Orbit's entrance animation settle"})
    client.request("POST", "/v1/studio/screenshot", {"output": str(output / "orbit-startup.png")})
    (output / "startup-results.json").write_text(json.dumps({"app": str(app), "firstLaunch": first_launch, "afterReopen": client.status(), "trustedClick": True, "oldPreferenceRemoved": True}, indent=2) + "\n")
    print("PASS Orbit opens on upgrade and relaunch; old website preference removed; native page click verified.")
    print("Startup artifacts: " + str(output))


if __name__ == "__main__":
    main()
