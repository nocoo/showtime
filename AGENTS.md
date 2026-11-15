# Showtime

Native macOS browser for agent-directed real-web interaction and H.264 demo recording.
Profile: native-hybrid.
Direction: [studio design](docs/studio.md). Frameworks must preserve this handbook.

## Scope and instruction sources

- This file is the only project handbook; nested files do not compete with it. Do not create a `CLAUDE.md` alias or copy.
- This file is the quality contract; hooks, CI and config are enforcement. Close implementation gaps without lowering the contract. Historical test results are not evidence of a current passing run.
- Human docs: [README.md](README.md) and [English README](docs/README.en.md). Detailed constraints: [development, validation and release](docs/01-development-release.md). Version: `package.json`; `scripts/version.py` generates Swift/plist metadata. Enforcement: `scripts/test.sh`, `.github/workflows/ci.yml`; no installed Git hooks. Accidents: [Retrospective.md](Retrospective.md). Machine workflow: global `AGENTS.md` and Git rules.

## Project invariants

- Preserve genuine WebKit/AppKit input and native window behavior; JavaScript inspects/asserts without replacing clicks.
- Install/update Agent tools only after the explicit AI Director button; normal launch, page entry and copying instructions must not execute Python or change tools, profiles or PATH.
- Use stable user-support-directory CLI/MCP entries, shared schema and bundled skills; no developer paths/credentials in user instructions or bytecode inside signed apps.
- Start with built-in Orbit and never restore a private prior URL. Keep real-site evidence/connection files in ignored `artifacts/`.
- Preserve shared FrameLayout geometry, even/proportional video dimensions, None/Auto defaults, frame themes and transparent overlays; detailed constraints are mandatory in the linked development document.
- Cancellation produces playable partial MP4; report duplicated frames/capture speed honestly. Preserve 4K density and bounded snapshot prefetch.
- Root package.json is metadata only: no root npm/bun install or lockfile. Keep Chinese README and English documentation synchronized for behavior changes.

## Setup and commands

Native app/core in `Sources/Showtime` and `Sources/ShowtimeCore` (macOS 14+, Swift 6 tools / Swift 5 mode); CLI/MCP `scripts/showtime` on Python 3.10+ standard library; core checks in `Tests/ShowtimeCoreTests` plus standalone `ShowtimeChecks` executable; media/overlay on WebKit and AVFoundation with React dependencies only in `examples/overlay-react`. Run from root with Swift 6/Xcode or Command Line Tools, Python 3.10+, and Node for syntax checks. Media acceptance needs FFmpeg and an unlocked GUI session. Documentation checks must not operate the everyday app.

```bash
scripts/test.sh
python3 scripts/version.py check
scripts/build.sh debug
scripts/showtime --version
python3 scripts/test_integration.py --output-dir artifacts/input-check
python3 scripts/test_workflow.py --output-dir artifacts/workflow-check
SHOWTIME_ARCH=universal scripts/build.sh release
```

## Testing and quality contract

Quality follows `system1-quality` (12 slots `S1..Z1` in `.github/workflows/quality-slots.yml`, `nocoo/base-ci v2026.15` for pinned actions). Statuses: `impl`, `na`, `manual`, or `planned`.

| Slot | Status | Implementation / Evidence |
| --- | --- | --- |
| S1: Typecheck | impl | `python3 scripts/version.py check`, `node --check Sources/Showtime/Resources/Demo/app.js`, `swift build --package-path .` |
| S2: Lint | na | No dedicated lint gate configured |
| S3: Workflow Lint | impl | `actionlint`, immutable `nocoo/base-ci` SHA check, and `yamllint` |
| G1: Secret Scan | impl | `gitleaks detect --no-banner --verbose --redact --no-git` |
| G2: Dependency Vulnerabilities | impl | `osv-scanner scan --lockfile=examples/overlay-react/bun.lock` |
| B1: Build | impl | `scripts/build.sh release` (universal, ad-hoc signed) and `scripts/package_release.py --local-preview` |
| L1: Unit Tests & Coverage | impl | `bash -n`, `sh -n`, `swift run --package-path . ShowtimeChecks`, `py_compile`, and `scripts/test_guides.py` |
| L2: Runtime | na | Not a Cloudflare Worker project |
| L3: Integration | na (manual) | `scripts/test_integration.py` runs manually against an unlocked GUI session |
| L4: E2E | na (manual) | `scripts/test_workflow.py` and media/capture runners run manually on an unlocked desktop |
| P1: Package Check | na | Native macOS app/SwiftPM package; not published to npm |
| Z1: Gate | impl | Aggregates all 11 slot outcomes and verifies `tested-sha` |

No local Git hooks are installed. CI runs `quality` via `.github/workflows/ci.yml` → `quality-slots.yml`.
Never bypass commit/push hooks, force-push, or use autofix in checks. Documentation changes do not authorize deploying or implementing new gates.

## Resources and isolation

Use an independent bundle ID, free `SHOWTIME_PORT`, and one absolute `SHOWTIME_CONNECTION` under ignored artifacts for both app and client when another task uses Showtime. Keep outputs new, desktop unlocked and page visible; restore prior settings. Do not mix whole-window diagnostic captures into motion acceptance.

## Operations / release

Follow [development/release procedures](docs/01-development-release.md), [versioning](docs/versioning.md) and [signing](docs/signing.md). Preserve explicit versions, real signature/notarization facts, stable installed tools and immutable releases. This documentation task does not authorize release or changes to Hexly.

## Retrospective

Move accident narratives to [Retrospective.md](Retrospective.md); keep at most about ten concise recurring project rules here. Put architecture and operational detail in linked docs.

- Preserve default Orbit startup and the explicit image-loading fix.
- Action completion and encoder FPS do not establish captured visual correctness.
