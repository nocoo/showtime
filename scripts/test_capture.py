#!/usr/bin/env python3
"""Check real-page capture settings, MP4 output, and live MCP direction in Showtime."""
from __future__ import annotations

import argparse
import json
import shutil
import subprocess
import sys
import tempfile
import time
from pathlib import Path

sys.dont_write_bytecode = True
from showtime_client import Client, ShowtimeError


class MCP:
    def __init__(self):
        self.process = subprocess.Popen([sys.executable, str(Path(__file__).with_name("showtime_mcp.py"))],
                                        stdin=subprocess.PIPE, stdout=subprocess.PIPE, text=True)
        self.sequence = 0

    def request(self, method, params):
        self.sequence += 1
        self.process.stdin.write(json.dumps({"jsonrpc": "2.0", "id": self.sequence, "method": method, "params": params}) + "\n")
        self.process.stdin.flush()
        response = json.loads(self.process.stdout.readline())
        assert response["id"] == self.sequence and "error" not in response, response
        return response["result"]

    def call(self, name, **arguments):
        result = self.request("tools/call", {"name": name, "arguments": arguments})
        assert not result.get("isError"), result
        return json.loads(result["content"][0]["text"])

    def close(self):
        self.process.stdin.close()
        self.process.wait(timeout=5)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--url", default="showtime://demo", help="A real local or remote website to capture")
    parser.add_argument("--output-dir", type=Path)
    args = parser.parse_args()
    if not shutil.which("ffprobe") or not shutil.which("ffmpeg"):
        parser.error("Install FFmpeg to inspect the exported movies and frame colors.")
    output = (args.output_dir or Path(tempfile.mkdtemp(prefix="showtime-capture-"))).resolve()
    if args.output_dir: output.mkdir(parents=True, exist_ok=False)
    client = Client()
    initial = client.status()
    assert not any(initial[key] for key in ("playing", "recording", "preparing", "finishing")), "Finish the current take first."
    original_settings = client.request("GET", "/v1/settings")
    mcp = MCP()
    results = []

    def check(name, **facts):
        results.append({"check": name, **facts})
        print("PASS " + name, flush=True)

    def wait_for(predicate, timeout=8):
        deadline = time.monotonic() + timeout
        while time.monotonic() < deadline:
            state = client.status()
            if predicate(state): return state
            time.sleep(0.08)
        raise AssertionError("Showtime did not reach the expected state.")

    def sample(path, x, y):
        data = subprocess.check_output(["ffmpeg", "-v", "error", "-i", str(path), "-vf", f"crop=1:1:{x}:{y}",
                                        "-frames:v", "1", "-f", "rawvideo", "-pix_fmt", "rgb24", "-"])
        return list(data[:3])

    try:
        mcp.request("initialize", {"protocolVersion": "2025-06-18", "capabilities": {}, "clientInfo": {"name": "capture-check", "version": "1"}})
        names = {tool["name"] for tool in mcp.request("tools/list", {})["tools"]}
        assert {"showtime_settings", "showtime_studio", "showtime_record"} <= names
        mcp.call("showtime_open", url=args.url)
        opened = client.status()
        actual_url = opened["url"]
        assert opened["storyboard"]["cues"] == 0
        assert opened["displayURL"] == actual_url and opened["displayTitle"] == opened["title"]
        check("A real website opens with its original identity and no implicit demo storyboard", url=actual_url)

        mcp.call("showtime_settings", canvas={"width": 1440, "height": 810, "inset": 32, "browserTheme": "light", "frame": "none"},
                 video={"width": 1920, "height": 1080, "fps": 30})
        desktop = mcp.call("showtime_settings", canvas={"height": 900})
        assert desktop["video"] == {"width": 1920, "height": 1200, "fps": 30}
        for patch in ({"canvas": {"width": 600}}, {"video": {"fps": 25}}, {"video": {"width": 1919}},
                      {"canvas": {"browserTheme": "blue"}}, {"video": {"width": 1920, "height": 1080}}):
            try: client.request("POST", "/v1/settings", patch)
            except ShowtimeError: pass
            else: raise AssertionError("Invalid settings were accepted: " + str(patch))
            assert client.request("GET", "/v1/settings") == desktop, "Rejected edits must not partially change the session."
        check("Canvas aspect changes fit the output, and invalid edits are atomic")

        client.request("POST", "/v1/studio", {"mode": "studio", "showInspector": True, "inspector": "Canvas", "theme": "light"})
        light = output / "frame-light.png"
        dark = output / "frame-dark.png"
        mcp.call("showtime_screenshot", output=str(light), includeImage=False)
        mcp.call("showtime_settings", canvas={"browserTheme": "dark"})
        mcp.call("showtime_screenshot", output=str(dark), includeImage=False)
        # Both samples sit on the title bar's plain top edge, away from glyphs.
        assert min(sample(light, 176, 50)) > 200 and max(sample(dark, 176, 50)) < 100
        mcp.call("showtime_studio", theme="dark")
        client.act({"action": "assert", "script": "!matchMedia('(prefers-color-scheme: dark)').matches"})
        check("Browser title bar colors reach exported frames independently of Studio and webpage themes")

        cases = [(1440, 810, 1280, 720, 24), (1440, 900, 1280, 800, 30), (900, 1600, 720, 1280, 60)]
        for index, (cw, ch, width, height, fps) in enumerate(cases):
            mcp.call("showtime_settings", canvas={"width": cw, "height": ch}, video={"width": width, "height": height, "fps": fps})
            wait_for(lambda state: abs(state["viewport"]["width"] - (cw - 64)) < 1
                     and abs(state["viewport"]["height"] - (ch - 64 - 56)) < 1)
            movie = output / f"current-page-{fps}fps.mp4"
            if index == 0:
                window = client.request("GET", "/v1/studio/window")
                client.request("POST", "/v1/studio/window", {"action": "click", "x": window["frame"]["width"] - 70,
                               "y": window["frame"]["height"] - 26})
                wait_for(lambda state: state["recording"])
            else:
                mcp.call("showtime_record", operation="start", output=str(movie))
            recording = client.status()
            assert recording["recording"] and not recording["playing"] and recording["url"] == actual_url
            try: client.request("POST", "/v1/settings", {"video": {"fps": 30}})
            except ShowtimeError as error: assert "409" in str(error)
            else: raise AssertionError("Settings changed during a take.")
            time.sleep(0.9)
            result = mcp.call("showtime_record", operation="stop")
            if index == 0: shutil.copyfile(result["output"], movie)
            probe = json.loads(subprocess.check_output(["ffprobe", "-v", "error", "-select_streams", "v:0", "-show_entries",
                                                        "stream=codec_name,width,height,r_frame_rate,nb_frames:format=duration",
                                                        "-of", "json", str(movie)]))
            stream = probe["streams"][0]
            assert (stream["width"], stream["height"], stream["r_frame_rate"]) == (width, height, f"{fps}/1")
            assert stream["codec_name"] == "h264" and float(probe["format"]["duration"]) >= 0.9
            assert client.status()["url"] == actual_url
            check(f"Current-page recording exports {width} × {height} at {fps} fps", movie=str(movie), probe=probe)

        mcp.call("showtime_settings", canvas={"width": 1440, "height": 810}, video={"width": 1280, "height": 720, "fps": 30})
        mcp.call("showtime_studio", mode="theater")
        script = {"name": "A scene with a clear purpose", "steps": [
            {"action": "marker", "text": "The opening scene"},
            {"action": "parallel", "label": "Bring the story into focus", "steps": [
                {"action": "move", "x": 700, "y": 360, "duration": 0.6},
                {"action": "caption", "text": "A real website. A directed film.", "duration": 4},
                {"action": "wait", "duration": 2}]},
            {"action": "wait", "label": "Let the closing frame breathe", "duration": 0.3}]}
        job = mcp.call("showtime_run", script=script, rehearse=True)
        live = wait_for(lambda state: state["director"].get("current", {}).get("title") == "Bring the story into focus")["director"]
        assert live["source"] == "agent" and live["phase"] == "working" and live["scene"] == "The opening scene"
        assert live["next"]["title"] == "Let the closing frame breathe" and live["completed"] == 1
        assert client.status()["director"] == live, "Status polling must not replace the visible action."
        client.request("POST", "/v1/studio/screenshot", {"output": str(output / "theater-live.png")})
        finished = mcp.call("showtime_job", id=job["job"], wait=True)
        assert finished["status"] == "completed"
        assert client.status()["director"]["completed"] == 3
        check("Theater shows live MCP scene, cue, next action, and synchronized completion", live=live)
    finally:
        if any(client.status()[key] for key in ("playing", "recording")):
            client.request("POST", "/v1/cancel", {})
            wait_for(lambda state: not any(state[key] for key in ("playing", "recording", "preparing", "finishing")))
        client.request("POST", "/v1/settings", original_settings)
        client.act({"action": "caption", "text": ""})
        client.request("POST", "/v1/studio", initial["studio"])
        mcp.close()
        (output / "capture-results.json").write_text(json.dumps(results, indent=2) + "\n")
    print("Capture artifacts: " + str(output), flush=True)


if __name__ == "__main__":
    main()
