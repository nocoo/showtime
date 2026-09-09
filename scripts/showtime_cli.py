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


def parser():
    root = argparse.ArgumentParser(prog="showtime", description="Direct real webpages. Make little films.")
    commands = root.add_subparsers(dest="command", required=True)
    commands.add_parser("status", help="Get browser, camera, recording, and job status")
    commands.add_parser("inspect", help="Get visible elements with selectors and viewport coordinates")
    open_parser = commands.add_parser("open", help="Navigate to a URL (showtime://demo opens Orbit)")
    open_parser.add_argument("url")
    open_parser.add_argument("--title")
    open_parser.add_argument("--display-url", dest="displayURL")
    action_parser = commands.add_parser("act", help="Execute one JSON action; prefix a filename with @ to read a file")
    action_parser.add_argument("action")
    action_parser.add_argument("--no-wait", action="store_true")
    evaluate = commands.add_parser("eval", help="Evaluate a JavaScript expression (including promises)")
    evaluate.add_argument("expression")
    for name, help_text in [("run", "Run a JSON film script"), ("demo", "Run the bundled Orbit launch film")]:
        cmd = commands.add_parser(name, help=help_text)
        if name == "run":
            cmd.add_argument("file", type=Path)
        cmd.add_argument("--output", help="MP4 output path; enables recording")
        cmd.add_argument("--rehearse", action="store_true", help="Run without recording")
        cmd.add_argument("--no-wait", action="store_true", help="Return a job ID immediately")
    wait = commands.add_parser("wait", help="Wait for a job and return its results")
    wait.add_argument("job")
    wait.add_argument("--timeout", type=float, default=3600)
    job = commands.add_parser("job", help="Get a job without waiting")
    job.add_argument("job")
    screenshot = commands.add_parser("screenshot", help="Save the composed film canvas as a PNG")
    screenshot.add_argument("output", nargs="?")
    record = commands.add_parser("record", help="Start or finish a manual/API-driven recording")
    rec = record.add_subparsers(dest="operation", required=True)
    start = rec.add_parser("start")
    start.add_argument("--output")
    start.add_argument("--width", type=int, default=1920)
    start.add_argument("--height", type=int, default=1080)
    start.add_argument("--fps", type=int, choices=[24,30,60], default=30)
    rec.add_parser("stop")
    commands.add_parser("stop", help="Stop a job; an interrupted recording is finalized as a playable partial take")
    commands.add_parser("mcp-config", help="Print a ready-to-paste MCP configuration")
    return root


def main(argv=None):
    args = parser().parse_args(argv)
    try:
        if args.command == "mcp-config":
            value = {"mcpServers": {"showtime": {"command": "python3", "args": [str(Path(__file__).resolve().with_name("showtime_mcp.py"))]}}}
        else:
            client = Client()
            if args.command == "status": value = client.status()
            elif args.command == "inspect": value = client.request("GET", "/v1/inspect")
            elif args.command == "open":
                step = {"action": "open", "url": args.url}
                for key in ("title", "displayURL"):
                    if getattr(args, key) is not None: step[key] = getattr(args, key)
                value = client.act(step)
            elif args.command == "act":
                source = Path(args.action[1:]).read_text() if args.action.startswith("@") else args.action
                value = client.act(json.loads(source), wait=not args.no_wait)
            elif args.command == "eval":
                job = client.act({"action": "evaluate", "script": args.expression})
                value = job["results"][0].get("value")
            elif args.command in ("run", "demo"):
                script = json.loads(args.file.read_text()) if args.command == "run" else client.request("GET", "/v1/scripts/demo")
                script = resolve_script_paths(script, args.file.resolve().parent if args.command == "run" else Path.cwd())
                if args.output:
                    script.setdefault("recording", {}).update(output=absolute_path(args.output))
                if args.rehearse:
                    script.pop("recording", None)
                value = client.run(script, wait=not args.no_wait)
            elif args.command == "wait": value = client.wait(args.job, args.timeout)
            elif args.command == "job": value = client.request("GET", "/v1/jobs/" + args.job)
            elif args.command == "screenshot":
                value = client.request("POST", "/v1/screenshot", {"output": absolute_path(args.output)} if args.output else {})
            elif args.command == "record":
                if args.operation == "stop": value = client.request("POST", "/v1/recording/stop", {})
                else:
                    body = {"width": args.width, "height": args.height, "fps": args.fps}
                    if args.output: body["output"] = absolute_path(args.output)
                    value = client.request("POST", "/v1/recording/start", body)
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
