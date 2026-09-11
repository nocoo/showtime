#!/usr/bin/env python3
"""Verify native navigation, Orbit backdrops/glow, and combined camera playback."""
from __future__ import annotations

import argparse
import functools
import http.server
import json
import shutil
import subprocess
import sys
import tempfile
import threading
import time
from pathlib import Path

sys.dont_write_bytecode = True
from showtime_client import Client, ShowtimeError
from showtime_schema import BACKDROPS
from test_capture import MCP


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output-dir", type=Path)
    args = parser.parse_args()
    if not shutil.which("ffmpeg"):
        parser.error("Install FFmpeg to inspect the actual frames.")
    output = (args.output_dir or Path(tempfile.mkdtemp(prefix="showtime-presentation-"))).resolve()
    if args.output_dir:
        output.mkdir(parents=True, exist_ok=False)
    client, mcp = Client(), MCP()
    initial = client.status()
    assert not initial["busy"], "Finish the current take first."
    settings = client.request("GET", "/v1/settings")
    window = client.request("GET", "/v1/studio/window")
    results = []

    def check(name, **facts):
        results.append({"check": name, **facts})
        print("PASS " + name, flush=True)

    def wait_for(predicate, timeout=10):
        deadline = time.monotonic() + timeout
        while time.monotonic() < deadline:
            state = client.status()
            if predicate(state):
                return state
            time.sleep(.05)
        raise AssertionError("Expected state not reached: " + json.dumps(client.status()))

    def screenshot(name, native=False):
        path = output / (name + ".png")
        client.request("POST", "/v1/studio/screenshot" if native else "/v1/screenshot", {"output": str(path)})
        return path

    def pixels(path, size=None):
        filters = (f"scale={size[0]}:{size[1]}," if size else "") + "format=rgb24"
        return subprocess.check_output(["ffmpeg", "-v", "error", "-i", str(path), "-vf", filters,
                                        "-frames:v", "1", "-f", "rawvideo", "-"])

    def sample(data, x, y):
        index = (y * 1920 + x) * 3
        return tuple(data[index:index + 3])

    # The fixed Studio location row is available even on devices without chrome.
    def navigation_button(index):
        client.request("POST", "/v1/studio/window", {"action": "restore"})
        # Activation and SwiftUI's enabled state settle after the design job ends.
        time.sleep(.2)
        layout = client.request("GET", "/v1/studio/window")
        client.request("POST", "/v1/studio/window", {"action": "click", "x": 347 + index * 24,
                       "y": layout["contentLayout"]["height"] - 116})

    armed, requested, released = threading.Event(), threading.Event(), threading.Event()

    class OrbitServer(http.server.SimpleHTTPRequestHandler):
        def do_GET(self):
            if armed.is_set() and self.path.split("?")[0] == "/demo/":
                requested.set()
                released.wait(40)
            self.path = self.path.replace("/demo/", "/", 1)
            try:
                super().do_GET()
            except (BrokenPipeError, ConnectionResetError):
                pass

        def end_headers(self):
            self.send_header("Cache-Control", "no-store")
            super().end_headers()

        def log_message(self, *args):
            pass

    demo = Path(__file__).resolve().parent.parent / "Sources/Showtime/Resources/Demo"
    server = http.server.ThreadingHTTPServer(("127.0.0.1", 0), functools.partial(OrbitServer, directory=str(demo)))
    threading.Thread(target=server.serve_forever, daemon=True).start()
    try:
        mcp.request("initialize", {"protocolVersion": "2025-06-18"})
        client.request("POST", "/v1/studio/window", {"action": "restore"})
        client.request("POST", "/v1/studio", {"mode": "studio", "theme": "light", "showInspector": True, "inspector": "Canvas"})
        client.design({"action": "open", "url": "showtime://demo"})
        client.design({"action": "waitFor", "label": "Visible Orbit page (unlock the Mac if paused)", "timeout": 10,
                       "script": "!document.hidden && document.querySelector('#revenue-chart') && getComputedStyle(document.querySelector('.content')).opacity === '1'"})
        base = client.status()["url"]
        destination = base + "?story=launch"
        client.design({"action": "open", "url": destination})
        assert client.status()["navigation"]["canGoBack"] and not client.status()["navigation"]["canGoForward"]
        navigation_button(0)
        wait_for(lambda s: s["url"] == base and not s["navigation"]["loading"])
        assert client.status()["navigation"]["canGoForward"]
        navigation_button(1)
        wait_for(lambda s: s["url"] == destination and not s["navigation"]["loading"])
        assert not client.status()["navigation"]["canGoForward"]
        navigation_button(0)
        wait_for(lambda s: s["url"] == base and not s["navigation"]["loading"])
        client.design({"action": "open", "url": base + "?story=revenue"})
        assert not client.status()["navigation"]["canGoForward"], "A new navigation must discard the forward branch"
        check("Native Back/Forward follow WebKit history and new navigation clears forward history")

        base = client.status()["url"]
        for fragment in ("#projects", "#projects", "#overview", ""):
            started = time.monotonic()
            client.design({"action": "open", "url": base + fragment, "timeout": 3})
            assert client.status()["ready"] and time.monotonic() - started < 3
        check("Changed, repeated, and cleared URL fragments complete without a false timeout")

        # A real Orbit reload whose HTTP response is intentionally delayed.
        # Click Open so this exercises a human navigation, including its async wait.
        client.design({"action": "open", "url": f"http://localhost:{server.server_port}/demo/"})
        time.sleep(.3)
        layout = client.request("GET", "/v1/studio/window")
        armed.set()
        client.request("POST", "/v1/studio/window", {"action": "click", "x": layout["frame"]["width"] - 80,
                       "y": layout["contentLayout"]["height"] - 116})
        assert requested.wait(5), "The native Open button did not start loading"
        wait_for(lambda s: s["navigation"]["loading"] and s["navigation"]["canNavigate"])
        navigation_button(2)
        wait_for(lambda s: not s["navigation"]["loading"])
        stopped = time.monotonic()
        assert "error" not in client.status()
        screenshot("navigation-stopped", native=True)
        check("Native Stop cancels a slow human navigation and returns to the idle state")

        # Preserve the original Orbit product UI while varying its presentation.
        mcp.call("showtime_settings", canvas={"width": 1920, "height": 1080, "frame": "macbook-pro", "contentWidth": 1000,
                 "browserTheme": "light", "glow": False}, video={"width": 1920, "height": 1080, "fps": 30})
        client.design({"action": "cursor", "visible": False})
        client.design({"action": "wait", "duration": .6})
        colors = {}
        for backdrop in BACKDROPS:
            mcp.call("showtime_settings", canvas={"backdrop": backdrop})
            data = pixels(screenshot("backdrop-" + backdrop))
            colors[backdrop] = sample(data, 120, 540)
        assert len(set(colors.values())) == len(BACKDROPS)
        assert max(colors["silver"]) - min(colors["silver"]) < 15
        assert colors["mist"][1] > colors["mist"][0] and colors["sky"][2] > colors["sky"][0]
        assert colors["rose"][0] > colors["rose"][1] and colors["butter"][0] > colors["butter"][2]
        check("All nine backdrops render distinct, restrained colors around the real Orbit screen", colors=colors)

        glow_samples = []
        for theme, backdrop in (("light", "silver"), ("dark", "midnight")):
            mcp.call("showtime_settings", canvas={"browserTheme": theme, "backdrop": backdrop, "glow": False})
            before = pixels(screenshot("glow-" + theme + "-off"))
            mcp.call("showtime_settings", canvas={"glow": True, "glowRadius": .75, "glowSize": .3})
            after = pixels(screenshot("glow-" + theme + "-on"))
            difference = lambda x, y: max(b - a for a, b in zip(sample(before, x, y), sample(after, x, y)))
            assert 1 < difference(960, 100) < 35, "Glow must remain visible and subtle"
            assert difference(20, 20) < difference(960, 100), "Light must fall off away from the center"
            assert sample(before, 960, 540) == sample(after, 960, 540), "Glow must stay behind the webpage"
            mcp.call("showtime_settings", canvas={"glowRadius": 1.2, "glowSize": .8})
            larger = pixels(screenshot("glow-" + theme + "-larger"))
            assert sum(sample(larger, 960, 100)) > sum(sample(after, 960, 100)), "Changing radius and size must invalidate the backdrop cache"
            client.request("POST", "/v1/studio", {"theme": theme})
            screenshot("studio-" + theme, native=True)
            glow_samples.append({"theme": theme, "edgeDelta": difference(960, 100), "cornerDelta": difference(20, 20)})
        check("Glow fades from the center, stays behind content, and updates in Light/Dark preview and export", samples=glow_samples)

        # No later navigation may mask the old 30-second open timeout after Stop.
        while time.monotonic() - stopped < 31:
            assert "error" not in client.status()
            time.sleep(.2)
        assert "error" not in client.status()
        released.set(); armed.clear()
        check("Stopping a page load does not produce a delayed timeout error")

        current = client.request("GET", "/v1/settings")
        for invalid in ({"glowRadius": 0}, {"glowRadius": 2}, {"glowSize": -1}, {"glowSize": 2}, {"glow": "yes"}, {"backdrop": "neon"}):
            try:
                client.request("POST", "/v1/settings", {"canvas": invalid})
            except ShowtimeError:
                pass
            else:
                raise AssertionError("Invalid Canvas settings were accepted: " + str(invalid))
            assert client.request("GET", "/v1/settings") == current
        cli = subprocess.run([sys.executable, str(Path(__file__).with_name("showtime_cli.py")), "settings", "--backdrop", "silver",
                              "--glow", "--glow-radius", ".75", "--glow-size", ".3"], capture_output=True, text=True, check=True)
        assert json.loads(cli.stdout)["canvas"]["glow"]
        check("CLI/MCP share glow settings and rejected edits preserve the current Canvas")

        script = {"name": "Orbit · Revenue close-up", "canvas": {"width": 1920, "height": 1080, "inset": 64, "backdrop": "silver",
                  "glow": True, "glowRadius": .75, "glowSize": .3, "browserTheme": "light", "frame": "none"},
                  "setup": [{"action": "open", "url": "showtime://demo"}, {"action": "cursor", "visible": False},
                            {"action": "waitFor", "label": "Visible Orbit page (unlock the Mac if paused)", "timeout": 10,
                             "script": "!document.hidden && document.querySelector('#revenue-chart') && getComputedStyle(document.querySelector('.content')).opacity === '1'"}],
                  "steps": [{"action": "wait", "duration": .6},
                            {"id": "focus-revenue", "action": "camera", "scale": 1.5, "offsetX": 160, "offsetY": -70, "duration": 2, "easing": "linear"},
                            {"action": "wait", "duration": 1.2},
                            {"id": "overview", "action": "camera", "scale": 1, "offsetX": 0, "offsetY": 0, "duration": 1.2, "easing": "smooth"},
                            {"action": "wait", "duration": .4}]}
        (output / "camera-script.json").write_text(json.dumps(script, indent=2) + "\n")
        for mode in ("rehearse", "record"):
            client.request("POST", "/v1/studio/window", {"action": "restore"})
            options = {"output": str(output / "orbit-camera.mp4")} if mode == "record" else {}
            job = client.play(script, mode, wait=False, **options)["job"]
            samples = []
            while True:
                state = client.status()
                result = client.request("GET", "/v1/jobs/" + job)
                if result["status"] != "running":
                    break
                if state["playing"]:
                    assert not state["navigation"]["canNavigate"]
                camera = state["camera"]
                if 1.05 < camera["scale"] < 1.45:
                    progress = (camera["scale"] - 1) / .5
                    assert abs(camera["offsetX"] - 160 * progress) < .001
                    assert abs(camera["offsetY"] + 70 * progress) < .001
                    samples.append(camera)
                time.sleep(.07)
            (output / (mode + "-camera-result.json")).write_text(json.dumps({"job": result, "samples": samples}, indent=2) + "\n")
            assert result["status"] == "completed", result
            assert len(samples) >= 8, "Too few intermediate camera samples"
            assert client.status()["camera"]["offsetX"] == 0 and client.status()["camera"]["scale"] == 1
            check(mode.capitalize() + " animates scale and both offsets together, including the return to the overview", samples=len(samples))

        frames = []
        for index, timestamp in enumerate((.25, 1.0, 1.4, 1.8, 2.2, 3.3)):
            path = output / f"camera-frame-{index}.png"
            subprocess.run(["ffmpeg", "-v", "error", "-ss", str(timestamp), "-i", str(output / "orbit-camera.mp4"), "-frames:v", "1", str(path)], check=True)
            frames.append(pixels(path, (320, 180)))
        def distance(a, b):
            return sum(abs(x - y) for x, y in zip(a, b)) / len(a)
        intermediate = [min(distance(frame, frames[0]), distance(frame, frames[-1])) for frame in frames[1:-1]]
        assert all(value > 1.5 for value in intermediate), "The MP4 must contain intermediate camera positions, not just jump between its endpoints"
        check("The actual MP4 contains distinct intermediate camera frames", intermediateFrameDifferences=intermediate)
    finally:
        released.set(); server.shutdown(); server.server_close()
        if client.status()["busy"]:
            client.request("POST", "/v1/cancel", {})
            wait_for(lambda s: not s["busy"])
        client.request("POST", "/v1/settings", settings)
        client.design({"action": "open", "url": initial["url"]})
        client.design({"action": "camera", **initial["camera"], "duration": 0})
        client.request("POST", "/v1/studio", initial["studio"])
        client.request("POST", "/v1/studio/window", {"action": "resize", "width": window["frame"]["width"], "height": window["frame"]["height"]})
        mcp.close()
        (output / "presentation-results.json").write_text(json.dumps(results, indent=2) + "\n")
    print("Presentation artifacts: " + str(output), flush=True)


if __name__ == "__main__":
    main()
