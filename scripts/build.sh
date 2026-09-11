#!/bin/bash
set -euo pipefail
SHOWTIME_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SHOWTIME_CONFIGURATION="${1:-release}"
if [[ "$SHOWTIME_CONFIGURATION" != "debug" && "$SHOWTIME_CONFIGURATION" != "release" ]]; then
  echo "Usage: scripts/build.sh [debug|release]" >&2
  exit 1
fi
SHOWTIME_SIGN_IDENTITY="${CODE_SIGN_IDENTITY:-Apple Development}"
SHOWTIME_SIGN_TEAM="${DEVELOPMENT_TEAM:-93WWLTN9XU}"
SHOWTIME_ARCH="${SHOWTIME_ARCH:-$(uname -m)}"
case "$SHOWTIME_ARCH" in
  arm64|x86_64) SHOWTIME_ARCHES=("$SHOWTIME_ARCH") ;;
  universal) SHOWTIME_ARCHES=(arm64 x86_64) ;;
  *) echo "SHOWTIME_ARCH must be arm64, x86_64, or universal." >&2; exit 1 ;;
esac
if [[ "$SHOWTIME_SIGN_IDENTITY" != "-" ]]; then
  # Select a stable certificate name, never a rotating certificate SHA pin.
  if ! python3 - "$SHOWTIME_SIGN_IDENTITY" <<'PY'
import re
import subprocess
import sys

result = subprocess.run(["security", "find-identity", "-v", "-p", "codesigning"], capture_output=True, text=True)
names = re.findall(r'"([^"\n]+)"', result.stdout)
sys.exit(0 if result.returncode == 0 and any(sys.argv[1] in name for name in names) else 1)
PY
  then
    echo "No usable signing identity matches: $SHOWTIME_SIGN_IDENTITY" >&2
    echo "Configure the requested certificate with its private key for team $SHOWTIME_SIGN_TEAM. See docs/signing.md." >&2
    echo "For an explicitly temporary local or CI build, set CODE_SIGN_IDENTITY=-." >&2
    exit 1
  fi
else
  echo "Explicit temporary ad-hoc signing; this build has no stable Apple development identity." >&2
fi
python3 "$SHOWTIME_ROOT/scripts/version.py" sync >&2
# Refresh both icon consumers before SwiftPM copies the toolbar resource.
swift "$SHOWTIME_ROOT/scripts/make_icon.swift" "$SHOWTIME_ROOT/.build/Showtime.iconset" >&2
SHOWTIME_BINARIES=()
for SHOWTIME_TARGET_ARCH in "${SHOWTIME_ARCHES[@]}"; do
  SHOWTIME_TRIPLE="$SHOWTIME_TARGET_ARCH-apple-macosx14.0"
  swift build --package-path "$SHOWTIME_ROOT" -c "$SHOWTIME_CONFIGURATION" --triple "$SHOWTIME_TRIPLE" --product Showtime >&2
  SHOWTIME_BIN="$(swift build --package-path "$SHOWTIME_ROOT" -c "$SHOWTIME_CONFIGURATION" --triple "$SHOWTIME_TRIPLE" --show-bin-path)"
  SHOWTIME_BINARIES+=("$SHOWTIME_BIN/Showtime")
done
SHOWTIME_APP="$SHOWTIME_ROOT/dist/Showtime.app"
mkdir -p "$SHOWTIME_ROOT/dist"
SHOWTIME_STAGE="$(mktemp -d "$SHOWTIME_ROOT/dist/.showtime-build.XXXXXX")"
trap 'rm -rf "$SHOWTIME_STAGE"' EXIT
SHOWTIME_STAGED_APP="$SHOWTIME_STAGE/Showtime.app"
mkdir -p "$SHOWTIME_STAGED_APP/Contents/MacOS" "$SHOWTIME_STAGED_APP/Contents/Resources/Tools"
if [[ "${#SHOWTIME_BINARIES[@]}" == 1 ]]; then
  cp "${SHOWTIME_BINARIES[0]}" "$SHOWTIME_STAGED_APP/Contents/MacOS/Showtime"
else
  lipo -create "${SHOWTIME_BINARIES[@]}" -output "$SHOWTIME_STAGED_APP/Contents/MacOS/Showtime"
fi
cp "$SHOWTIME_ROOT/scripts/Info.plist" "$SHOWTIME_STAGED_APP/Contents/Info.plist"
ditto "$SHOWTIME_BIN/Showtime_Showtime.bundle" "$SHOWTIME_STAGED_APP/Contents/Resources/Showtime_Showtime.bundle"
cp "$SHOWTIME_ROOT/LICENSE" "$SHOWTIME_STAGED_APP/Contents/Resources/LICENSE"
cp "$SHOWTIME_ROOT/scripts/showtime" "$SHOWTIME_ROOT/scripts/showtime_cli.py" "$SHOWTIME_ROOT/scripts/showtime_client.py" "$SHOWTIME_ROOT/scripts/showtime_mcp.py" "$SHOWTIME_ROOT/scripts/showtime_schema.py" "$SHOWTIME_ROOT/scripts/showtime_version.py" "$SHOWTIME_ROOT/skills/showtime/SKILL.md" "$SHOWTIME_ROOT/package.json" "$SHOWTIME_STAGED_APP/Contents/Resources/Tools/"
chmod +x "$SHOWTIME_STAGED_APP/Contents/Resources/Tools/showtime" "$SHOWTIME_STAGED_APP/Contents/Resources/Tools/showtime_mcp.py"
iconutil -c icns "$SHOWTIME_ROOT/.build/Showtime.iconset" -o "$SHOWTIME_STAGED_APP/Contents/Resources/Showtime.icns"
SHOWTIME_SIGN_OPTIONS=(--force --sign "$SHOWTIME_SIGN_IDENTITY")
if [[ "$SHOWTIME_SIGN_IDENTITY" == "Developer ID Application"* ]]; then
  SHOWTIME_SIGN_OPTIONS+=(--options runtime --timestamp)
fi
codesign "${SHOWTIME_SIGN_OPTIONS[@]}" "$SHOWTIME_STAGED_APP" >&2
codesign --verify --deep --strict --verbose=2 "$SHOWTIME_STAGED_APP" >&2
if [[ "$SHOWTIME_SIGN_IDENTITY" != "-" ]]; then
  SHOWTIME_ACTUAL_TEAM="$(codesign --display --verbose=4 "$SHOWTIME_STAGED_APP" 2>&1 | sed -n 's/^TeamIdentifier=//p')"
  if [[ "$SHOWTIME_ACTUAL_TEAM" != "$SHOWTIME_SIGN_TEAM" ]]; then
    echo "Signing team mismatch: expected $SHOWTIME_SIGN_TEAM, got $SHOWTIME_ACTUAL_TEAM." >&2
    echo "Select the correct certificate name with CODE_SIGN_IDENTITY or set your DEVELOPMENT_TEAM. See docs/signing.md." >&2
    exit 1
  fi
  echo "Signed with $SHOWTIME_SIGN_IDENTITY · team $SHOWTIME_ACTUAL_TEAM" >&2
fi
# Replace the old bundle only after a clean build and signature verification.
if [[ -e "$SHOWTIME_APP" ]]; then mv "$SHOWTIME_APP" "$SHOWTIME_STAGE/previous.app"; fi
mv "$SHOWTIME_STAGED_APP" "$SHOWTIME_APP"
touch "$SHOWTIME_APP"
echo "$SHOWTIME_APP"
