#!/bin/bash
set -euo pipefail
SHOWTIME_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
python3 "$SHOWTIME_ROOT/scripts/version.py" check
swift run --package-path "$SHOWTIME_ROOT" ShowtimeChecks
python3 -m py_compile "$SHOWTIME_ROOT/scripts/showtime_client.py" "$SHOWTIME_ROOT/scripts/showtime_cli.py" "$SHOWTIME_ROOT/scripts/showtime_mcp.py" "$SHOWTIME_ROOT/scripts/showtime_version.py" "$SHOWTIME_ROOT/scripts/version.py" "$SHOWTIME_ROOT/scripts/test_integration.py"
node --check "$SHOWTIME_ROOT/Sources/Showtime/Resources/Demo/app.js"
