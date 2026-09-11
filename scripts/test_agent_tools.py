#!/usr/bin/env python3
"""Verify the tools explicitly installed in AI Director, outside the source tree."""
from __future__ import annotations

import argparse
import json
import os
import subprocess
import sys
from pathlib import Path

sys.dont_write_bytecode = True
from showtime_client import Client
from showtime_version import APP_VERSION


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--app", type=Path, required=True, help="The running app whose Install tools button was used")
    parser.add_argument("--output-dir", type=Path, required=True)
    parser.add_argument("--brief", type=Path, help="Optional saved clipboard text from Copy instructions for your agent")
    args = parser.parse_args()
    output = args.output_dir.resolve()
    output.mkdir(parents=True, exist_ok=False)
    app = args.app.resolve()
    installed = Path.home() / "Library/Application Support/Showtime/bin"
    bundled = app / "Contents/Resources/Tools"
    names = ("showtime", "showtime_cli.py", "showtime_client.py", "showtime_mcp.py", "showtime_schema.py", "showtime_version.py", "SKILL.md", "package.json")
    assert (installed / "showtime").exists(), "Click AI Director → Agent integration → Install tools first."
    for name in names:
        assert (installed / name).read_bytes() == (bundled / name).read_bytes(), "Update tools first: " + name
        assert (installed / name).stat().st_mode & 0o777 == (0o755 if name == "showtime" else 0o600)
    print("PASS Explicitly installed tools match the app and have the intended permissions", flush=True)

    environment = dict(os.environ, PATH="/usr/bin:/bin:/usr/sbin:/sbin")

    def run(*command, input=None):
        return subprocess.run(command, input=input, cwd=output, env=environment, text=True,
                              capture_output=True, check=True, timeout=20).stdout

    cli = str(installed / "showtime")
    assert run(cli, "--version").strip() == "showtime " + APP_VERSION
    assert run(cli, "guide").strip() == (bundled / "SKILL.md").read_text().strip()
    assert json.loads(run(cli, "schema", "camera"))["properties"]["flipX"]["type"] == "boolean"
    state = json.loads(run(cli, "status"))
    assert state["ready"] and state["appVersion"] == APP_VERSION
    assert state["url"] == Client().status()["url"]
    print("PASS Installed CLI connects outside the repository with a minimal GUI PATH", flush=True)

    config_text = run(cli, "mcp-config")
    config = json.loads(config_text)["mcpServers"]["showtime"]
    assert config == {"command": "/bin/sh", "args": ["-c", 'exec "$HOME/Library/Application Support/Showtime/bin/showtime" mcp']}
    for text in (config_text, args.brief.read_text() if args.brief else ""):
        assert str(Path.home()) not in text and str(app) not in text and "artifacts/" not in text
    if args.brief:
        brief = args.brief.read_text()
        assert (bundled / "SKILL.md").read_text().strip() in brief
        assert all(command in brief for command in ("showtime guide", "showtime schema", "showtime_help", "showtime rehearse", "showtime record"))
        copied = json.loads(brief.split("Current settings:\n", 1)[1].splitlines()[0])
        copied["canvas"].setdefault("contentWidth", None)
        current = Client().request("GET", "/v1/settings")
        assert copied == {"canvas": current["canvas"], "recording": current["video"]}
        print("PASS Copied instructions include the full skill and exact current Canvas and export settings", flush=True)
    messages = [
        {"jsonrpc": "2.0", "id": 1, "method": "initialize", "params": {
            "protocolVersion": "2025-06-18", "capabilities": {}, "clientInfo": {"name": "installed-tools-check", "version": "1"}}},
        {"jsonrpc": "2.0", "method": "notifications/initialized"},
        {"jsonrpc": "2.0", "id": 2, "method": "tools/call", "params": {"name": "showtime_status", "arguments": {}}},
        {"jsonrpc": "2.0", "id": 3, "method": "tools/call", "params": {"name": "showtime_help", "arguments": {"topic": "workflow"}}},
        {"jsonrpc": "2.0", "id": 4, "method": "tools/call", "params": {"name": "showtime_help", "arguments": {"topic": "camera"}}},
    ]
    replies = [json.loads(line) for line in run(config["command"], *config["args"],
                input="".join(json.dumps(message) + "\n" for message in messages)).splitlines()]
    assert [reply["id"] for reply in replies] == [1, 2, 3, 4] and all("error" not in reply for reply in replies)
    assert replies[0]["result"]["serverInfo"]["version"] == APP_VERSION
    result = replies[1]["result"]
    assert not result.get("isError")
    mcp_state = json.loads(result["content"][0]["text"])
    assert mcp_state["ready"] and mcp_state["appVersion"] == APP_VERSION and mcp_state["url"] == state["url"]
    assert replies[2]["result"]["content"][0]["text"].strip() == (bundled / "SKILL.md").read_text().strip()
    assert json.loads(replies[3]["result"]["content"][0]["text"]) == json.loads(run(cli, "schema", "camera"))
    print("PASS Portable MCP configuration completes initialization and status without app or source paths", flush=True)

    run("/usr/bin/codesign", "--verify", "--deep", "--strict", str(app))
    assert not list((app / "Contents/Resources").rglob("__pycache__"))
    assert not list(installed.rglob("__pycache__"))
    print("PASS Running CLI / MCP leaves the signed app and tools free of bytecode", flush=True)
    (output / "agent-tools-results.json").write_text(json.dumps({
        "app": str(app), "version": APP_VERSION, "files": list(names), "mcpConfiguration": config,
        "minimalPath": environment["PATH"], "signatureVerified": True, "briefChecked": bool(args.brief),
    }, indent=2) + "\n")


if __name__ == "__main__":
    main()
