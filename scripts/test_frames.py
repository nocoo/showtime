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
        mcp.call("showtime_settings", canvas={"width": 1920, "height": 1080, "inset": 32, "frame": "none", "contentWidth": None, "browserTheme": "light", "backdrop": "mist"},
                 video={"width": 1920, "height": 1080, "fps": 30})
        mcp.call("showtime_design", step={"action": "open", "url": "showtime://demo"})
        cases = [("none", 1856, 960, 1016), ("iphone-16-pro", 402, 790, 898),
                 ("iphone-16-pro-max", 440, 872, 980),
                 ("ipad-pro-11", 834, 1148, 1238), ("ipad-pro-13", 1032, 1330, 1420),
                 ("macbook-neo", 1204, 697, 912), ("macbook-pro", 1728, 1080, 1251)]
        settings_tool = next(tool for tool in mcp.request("tools/list", {})["tools"] if tool["name"] == "showtime_settings")
        assert settings_tool["inputSchema"]["properties"]["canvas"]["properties"]["frame"]["enum"] == [case[0] for case in cases]
        check("MCP advertises the current device list")
        for frame, width, height, frame_height in cases:
            # These devices fit the 1016 px available height of the default Canvas.
            width, height = width * 1016 / frame_height, height * 1016 / frame_height
            # Exercise the same MCP setting consumed by scripts and the sidebar.
            settings = mcp.call("showtime_settings", canvas={"frame": frame, "browserTheme": "light"})
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
            if frame.startswith("macbook"):
                mcp.call("showtime_settings", canvas={"browserTheme": "dark"})
                wait_viewport(width, height)
                client.request("POST", "/v1/screenshot", {"output": str(output / f"{frame}-dark-film.png")})
                client.request("POST", "/v1/studio/screenshot", {"output": str(output / f"{frame}-dark-native.png"), "nativeOnly": True})
                check(f"{frame}: dark finish in native preview and export, unchanged viewport")

        for legacy, replacement in [("iphone-se", "iphone-16-pro"), ("ipad-mini", "ipad-pro-11"), ("macbook", "macbook-neo")]:
            settings = client.request("POST", "/v1/settings", {"canvas": {"frame": legacy}})
            assert settings["canvas"]["frame"] == replacement
            assert settings["canvas"]["width"] == 1920 and settings["canvas"]["height"] == 1080
            assert settings["video"] == {"width": 1920, "height": 1080, "fps": 30}
        check("Retired frame names migrate without losing Canvas or export settings")

        mcp.call("showtime_settings", canvas={"width": 3840, "height": 2160, "inset": 160, "contentWidth": 2000, "frame": "none"},
                 video={"width": 3840, "height": 2160, "fps": 24})
        for frame, height in [("none", 2000 * (2160 - 56) / 3840), ("macbook-neo", 2000 * 697 / 1204), ("macbook-pro", 1250)]:
            settings = mcp.call("showtime_settings", canvas={"frame": frame})
            assert settings["canvas"]["contentWidth"] == 2000
            assert settings["video"] == {"width": 3840, "height": 2160, "fps": 24}
            wait_viewport(2000, height)
            client.act({"action": "click", "selector": "#new-project", "duration": 0.1})
            assert_page("!!document.querySelector('#project-name')")
            client.act({"action": "key", "key": "escape"})
            client.act({"action": "cursor", "visible": False})
            client.request("POST", "/v1/screenshot", {"output": str(output / f"{frame}-width-2000.png")})
        check("Fixed 2000 px content keeps device proportions, native input, and 4K export settings")

        stable = client.request("GET", "/v1/settings")
        for patch in [{"contentWidth": value} for value in [0, -1, 1.5, 3841]] + [{"frame": "iphone-16-pro"}, {"width": 1280, "height": 720}]:
            try:
                client.request("POST", "/v1/settings", {"canvas": patch})
            except ShowtimeError:
                pass
            else:
                raise AssertionError("An invalid fixed content width was accepted")
            assert client.request("GET", "/v1/settings") == stable
        check("Invalid widths and incompatible frame/Canvas changes leave all settings unchanged")

        mcp.call("showtime_settings", canvas={"frame": "none", "inset": 0, "browserTheme": "light"})
        wait_viewport(2000, 2000 * (2160 - 56) / 3840)
        assert_page("!!document.querySelector('#revenue-chart') && document.documentElement.scrollWidth === innerWidth")
        wide, narrow = output / "content-wide.png", output / "content-narrow.png"
        client.request("POST", "/v1/screenshot", {"output": str(wide)})
        mcp.call("showtime_settings", canvas={"contentWidth": 1000})
        wait_viewport(1000, 1000 * (2160 - 56) / 3840)
        assert_page("!!document.querySelector('#revenue-chart') && document.documentElement.scrollWidth === innerWidth")
        client.request("POST", "/v1/screenshot", {"output": str(narrow)})
        # This point is on the wide browser's light title bar, outside the narrower window.
        # Keep Orbit intact so both artifacts also show the real responsive dashboard.
        def sample(path):
            return subprocess.check_output(["ffmpeg", "-v", "error", "-i", str(path), "-vf", "crop=1:1:1200:526",
                                            "-frames:v", "1", "-f", "rawvideo", "-pix_fmt", "rgb24", "-"])
        before, after = sample(wide), sample(narrow)
        assert min(before) > 235
        assert sum(abs(a - b) for a, b in zip(before, after)) > 25, "Shrinking content must replace the previous window with backdrop"
        check("Fixed width reflows Orbit and refreshes exported window geometry and margins without changing the page")

        for argument, expected in [("1200", 1200), ("auto", None)]:
            settings = json.loads(subprocess.check_output([sys.executable, str(Path(__file__).with_name("showtime_cli.py")),
                                                         "settings", "--content-width", argument]))
            assert settings["canvas"]["contentWidth"] == expected
        check("CLI sets a fixed content width and restores Auto")
        mcp.call("showtime_settings", canvas={"width": 1920, "height": 1080, "inset": 32, "contentWidth": None},
                 video={"width": 1920, "height": 1080, "fps": 30})

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
        for frame in ["iphone-16-pro", "ipad-pro-11", "macbook-neo", "macbook-pro"]:
            movie = output / f"{frame}.mp4"
            video_width, video_height = (3840, 2160) if frame.startswith("macbook") else (1280, 720)
            if frame.startswith("macbook"):
                mcp.call("showtime_settings", canvas={"width": 3840, "height": 2160},
                         video={"width": video_width, "height": video_height, "fps": 24})
            mcp.call("showtime_settings", canvas={"frame": frame, "browserTheme": "light", "contentWidth": 2000 if frame.startswith("macbook") else None})
            time.sleep(0.2)
            mcp.call("showtime_studio", mode="theater")
            take = mcp.call("showtime_record", output=str(movie), script={"steps": [
                {"action": "caption", "text": "A frame for every story.", "duration": 2},
                {"action": "click", "selector": "#new-project", "duration": 0.3},
                {"action": "key", "key": "escape"},
                {"action": "wait", "duration": 0.8}]})
            try:
                client.request("POST", "/v1/settings", {"canvas": {"frame": "none"}})
            except ShowtimeError as error:
                assert "409" in str(error)
            else:
                raise AssertionError("Frame changed during recording")
            job = mcp.call("showtime_job", id=take["job"], wait=True)
            assert job["status"] == "completed"
            result = next(item["recording"] for item in job["results"] if "recording" in item)
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
