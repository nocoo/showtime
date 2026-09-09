"""Read the app version from the source manifest or the bundled copy."""
from __future__ import annotations

import json
import re
from pathlib import Path

SCRIPT_DIRECTORY = Path(__file__).resolve().parent
MANIFEST = next((path for path in (SCRIPT_DIRECTORY / "package.json", SCRIPT_DIRECTORY.parent / "package.json")
                 if path.is_file()), SCRIPT_DIRECTORY.parent / "package.json")


def read_version() -> str:
    version = json.loads(MANIFEST.read_text())["version"]
    if not isinstance(version, str) or not re.fullmatch(r"(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)", version):
        raise ValueError("package.json version must use the format X.Y.Z, without a v prefix.")
    return version


APP_VERSION = read_version()
