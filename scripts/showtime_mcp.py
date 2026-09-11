#!/usr/bin/env python3
"""Showtime design and script-playback MCP bridge. Python 3.10+, standard library only."""
from __future__ import annotations

import base64
import json
import sys
from pathlib import Path

sys.dont_write_bytecode = True
from showtime_client import Client, ShowtimeError, absolute_path, resolve_script_paths
from showtime_schema import ACTIONS, BOOL, CANVAS, RANGE, STEP, STR, VIDEO, check_keys, describe, guide, schema
from showtime_version import APP_VERSION


SOURCE = {
    "script": {"type": "object", "description": "A film script object. Read showtime_help(topic='script') for its exact schema. Supply script or path, exclusively."},
    "path": {"type": "string", "description": "JSON script file. Assets and in-script output paths resolve relative to this file."},
    **RANGE,
}
PLAYBACK = {**SOURCE, "screenshot": STR, "wait": BOOL}
TOOLS = [
    {"name": "showtime_help", "description": "Read the directing or project-demo skill, exact script/action schema, or editable example. The project-demo topic covers Remotion bookends, narration, subtitles, and background music.",
     "inputSchema": schema({"topic": {"type": "string", "enum": ["workflow", "project-demo", "script", "example", *ACTIONS]}})},
    {"name": "showtime_status", "description": "Read workflow mode, actual job/recording state, camera transform, held caption, viewport, settings, and director progress. Polling does not create activity.",
     "inputSchema": schema()},
    {"name": "showtime_inspect", "description": "Read visible real webpage controls, selectors, and coordinates. Inspect after navigation or changing the viewport. Camera transforms do not change target coordinates.",
     "inputSchema": schema()},
    {"name": "showtime_settings", "description": "Read or change Canvas, frame, and video settings between jobs. Use the same canvas/recording objects in the final script. Changes persist.",
     "inputSchema": schema({"canvas": CANVAS, "video": VIDEO})},
    {"name": "showtime_studio", "description": "Choose the Studio workspace, Theater playback view, or AI Director guide. Studio theme is independent of the webpage and exported film.",
     "inputSchema": schema({"mode": {"type": "string", "enum": ["studio", "theater", "director"]},
                            "theme": {"type": "string", "enum": ["light", "dark"]},
                            "inspector": {"type": "string", "enum": ["Canvas", "Frame", "Cursor", "Text", "Export"]}, "showInspector": BOOL})},
    {"name": "showtime_design", "description": "Preview one action between takes. Uses exactly the action syntax in script setup/steps. Captions remain visible for inspection until cleared or playback starts. Optional screenshot captures the result; returns its image when waiting (default true). Playback rejects design mutations.",
     "inputSchema": schema({"step": STEP, "screenshot": STR, "wait": BOOL, "includeImage": BOOL}, ["step"])},
    {"name": "showtime_validate", "description": "Preflight the entire script and inclusive selected range without executing webpage actions. Checks both setup and steps. mode defaults to rehearse; record also validates a new output path and recording dimensions.",
     "inputSchema": schema({**SOURCE, "mode": {"type": "string", "enum": ["rehearse", "record"]}, "output": STR, "screenshot": STR})},
    {"name": "showtime_rehearse", "description": "Run setup, then the selected script range locally without starting recording. from/to are inclusive step numbers or IDs. Earlier steps are not replayed. Camera/captions reset before setup; the webpage stays as-is unless setup/steps navigate. Returns a job immediately unless wait=true.",
     "inputSchema": schema(PLAYBACK)},
    {"name": "showtime_record", "description": "Run script setup before recording, then execute the selected range locally and finalize MP4. All timing lives in the script; no live action stream. A new output path is required here or in script.recording.output. Returns a job unless wait=true; cancellation saves a playable partial film.",
     "inputSchema": schema({**PLAYBACK, "output": STR})},
    {"name": "showtime_job", "description": "Read progress, setup position, original step numbers/IDs, per-step results, failures, final screenshot, and MP4 statistics. wait=true waits for completion; includeImage=true returns a captured final screenshot.",
     "inputSchema": schema({"id": STR, "wait": BOOL, "includeImage": BOOL}, ["id"])},
    {"name": "showtime_stop", "description": "Cancel the current design or playback job. A recording owned by the job is finalized as a playable partial MP4.",
     "inputSchema": schema()},
    {"name": "showtime_screenshot", "description": "Capture the composed film Canvas for visual inspection, including camera, cursor, frame, and captions. App controls are excluded. Saves a new PNG and returns its image by default.",
     "inputSchema": schema({"output": STR, "includeImage": BOOL})},
]


def load_script(args):
    if ("path" in args) == ("script" in args):
        raise ShowtimeError("Supply exactly one of script or path.")
    path = Path(args["path"]).expanduser().resolve() if "path" in args else None
    value = json.loads(path.read_text()) if path else args["script"]
    return resolve_script_paths(value, path.parent if path else Path.cwd())


