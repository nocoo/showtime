#!/usr/bin/env python3
"""Verify transparent React overlays, native input, timing, and actual MP4 frames."""
from __future__ import annotations

import argparse
import functools
import http.server
import json
import os
import shutil
import subprocess
import sys
import tempfile
import threading
import time
from pathlib import Path

sys.dont_write_bytecode = True
from showtime_client import Client, ShowtimeError
from test_capture import MCP


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output-dir", type=Path)
    parser.add_argument("--recordings-only", action="store_true", help="Run only the rehearsal and movie checks")
    args = parser.parse_args()
    root = Path(__file__).resolve().parent.parent
    example = root / "examples/overlay-react"
    if not (example / "dist/like.js").is_file():
        parser.error("Build the React example first: cd examples/overlay-react && bun install && bun run build")
    if not all(shutil.which(tool) for tool in ("ffmpeg", "ffprobe")):
        parser.error("Install FFmpeg to inspect the actual preview and movie frames.")
    output = (args.output_dir or Path(tempfile.mkdtemp(prefix="showtime-overlay-"))).resolve()
    if args.output_dir:
        output.mkdir(parents=True, exist_ok=False)
    client, mcp = Client(), MCP()
    initial = client.status()
    assert not initial["busy"], "Finish the current take first."
    settings = client.request("GET", "/v1/settings")
    results = []

    def check(name, **facts):
        results.append({"check": name, **facts})
        print("PASS " + name, flush=True)

    def evaluate(expression):
        return client.design({"action": "evaluate", "script": expression})["results"][0]["value"]

    def cli(*arguments):
        result = subprocess.run([sys.executable, str(root / "scripts/showtime_cli.py"), *map(str, arguments)],
                                capture_output=True, text=True, timeout=90)
        assert result.returncode == 0, result.stdout + result.stderr
        return json.loads(result.stdout)

    def wait_state(predicate, timeout=15):
        deadline = time.monotonic() + timeout
        while time.monotonic() < deadline:
            state = client.status()
            if predicate(state):
                return state
            time.sleep(.05)
        raise AssertionError("Expected state not reached: " + json.dumps(client.status()))

    def rejected(step, message):
        started = time.monotonic()
        try:
            client.design(step)
        except ShowtimeError as error:
            assert message.lower() in str(error).lower(), str(error)
        else:
            raise AssertionError("Invalid renderer was accepted")
        assert time.monotonic() - started < 6, "Renderer failure must be bounded"

    def pixels(path, at=None, width=480):
        command = ["ffmpeg", "-v", "error"]
        if at is not None:
            command += ["-ss", str(at)]
        return subprocess.check_output([*command, "-i", str(path), "-vf", f"scale={width}:-1,format=rgb24",
                                        "-frames:v", "1", "-f", "rawvideo", "-"])

    def pink(data):
        return {i // 3 for i in range(0, len(data), 3)
                if data[i] > 170 and data[i+1] < 130 and 90 < data[i+2] < 220 and data[i] - data[i+1] > 70}

    def screenshot(name, native=False):
        path = output / name
        endpoint = "/v1/studio/screenshot" if native else "/v1/screenshot"
        client.request("POST", endpoint, {"output": str(path), **({"nativeOnly": True} if native else {})})
        return path

    def fixture(name, body):
        path = output / name
        path.write_text("<!doctype html><meta charset=utf-8><style>html,body{margin:0;background:transparent}</style>" + body)
        return str(path)

    def inspect_movie(path, take, width, height):
        metadata = json.loads(subprocess.check_output(["ffprobe", "-v", "error", "-show_entries",
            "stream=codec_name,width,height,r_frame_rate:format=duration", "-of", "json", str(path)]))
        stream = metadata["streams"][0]
        assert (stream["width"], stream["height"], stream["r_frame_rate"]) == (width, height, "30/1"), metadata
        assert stream["codec_name"] == "h264" and float(metadata["format"]["duration"]) > .5
        assert take["capturedFrames"] > 1 and take["duplicatedFrames"] == take["frames"] - take["capturedFrames"]
        # Decode the whole movie as well as inspecting representative frames.
        subprocess.run(["ffmpeg", "-v", "error", "-i", str(path), "-f", "null", "-"], check=True)
        return {key: take[key] for key in ("frames", "capturedFrames", "duplicatedFrames", "effectiveCaptureFPS")}

    visible = {"action": "waitFor", "script": "!document.hidden && document.querySelector('.content') && document.querySelector('.content').getAnimations().every(a => a.playState === 'finished')", "timeout": 15}
    canvas = {"width": 1920, "height": 1080, "inset": 64, "frame": "none", "contentWidth": None,
              "backdrop": "sky", "browserTheme": "light"}
    video = {"width": 1920, "height": 1080, "fps": 30}
    setup = [{"action": "open", "url": "showtime://demo"}, visible,
             {"action": "overlay", "source": str(example / "index.html"), "props": {"visible": False}}]
    try:
        mcp.request("initialize", {"protocolVersion": "2025-06-18"})
        assert cli("schema", "overlay") == mcp.call("showtime_help", topic="overlay")
        client.request("POST", "/v1/settings", {"canvas": canvas, "video": video})
        client.request("POST", "/v1/studio", {"mode": "theater", "theme": "light"})
        client.request("POST", "/v1/studio/window", {"action": "restore"})
        client.play({"setup": setup[:2], "steps": [{"action": "cursor", "visible": False}]}, "rehearse")
        if not args.recordings_only:
            baseline = pixels(screenshot("baseline.png"))
            action_path = output / "relative-action.json"
            # Compute the relative path for arbitrary user-selected artifact directories.
            action_path.write_text(json.dumps({"action": "overlay", "source": os.path.relpath(example / "index.html", output),
                                               "props": {"label": "React on a real webpage", "count": 128}, "duration": 30}))
            cli("design", "@" + str(action_path))
            client.design({"action": "wait", "duration": .5})
            composed = pixels(screenshot("react-preview.png"))
            native = pixels(screenshot("react-native.png", native=True))
            assert len(pink(composed)) > 70 and len(pink(native)) > 15, "React artwork must appear in both exports and the native preview"
            # Empty top-left Canvas margin remains identical, so the WebView is truly transparent.
            assert composed[:480 * 3 * 8] == baseline[:480 * 3 * 8], "Overlay must preserve the Canvas behind transparent pixels"
            check("CLI/MCP schema, relative HTML/assets, React rendering, and native/export alpha composition")

            client.design({"action": "click", "selector": "#new-project", "duration": .2})
            client.design({"action": "waitFor", "selector": "#project-name"})
            client.design({"action": "overlay", "clear": True})
            client.design({"action": "type", "selector": "#project-name", "text": "Overlay", "clear": True, "delay": .01})
            focus_source = fixture("focus.html", '<input id="focus" autofocus><script>window.showtimeOverlay = () => document.querySelector("input").focus();</script>')
            client.design({"action": "overlay", "source": focus_source})
            client.design({"action": "type", "text": " input proof", "delay": .01})
            assert evaluate("document.querySelector('#project-name').value === 'Overlay input proof'"), "An overlay must not steal the website's keyboard focus"
            client.design({"action": "overlay", "clear": True})
            button = evaluate("(() => {const e=document.querySelector('#create-project'), r=e.getBoundingClientRect(); return {x:r.x+r.width/2,y:r.y+r.height/2,color:getComputedStyle(e).backgroundColor.match(/\\d+/g).map(Number)};})()")
            data = pixels(screenshot("input-baseline-native.png", native=True), width=800)
            height = len(data) // 3 // 800
            remaining = {(i // 3 % 800, i // 3 // 800) for i in range(0, len(data), 3)
                         if height / 5 < i // 3 // 800 < height * 4 / 5
                         and max(abs(a-b) for a, b in zip(data[i:i+3], button["color"])) < 14}
            components = []
            while remaining:
                component = [remaining.pop()]
                for x, y in component:
                    for neighbor in ((x-1, y), (x+1, y), (x, y-1), (x, y+1)):
                        if neighbor in remaining:
                            remaining.remove(neighbor)
                            component.append(neighbor)
                components.append(component)
            points = max(components, key=len, default=[])
            assert len(points) > 100, "Locate the real Orbit submit button before covering it"
            client.design({"action": "overlay", "source": str(example / "index.html"), "props": {
                "x": button["x"] + 64, "y": button["y"] + 120, "label": "Click through me", "count": 129}, "duration": 30})
            client.design({"action": "wait", "duration": .5})
            screenshot("covered-button-native.png", native=True)
            window = client.request("GET", "/v1/studio/window")["frame"]
            client.request("POST", "/v1/studio/window", {"action": "click",
                "x": sum(p[0] for p in points) / len(points) / 800 * window["width"],
                "y": window["height"] * (1 - sum(p[1] for p in points) / len(points) / height)})
            client.design({"action": "wait", "duration": .4})
            click_result = evaluate("({created:window.orbit.state.projects.some(p => p.name === 'Overlay input proof'), trusted:window.__inputLog.some(e => e.kind === 'click' && e.target === 'create-project' && e.trusted), input:document.querySelector('#project-name')?.value, events:window.__inputLog.slice(-8)})")
            assert click_result["created"] and click_result["trusted"], click_result
            check("Native window clicks pass through opaque React artwork; autofocus and script focus cannot divert text input")

            client.design({"action": "overlay", "props": {"label": "Replaced"}, "duration": .5})
            assert client.status()["overlay"]["props"] == {"label": "Replaced"}
            wait_state(lambda s: not s["overlay"]["active"])
            client.design({"action": "overlay", "props": {}, "duration": 20})
            assert client.status()["overlay"]["props"] == {}
            client.design({"action": "overlay", "clear": True})
            assert not client.status()["overlay"]["active"]
            held = {"setup": [*setup, {"action": "wait", "duration": 1.5}],
                    "steps": [{"id": "held", "action": "wait", "duration": .8},
                              {"id": "reaction", "action": "overlay", "props": {"label": "Fresh range"}, "duration": 1}]}
            client.request("POST", "/v1/studio/window", {"action": "restore"})
            job = client.play(held, "rehearse", wait=False)["job"]
            wait_state(lambda s: s["overlay"]["ready"])
            time.sleep(.35)
            assert client.status()["overlay"]["frame"] == 0, "Setup must hold the animation's first frame"
            client.wait(job)
            for _ in range(2):
                client.request("POST", "/v1/studio/window", {"action": "restore"})
                take = client.play(held, "rehearse", **{"from": "reaction", "to": "reaction"})
                assert take["results"][-1]["value"]["frame"] == 0, take
            client.play({"steps": [{"action": "wait", "duration": .1}]}, "rehearse")
            assert not client.status()["overlay"]["ready"], "A new range must not inherit a previous renderer"
            check("Props replacement, restart, duration, clear, setup frame zero, and repeated range isolation")

            missing = fixture("no-callback.html", "<p>No callback</p>")
            throwing = fixture("throwing.html", '<script>window.showtimeOverlay=()=>{throw new Error("overlay-proof-error")}</script>')
            hanging = fixture("hanging.html", '<script>window.showtimeOverlay=()=>new Promise(()=>{})</script>')
            rejected({"action": "overlay", "props": {}}, "load")
            rejected({"action": "overlay", "source": missing, "timeout": .3}, "showtimeOverlay")
            rejected({"action": "overlay", "source": throwing}, "overlay-proof-error")
            rejected({"action": "overlay", "source": hanging}, "timed out")
            job = client.design({"action": "overlay", "source": missing, "timeout": 30}, wait=False)["job"]
            time.sleep(.2)
            started = time.monotonic()
            client.request("POST", "/v1/cancel", {})
            assert client.wait(job)["status"] == "cancelled" and time.monotonic() - started < 3
            # Prove HTTP pages can render, using the same React bundle and local assets.
            class Handler(http.server.SimpleHTTPRequestHandler):
                def log_message(self, *_):
                    pass
            with http.server.ThreadingHTTPServer(("127.0.0.1", 0), functools.partial(Handler, directory=str(example))) as server:
                thread = threading.Thread(target=server.serve_forever, daemon=True)
                thread.start()
                try:
                    client.design({"action": "overlay", "source": f"http://127.0.0.1:{server.server_port}/", "props": {"label": "HTTP recovery"}})
                    assert client.status()["overlay"]["ready"]
                finally:
                    server.shutdown()
                    thread.join()
            check("Missing/throwing/hung renderers fail promptly, Stop cancels loading, and HTTP loading recovers")

        # Run the useful shipped project workflow through the CLI and MCP.
        client.request("POST", "/v1/studio/window", {"action": "restore"})
        cli("rehearse", example / "demo.json")
        film = output / "orbit-react-1080p.mp4"
        client.request("POST", "/v1/studio/window", {"action": "restore"})
        job = mcp.call("showtime_record", path=str(example / "demo.json"), output=str(film), wait=True)
        take = job["results"][-1]["recording"]
        facts = inspect_movie(film, take, 1920, 1080)
        assert len(pink(pixels(film, 2))) > 40, "React must reach the actual movie"
        frames = [pink(pixels(film, at)) for at in (1.1, 1.3, 1.6)]
        assert any(len(a ^ b) > 20 for a, b in zip(frames, frames[1:])), "The recorded reaction must animate"
        subprocess.run(["ffmpeg", "-v", "error", "-ss", "2", "-i", str(film), "-frames:v", "1", str(output / "movie-1080p.png")], check=True)
        check("Shipped CLI rehearsal and MCP recording preserve real input and animated React frames at 1080p", **facts)

        high = {"canvas": canvas, "recording": {"width": 3840, "height": 2160, "fps": 30}, "setup": setup,
                "steps": [{"action": "parallel", "steps": [
                           {"action": "overlay", "props": {"label": "React at 4K"}, "duration": 2},
                           {"action": "camera", "scale": 1.15, "duration": .6},
                           {"action": "caption", "text": "Real pixels, real interactions", "duration": 2},
                           {"action": "wait", "duration": 2.3}]}]}
        high_path = output / "orbit-react-4k.mp4"
        client.request("POST", "/v1/studio/window", {"action": "restore"})
        high_job = client.play(high, "record", output=str(high_path))
        high_take = high_job["results"][-1]["recording"]
        facts = inspect_movie(high_path, high_take, 3840, 2160)
        # The first 4K encoder frame can take time before the first script cue starts.
        middle = high_take["duration"] / 2
        assert len(pink(pixels(high_path, middle))) > 60
        subprocess.run(["ffmpeg", "-v", "error", "-ss", str(middle), "-i", str(high_path), "-frames:v", "1", str(output / "movie-4k.png")], check=True)
        check("4K recording keeps overlay pixels above camera movement and below native captions", **facts)

        partial = output / "orbit-react-partial.mp4"
        high["recording"] = video
        high["steps"] = [{"action": "overlay", "props": {"label": "A playable partial take"}}, {"action": "wait", "duration": 30}]
        client.request("POST", "/v1/studio/window", {"action": "restore"})
        job = client.play(high, "record", wait=False, output=str(partial))["job"]
        wait_state(lambda s: s["recording"])
        time.sleep(1.4)
        client.request("POST", "/v1/cancel", {})
        cancelled = client.wait(job)
        assert cancelled["status"] == "cancelled" and cancelled["results"][-1]["partial"]
        facts = inspect_movie(partial, cancelled["results"][-1]["recording"], 1920, 1080)
        assert len(pink(pixels(partial, .7))) > 60
        check("Stop finalizes a decodable partial MP4 containing the React layer", **facts)
    finally:
        state = client.status()
        if state["busy"]:
            client.request("POST", "/v1/cancel", {})
            wait_state(lambda s: not s["busy"])
        client.design({"action": "overlay", "clear": True})
        client.request("POST", "/v1/settings", settings)
        client.design({"action": "camera", "scale": 1, "offsetX": 0, "offsetY": 0, "rotation": 0,
                       "flipX": False, "flipY": False, "duration": 0})
        client.design({"action": "caption", "text": ""})
        client.design({"action": "open", "url": initial["url"]})
        client.request("POST", "/v1/studio", {key: initial["studio"][key] for key in ("mode", "theme", "inspector", "showInspector")})
        mcp.close()
        (output / "results.json").write_text(json.dumps(results, indent=2) + "\n")
    print(f"Overlay checks complete: {output}")


if __name__ == "__main__":
    main()
