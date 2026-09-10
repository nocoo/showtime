#!/usr/bin/env python3
"""Check device viewports, native input, and framed video in a running Showtime.app."""
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
from test_capture import MCP


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output-dir", type=Path)
    args = parser.parse_args()
    if not shutil.which("ffprobe") or not shutil.which("ffmpeg"):
        parser.error("Install FFmpeg to check exported video.")
    output = (args.output_dir or Path(tempfile.mkdtemp(prefix="showtime-frames-"))).resolve()
    if args.output_dir:
        output.mkdir(parents=True, exist_ok=False)
    client = Client()
    initial = client.status()
    assert not any(initial[key] for key in ("playing", "recording", "preparing", "finishing")), "Finish the current take first."
    original_settings = client.request("GET", "/v1/settings")
    mcp = MCP()
    results = []

    def check(name, **facts):
        results.append({"check": name, **facts})
        print("PASS " + name, flush=True)

    def evaluate(expression):
        return client.act({"action": "evaluate", "script": expression})["results"][0]["value"]

    def assert_page(expression):
        client.act({"action": "assert", "script": expression})

    def wait_viewport(width, height):
        for _ in range(60):
            viewport = client.status()["viewport"]
            if abs(viewport["width"] - width) < 1 and abs(viewport["height"] - height) < 1:
                assert_page(f"Math.abs(innerWidth - {width}) <= 1 && Math.abs(innerHeight - {height}) <= 1")
                return
            time.sleep(0.05)
        raise AssertionError(f"Expected {width} × {height}, got {viewport}")

    try:
        mcp.request("initialize", {"protocolVersion": "2025-06-18", "capabilities": {}, "clientInfo": {"name": "frame-check", "version": "1"}})
        mcp.call("showtime_studio", mode="studio", inspector="Frame", showInspector=True, theme="light")
        mcp.call("showtime_settings", canvas={"width": 1920, "height": 1080, "inset": 32, "frame": "none", "browserTheme": "light"},
                 video={"width": 1920, "height": 1080, "fps": 30})
        mcp.call("showtime_open", url="showtime://demo")
        cases = [("none", 1856, 960, 1016), ("iphone-se", 375, 647, 889), ("iphone-16-pro", 402, 790, 898),
                 ("iphone-16-pro-max", 440, 872, 980), ("ipad-mini", 744, 1087, 1253),
                 ("ipad-pro-11", 834, 1148, 1238), ("ipad-pro-13", 1032, 1330, 1420),
                 ("macbook", 1440, 844, 990), ("macbook-pro", 1536, 960, 1042)]
        for frame, width, height, frame_height in cases:
            # These devices fit the 1016 px available height of the default Canvas.
            width, height = width * 1016 / frame_height, height * 1016 / frame_height
            # Exercise the same MCP setting consumed by scripts and the sidebar.
            settings = mcp.call("showtime_settings", canvas={"frame": frame})
            assert settings["canvas"]["width"] == 1920 and settings["canvas"]["height"] == 1080
            assert settings["video"] == {"width": 1920, "height": 1080, "fps": 30}
            wait_viewport(width, height)
            assert_page("document.documentElement.scrollWidth === innerWidth")
            client.act({"action": "click", "selector": "#new-project", "duration": 0.12})
            client.act({"action": "type", "selector": "#project-name", "text": "Frame check 🌱", "clear": True, "delay": 0.01})
            assert_page("document.querySelector('#project-name').value === 'Frame check 🌱' && "
                        "window.__inputLog.some(e=>e.kind==='click' && e.trusted && e.target==='new-project') && "
                        "window.__inputLog.some(e=>e.kind==='input' && e.trusted && e.value==='Frame check 🌱')")
            client.act({"action": "key", "key": "escape"})
            client.act({"action": "cursor", "visible": False})
            client.request("POST", "/v1/screenshot", {"output": str(output / f"{frame}-film.png")})
            client.request("POST", "/v1/studio/screenshot", {"output": str(output / f"{frame}-native.png"), "nativeOnly": True})
            check(f"{frame}: responsive viewport, trusted click and typing, unchanged Canvas/video", viewport=[width, height])

        stable = client.request("GET", "/v1/settings")
        for invalid in ["unknown-phone", 42, None]:
            try:
                client.request("POST", "/v1/settings", {"canvas": {"frame": invalid}})
            except ShowtimeError:
                pass
            else:
                raise AssertionError("Invalid frame was accepted")
            assert client.request("GET", "/v1/settings") == stable
        check("Invalid device selection is rejected atomically")

        mcp.call("showtime_settings", canvas={"frame": "iphone-16-pro"})
        wait_viewport(402 * 1016 / 898, 790 * 1016 / 898)
        client.act({"action": "scroll", "selector": ".main-scroll", "deltaY": 300, "duration": 0.3})
        client.act({"action": "wait", "duration": 0.2})
        assert_page("document.querySelector('.main-scroll').scrollTop > 100 && window.__inputLog.some(e=>e.kind==='wheel' && e.trusted)")
        client.act({"action": "zoom", "x": 200, "y": 300, "scale": 1.5, "duration": 0.2})
        client.act({"action": "scroll", "selector": ".main-scroll", "deltaY": -1000, "duration": 0.3})
        client.act({"action": "wait", "duration": 0.2})
        assert_page("document.querySelector('.main-scroll').scrollTop < 1")
        client.act({"action": "click", "selector": "#new-project", "duration": 0.12})
        assert_page("!!document.querySelector('#project-name')")
        client.act({"action": "key", "key": "escape"})
        client.act({"action": "zoom", "scale": 1, "duration": 0.1})
        check("Native wheel and click stay accurate with a fitted, zoomed phone viewport")

        # A real native range control catches offset errors across the whole width.
        evaluate("""(() => {
          const slider = document.createElement('input'); slider.type='range'; slider.id='frame-slider';
          slider.min=0; slider.max=100; slider.value=0;
          slider.style='position:fixed;left:40px;top:90px;width:300px;height:32px;z-index:9999';
          window.frameDrag=[]; slider.addEventListener('input',e=>window.frameDrag.push(e.isTrusted));
          document.body.append(slider); return true;
        })()""")
        client.act({"action": "drag", "x": 48, "y": 106, "toX": 329, "toY": 106, "duration": 0.5})
        assert_page("Number(document.querySelector('#frame-slider').value)>85 && window.frameDrag.length>0 && window.frameDrag.every(Boolean)")
        evaluate("(() => { document.querySelector('#frame-slider').remove(); return true; })()")
        check("A fitted phone preserves trusted native drag input")

        # Canvas resizing changes the fitted viewport; native input must follow it.
        for canvas, video in [((900, 1600), (1080, 1920)), ((800, 500), (1280, 800))]:
            mcp.call("showtime_settings", canvas={"width": canvas[0], "height": canvas[1]},
                     video={"width": video[0], "height": video[1]})
            scale = min((canvas[0] - 64) / 432, (canvas[1] - 64) / 898)
            wait_viewport(402 * scale, 790 * scale)
            client.act({"action": "click", "selector": "#new-project", "duration": 0.1})
            assert_page("!!document.querySelector('#project-name')")
            client.act({"action": "key", "key": "escape"})
            client.request("POST", "/v1/studio/screenshot", {"output": str(output / f"phone-canvas-{canvas[0]}.png"), "nativeOnly": True})
        check("Portrait and minimum Canvas resize the phone viewport and preserve native input")

        mcp.call("showtime_settings", canvas={"width": 1920, "height": 1080}, video={"width": 1280, "height": 720, "fps": 24})
        for frame in ["iphone-16-pro", "ipad-pro-11", "macbook", "macbook-pro"]:
            movie = output / f"{frame}.mp4"
            video_width, video_height = (3840, 2160) if frame.startswith("macbook") else (1280, 720)
            if frame.startswith("macbook"):
                mcp.call("showtime_settings", canvas={"width": 3840, "height": 2160},
                         video={"width": video_width, "height": video_height, "fps": 24})
            mcp.call("showtime_settings", canvas={"frame": frame})
            time.sleep(0.2)
            mcp.call("showtime_studio", mode="theater")
            mcp.call("showtime_record", operation="start", output=str(movie))
            try:
                client.request("POST", "/v1/settings", {"canvas": {"frame": "none"}})
            except ShowtimeError as error:
                assert "409" in str(error)
            else:
                raise AssertionError("Frame changed during recording")
            mcp.call("showtime_act", step={"action": "caption", "text": "A frame for every story.", "duration": 2})
            mcp.call("showtime_act", step={"action": "click", "selector": "#new-project", "duration": 0.3})
            mcp.call("showtime_act", step={"action": "key", "key": "escape"})
            mcp.call("showtime_act", step={"action": "wait", "duration": 0.8})
            result = mcp.call("showtime_record", operation="stop")
            probe = json.loads(subprocess.check_output(["ffprobe", "-v", "error", "-show_entries",
                "stream=codec_name,width,height,r_frame_rate:format=duration", "-of", "json", str(movie)]))
            stream = probe["streams"][0]
            assert (stream["codec_name"], stream["width"], stream["height"], stream["r_frame_rate"]) == ("h264", video_width, video_height, "24/1")
            assert float(probe["format"]["duration"]) >= 1
            subprocess.run(["ffmpeg", "-v", "error", "-ss", "0.15", "-i", str(movie), "-frames:v", "1", str(output / f"{frame}-video.png")], check=True)
            check(f"{frame}: playable framed MP4, captions and input, busy-setting rejection", recording=result, probe=probe)
            client.act({"action": "caption", "text": ""})

        # A legacy script with no frame key still produces the unframed browser.
        client.run({"name": "Legacy Canvas", "canvas": {"width": 1920, "height": 1080}, "steps": [{"action": "wait", "duration": 0.1}]})
        wait_viewport(1856, 960)
        assert client.status()["canvas"]["frame"] == "none"
        check("Legacy JSON scripts restore the default unframed browser")
    finally:
        if client.status()["playing"]:
            client.request("POST", "/v1/cancel", {})
            for _ in range(200):
                if not client.status()["playing"]: break
                time.sleep(0.1)
        if client.status()["recording"]:
            client.request("POST", "/v1/recording/stop", {})
        (output / "frame-results.json").write_text(json.dumps(results, indent=2) + "\n")
        client.act({"action": "caption", "text": ""})
        client.act({"action": "zoom", "scale": 1, "duration": 0})
        client.request("POST", "/v1/settings", original_settings)
        client.act({"action": "open", "url": initial["url"], "title": initial["displayTitle"], "displayURL": initial["displayURL"]})
        client.request("POST", "/v1/studio", initial["studio"])
        mcp.close()
    print("Frame artifacts: " + str(output), flush=True)


if __name__ == "__main__":
    main()
