#!/usr/bin/env python3
"""Check native window behavior and responsive Studio layout in the running app."""
from __future__ import annotations

import argparse
import json
import subprocess
import tempfile
import time
from pathlib import Path

from showtime_client import Client, ShowtimeError
from showtime_version import APP_VERSION


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output-dir", type=Path, help="New directory for Studio screenshots and window results")
    args = parser.parse_args()
    output = args.output_dir or Path(tempfile.mkdtemp(prefix="showtime-studio-"))
    if args.output_dir:
        output.mkdir(parents=True, exist_ok=False)
    output = output.resolve()
    client = Client()
    status = client.status()
    if any(status[key] for key in ("playing", "recording", "preparing", "finishing")):
        raise ShowtimeError("Finish the current take before running Studio checks.")
    assert status["appVersion"] == APP_VERSION, "Rebuild and reopen the app first."
    endpoint = "/v1/studio/window"
    results = []

    def window():
        return client.request("GET", endpoint)

    def action(name, **values):
        return client.request("POST", endpoint, {"action": name, **values})

    def wait_for(predicate, label, timeout=8):
        deadline = time.monotonic() + timeout
        while time.monotonic() < deadline:
            state = window()
            if not state["transitioning"] and predicate(state):
                # A second sample avoids mistaking the start of an AppKit
                # animation for its settled frame.
                time.sleep(0.2)
                settled = window()
                if not settled["transitioning"] and predicate(settled) and settled["frame"] == state["frame"]:
                    results.append({"check": label, "window": settled})
                    print("PASS " + label, flush=True)
                    return settled
            time.sleep(0.1)
        raise AssertionError(label + ": " + json.dumps(window()))

    def same_frame(state, target):
        return all(abs(state["frame"][key] - target["frame"][key]) <= 1 for key in ("x", "y", "width", "height"))

    def normal(state):
        return not any(state[key] for key in ("zoomed", "minimized", "fullscreen"))

    def screenshot(name):
        # Allow the sidebar transition and the WebKit compositor to settle.
        time.sleep(0.35)
        client.request("POST", "/v1/studio/screenshot", {"output": str(output / (name + ".png"))})

    action("restore")
    wait_for(normal, "Window is ready")
    original = window()
    previous_studio = status["studio"]
    try:
        action("resize", width=min(1560, max(original["minimumSize"]["width"], original["screen"]["width"] - 120)),
               height=min(1040, max(original["minimumSize"]["height"], original["screen"]["height"] - 120)))
        baseline = wait_for(normal, "Normal window layout")
        lights = baseline["trafficLights"]
        assert set(lights) == {"close", "minimize", "zoom"}
        assert all(button["enabled"] and button["visible"] for button in lights.values())
        frames = [lights[name]["frame"] for name in ("close", "minimize", "zoom")]
        assert frames[0]["x"] < frames[1]["x"] < frames[2]["x"]
        assert max(frame["y"] for frame in frames) - min(frame["y"] for frame in frames) <= 1
        assert all(frame["y"] >= baseline["contentLayout"]["height"] for frame in frames)
        print("PASS Real traffic lights are visible and aligned in the titlebar", flush=True)

        action("minimize")
        wait_for(lambda state: state["minimized"], "Native yellow button minimizes")
        action("restore")
        wait_for(lambda state: normal(state) and same_frame(state, baseline), "Minimize restores the original frame")

        action("zoom")
        wait_for(lambda state: state["zoomed"] and not same_frame(state, baseline), "Native zoom expands the window")
        action("restore")
        wait_for(lambda state: normal(state) and same_frame(state, baseline), "Zoom restores the original frame")

        entry = action("fullscreen")
        if entry["transitioning"]:
            try:
                action("restore")
            except ShowtimeError as error:
                assert "409" in str(error)
            else:
                raise AssertionError("An overlapping full-screen operation was accepted.")
            print("PASS Overlapping full-screen operations are rejected until AppKit finishes", flush=True)
        wait_for(lambda state: state["fullscreen"], "Native full-screen entry")
        action("restore")
        wait_for(lambda state: normal(state) and same_frame(state, baseline), "Full screen restores the original frame")

        preference = subprocess.run(["defaults", "read", "-g", "AppleActionOnDoubleClick"],
                                    capture_output=True, text=True).stdout.strip().lower()
        action("doubleClickTitlebar")
        if preference == "minimize":
            wait_for(lambda state: state["minimized"], "Titlebar double-click honors Minimize preference")
            action("restore")
        elif preference == "none":
            time.sleep(0.4)
            wait_for(lambda state: normal(state) and same_frame(state, baseline), "Titlebar double-click honors None preference")
        else:
            wait_for(lambda state: state["zoomed"], "Titlebar double-click expands")
            action("doubleClickTitlebar")
        wait_for(lambda state: normal(state) and same_frame(state, baseline), "Titlebar double-click preserves restoration")

        client.act({"action": "open", "url": "showtime://demo"})
        time.sleep(0.8)
        client.request("POST", "/v1/studio", {"theater": False, "showInspector": True, "inspector": "Canvas"})
        screenshot("canvas")
        client.request("POST", "/v1/studio", {"inspector": "Cursor"})
        screenshot("cursor")
        client.request("POST", "/v1/studio", {"inspector": "Text"})
        screenshot("text")
        minimum = baseline["minimumSize"]
        action("resize", width=minimum["width"], height=minimum["height"])
        wait_for(lambda state: state["frame"]["width"] == minimum["width"] and state["frame"]["height"] == minimum["height"],
                 "Minimum window size")
        client.request("POST", "/v1/studio", {"inspector": "Canvas"})
        screenshot("minimum")
        client.act({"action": "click", "selector": "#new-project", "duration": 0.15})
        client.act({"action": "assert", "script": "!!document.querySelector('#project-name') && window.__inputLog.some(e=>e.kind==='click' && e.trusted && e.target==='new-project')"})
        client.act({"action": "key", "key": "escape"})
        print("PASS Trusted webpage clicks remain accurate at minimum window size", flush=True)

        client.request("POST", "/v1/studio", {"theater": True})
        screenshot("theater")
        client.act({"action": "click", "selector": "#range-quarter", "duration": 0.15})
        client.act({"action": "assert", "script": "window.orbit.state.range === 'quarter' && window.__inputLog.some(e=>e.kind==='click' && e.trusted && e.target==='range-quarter')"})
        print("PASS Theater mode preserves trusted webpage input", flush=True)
    finally:
        wait_for(lambda state: True, "Window animation has settled")
        action("restore")
        wait_for(normal, "Restored after checks")
        action("resize", width=original["frame"]["width"], height=original["frame"]["height"])
        client.request("POST", "/v1/studio", {"inspector": previous_studio["inspector"],
                       "showInspector": previous_studio["showInspector"], "theater": previous_studio.get("theater", False)})
        (output / "window-results.json").write_text(json.dumps(results, indent=2) + "\n")
    print("Studio artifacts: " + str(output), flush=True)


if __name__ == "__main__":
    main()