def call_tool(name, args):
    definition = next((tool for tool in TOOLS if tool["name"] == name), None)
    if definition is None:
        raise ShowtimeError("Unknown tool: " + name)
    check_keys(args, definition["inputSchema"], name)
    for flag in ("wait", "includeImage"):
        if flag in args and not isinstance(args[flag], bool):
            raise ShowtimeError(flag + " must be a Boolean.")
    if name == "showtime_help":
        topic = args.get("topic", "workflow")
        if topic in ("workflow", "project-demo"):
            return {"content": [{"type": "text", "text": guide(topic)}], "isError": False}
        value = Client().request("GET", "/v1/scripts/demo") if topic == "example" else describe(topic)
        return {"content": [{"type": "text", "text": json.dumps(value, ensure_ascii=False, indent=2)}], "isError": False}

    client = Client()
    image_path = None
    if name == "showtime_status":
        value = client.status()
    elif name == "showtime_inspect":
        value = client.request("GET", "/v1/inspect")
    elif name == "showtime_settings":
        for key, definition in (("canvas", CANVAS), ("video", VIDEO)):
            if key in args:
                check_keys(args[key], definition, key)
        value = client.request("POST", "/v1/settings", args) if args else client.request("GET", "/v1/settings")
    elif name == "showtime_studio":
        value = client.request("POST", "/v1/studio", args) if args else client.request("GET", "/v1/studio")
    elif name == "showtime_design":
        value = client.design(args["step"], wait=args.get("wait", True), screenshot=args.get("screenshot"))
        if args.get("includeImage", True):
            image_path = value.get("screenshot")
    elif name in ("showtime_validate", "showtime_rehearse", "showtime_record"):
        script = load_script(args)
        options = {key: args[key] for key in ("from", "to", "output", "screenshot") if key in args}
        if name == "showtime_validate":
            value = client.validate(script, args.get("mode", "rehearse"), **options)
        else:
            value = client.play(script, name.removeprefix("showtime_"), wait=args.get("wait", False), **options)
    elif name == "showtime_job":
        value = client.wait(args["id"]) if args.get("wait") else client.request("GET", "/v1/jobs/" + args["id"])
        if args.get("includeImage"):
            image_path = value.get("screenshot")
    elif name == "showtime_stop":
        value = client.request("POST", "/v1/cancel", {})
    elif name == "showtime_screenshot":
        body = {"output": absolute_path(args["output"])} if args.get("output") else {}
        value = client.request("POST", "/v1/screenshot", body)
        if args.get("includeImage", True):
            image_path = value["path"]
    content = [{"type": "text", "text": json.dumps(value, ensure_ascii=False, indent=2)}]
    if image_path:
        content.append({"type": "image", "mimeType": "image/png", "data": base64.b64encode(Path(image_path).read_bytes()).decode()})
    return {"content": content, "isError": False}


def respond(message):
    request_id = message.get("id")
    if request_id is None:
        return None
    method = message.get("method")
    if method == "initialize":
        requested = message.get("params", {}).get("protocolVersion")
        protocol = requested if requested in ("2024-11-05", "2025-03-26", "2025-06-18") else "2025-06-18"
        result = {"protocolVersion": protocol, "capabilities": {"tools": {"listChanged": False}},
                  "serverInfo": {"name": "showtime", "version": APP_VERSION},
                  "instructions": "Start with showtime_help to read the bundled skill and exact syntax. Design with showtime_design and screenshots, then write JSON and use showtime_validate, showtime_rehearse, showtime_record. Rehearsal and recording execute complete scripts or inclusive step ranges locally, including waits. Do not stream design actions during playback. Follow job progress with showtime_job; one job runs at a time."}
    elif method == "ping":
        result = {}
    elif method == "tools/list":
        result = {"tools": TOOLS}
    elif method == "tools/call":
        params = message.get("params", {})
        try:
            if not isinstance(params.get("arguments", {}), dict):
                raise ShowtimeError("Tool arguments must be an object.")
            result = call_tool(params["name"], params.get("arguments", {}))
        except (ShowtimeError, OSError, ValueError, KeyError, TypeError) as exc:
            result = {"content": [{"type": "text", "text": str(exc)}], "isError": True}
    else:
        return {"jsonrpc": "2.0", "id": request_id, "error": {"code": -32601, "message": "Method not found"}}
    return {"jsonrpc": "2.0", "id": request_id, "result": result}


def main():
    for line in sys.stdin:
        if not line.strip():
            continue
        try:
            if len(line) > 4 * 1024 * 1024:
                raise ValueError("Request too large")
            message = json.loads(line)
            if not isinstance(message, dict):
                raise ValueError("Expected one JSON-RPC object per line")
            response = respond(message)
        except (ValueError, TypeError) as exc:
            response = {"jsonrpc": "2.0", "id": None, "error": {"code": -32700, "message": str(exc)}}
        if response is not None:
            print(json.dumps(response, ensure_ascii=False, separators=(",", ":")), flush=True)


if __name__ == "__main__":
    main()
