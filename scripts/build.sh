#!/bin/bash
set -euo pipefail
SHOWTIME_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SHOWTIME_CONFIGURATION="${1:-release}"
if [[ "$SHOWTIME_CONFIGURATION" != "debug" && "$SHOWTIME_CONFIGURATION" != "release" ]]; then
  echo "Usage: scripts/build.sh [debug|release]" >&2
  exit 1
fi
python3 "$SHOWTIME_ROOT/scripts/version.py" sync >&2
swift build --package-path "$SHOWTIME_ROOT" -c "$SHOWTIME_CONFIGURATION" --product Showtime >&2
SHOWTIME_BIN="$(swift build --package-path "$SHOWTIME_ROOT" -c "$SHOWTIME_CONFIGURATION" --show-bin-path)"
SHOWTIME_APP="$SHOWTIME_ROOT/dist/Showtime.app"
mkdir -p "$SHOWTIME_APP/Contents/MacOS" "$SHOWTIME_APP/Contents/Resources/Tools"
# Remove caches left by older builds before sealing the resource directory.
rm -rf "$SHOWTIME_APP/Contents/Resources/Tools/__pycache__"
cp "$SHOWTIME_BIN/Showtime" "$SHOWTIME_APP/Contents/MacOS/Showtime"
cp "$SHOWTIME_ROOT/scripts/Info.plist" "$SHOWTIME_APP/Contents/Info.plist"
ditto "$SHOWTIME_BIN/Showtime_Showtime.bundle" "$SHOWTIME_APP/Contents/Resources/Showtime_Showtime.bundle"
cp "$SHOWTIME_ROOT/scripts/showtime" "$SHOWTIME_ROOT/scripts/showtime_cli.py" "$SHOWTIME_ROOT/scripts/showtime_client.py" "$SHOWTIME_ROOT/scripts/showtime_mcp.py" "$SHOWTIME_ROOT/scripts/showtime_version.py" "$SHOWTIME_ROOT/package.json" "$SHOWTIME_APP/Contents/Resources/Tools/"
chmod +x "$SHOWTIME_APP/Contents/Resources/Tools/showtime" "$SHOWTIME_APP/Contents/Resources/Tools/showtime_mcp.py"
if [[ ! -f "$SHOWTIME_APP/Contents/Resources/Showtime.icns" || "$SHOWTIME_ROOT/scripts/make_icon.swift" -nt "$SHOWTIME_APP/Contents/Resources/Showtime.icns" ]]; then
  mkdir -p "$SHOWTIME_ROOT/.build/Showtime.iconset"
  swift "$SHOWTIME_ROOT/scripts/make_icon.swift" "$SHOWTIME_ROOT/.build/Showtime.iconset"
  iconutil -c icns "$SHOWTIME_ROOT/.build/Showtime.iconset" -o "$SHOWTIME_APP/Contents/Resources/Showtime.icns"
fi
codesign --force --deep --sign - "$SHOWTIME_APP" >&2
echo "$SHOWTIME_APP"
