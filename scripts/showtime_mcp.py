#!/usr/bin/env python3
"""Showtime MCP stdio bridge. JSON-RPC on stdout; no dependencies beyond Python 3.10+."""
from __future__ import annotations

import base64
import json
import sys
from pathlib import Path

# The bridge also ships inside the signed app bundle.
sys.dont_write_bytecode = True
from showtime_client import Client, ShowtimeError, absolute_path, resolve_script_paths
from showtime_version import APP_VERSION


def schema(properties=None, required=None):
    result = {"type": "object", "properties": properties or {}, "additionalProperties": False}
    if required:
        result["required"] = required
    return result


STR = {"type": "string"}
BOOL = {"type": "boolean"}
NUMBER = {"type": "number"}
STEP = {"type": "object", "description": "A Showtime action. Coordinates are CSS pixels in the unzoomed webpage viewport, origin top-left. Selectors resolve visible elements and scroll them into view.", "properties": {
    "action": {"type": "string", "enum": ["open","metadata","move","click","doubleClick","drag","scroll","type","key","wait","waitFor","zoom","caption","cursor","marker","assert","screenshot","evaluate","parallel"]},
    "url": STR, "title": STR, "displayURL": STR, "selector": STR, "toSelector": STR,
    "x": NUMBER, "y": NUMBER, "toX": NUMBER, "toY": NUMBER, "duration": NUMBER, "timeout": NUMBER,
    "text": STR, "subtitle": STR, "eyebrow": STR, "style": STR, "position": STR, "color": STR, "size": NUMBER,
    "visible": BOOL, "image": STR, "hotspotX": NUMBER, "hotspotY": NUMBER, "clickEffect": BOOL,
    "scale": NUMBER, "deltaX": NUMBER, "deltaY": NUMBER, "key": STR,
    "modifiers": {"type":"array","items":STR}, "clear": BOOL, "delay": NUMBER, "script": STR,
    "equals": {}, "output": STR, "easing": STR, "arc": NUMBER, "label": STR,
    "steps": {"type":"array","items":{"type":"object"}},
}, "required": ["action"], "additionalProperties": False}

CANVAS_SETTINGS = schema({
    "width": {"type": "integer", "minimum": 800, "maximum": 3840},
    "height": {"type": "integer", "minimum": 500, "maximum": 2160},
    "inset": {"type": "number", "description": "Canvas margin used only when contentWidth is null (Auto)."},
    "contentWidth": {"type": ["integer", "null"], "minimum": 1, "maximum": 3840,
                     "description": "Inner screen width in Canvas pixels, excluding hardware. Height follows the device screen ratio; none uses the Canvas ratio. The frame stays centered and inset is ignored for a fixed width. The full frame must fit; excessive widths are rejected with the current maximum. Omit to keep the current setting, or set null for Auto."},
    "backdrop": {"type": "string", "enum": ["mist", "pearl", "midnight"]},
    "browserTheme": {"type": "string", "enum": ["light", "dark"], "description": "Frame appearance: light uses silver hardware; dark uses indigo on MacBook Neo and space black on other devices, with matching browser/status bars. Independent of Studio and webpage appearance."},
    "frame": {"type": "string", "enum": ["none", "iphone-16-pro", "iphone-16-pro-max", "ipad-pro-11", "ipad-pro-13", "macbook-neo", "macbook-pro"],
              "description": "Default none. Frames define screen proportions and appearance; contentWidth sets the screen width, or null fits automatically. Webpages are captured at Export pixel density. Inspect again after changing frame, contentWidth, Canvas size, or inset for current CSS coordinates. This does not emulate iOS or touch input."},
})
VIDEO_SETTINGS = schema({
    "width": {"type": "integer", "minimum": 640, "maximum": 3840},
    "height": {"type": "integer", "minimum": 360, "maximum": 2160},
    "fps": {"type": "integer", "enum": [24, 30, 60]},
})

