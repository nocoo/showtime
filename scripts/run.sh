#!/bin/bash
set -euo pipefail
SHOWTIME_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
"$SHOWTIME_ROOT/scripts/build.sh" "${1:-debug}"
open "$SHOWTIME_ROOT/dist/Showtime.app"
