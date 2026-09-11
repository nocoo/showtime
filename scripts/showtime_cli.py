#!/usr/bin/env python3
"""Command-line director for Showtime. Run --help for examples."""
from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

# Keep the signed app bundle read-only when this entry point runs directly.
sys.dont_write_bytecode = True
from showtime_client import Client, ShowtimeError, absolute_path, resolve_script_paths
from showtime_schema import ACTIONS, BACKDROPS, describe, guide
from showtime_version import APP_VERSION


def dimensions(value):
    try:
        width, height = (int(part) for part in value.lower().replace("×", "x").split("x"))
        return {"width": width, "height": height}
    except ValueError as exc:
        raise argparse.ArgumentTypeError("Use WIDTHxHEIGHT, for example 1920x1080") from exc


def content_width(value):
    if value.lower() == "auto":
        return None
    try:
        width = int(value)
        if width > 0:
            return width
    except ValueError:
        pass
    raise argparse.ArgumentTypeError("Use a positive whole number of pixels, or auto")


def parser():
    root = argparse.ArgumentParser(prog="showtime", description="Design with individual actions. Rehearse and record locally executed JSON scripts.",
                                   epilog="Start with 'showtime guide' and 'showtime schema'. Design and script steps use identical JSON actions.")
    root.add_argument("--version", action="version", version=f"%(prog)s {APP_VERSION}")
    commands = root.add_subparsers(dest="command", required=True)
    commands.add_parser("guide", help="Read the bundled directing skill and workflow")
    schema_parser = commands.add_parser("schema", help="Read the exact script or action JSON schema")
    schema_parser.add_argument("topic", nargs="?", choices=["script", *ACTIONS])
    commands.add_parser("example", help="Print the bundled Orbit JSON script for editing or rehearsal")
    commands.add_parser("status", help="Get browser, camera, recording, and job status")
    commands.add_parser("inspect", help="Get visible elements with selectors and viewport coordinates")
    studio = commands.add_parser("studio", help="Choose the workspace mode or light/dark theme")
    studio.add_argument("--mode", choices=["studio", "theater", "director"])
    studio.add_argument("--theme", choices=["light", "dark"])
    studio.add_argument("--inspector", choices=["Canvas", "Frame", "Cursor", "Text", "Export"])
    settings = commands.add_parser("settings", help="Read or adjust Canvas dimensions, video resolution, and frame rate")
    settings.add_argument("--canvas", type=dimensions, metavar="WIDTHxHEIGHT")
    settings.add_argument("--video", type=dimensions, metavar="WIDTHxHEIGHT")
    settings.add_argument("--fps", type=int, choices=[24, 30, 60])
    settings.add_argument("--inset", type=float, help="Canvas margin when content width is Auto")
    settings.add_argument("--content-width", dest="contentWidth", type=content_width, default=argparse.SUPPRESS,
                          metavar="PIXELS|auto", help="Screen width in Canvas pixels, excluding the frame; auto fits using inset")
    settings.add_argument("--backdrop", choices=BACKDROPS)
    settings.add_argument("--glow", action=argparse.BooleanOptionalAction, default=None, help="Enable a subtle central glow behind the frame")
    settings.add_argument("--glow-radius", dest="glowRadius", type=float, help="Soft falloff relative to the Canvas short edge: 0.1–1.5")
    settings.add_argument("--glow-size", dest="glowSize", type=float, help="Bright core diameter relative to the Canvas short edge: 0–1")
    settings.add_argument("--frame", choices=["none", "iphone-16-pro", "iphone-16-pro-max", "ipad-pro-11", "ipad-pro-13", "macbook-neo", "macbook-pro"],
                          help="Device proportions and appearance; --content-width sets screen width. Default: none")
    settings.add_argument("--browser-theme", dest="browserTheme", choices=["light", "dark"], help="Frame appearance: light silver; dark indigo on MacBook Neo, space black on other devices; independent of Studio appearance")
    action_parser = commands.add_parser("design", help="Preview one action without recording; use the identical JSON in script steps")
    action_parser.add_argument("action")
    action_parser.add_argument("--screenshot", help="Save the resulting design preview to a new PNG path")
    action_parser.add_argument("--no-wait", action="store_true")
    for name, help_text in [("validate", "Preflight a script and selected range without executing actions"),
                            ("rehearse", "Execute a script or inclusive step range without starting a recording"),
                            ("record", "Execute a script or inclusive step range and save an MP4")]:
        cmd = commands.add_parser(name, help=help_text)
        cmd.add_argument("file", type=Path)
        cmd.add_argument("--from", dest="from_step", type=boundary, help="First step: one-based number or step ID (inclusive)")
        cmd.add_argument("--to", dest="to_step", type=boundary, help="Last step: one-based number or step ID (inclusive)")
        cmd.add_argument("--screenshot", help="Capture the final frame to a new PNG path")
        if name in ("validate", "record"):
            cmd.add_argument("--output", help="New MP4 path; overrides recording.output in the script")
        if name == "validate":
            cmd.add_argument("--mode", choices=["rehearse", "record"], default="rehearse")
        else:
            cmd.add_argument("--no-wait", action="store_true", help="Return a job ID immediately; playback continues in the App")
    wait = commands.add_parser("wait", help="Wait for a job and return its results")
    wait.add_argument("job")
    wait.add_argument("--timeout", type=float, default=3600)
    job = commands.add_parser("job", help="Get a job without waiting")
    job.add_argument("job")
    screenshot = commands.add_parser("screenshot", help="Save the composed film canvas as a PNG")
    screenshot.add_argument("output", nargs="?")
    commands.add_parser("stop", help="Stop a job; an interrupted recording is finalized as a playable partial take")
    commands.add_parser("mcp-config", help="Print a ready-to-paste MCP configuration")
    commands.add_parser("mcp", help="Run the MCP stdio bridge for an agent client")
    return root


