# Showtime

Native macOS browser (macOS 14+, Swift 6 tools / Swift 5 mode; WebKit + AVFoundation; Python 3.10+ stdlib CLI/MCP) for agent-directed real-web interaction and H.264 demo recording.
Docs: [README.md](README.md) · [English README](docs/README.en.md) · [Studio Design](docs/studio.md) · [Development & Release](docs/01-development-release.md) · [Versioning](docs/versioning.md) · [Signing](docs/signing.md) · [Retrospective](Retrospective.md)

## Commands

Run from root with Swift 6 (Xcode or Command Line Tools), Python 3.10+, and Node (Demo JS syntax). App/core live in `Sources/Showtime` and `Sources/ShowtimeCore`, standalone `ShowtimeChecks` in `Tests/ShowtimeCoreTests`, CLI/MCP in `scripts/showtime`, and React deps only in `examples/overlay-react`. Media acceptance requires FFmpeg and an unlocked GUI session.

```sh
scripts/test.sh                                                        # S1 + L1 core & static checks
python3 scripts/version.py check                                       # S1 version sync check
swift build --package-path .                                           # S1 Swift build check
scripts/build.sh debug                                                 # Build debug dist/Showtime.app
scripts/showtime --version                                             # CLI version smoke check
python3 scripts/test_integration.py --output-dir artifacts/input-check # L3 manual (unlocked GUI)
python3 scripts/test_workflow.py --output-dir artifacts/workflow-check # L4 manual (unlocked GUI + FFmpeg)
SHOWTIME_ARCH=universal scripts/build.sh release                       # B1 universal release build
python3 scripts/package_release.py --local-preview                     # B1 local preview archive check
```

## Invariants

- Preserve genuine WebKit/AppKit input and native window behavior; JavaScript inspects/asserts without replacing clicks.
- Install/update Agent tools only via the explicit AI Director button; normal launch, page entry, and copying instructions must not execute Python or alter tools, profiles, or PATH.
- Use stable user-support-directory CLI/MCP entries, shared schema, and bundled skills; keep developer paths/credentials out of user instructions and bytecode out of signed apps.
- Always start on built-in Orbit (never restore a private prior URL) and preserve explicit brand image loading ([branding.md](docs/branding.md)); keep real-site evidence/connection files in ignored `artifacts/`.
- Preserve shared `FrameLayout` geometry, even/proportional video dimensions, None/Auto defaults, frame themes, and transparent overlays (see [01-development-release.md](docs/01-development-release.md)).
- Cancellation must yield playable partial MP4s; report duplicated frames/capture speed honestly, keep 4K density and bounded prefetch, and never treat action completion or encoder FPS as visual correctness.
- Root `package.json` is version/metadata only (no root install/lockfile; `scripts/version.py` generates Swift/plist). Keep Chinese and English READMEs synced on behavior changes.
- Releases require explicit authorization and follow [01-development-release.md](docs/01-development-release.md), [versioning.md](docs/versioning.md), and [signing.md](docs/signing.md).
- Preserve explicit versions, real signature/notarization facts, stable installed tools, and immutable releases; never alter Hexly or other repos for Showtime releases.

## Quality & Local Gates

Follows `system1-quality`; CI slot definitions and pinned `base-ci` actions live in `.github/workflows/quality-slots.yml` via `.github/workflows/ci.yml` (`quality / Z1: Gate` aggregates slots and verifies `tested-sha`). Status vocabulary: `enforced`, `planned`, `manual`, `N/A`.

- **Enforced in CI**: `S1`, `S3`, `G1`, `G2` (`examples/overlay-react/bun.lock`), `B1`, `L1` (`ShowtimeChecks` + script/guide checks), `Z1`. Checks are check-only; past runs do not prove a current pass.
- **Exceptions / gaps**: `S2` (`N/A`, no lint gate); `L2` (`N/A`, not a Worker); `L3`/`L4` (`manual`, unlocked GUI/desktop); `P1` (`N/A`, not published to npm).
- **Local hooks**: none installed yet (`planned`); run `scripts/test.sh` locally before committing.

## Resources & Isolation

| Lane | Endpoint / State | Boundary |
| --- | --- | --- |
| Everyday App | Default `studio.showtime.mac` & user settings | Docs checks must not operate the everyday app; restore prior settings after GUI runs |
| Isolated Test | Independent bundle ID, free `SHOWTIME_PORT`, single absolute `SHOWTIME_CONNECTION` in `artifacts/` | Share across app & client when another task uses Showtime; new output dirs, desktop unlocked, page visible |
| Motion / Release | Fresh `artifacts/*` dirs; `dist/release-vX.Y.Z/` | Never mix whole-window diagnostic captures into motion acceptance; releases require explicit authorization |

## Retrospective

Record incident narratives in [Retrospective.md](Retrospective.md); promote recurring project constraints to `Invariants` above and enforceable safeguards to tests/hooks.
