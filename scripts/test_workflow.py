#!/usr/bin/env python3
"""Exercise design previews and autonomous JSON playback with Orbit's launch story."""
from __future__ import annotations

import argparse
import json
import math
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
    if not shutil.which("ffmpeg") or not shutil.which("ffprobe"):
        parser.error("Install FFmpeg to check preview pixels and MP4 output.")
    output = (args.output_dir or Path(tempfile.mkdtemp(prefix="showtime-workflow-"))).resolve()
    if args.output_dir:
        output.mkdir(parents=True, exist_ok=False)
    client, mcp = Client(), MCP()
    initial = client.status()
    assert not initial["busy"], "Finish the current take first."
    original_settings = client.request("GET", "/v1/settings")
    orbit = json.loads((Path(__file__).resolve().parent.parent /
                        "Sources/Showtime/Resources/Scripts/orbit-launch.json").read_text())
    results = []

    def check(name, **facts):
        results.append({"check": name, **facts})
        print("PASS " + name, flush=True)

    def cli(*arguments, good=True):
        result = subprocess.run([sys.executable, str(Path(__file__).with_name("showtime_cli.py")), *map(str, arguments)],
                                capture_output=True, text=True, timeout=45)
        assert (result.returncode == 0) == good, result.stdout + result.stderr
        assert "Traceback" not in result.stderr, result.stderr
        return result.stdout if good else result.stderr

    def evaluate(expression):
        return client.design({"action": "evaluate", "script": expression})["results"][0]["value"]

    def rejected(operation, contains=None):
        try:
            operation()
        except (ShowtimeError, ValueError) as error:
            if contains:
                assert contains in str(error), str(error)
        else:
            raise AssertionError("Invalid operation was accepted")

    def wait_state(predicate, timeout=15):
        deadline = time.monotonic() + timeout
        while time.monotonic() < deadline:
            state = client.status()
            if predicate(state):
                return state
            time.sleep(.05)
        raise AssertionError("Expected state not reached: " + json.dumps(client.status()))

    def probe(path):
        return json.loads(subprocess.check_output(["ffprobe", "-v", "error", "-show_entries",
            "stream=codec_name,width,height,r_frame_rate:format=duration", "-of", "json", str(path)]))

    def pixel(path, x, y):
        return list(subprocess.check_output(["ffmpeg", "-v", "error", "-i", str(path), "-vf",
            f"format=rgb24,crop=1:1:{int(x)}:{int(y)}", "-frames:v", "1", "-f", "rawvideo", "-"])[:3])

    try:
        mcp.request("initialize", {"protocolVersion": "2025-06-18"})
        definitions = {tool["name"]: tool["inputSchema"] for tool in mcp.request("tools/list", {})["tools"]}
        assert len(definitions) == 12
        assert {"showtime_help", "showtime_design", "showtime_validate", "showtime_rehearse", "showtime_record", "showtime_stop"} <= definitions.keys()
        schema = json.loads(cli("schema"))
        assert definitions["showtime_design"]["properties"]["step"] == schema["script"]["properties"]["steps"]["items"]
        for name in schema["actions"]:
            assert json.loads(cli("schema", name)) == mcp.call("showtime_help", topic=name)
        help_text = mcp.request("tools/call", {"name": "showtime_help", "arguments": {}})["content"][0]["text"]
        assert cli("guide").strip() == help_text.strip()
        check("CLI and MCP advertise the same actions, schemas, and bundled skill")

        client.request("POST", "/v1/settings", {"canvas": {**orbit["canvas"], "frame": "none", "contentWidth": None, "browserTheme": "light"},
                                               "video": orbit["recording"]})
        client.request("POST", "/v1/studio", {"mode": "theater", "theme": "light"})
        client.request("POST", "/v1/studio/window", {"action": "restore"})
        client.design({"action": "camera", "scale": 1, "offsetX": 0, "offsetY": 0, "rotation": 0,
                       "flipX": False, "flipY": False, "duration": 0})
        for step in orbit["setup"]:
            client.design(step)
        client.design({"action": "waitFor", "script": "document.querySelector('#revenue-chart') && document.querySelector('.content').getAnimations().every(a => a.playState === 'finished')"})
        caption = {**orbit["steps"][1], "duration": .15}
        preview = output / "design-caption.png"
        result = mcp.call("showtime_design", step=caption, screenshot=str(preview), includeImage=False)
        time.sleep(.35)
        assert result["mode"] == "design" and result["status"] == "completed" and preview.is_file()
        state = client.status()
        assert state["caption"]["held"] and not state["recording"] and not state["busy"]
        assert state["workflow"] == "design"
        client.request("POST", "/v1/studio/screenshot", {"output": str(output / "design-native.png")})
        client.play({"steps": [caption, {"action": "wait", "duration": .3}]}, "rehearse")
        assert "caption" not in client.status()
        check("Design holds short captions for inspection; the identical script action expires on schedule")

        for malformed in ([], None, {"steps": [None]}, {"steps": [{"action": "camera", "flip": True}]}):
            path = output / "invalid.json"
            path.write_text(json.dumps(malformed))
            cli("validate", path, good=False)
            response = mcp.request("tools/call", {"name": "showtime_rehearse", "arguments": {"script": malformed}})
            assert response["isError"]
        rejected(lambda: client.request("POST", "/v1/design", {"step": {"action": "wait"}, "screenshot": 42}), "string")
        for malformed in (None, [], 42, "wait"):
            rejected(lambda: client.request("POST", "/v1/design", {"step": malformed}), "Design accepts")
        rejected(lambda: client.request("POST", "/v1/rehearse", {"script": {"steps": [{"action": "wait"}]}, "mode": "record"}))
        evaluate("window.workflowSentinel = 0")
        invalid = {"setup": [{"action": "evaluate", "script": "window.workflowSentinel = 1"}],
                   "steps": [{"action": "wait", "duration": .1}, {"action": "camera", "scale": 0}]}
        rejected(lambda: client.play(invalid, "rehearse", **{"to": 1}))
        assert evaluate("window.workflowSentinel") == 0
        for boundary in (True, 0, 1.5, "missing"):
            rejected(lambda: client.validate({"steps": [{"action": "wait"}]}, **{"from": boundary}))
        proposed = output / "validation-does-not-create" / "take.mp4"
        assert client.validate({"steps": [{"action": "wait"}]}, "record", output=str(proposed))["valid"]
        assert not proposed.parent.exists()
        check("Malformed scripts, unknown fields, invalid later steps, and bad ranges fail before side effects")

        script = {"name": "Range playback", "setup": [{"id": "prepare", "action": "evaluate", "script": "window.workflowLog = ['setup']"}],
                  "steps": [{"id": name, "action": "evaluate", "script": f"window.workflowLog.push('{name}')"}
                            for name in ("intro", "feature", "closing")]}
        path = output / "range.json"
        path.write_text(json.dumps(script))
        result = json.loads(cli("rehearse", path, "--from", "feature", "--to", "closing"))
        assert result["range"] == {"from": 2, "to": 3, "scriptSteps": 3} and result["completed"] == 2
        assert [(v["step"], v.get("id")) for v in result["results"] if v["phase"] == "steps"] == [(2, "feature"), (3, "closing")]
        assert evaluate("window.workflowLog") == ["setup", "feature", "closing"]
        result = mcp.call("showtime_rehearse", path=str(path), **{"from": 2, "to": 2, "wait": True})
        assert result["completed"] == 1 and evaluate("window.workflowLog") == ["setup", "feature"]
        client.play(script, "rehearse")
        assert evaluate("window.workflowLog") == ["setup", "intro", "feature", "closing"]
        check("CLI and MCP ranges run explicit setup and preserve original indices without replaying skipped steps")

        # One request starts the entire sequence; status polling never supplies the next action.
        autonomous = {"setup": [{"id": "prepare", "action": "wait", "duration": .25}], "steps": [
            {"id": "first", "action": "wait", "duration": .8},
            {"id": "second", "action": "wait", "duration": .8},
            {"id": "done", "action": "evaluate", "script": "window.workflowSentinel = 7"}]}
        job = mcp.call("showtime_rehearse", script=autonomous)["job"]
        wait_state(lambda s: s["busy"])
        rejected(lambda: client.design({"action": "wait", "duration": 0}), "409")
        rejected(lambda: client.request("POST", "/v1/settings", {"video": {"fps": 30}}), "409")
        samples = []
        while True:
            current = mcp.call("showtime_job", id=job)
            if current["status"] != "running":
                break
            state = client.status()
            samples.append({"phase": current["phase"], "current": current.get("current"), "playing": state["playing"],
                            "recording": state["recording"], "workflow": state["workflow"]})
            time.sleep(.08)
        assert all(s["playing"] and not s["recording"] and s["workflow"] == "rehearse" for s in samples[:-1])
        assert {s["current"].get("id") for s in samples if s["current"]} >= {"first", "second"}
        assert current["elapsed"] >= 1.85 and evaluate("window.workflowSentinel") == 7
        (output / "playback-samples.json").write_text(json.dumps(samples, indent=2))
        check("Local waits preserve one rehearsal job across cue boundaries without further Agent instructions", samples=len(samples))

        failed = client.play({"setup": [{"id": "must-exist", "action": "waitFor", "selector": "#missing-workflow", "timeout": .1}],
                              "steps": [{"action": "wait"}]}, "rehearse", wait=False)["job"]
        rejected(lambda: client.wait(failed), "Setup 1 (must-exist)")
        failure = mcp.call("showtime_job", id=failed)
        assert failure["status"] == "failed" and failure["current"]["id"] == "must-exist"
        check("A failed setup returns its original ID and an actionable error")

        asset = output / "cursor.png"
        shutil.copyfile(Path(__file__).resolve().parent.parent / "examples/cursors/diamond.png", asset)
        relative = {"setup": [{"action": "cursor", "style": "custom", "image": "cursor.png"}],
                    "steps": [{"action": "screenshot", "output": "relative-frame.png"}]}
        path = output / "relative.json"
        path.write_text(json.dumps(relative))
        cli("rehearse", path)
        assert (output / "relative-frame.png").is_file()
        rejected(lambda: client.design({"action": "screenshot", "output": str(output / "relative-frame.png")}), "exists")
        check("Assets in setup and screenshot paths resolve relative to the script; existing outputs are preserved")

        # Explore the same project form used by the launch film, with real content and controls.
        for step in orbit["setup"]:
            client.design(step)
        create_start = next(i for i, step in enumerate(orbit["steps"]) if step.get("selector") == "#new-project")
        create_end = next(i for i, step in enumerate(orbit["steps"]) if step.get("selector") == "#create-project")
        for step in orbit["steps"][create_start:create_end]:
            if step["action"] != "caption":
                client.design({**step, "clear": True} if step["action"] == "type" else step)
        assert evaluate("document.querySelector('#project-name').value === 'Autumn launch' && document.querySelector('#project-description').value === 'A thoughtful new chapter for Orbit.'"), "The project form changed outside the scripted input"
        client.design({"action": "cursor", "visible": False})
        client.design({"action": "wait", "duration": .4})
        client.request("POST", "/v1/screenshot", {"output": str(output / "orbit-project-design.png")})
        button = evaluate(r"""(() => {
          const e = document.querySelector('#create-project'), r = e.getBoundingClientRect();
          return {x:r.x + 8, y:r.y + r.height/2,
                  color:getComputedStyle(e).backgroundColor.match(/\d+/g).map(Number)};
        })()""")
        viewport = client.status()["viewport"]
        camera = {"action": "camera", "x": viewport["width"] / 2, "y": viewport["height"] / 2,
                  "scale": .68, "offsetX": 24, "offsetY": -8, "rotation": 12,
                  "flipX": True, "flipY": True, "duration": .5}
        film = output / "orbit-camera-study.png"
        client.design(camera, screenshot=str(film))
        # Follow an existing button through both mirrors, clockwise rotation, and pan.
        density = orbit["recording"]["width"] / orbit["canvas"]["width"]
        dx, dy = (camera["x"] - button["x"]) * camera["scale"], (camera["y"] - button["y"]) * camera["scale"]
        angle = math.radians(camera["rotation"])
        x = (32 + camera["x"] + camera["offsetX"] + dx * math.cos(angle) - dy * math.sin(angle)) * density
        y = (88 + camera["y"] + camera["offsetY"] + dx * math.sin(angle) + dy * math.cos(angle)) * density
        def button_color(rgb):
            return max(abs(a - b) for a, b in zip(rgb, button["color"])) < 14
        assert button_color(pixel(film, x, y))
        assert min(pixel(film, 50 * density, 105 * density)) > 235, "Zooming out must expose clean white page margins"
        native = output / "orbit-camera-native.png"
        time.sleep(.25)
        client.request("POST", "/v1/studio/screenshot", {"output": str(native), "nativeOnly": True})
        data = subprocess.check_output(["ffmpeg", "-v", "error", "-i", str(native), "-vf", "scale=800:-1,format=rgb24", "-f", "rawvideo", "-"])
        # Locate the actual green submit button, separating it from smaller brand details.
        # Exclude the App's toolbars above and below the centered Orbit form.
        height = len(data) // 3 // 800
        remaining = {(i // 3 % 800, i // 3 // 800) for i in range(0, len(data), 3)
                     if height / 5 < i // 3 // 800 < height * 4 / 5 and button_color(data[i:i+3])}
        components = []
        while remaining:
            component = [remaining.pop()]
            for px, py in component:
                for neighbor in ((px-1, py), (px+1, py), (px, py-1), (px, py+1)):
                    if neighbor in remaining:
                        remaining.remove(neighbor)
                        component.append(neighbor)
            components.append(component)
        points = max(components, key=len, default=[])
        assert len(points) > 100, "The native preview must show Orbit's transformed Create project button"
        px = sum(p[0] for p in points) / len(points)
        py = sum(p[1] for p in points) / len(points)
        window = client.request("GET", "/v1/studio/window")["frame"]
        client.request("POST", "/v1/studio/window", {"action": "click", "x": px / 800 * window["width"],
                       "y": window["height"] * (1 - py / (len(data) / 3 / 800))})
        time.sleep(.15)
        project_created = "window.orbit.state.projects.some(p => p.name === 'Autumn launch' && p.team === 'Marketing')"
        click_result = evaluate("({created:" + project_created + ", trusted:window.__inputLog.some(e => e.kind === 'click' && e.trusted && e.target === 'create-project')})")
        assert click_result == {"created": True, "trusted": True}, click_result
        client.design({"action": "camera", "scale": 1, "offsetX": 0, "offsetY": 0, "rotation": 0,
                       "flipX": False, "flipY": False, "duration": .5})
        check("Orbit's real project form preserves exported camera geometry and trusted native input through pan, rotation, and mirrors")

        # Rehearse useful sections of the shipped story before recording the entire film.
        orbit["setup"].append({"id": "settle", "action": "wait", "duration": 1.2})
        path = output / "orbit-launch.json"
        path.write_text(json.dumps(orbit, ensure_ascii=False, indent=2) + "\n")
        revenue_start = next(i for i, step in enumerate(orbit["steps"]) if step.get("selector") == "#revenue-card")
        revenue_hold = next(i for i, step in enumerate(orbit["steps"]) if step.get("selector") == "#range-quarter") + 1
        revenue_preview = output / "orbit-revenue-rehearsal.png"
        rehearsal = json.loads(cli("rehearse", path, "--from", revenue_start + 1, "--to", revenue_hold + 1,
                                   "--screenshot", revenue_preview))
        assert rehearsal["completed"] == revenue_hold - revenue_start + 1
        assert evaluate("window.orbit.state.range === 'quarter' && window.__inputLog.some(e => e.kind === 'click' && e.trusted && e.target === 'range-quarter')")
        revenue_camera = client.status()["camera"]
        revenue_points = evaluate("""(() => {
          const line = document.querySelector('#revenue-line');
          return [.4, .6, .8].map(t => {
            const p = line.getPointAtLength(line.getTotalLength() * t).matrixTransform(line.getScreenCTM());
            return {x:p.x, y:p.y};
          });
        })()""")
        project_rehearsal = json.loads(cli("rehearse", path, "--from", "feature", "--to", create_end + 3,
                                           "--screenshot", output / "orbit-project-rehearsal.png"))
        assert project_rehearsal["status"] == "completed" and evaluate(project_created)
        check("Orbit's revenue and project chapters rehearse independently from explicit setup using the shipped script")

        movie = output / "orbit-launch.mp4"
        take = mcp.call("showtime_record", path=str(path), output=str(movie), screenshot=str(output / "orbit-final.png"))["job"]
        deadline = time.monotonic() + 15
        while True:
            preparing = mcp.call("showtime_job", id=take)
            if preparing["phase"] == "setup" and preparing.get("current", {}).get("id") == "settle":
                state = client.status()
                confirmed = mcp.call("showtime_job", id=take)
                if confirmed["phase"] == "setup" and confirmed.get("current", {}).get("id") == "settle":
                    assert state["busy"] and state["playing"] and not state["recording"], "Setup must run before the recorder starts"
                    break
            assert time.monotonic() < deadline, "The explicit setup wait was not observed"
            time.sleep(.08)
        wait_state(lambda s: s["recording"])
        # Full AppKit window snapshots are covered separately; rasterizing the
        # controls during this take would stall the recording's opening frames.
        finished = mcp.call("showtime_job", id=take, wait=True)
        (output / "orbit-recording-result.json").write_text(json.dumps(finished, indent=2) + "\n")
        stats = next(item["recording"] for item in finished["results"] if "recording" in item)
        assert finished["status"] == "completed" and finished["mode"] == "record"
        step_results = [item for item in finished["results"] if item.get("phase") == "steps"]
        assert len(step_results) == len(orbit["steps"])
        assert any(item.get("id") == "settle" and item["phase"] == "setup" and item["duration"] >= 1.2
                   for item in finished["results"])
        assert stats["capturedFrames"] > 0 and stats["duplicatedFrames"] >= 0
        stream = probe(movie)["streams"][0]
        assert (stream["codec_name"], stream["width"], stream["height"], stream["r_frame_rate"]) == ("h264", 1920, 1080, "30/1")
        assert evaluate(project_created + " && window.orbit.state.invites.includes('sam@acme.design')")
        for name, index, offset in [("opening", 2, 1.5), ("revenue", revenue_hold, .8),
                                    ("project", create_end, .3), ("closing", len(orbit["steps"]) - 1, 2)]:
            timestamp = sum(item["duration"] for item in step_results[:index]) + offset
            subprocess.run(["ffmpeg", "-v", "error", "-ss", str(timestamp), "-i", str(movie),
                            "-frames:v", "1", str(output / f"orbit-film-{name}.png")], check=True)
        assert max(pixel(output / "orbit-film-opening.png", 650, 480)) < 100, "Orbit's opening title must be visible during its scripted hold"
        # The real revenue curve must land at the same zoomed coordinates in rehearsal and film.
        for point in revenue_points:
            x = (32 + revenue_camera["x"] + (point["x"] - revenue_camera["x"]) * revenue_camera["scale"]) * density
            y = (88 + revenue_camera["y"] + (point["y"] - revenue_camera["y"]) * revenue_camera["scale"]) * density
            for frame in (revenue_preview, output / "orbit-film-revenue.png"):
                r, g, b = pixel(frame, x, y)
                assert g > r + 20 and g > b + 30, f"Orbit's revenue curve is missing from {frame.name} at {(x, y)}"
        rejected(lambda: client.play(orbit, "record", output=str(movie)), "exists")
        check("The complete Orbit launch film preserves zoomed chart pixels, real project creation, timed captions, and setup-free recording",
              recording=stats, actionSeconds=sum(item["duration"] for item in step_results))

        partial = output / "partial.mp4"
        take = mcp.call("showtime_record", script={"steps": [{"action": "wait", "duration": 30}]}, output=str(partial))["job"]
        wait_state(lambda s: s["recording"])
        rejected(lambda: client.design({"action": "caption", "text": "Cannot interrupt a take"}), "409")
        time.sleep(.7)
        mcp.call("showtime_stop")
        stopped = mcp.call("showtime_job", id=take, wait=True)
        assert stopped["status"] == "cancelled" and any(item.get("partial") for item in stopped["results"])
        assert probe(partial)["streams"][0]["codec_name"] == "h264"
        assert not client.status()["busy"]
        check("Cancellation finalizes a playable partial MP4 and releases the job")
    finally:
        if client.status()["busy"]:
            client.request("POST", "/v1/cancel", {})
            wait_state(lambda s: not s["busy"])
        client.request("POST", "/v1/settings", original_settings)
        client.design({"action": "open", "url": initial["url"]})
        client.design({"action": "camera", "scale": 1, "offsetX": 0, "offsetY": 0, "rotation": 0, "flipX": False, "flipY": False, "duration": 0})
        client.design({"action": "caption", "text": ""})
        client.request("POST", "/v1/studio", initial["studio"])
        mcp.close()
        (output / "workflow-results.json").write_text(json.dumps(results, indent=2) + "\n")
    print("Workflow artifacts: " + str(output), flush=True)


if __name__ == "__main__":
    main()
