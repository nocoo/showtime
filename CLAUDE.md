# Showtime

Native macOS browser for agent-directed real-web interaction and H.264 demo recording.
Profile: native-hybrid.
Direction: [studio design](docs/studio.md). Frameworks must preserve this handbook.

## Sources of Truth

This file is the quality contract; hooks, CI and config are enforcement. Close implementation gaps without lowering the contract. Historical test results are not evidence of a current passing run.

| Fact | Where |
|---|---|
| Human docs | [README.md](README.md), [English README](docs/README.en.md) |
| Detailed project constraints | [development, validation and release](docs/01-development-release.md) |
| Version | `package.json`; `scripts/version.py` generates Swift/plist metadata |
| Enforcement | `scripts/test.sh`, `.github/workflows/ci.yml`; no installed Git hooks |
| Accidents | [Retrospective.md](Retrospective.md) |
| Machine workflow | global `AGENTS.md` and Git rules |

## Project Invariants

- Preserve genuine WebKit/AppKit input and native window behavior; JavaScript inspects/asserts without replacing clicks.
- Install/update Agent tools only after the explicit AI Director button; normal launch, page entry and copying instructions must not execute Python or change tools, profiles or PATH.
- Use stable user-support-directory CLI/MCP entries, shared schema and bundled skills; no developer paths/credentials in user instructions or bytecode inside signed apps.
- Start with built-in Orbit and never restore a private prior URL. Keep real-site evidence/connection files in ignored `artifacts/`.
- Preserve shared FrameLayout geometry, even/proportional video dimensions, None/Auto defaults, frame themes and transparent overlays; detailed constraints are mandatory in the linked development document.
- Cancellation produces playable partial MP4; report duplicated frames/capture speed honestly. Preserve 4K density and bounded snapshot prefetch.
- Root package.json is metadata only: no root npm/bun install or lockfile. Keep Chinese README and English documentation synchronized for behavior changes.

## Stack / Layout

| Lane | Location / choice |
|---|---|
| Native app / core | `Sources/Showtime`, `Sources/ShowtimeCore`; macOS 14+, Swift 6 tools / Swift 5 mode |
| CLI / MCP | `scripts/showtime`, Python 3.10+ standard library |
| Core checks | `Tests/ShowtimeCoreTests`, standalone `ShowtimeChecks` executable |
| Media / overlay | WebKit, AVFoundation; React dependencies only in `examples/overlay-react` |

## Commands

Run from root with Swift 6/Xcode or Command Line Tools, Python 3.10+, and Node for syntax checks. Media acceptance needs FFmpeg and an unlocked GUI session. Documentation checks must not operate the everyday app.

```bash
scripts/test.sh
python3 scripts/version.py check
scripts/build.sh debug
scripts/showtime --version
python3 scripts/test_integration.py --output-dir artifacts/input-check
python3 scripts/test_workflow.py --output-dir artifacts/workflow-check
SHOWTIME_ARCH=universal scripts/build.sh release
```

## Verification

6DQ = L1/L2/L3 + G1/G2 + D1 (test isolation). Status: `enforced`, `planned`, `manual`, or `N/A`; partial enforcement below does not certify the full required bar.
L1 requires statements, branches, functions and lines each ≥95%, with no skipped/focused tests; preserve any stricter package threshold. Native tools must identify unmeasured metrics as gaps.
G1 requires check-only strict analysis/formatting with zero errors/warnings. G2 requires dependency and secret scans, with missing required scanners failing.

| Dimension | Status | Required proof and current evidence/gap |
|---|---|---|
| L1 Swift / Python | planned | CI runs standalone Swift core checks and guide checks; no four-metric ≥95% coverage gate. |
| L2 local control API | manual | Integration runner exercises real HTTP/auth/input; complete endpoint/method coverage is not enforced. |
| L3 native / CLI / MP4 | manual | Workflow/studio/capture/frame/tool runners are mapped to changes in the development document; inspect actual video frames. |
| G1 Swift / Python / JS | planned | CI checks versions, syntax, Python compilation, JS and builds; zero-warning lint/format remains incomplete. |
| G2 | planned | No automated secret/dependency scanning; bundled tools still require secret review. |
| D1 | manual | Dedicated bundle/port/connection, fresh outputs and serial app interaction are required; isolation is not a complete automated gate. |

CI runs `scripts/test.sh`, a universal release build with explicit ad-hoc signing, and local-preview packaging. It does not run desktop acceptance, personal signing, notarization or publication.

Target hooks: pre-commit checks G1 + L1 against the index snapshot (`git checkout-index`) in <30s; pre-push checks L2 and G2 in parallel against every stdin push ref/commit in <3min, plus build where applicable. L3 runs in CI or an explicit manual lane.
Never bypass commit/push hooks, force-push, or use autofix in checks. Documentation changes do not authorize deploying or implementing new gates.

## Resources / Isolation

Use an independent bundle ID, free `SHOWTIME_PORT`, and one absolute `SHOWTIME_CONNECTION` under ignored artifacts for both app and client when another task uses Showtime. Keep outputs new, desktop unlocked and page visible; restore prior settings. Do not mix whole-window diagnostic captures into motion acceptance.

## Operations / Release

Follow [development/release procedures](docs/01-development-release.md), [versioning](docs/versioning.md) and [signing](docs/signing.md). Preserve explicit versions, real signature/notarization facts, stable installed tools and immutable releases. This documentation task does not authorize release or changes to Hexly.

## Retrospective

Move accident narratives to [Retrospective.md](Retrospective.md); keep at most about ten concise recurring project rules here. Put architecture and operational detail in linked docs.

- Preserve default Orbit startup and the explicit image-loading fix.
- Action completion and encoder FPS do not establish captured visual correctness.
