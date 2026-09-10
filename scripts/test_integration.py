#!/usr/bin/env python3
"""Exercise native browser input and recording against a running Showtime.app."""
from __future__ import annotations

import argparse
import json
import tempfile
import time
import urllib.error
import urllib.request
from pathlib import Path

from showtime_client import Client, ShowtimeError
from showtime_version import APP_VERSION


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output-dir", type=Path, help="New directory for screenshots and a partial MP4")
    args = parser.parse_args()
    output = args.output_dir or Path(tempfile.mkdtemp(prefix="showtime-checks-"))
    if args.output_dir:
        output.mkdir(parents=True, exist_ok=False)
    output = output.resolve()
    client = Client()
    status = client.status()
    if any(status[key] for key in ("playing", "recording", "preparing", "finishing")):
        raise ShowtimeError("Finish the current take before running integration checks.")
    assert status["appVersion"] == APP_VERSION, "Rebuild and reopen the app first."

    original_settings = client.request("GET", "/v1/settings")
    try:
        # Orbit intentionally overflows at this authored viewport. At the new
        # 1920 × 1080 default it fits vertically, so a scroll cannot change scrollTop.
        client.request("POST", "/v1/settings", {
            "canvas": {"width": 1440, "height": 810, "inset": 32},
            "video": {"width": 1920, "height": 1080, "fps": 30},
        })
        check_input(client, output)
    finally:
        if any(client.status()[key] for key in ("playing", "recording", "preparing", "finishing")):
            client.request("POST", "/v1/cancel", {})
            deadline = time.monotonic() + 20
            while any(client.status()[key] for key in ("playing", "recording", "preparing", "finishing")):
                if time.monotonic() >= deadline:
                    raise ShowtimeError("The check did not stop; restore capture settings after it finishes.")
                time.sleep(0.1)
        client.request("POST", "/v1/settings", original_settings)


def check_input(client: Client, output: Path):

    def act(action, **values):
        return client.act({"action": action, **values})

    def verify(expression, label):
        act("assert", script=expression, label=label)
        print("PASS " + label, flush=True)

    act("open", url="showtime://demo")
    assert client.status()["title"] == client.status()["displayTitle"]
    act("metadata", title="Green studio", displayURL="https://demo.example.com")
    assert client.status()["displayTitle"] == "Green studio"
    assert client.status()["url"] != client.status()["displayURL"]
    act("metadata")
    assert client.status()["url"] == client.status()["displayURL"]
    print("PASS Default metadata, overrides, and reset", flush=True)

    act("cursor", style="custom", size=40, color="#4A8234", visible=True,
        image=str(Path(__file__).resolve().parent.parent / "examples/cursors/diamond.png"),
        hotspotX=0.5, hotspotY=0.5)
    act("click", selector="#range-quarter", duration=0.2)
    verify("window.orbit.state.range === 'quarter' && window.__inputLog.some(e=>e.kind==='click' && e.trusted && e.target==='range-quarter')",
           "Custom cursor and trusted page click")
    client.request("POST", "/v1/screenshot", {"output": str(output / "custom-cursor.png")})
    act("click", selector="#new-project", duration=0.15)
    act("waitFor", selector="#project-name")
    act("type", selector="#project-name", text="旧名字", delay=0.01)
    act("type", selector="#project-name", text="青草项目 🌱", clear=True, delay=0.01)
    verify("document.querySelector('#project-name').value === '青草项目 🌱' && window.__inputLog.some(e=>e.kind==='input' && e.trusted && e.value==='青草项目 🌱')",
           "Native clear and Unicode text input")
    act("key", key="escape")
    verify("!document.querySelector('#project-name')", "Native Escape closes the form")

    act("scroll", selector=".main-scroll", deltaY=320, duration=0.4)
    act("wait", duration=0.3)
    verify("document.querySelector('.main-scroll').scrollTop > 100 && window.__inputLog.some(e=>e.kind==='wheel' && e.trusted)",
           "Native wheel scroll reaches the correct viewport")
    act("zoom", scale=1.4, x=700, y=350, duration=0.2)
    act("scroll", selector=".main-scroll", deltaY=-320, duration=0.4)
    act("wait", duration=0.3)
    verify("document.querySelector('.main-scroll').scrollTop < 1", "Scroll remains accurate while zoomed")
    act("zoom", scale=1, duration=0.2)

    act("evaluate", script="""(() => {
      const slider=document.createElement('input'); slider.id='native-slider'; slider.type='range';
      slider.min=0; slider.max=100; slider.value=0;
      slider.style='position:fixed;left:350px;top:40px;width:300px;height:30px;z-index:9999';
      window.__sliderTrusted=[]; slider.addEventListener('input',e=>window.__sliderTrusted.push(e.isTrusted));
      document.body.append(slider); return true;
    })()""")
    act("drag", x=358, y=55, toX=635, toY=55, duration=0.5)
    verify("Number(document.querySelector('#native-slider').value)>85 && window.__sliderTrusted.length>0 && window.__sliderTrusted.every(Boolean)",
           "Native slider drag produces trusted input")
    act("evaluate", script="(() => {document.querySelector('#native-slider').remove(); return true;})()")

    for headers, expected in [({}, 401), ({"Authorization": "Bearer " + client.token, "Origin": "https://example.com"}, 403)]:
        request = urllib.request.Request(client.url + "/v1/status", headers=headers)
        try:
            client.opener.open(request, timeout=5)
        except urllib.error.HTTPError as error:
            assert error.code == expected
        else:
            raise AssertionError("An unauthorized request was accepted.")
    print("PASS API authentication and browser-origin protection", flush=True)

    job_id = client.run({"version": 1, "name": "Cancellation check",
        "canvas": {"width": 1440, "height": 810, "inset": 32, "backdrop": "mist"},
        "recording": {"output": str(output / "cancelled-take.mp4"), "width": 1280, "height": 720, "fps": 30},
        "steps": [{"action": "open", "url": "showtime://demo"}, {"action": "wait", "duration": 20}]
    }, wait=False)["job"]
    for _ in range(100):
        if client.status()["recording"]:
            break
        time.sleep(0.1)
    else:
        raise AssertionError("Recording did not start.")
    try:
        client.act({"action": "wait", "duration": 0.1}, wait=False)
    except ShowtimeError as error:
        assert "409" in str(error)
    else:
        raise AssertionError("Concurrent director jobs were accepted.")
    time.sleep(1.4)
    client.request("POST", "/v1/cancel", {})
    result = client.wait(job_id, timeout=20)
    assert result["status"] == "cancelled" and Path(result["output"]).stat().st_size > 0
    assert any(item.get("partial") for item in result["results"])
    assert not any(client.status()[key] for key in ("playing", "recording", "preparing", "finishing"))
    (output / "cancelled-take-result.json").write_text(json.dumps(result, indent=2) + "\n")
    print("PASS Concurrent job rejection and partial MP4 finalization", flush=True)
    print("Integration artifacts: " + str(output), flush=True)


if __name__ == "__main__":
    main()
