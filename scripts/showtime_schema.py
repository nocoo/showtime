"""The action vocabulary shared by CLI discovery, MCP schemas, and script checks."""
from __future__ import annotations

from pathlib import Path


def schema(properties=None, required=None, description=None):
    value = {"type": "object", "properties": properties or {}, "additionalProperties": False}
    if required:
        value["required"] = required
    if description:
        value["description"] = description
    return value


STR = {"type": "string"}
BOOL = {"type": "boolean"}
NUMBER = {"type": "number"}
DURATION = {"type": "number", "minimum": 0, "maximum": 300, "description": "Seconds. Motion and wait block playback; caption duration does not."}
TARGET = {"selector": STR, "x": NUMBER, "y": NUMBER}
MOTION = {"duration": DURATION, "easing": {"type": "string", "enum": ["linear", "smooth", "cinematic"]}}
BACKDROPS = ["mist", "pearl", "midnight", "silver", "cloud", "sky", "mint", "rose", "butter"]
CAPTURE = {
    "width": {"type": "integer", "minimum": 640, "maximum": 3840},
    "height": {"type": "integer", "minimum": 360, "maximum": 2160},
    "fps": {"type": "integer", "enum": [24, 30, 60]},
}
CANVAS = schema({
    "width": {"type": "integer", "minimum": 800, "maximum": 3840},
    "height": {"type": "integer", "minimum": 500, "maximum": 2160},
    "inset": NUMBER,
    "contentWidth": {"type": ["integer", "null"], "minimum": 1, "description": "Inner screen width in Canvas pixels. null fits automatically. The full frame must fit inside the Canvas."},
    "backdrop": {"type": "string", "enum": BACKDROPS},
    "glow": {"type": "boolean", "description": "Subtle central light behind the frame. Default false. Adapts to frame appearance and dark backdrops."},
    "glowRadius": {"type": "number", "minimum": .1, "maximum": 1.5, "description": "Fade distance beyond the bright core, relative to the Canvas short edge. Default .75."},
    "glowSize": {"type": "number", "minimum": 0, "maximum": 1, "description": "Bright core diameter relative to the Canvas short edge. Default .3."},
    "browserTheme": {"type": "string", "enum": ["light", "dark"]},
    "frame": {"type": "string", "enum": ["none", "iphone-16-pro", "iphone-16-pro-max", "ipad-pro-11", "ipad-pro-13", "macbook-neo", "macbook-pro"]},
})
VIDEO = schema(CAPTURE)


def action(name, description, fields=None, required=None):
    return schema({"action": {"type": "string", "enum": [name]},
                   "id": {"type": "string", "minLength": 1, "maxLength": 80, "description": "Optional unique, nonnumeric step ID for --from/--to."},
                   "label": STR, **(fields or {})}, ["action", *(required or [])], description)


ACTIONS = {
    "open": action("open", "Navigate the real browser. Omit title/displayURL to display the real page identity.",
                   {"url": STR, "title": STR, "displayURL": STR, "timeout": {"type": "number", "minimum": .1, "maximum": 120}}, ["url"]),
    "metadata": action("metadata", "Replace film title/address overrides. An omitted field resets that override; the actual page does not navigate.", {"title": STR, "displayURL": STR}),
    "move": action("move", "Move the real pointer to a selector or x/y, in untransformed webpage CSS pixels. Default duration .75 seconds.", {**TARGET, **MOTION, "arc": NUMBER}),
    "click": action("click", "Move to a selector or x/y and send a native click. Default movement duration .55 seconds.", {**TARGET, **MOTION, "arc": NUMBER}),
    "doubleClick": action("doubleClick", "Send native double-click input to a selector or x/y.", {**TARGET, **MOTION, "arc": NUMBER}),
    "drag": action("drag", "Native drag from selector or x/y to toSelector or toX/toY. Default drag duration 1.2 seconds.", {**TARGET, **MOTION, "arc": NUMBER, "toSelector": STR, "toX": NUMBER, "toY": NUMBER}),
    "scroll": action("scroll", "Send a native wheel gesture over the target. Positive deltaY scrolls down. Default deltaY 480, duration .9 seconds.", {**TARGET, **MOTION, "deltaX": NUMBER, "deltaY": NUMBER}),
    "type": action("type", "Focus the target when supplied and type native Unicode input. clear=true replaces existing text. Default delay .045 seconds per character.",
                   {**TARGET, "text": {"type": "string", "maxLength": 100000}, "clear": BOOL, "delay": {"type": "number", "minimum": 0, "maximum": 2}}, ["text"]),
    "key": action("key", "Send a native key: e.g. enter, tab, escape, backspace, or a character, with optional modifiers.",
                  {"key": STR, "modifiers": {"type": "array", "items": {"type": "string", "enum": ["command", "shift", "option", "control"]}}}, ["key"]),
    "wait": action("wait", "Hold locally for duration seconds (default 1). No Agent round trip occurs during the hold.", {"duration": DURATION}),
    "waitFor": action("waitFor", "Wait for a visible selector or a JavaScript Boolean condition. Default timeout 10 seconds.",
                      {"selector": STR, "script": STR, "timeout": {"type": "number", "minimum": .1, "maximum": 120}}),
    "camera": action("camera", "Transform webpage content; device frame and captions stay fixed. Omitted fields keep their current values. x/y or selector sets the pivot. Offsets are CSS pixels; positive rotation is clockwise in degrees. Mirrors switch immediately; numeric fields animate for duration (default 1).",
                     {**TARGET, **MOTION, "scale": {"type": "number", "minimum": .25, "maximum": 4},
                      "offsetX": {"type": "number", "minimum": -8192, "maximum": 8192},
                      "offsetY": {"type": "number", "minimum": -8192, "maximum": 8192},
                      "rotation": {"type": "number", "minimum": -360, "maximum": 360}, "flipX": BOOL, "flipY": BOOL}),
    "zoom": action("zoom", "Existing script shorthand for camera scale/focus. Omitted scale resets to 1. Prefer camera for new scripts.", {**TARGET, **MOTION, "scale": {"type": "number", "minimum": .25, "maximum": 4}}),
    "caption": action("caption", "Show one caption, replacing the previous caption. Empty/omitted text clears it. Design holds the preview for screenshots; playback uses duration (default 3 seconds) without blocking subsequent steps.",
                      {"text": {"type": "string", "maxLength": 400}, "subtitle": STR, "eyebrow": STR,
                       "style": {"type": "string", "enum": ["glass", "minimal", "title"]},
                       "position": {"type": "string", "enum": ["bottom", "center", "top"]}, "duration": DURATION}),
    "cursor": action("cursor", "Patch cursor appearance. custom requires an image path. Hotspots are fractions of image dimensions. Values carry between design actions; script setup should specify the desired appearance.",
                     {"style": {"type": "string", "enum": ["arrow", "ring", "dot", "hand", "spotlight", "custom"]},
                      "size": {"type": "number", "minimum": 8, "maximum": 96}, "color": STR, "visible": BOOL, "clickEffect": BOOL,
                      "image": STR, "hotspotX": {"type": "number", "minimum": 0, "maximum": 1}, "hotspotY": {"type": "number", "minimum": 0, "maximum": 1}}),
    "marker": action("marker", "Name a scene in Theater; use id to select its step for partial playback.", {"text": STR}),
    "assert": action("assert", "Evaluate JavaScript and compare its JSON value with equals (default true). A mismatch fails the job at this step.", {"script": STR, "equals": {}}, ["script"]),
    "evaluate": action("evaluate", "Evaluate JavaScript, including promises, and return the JSON result. Use native input actions for page interaction.", {"script": STR}, ["script"]),
    "screenshot": action("screenshot", "Save the composed film frame to a new PNG path at this point in playback.", {"output": STR}, ["output"]),
}
ACTIONS["parallel"] = action("parallel", "Run independent visual tracks together. One camera/zoom, one move, one caption, plus waits; the group completes when all tracks finish.",
                             {"steps": {"type": "array", "minItems": 1, "maxItems": 8,
                                        "items": {"oneOf": [ACTIONS[name] for name in ("move", "camera", "zoom", "caption", "wait")]}}}, ["steps"])
