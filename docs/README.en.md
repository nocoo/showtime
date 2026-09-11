<p align="center">
  <img src="../logo-readme.png" width="128" height="128" alt="Showtime black-and-white clapperboard icon" />
</p>
<h1 align="center">Showtime</h1>
<p align="center"><strong>A native macOS browser for agent-directed product demo recordings.</strong><br>Interact with real webpages · Choreograph cameras and cursors · Export MP4</p>
<p align="center"><a href="../README.md">简体中文</a></p>
<p align="center">
  <img src="https://img.shields.io/badge/macOS-14%2B-222222?logo=apple&logoColor=white" alt="macOS 14+" />
  <img src="https://img.shields.io/badge/Swift-6-F05138?logo=swift&logoColor=white" alt="Swift 6" />
  <img src="https://img.shields.io/badge/SwiftUI-007AFF?logo=swift&logoColor=white" alt="SwiftUI" />
  <a href="https://github.com/nocoo/showtime/actions/workflows/ci.yml"><img src="https://github.com/nocoo/showtime/actions/workflows/ci.yml/badge.svg" alt="macOS build" /></a>
  <a href="../LICENSE"><img src="https://img.shields.io/badge/License-MIT-4A8234" alt="MIT License" /></a>
</p>

---

## What is this?

Showtime turns real webpages, mouse interactions, camera movement, and animated text into repeatable product demonstrations. Work in the native macOS studio or let an agent inspect pages and direct interactions through the CLI or MCP, then record the composed result as MP4.

Pages run in WebKit. Recordings include the browser frame, backdrop, presentation cursor, and text. An interactive Orbit demo website and a complete launch script are included. Current exports have no audio track.

## Features

- **Real webpage interaction** — Open public sites or local development pages. Move, click, double-click, drag, scroll, and type using CSS selectors or coordinates; wait for elements and check page state.
- **Camera and composition** — Combine close-up and offsets with the Camera pad, then animate them together in scripts. Choreograph titles and parallel actions. Nine backdrops retain the original green and add presentation gray, pale candy colors, and an adjustable central glow. Canvas supports up to 4K (3840 × 2160); compact browser controls provide Back, Forward, and Stop loading.
- **Device frames** — Choose iPhone 16 Pro / Pro Max, iPad Pro 11 / 13-inch, or MacBook Neo and MacBook Pro frames redrawn from the 2026 designs, with None as the default. Light uses silver; Dark uses indigo on Neo and space black on other devices. Set Content width to size the screen independently and center the device with more space around it, or keep Auto to fit the Canvas. Web content and hardware render at the Export resolution, including 4K.
- **Presentation cursors** — Use macOS arrow and hand artwork, a ring, dot, spotlight, or a custom PNG. Adjust size, color, hotspot, and click effects.
- **Repeatable scripts** — Save actions as JSON, rehearse, then record. Jobs report progress and individual cue results, support asynchronous execution, and can be stopped early.
- **Recording and stills** — Export H.264 MP4 or a PNG of the composed canvas. Choose 24, 30, or 60 fps; the default is 1920 × 1080 at 30 fps. Stopping a recording finalizes a playable partial take.
- **Agent access** — A Python CLI and MCP stdio server share the local control API, with no third-party Python dependencies. Agents can inspect elements before performing actions with selectors.

## Installation