TOOLS = [
    {"name":"showtime_settings","description":"Read or atomically update the same Canvas and video settings shown in Studio. Canvas uses CSS pixels; video uses even H.264 pixels. Changing canvas automatically fits the output to its aspect ratio unless video dimensions are supplied. Settings persist and apply to live recording. Available between takes.","inputSchema":schema({"canvas":CANVAS_SETTINGS,"video":VIDEO_SETTINGS})},
    {"name":"showtime_studio","description":"Choose studio, theater, or director workspace and a light/dark Studio theme. Theater shows the real webpage with live director cue cards and progress. Director opens the agent setup guide and is available between takes. Studio appearance does not change the exported film.","inputSchema":schema({"mode":{"type":"string","enum":["studio","theater","director"]},"theme":{"type":"string","enum":["light","dark"]},"inspector":{"type":"string","enum":["Canvas","Frame","Cursor","Text","Export"]},"showInspector":BOOL})},
    {"name":"showtime_status","description":"Get the actual and displayed URL/title, viewport size, camera, cursor, and current recording/job state.","inputSchema":schema()},
    {"name":"showtime_inspect","description":"Inspect visible interactive webpage elements. Returns stable CSS selectors, labels, and bounding rectangles. Use before planning real clicks.","inputSchema":schema()},
    {"name":"showtime_open","description":"Navigate the native browser. Optional title/displayURL only change the film's browser chrome. Omit both to show real page details. Use showtime://demo for the bundled Orbit app.","inputSchema":schema({"url":STR,"title":STR,"displayURL":STR},["url"])},
    {"name":"showtime_act","description":"Perform a native mouse/keyboard action or change a cinematic effect. Click/type/scroll use native input. caption is non-blocking; wait adds a pause. zoom is a camera transform (1–4×). metadata replaces both overrides; omit a field to reset it. Cursor styles: arrow/hand use genuine macOS artwork; ring/dot/spotlight use color. custom needs image=absolute PNG path, optional hotspotX/hotspotY (0–1 fractions). clickEffect toggles ripples. parallel accepts one move, one zoom, one caption, and waits.","inputSchema":schema({"step":STEP,"wait":BOOL},["step"])},
    {"name":"showtime_run","description":"Run a repeatable film script. Supply a script object or an absolute JSON path. Script shape: {version:1,name,canvas?:{width:1920,height:1080,inset:32,contentWidth:null,backdrop:'mist'},recording?:{output,width:1920,height:1080,fps:30},steps:[...]}. Recording and canvas aspect ratios must match. Output paths must not exist. Returns a job immediately unless wait=true. Use showtime_job to follow progress. rehearse=true disables recording.","inputSchema":schema({"script":{"type":"object"},"path":STR,"output":STR,"rehearse":BOOL,"wait":BOOL})},
    {"name":"showtime_job","description":"Get a job's progress, cue results, errors, and MP4 output path. Set wait=true to wait for completion.","inputSchema":schema({"id":STR,"wait":BOOL},["id"])},
    {"name":"showtime_record","description":"Record the current real webpage using Studio's video settings unless overridden. start allows subsequent showtime_act calls to direct a live recording. Stop saves an MP4; cancelling a script finalizes a playable partial take.","inputSchema":schema({"operation":{"type":"string","enum":["start","stop","cancel"]},"output":STR,"width":{"type":"integer"},"height":{"type":"integer"},"fps":{"type":"integer","enum":[24,30,60]}},["operation"])},
    {"name":"showtime_screenshot","description":"Capture the composed film canvas including browser chrome, camera, cursor, and captions. Saves a PNG and returns it for visual inspection. Output path must not exist.","inputSchema":schema({"output":STR,"includeImage":BOOL})},
]