STEP = {"oneOf": list(ACTIONS.values()), "description": "The identical action object is used for design previews, setup, and script steps. Targets use original webpage CSS coordinates, even after camera transforms."}
SCRIPT = schema({"version": {"type": "integer", "enum": [1]}, "name": STR, "canvas": CANVAS,
                 "recording": schema({**CAPTURE, "output": STR}),
                 "setup": {"type": "array", "items": STEP, "description": "Explicit preparation before every selected range, outside the MP4. Earlier steps are never implicitly replayed."},
                 "steps": {"type": "array", "minItems": 1, "maxItems": 1000, "items": STEP}}, ["steps"])
BOUNDARY = {"oneOf": [{"type": "integer", "minimum": 1}, {"type": "string", "minLength": 1}],
            "description": "Inclusive, one-based top-level step number or step ID. Does not address setup or parallel children."}
RANGE = {"from": BOUNDARY, "to": BOUNDARY}


def check_keys(value, definition, label):
    if not isinstance(value, dict):
        raise ValueError(label + " must be a JSON object.")
    unknown = value.keys() - definition["properties"].keys()
    missing = set(definition.get("required", [])) - value.keys()
    if unknown:
        raise ValueError(label + ": unknown fields " + ", ".join(sorted(unknown)))
    if missing:
        raise ValueError(label + ": missing fields " + ", ".join(sorted(missing)))


def check_action(step):
    if not isinstance(step, dict) or not isinstance(step.get("action"), str) or step["action"] not in ACTIONS:
        raise ValueError("Unknown action. Read showtime schema for supported actions.")
    check_keys(step, ACTIONS[step["action"]], step["action"])
    if step["action"] == "parallel":
        if not isinstance(step["steps"], list):
            raise ValueError("parallel steps must be an array.")
        for child in step["steps"]:
            check_action(child)


def check_script(script):
    check_keys(script, SCRIPT, "Script")
    for section in ("setup", "steps"):
        if not isinstance(script.get(section, []), list):
            raise ValueError(section + " must be an array.")
        for index, step in enumerate(script.get(section, []), 1):
            try:
                check_action(step)
            except ValueError as exc:
                raise ValueError(f"{section} {index}: {exc}") from exc
    for section in ("canvas", "recording"):
        if section in script:
            check_keys(script[section], SCRIPT["properties"][section], section)


def describe(topic=None):
    if topic is None or topic == "script":
        return {"script": SCRIPT, "range": RANGE, "actions": list(ACTIONS)}
    if topic not in ACTIONS:
        raise ValueError("Unknown schema topic: " + topic)
    return ACTIONS[topic]


def guide(topic="workflow"):
    if topic not in ("workflow", "project-demo"):
        raise ValueError("Unknown guide topic: " + topic)
    filename = "PROJECT_DEMO_SKILL.md" if topic == "project-demo" else "SKILL.md"
    skill = "showtime-project-demo" if topic == "project-demo" else "showtime"
    bundled = Path(__file__).resolve().parent / filename
    source = Path(__file__).resolve().parent.parent / "skills" / skill / "SKILL.md"
    return (bundled if bundled.is_file() else source).read_text()
