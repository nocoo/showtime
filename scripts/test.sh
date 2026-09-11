#!/bin/bash
set -euo pipefail
SHOWTIME_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
python3 "$SHOWTIME_ROOT/scripts/version.py" check
bash -n "$SHOWTIME_ROOT/scripts/build.sh"
sh -n "$SHOWTIME_ROOT/scripts/showtime"
swift run --package-path "$SHOWTIME_ROOT" ShowtimeChecks
python3 -m py_compile "$SHOWTIME_ROOT"/scripts/*.py
python3 "$SHOWTIME_ROOT/scripts/test_guides.py"
node --check "$SHOWTIME_ROOT/Sources/Showtime/Resources/Demo/app.js"
