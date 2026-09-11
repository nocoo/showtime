#!/usr/bin/env python3
"""Exercise CLI/MCP guide discovery from source and a portable tool bundle, offline."""
from __future__ import annotations

import json
import os
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

sys.dont_write_bytecode = True
ROOT = Path(__file__).resolve().parents[1]


def main():
    expected = {
        "workflow": (ROOT / "skills/showtime/SKILL.md").read_text().strip(),
        "project-demo": (ROOT / "skills/showtime-project-demo/SKILL.md").read_text().strip(),
    }
    with tempfile.TemporaryDirectory(prefix="showtime-guides-") as folder:
        working = Path(folder)
        bundled = working / "Tools"
        bundled.mkdir()
        for name in ("showtime_cli.py", "showtime_client.py", "showtime_mcp.py", "showtime_schema.py", "showtime_version.py"):
            shutil.copy2(ROOT / "scripts" / name, bundled / name)
        shutil.copy2(ROOT / "package.json", bundled / "package.json")
        (bundled / "SKILL.md").write_text(expected["workflow"])
        (bundled / "PROJECT_DEMO_SKILL.md").write_text(expected["project-demo"])
        environment = dict(os.environ, SHOWTIME_CONNECTION=str(working / "not-running.json"))
        for scripts in (ROOT / "scripts", bundled):
            command = [sys.executable, str(scripts / "showtime_cli.py")]

            def run(arguments, input=None):
                return subprocess.run(command + arguments, input=input, cwd=working, env=environment,
                                      text=True, capture_output=True, check=True, timeout=20).stdout

            assert run(["guide"]).strip() == expected["workflow"]
            for topic, text in expected.items():
                assert run(["guide", topic]).strip() == text
            requests = [
                {"jsonrpc": "2.0", "id": topic, "method": "tools/call",
                 "params": {"name": "showtime_help", "arguments": {"topic": topic}}}
                for topic in expected
            ]
            requests.append({"jsonrpc": "2.0", "id": "list", "method": "tools/list"})
            replies = {reply["id"]: reply["result"] for reply in
                       map(json.loads, run(["mcp"], "".join(json.dumps(r) + "\n" for r in requests)).splitlines())}
            for topic, text in expected.items():
                assert not replies[topic]["isError"]
                assert replies[topic]["content"][0]["text"].strip() == text
            help_tool = next(t for t in replies["list"]["tools"] if t["name"] == "showtime_help")
            assert set(expected) <= set(help_tool["inputSchema"]["properties"]["topic"]["enum"])
        assert not list(bundled.rglob("__pycache__")), "Guide reads must leave bundled tools unchanged"
    print("PASS Both skills are available through CLI and MCP from source and a portable bundle, without an app connection")


if __name__ == "__main__":
    main()