def call_tool(name, args):
    client = Client()
    image_path = None
    if name == "showtime_status": value = client.status()
    elif name == "showtime_settings": value = client.request("POST", "/v1/settings", args) if args else client.request("GET", "/v1/settings")
    elif name == "showtime_studio": value = client.request("POST", "/v1/studio", args) if args else client.request("GET", "/v1/studio")
    elif name == "showtime_inspect": value = client.request("GET", "/v1/inspect")
    elif name == "showtime_open": value = client.act({"action":"open", **args})
    elif name == "showtime_act": value = client.act(args["step"], wait=args.get("wait",True))
    elif name == "showtime_run":
        if ("path" in args) == ("script" in args): raise ShowtimeError("Supply exactly one of script or path.")
        base = Path(args["path"]).expanduser().resolve().parent if "path" in args else Path.cwd()
        script = json.loads(Path(args["path"]).expanduser().read_text()) if "path" in args else args["script"]
        script = resolve_script_paths(script, base)
        if args.get("output"): script.setdefault("recording",{}).update(output=absolute_path(args["output"]))
        if args.get("rehearse"): script.pop("recording",None)
        value = client.run(script,wait=args.get("wait",False))
    elif name == "showtime_job":
        value = client.wait(args["id"]) if args.get("wait") else client.request("GET", "/v1/jobs/" + args["id"])
    elif name == "showtime_record":
        operation=args["operation"]
        if operation == "cancel": value=client.request("POST", "/v1/cancel",{})
        elif operation == "stop": value=client.request("POST", "/v1/recording/stop",{})
        elif operation == "start":
            body={key:args[key] for key in ("output","width","height","fps") if key in args}
            if "output" in body: body["output"]=absolute_path(body["output"])
            value=client.request("POST", "/v1/recording/start",body)
        else: raise ShowtimeError("operation must be start, stop, or cancel.")
    elif name == "showtime_screenshot":
        body={"output":absolute_path(args["output"])} if args.get("output") else {}
        value=client.request("POST", "/v1/screenshot",body)
        if args.get("includeImage",True): image_path=Path(value["path"])
    else: raise ShowtimeError("Unknown tool: " + name)
    content=[{"type":"text","text":json.dumps(value,ensure_ascii=False,indent=2)}]
    if image_path:
        content.append({"type":"image","mimeType":"image/png","data":base64.b64encode(image_path.read_bytes()).decode()})
    return {"content":content,"isError":False}


def respond(message):
    request_id=message.get("id")
    if request_id is None: return None
    method=message.get("method")
    if method == "initialize":
        requested=message.get("params",{}).get("protocolVersion")
        protocol=requested if requested in ("2024-11-05","2025-03-26","2025-06-18") else "2025-06-18"
        result={"protocolVersion":protocol,"capabilities":{"tools":{"listChanged":False}},"serverInfo":{"name":"showtime","version":APP_VERSION},"instructions":"Showtime controls a real native WebKit browser and records composed MP4 films. Inspect first, use selectors, and verify page state with assert actions. One director job runs at a time. Long films return job IDs; poll showtime_job. Captions do not pause the script."}
    elif method == "ping": result={}
    elif method == "tools/list": result={"tools":TOOLS}
    elif method == "tools/call":
        params=message.get("params",{})
        try:
            if not isinstance(params.get("arguments",{}),dict): raise ShowtimeError("Tool arguments must be an object.")
            result=call_tool(params["name"],params.get("arguments",{}))
        except (ShowtimeError,OSError,ValueError,KeyError,TypeError) as exc:
            result={"content":[{"type":"text","text":str(exc)}],"isError":True}
    else:
        return {"jsonrpc":"2.0","id":request_id,"error":{"code":-32601,"message":"Method not found"}}
    return {"jsonrpc":"2.0","id":request_id,"result":result}


def main():
    for line in sys.stdin:
        if not line.strip(): continue
        try:
            if len(line)>4*1024*1024: raise ValueError("Request too large")
            message=json.loads(line)
            if not isinstance(message,dict): raise ValueError("Expected one JSON-RPC object per line")
            response=respond(message)
        except (ValueError,TypeError) as exc:
            response={"jsonrpc":"2.0","id":None,"error":{"code":-32700,"message":str(exc)}}
        if response is not None:
            print(json.dumps(response,ensure_ascii=False,separators=(',',':')),flush=True)


if __name__ == "__main__":
    main()