Download the universal DMG from [GitHub Releases](https://github.com/nocoo/showtime/releases/latest), open it, and drag `Showtime.app` into Applications. A ZIP archive is also available. The app supports macOS 14+ on Apple Silicon and Intel; browsing and recording require neither Xcode nor source code.

This release uses ad-hoc signing and is not notarized by Apple. If macOS blocks the first launch, try opening the app, then confirm **System Settings → Privacy & Security → Open Anyway**. You can also run:

```sh
xattr -dr com.apple.quarantine "/Applications/Showtime.app"
open "/Applications/Showtime.app"
```

Replace the path if installed elsewhere; prefix `xattr` with `sudo` if permissions require it. This only removes this app's download quarantine flag; it does not add Apple signing or notarization.

For CLI / MCP access, use **AI Director → Agent integration → Install tools**. Python 3.10+ is required for these optional tools; the app offers download and setup guidance. After installation, add the tools to the current terminal session:

```sh
export PATH="$HOME/Library/Application Support/Showtime/bin:$PATH"
showtime status
showtime mcp-config
```

The entry point remains stable when the app moves. After upgrading, click **Update tools** if prompted. Normal launches and copying a director brief never install tools automatically.

### Build from source

Source builds need Swift 6 / Xcode Command Line Tools and Python 3.10+. If developer tools are missing, run `xcode-select --install` first.

```sh
git clone https://github.com/nocoo/showtime.git
cd showtime
scripts/run.sh
```

The script builds and opens `dist/Showtime.app`. Keep the app running when using the CLI or MCP. Rehearse the bundled Orbit script, then export your first demo:

```sh
showtime example > film.json
showtime validate film.json
showtime rehearse film.json
showtime record film.json --output ~/Movies/Showtime/orbit-launch.mp4
```

Use a new output path for each export; existing files are not overwritten. Recording dimensions must match the canvas aspect ratio.

## Commands

After the PATH setup above, run these from any directory. Use `showtime --help` for command options and `showtime schema` for the action grammar.

| Command | Purpose |
| --- | --- |
| `showtime guide` / `showtime schema camera` | Read the bundled skill, workflow, and exact JSON syntax |
| `showtime example` | Print an editable Orbit script |
| `showtime status` | Inspect page, camera, cursor, recording, and job state |
| `showtime design '{"action":"open","url":"http://localhost:3000"}'` | Open a page during design; public URLs and `showtime://demo` also work |
| `showtime inspect` | Get selectors, labels, and coordinates for visible interactive elements |
| `showtime settings --frame iphone-16-pro --content-width 400` | Set the frame and its inner screen width; use `auto` to fit |
| `showtime design '{"action":"caption","text":"Hello"}' --screenshot /tmp/preview-new.png` | Preview one action and capture the result |
| `showtime validate film.json` | Preflight the whole script and selected range |
| `showtime rehearse film.json --from feature --to closing` | Rehearse an inclusive range of step IDs or one-based numbers |
| `showtime record film.json --output ~/Movies/Showtime/film.mp4` | Run and record a script; add `--no-wait` to return a job ID immediately |
| `showtime job JOB_ID` / `showtime wait JOB_ID` | Inspect progress or wait for completion |
| `showtime screenshot /tmp/frame-new.png` | Save the composed canvas, including camera, cursor, and text |
| `showtime stop` | Cancel the active job and finalize recorded footage |
| `showtime mcp-config` / `showtime mcp` | Print MCP configuration or start the stdio bridge |

Design uses individual actions and screenshots. Rehearsal and recording execute prewritten JSON scripts locally, including all waits and transitions. Model thinking and network round trips do not interrupt playback. Design, script `setup`, and script `steps` share the same action objects. Design captions remain visible for inspection; playback captions expire after their duration. Camera actions support zooming in and out, translation, rotation, and horizontal/vertical mirroring.

### Connect an agent

Run `showtime mcp-config` and merge the output into a client that supports MCP stdio. The configuration invokes the stable `~/Library/Application Support/Showtime/bin/showtime` entry point through `/bin/sh`, which expands HOME. Session credentials are discovered automatically; source and App paths are unnecessary.

Available tools are `showtime_help`, `showtime_status`, `showtime_inspect`, `showtime_settings`, `showtime_studio`, `showtime_design`, `showtime_validate`, `showtime_rehearse`, `showtime_record`, `showtime_job`, `showtime_stop`, and `showtime_screenshot`. Start with `showtime_help`; `topic: "script"` or an action name returns its schema.

AI Director's **Copy instructions for your agent** includes the creative brief, current settings, connection instructions, syntax discovery commands, and the complete [bundled skill](../skills/showtime/SKILL.md). The Agent can start without locating a source checkout.

### Write a script

Save this as `film.json`, then use `showtime rehearse film.json` and `showtime record film.json --output /tmp/first-take-new.mp4`:

```json
{
  "version": 1,
  "name": "First take",
  "setup": [
    { "action": "open", "url": "showtime://demo" },
    { "action": "waitFor", "selector": "#new-project" }
  ],
  "steps": [
    { "id": "feature", "action": "move", "selector": "#new-project", "duration": 0.8 },
    { "action": "click", "selector": "#new-project" },
    { "id": "closing", "action": "wait", "duration": 1.5 }
  ]
}
```

Playback resets visual effects and runs `setup` before every selected range, outside the MP4. Ranges select steps, not video timecodes; skipped steps are never implicitly replayed. Put required page state in setup. `caption` does not pause subsequent actions; add `wait` when text needs time on screen. See the [local product script](../examples/local-product.json), [cursor examples](../examples/cursor-styles.json), and [Orbit film](../Sources/Showtime/Resources/Scripts/orbit-launch.json) for fuller examples.

## Project structure

```text
Sources/
├── Showtime/               # Native studio, browser, director, and recorder
│   └── Resources/          # Orbit website and bundled scripts
└── ShowtimeCore/           # Script models, validation, and HTTP protocol
scripts/                    # Build, CLI, MCP, and verification tools
examples/                   # Custom scripts and cursor examples
Tests/ShowtimeCoreTests/     # Standalone Swift checks
docs/                       # English README and version management
```

## Technology

| Layer | Technology |
| --- | --- |
| Native interface and input | [SwiftUI](https://developer.apple.com/xcode/swiftui/), [AppKit](https://developer.apple.com/documentation/appkit) |
| Real webpages | [WebKit](https://webkit.org/) |
| Video composition and export | [AVFoundation](https://developer.apple.com/av-foundation/) |
| Scripts and application build | [Swift](https://www.swift.org/), [Swift Package Manager](https://www.swift.org/documentation/package-manager/) |
| Agent interfaces | [Python](https://www.python.org/) standard library, [MCP](https://modelcontextprotocol.io/), local HTTP |

## Development

Swift Package Manager builds the project. Root `package.json` only stores version metadata and shortcuts; no Node dependency installation is needed. In addition to the installation requirements, tests need Node.js to check the bundled website's JavaScript syntax.

| Command | Purpose |
| --- | --- |
| `scripts/run.sh` | Build the Debug app and open the studio |
| `scripts/build.sh release` | Build the Release app at `dist/Showtime.app` |
| `scripts/test.sh` | Check version consistency, core behavior, and Python / JavaScript syntax |
| `python3 scripts/version.py check` | Verify generated version files |

## Testing

| Layer | Coverage | Execution |
| --- | --- | --- |
| Core checks | Script models, action validation, and HTTP protocol | `scripts/test.sh`, also run in CI |
| Build and syntax | Native app build, Python, and bundled website JavaScript | macOS CI |
| Native integration | Webpage input, cursors, zoom, authentication, job conflicts, and partial MP4 finalization | Run manually in a logged-in macOS desktop session |

Native integration checks need Showtime open with no recording or rehearsal in progress. They interact with the bundled demo page:

```sh
python3 scripts/test_integration.py
python3 scripts/test_workflow.py
```

## Documentation

| Document | Contents |
| --- | --- |
| [中文 README](../README.md) | Chinese usage guide |
| [Example scripts](../examples/) | Local product demos and cursor configuration |
| [Bundled skill](../skills/showtime/SKILL.md) | Design, script authoring, range playback, progress, and syntax discovery |
| [Project demo skill](../skills/showtime-project-demo/SKILL.md) | Brief intake, Remotion bookends, narration, subtitles, music, and verification; `showtime guide project-demo` |
| [Version management](versioning.md) | Version source, synchronization, and release commands; Chinese |
| [Changelog](../CHANGELOG.md) | Changes by version |
| [GitHub Releases](https://github.com/nocoo/showtime/releases) | Published versions |
| [Showtime on Hexly](https://hexly.ai/logos/showtime) | Project overview and icon |

## License

[MIT](../LICENSE) © 2026 NOCOO