def boundary(value):
    try:
        return int(value)
    except ValueError:
        return value


def main(argv=None):
    args = parser().parse_args(argv)
    try:
        if args.command == "guide":
            print(guide())
            return 0
        if args.command == "schema":
            print(json.dumps(describe(args.topic), ensure_ascii=False, indent=2))
            return 0
        if args.command == "mcp":
            from showtime_mcp import main as serve_mcp
            serve_mcp()
            return 0
        if args.command == "mcp-config":
            # Expand HOME in a shell; MCP JSON arguments are not shell-expanded.
            value = {"mcpServers": {"showtime": {"command": "/bin/sh", "args": ["-c", 'exec "$HOME/Library/Application Support/Showtime/bin/showtime" mcp']}}}
        else:
            client = Client()
            if args.command == "status": value = client.status()
            elif args.command == "example": value = client.request("GET", "/v1/scripts/demo")
            elif args.command == "inspect": value = client.request("GET", "/v1/inspect")
            elif args.command == "studio":
                body = {key: getattr(args, key) for key in ("mode", "theme", "inspector") if getattr(args, key) is not None}
                value = client.request("POST", "/v1/studio", body) if body else client.request("GET", "/v1/studio")
            elif args.command == "settings":
                canvas, video = dict(args.canvas or {}), dict(args.video or {})
                for key in ("inset", "backdrop", "glow", "glowRadius", "glowSize", "browserTheme", "frame"):
                    if getattr(args, key) is not None: canvas[key] = getattr(args, key)
                if hasattr(args, "contentWidth"): canvas["contentWidth"] = args.contentWidth
                if args.fps is not None: video["fps"] = args.fps
                body = {}
                if canvas: body["canvas"] = canvas
                if video: body["video"] = video
                value = client.request("POST", "/v1/settings", body) if body else client.request("GET", "/v1/settings")
            elif args.command == "design":
                path = Path(args.action[1:]).expanduser().resolve() if args.action.startswith("@") else None
                source = path.read_text() if path else args.action
                step = resolve_script_paths({"steps": [json.loads(source)]}, path.parent if path else Path.cwd())["steps"][0]
                value = client.design(step, wait=not args.no_wait, screenshot=args.screenshot)
            elif args.command in ("validate", "rehearse", "record"):
                path = args.file.expanduser().resolve()
                script = resolve_script_paths(json.loads(path.read_text()), path.parent)
                options = {key: value for key, value in (("from", args.from_step), ("to", args.to_step),
                           ("output", getattr(args, "output", None)), ("screenshot", args.screenshot)) if value is not None}
                if args.command == "validate":
                    value = client.validate(script, args.mode, **options)
                else:
                    value = client.play(script, args.command, wait=not args.no_wait, **options)
            elif args.command == "wait": value = client.wait(args.job, args.timeout)
            elif args.command == "job": value = client.request("GET", "/v1/jobs/" + args.job)
            elif args.command == "screenshot":
                value = client.request("POST", "/v1/screenshot", {"output": absolute_path(args.output)} if args.output else {})
            elif args.command == "stop": value = client.request("POST", "/v1/cancel", {})
        print(json.dumps(value, ensure_ascii=False, indent=2))
        return 0
    except (ShowtimeError, OSError, ValueError, KeyError, TypeError) as exc:
        print(f"showtime: {exc}", file=sys.stderr)
        return 1
    except KeyboardInterrupt:
        print("\nStopped waiting. The take is still running; use 'showtime stop' to stop it.", file=sys.stderr)
        return 130


if __name__ == "__main__":
    sys.exit(main())
