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
- **Camera and composition** — Choreograph zoom, movement, and animated titles, including parallel actions. Choose a backdrop, adjust canvas inset, and independently set the browser title and address shown in the recording. Canvas presets and custom sizes support up to 4K (3840 × 2160).
- **Device frames** — Choose from three iPhones, three iPads, a front-facing MacBook, and a 16-inch MacBook Pro with a modern flat chassis, with None as the default. All devices use silver in Light and space black in Dark. Frames define screen proportions and appearance; the webpage fits the screen area on the Canvas. Web content and hardware render at the Export resolution, including 4K.
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
scripts/showtime demo --rehearse
scripts/showtime demo --output artifacts/orbit-launch.mp4
```

Use a new output path for each export; existing files are not overwritten. Recording dimensions must match the canvas aspect ratio.

## Commands

Run these from the repository root. Use `scripts/showtime --help` for the full reference.

| Command | Purpose |
| --- | --- |
| `scripts/showtime status` | Inspect page, camera, cursor, recording, and job state |
| `scripts/showtime open http://localhost:3000` | Open a page; public URLs and `showtime://demo` also work |
| `scripts/showtime inspect` | Get selectors, labels, and coordinates for visible interactive elements |
| `scripts/showtime act '{"action":"click","selector":"#new-project"}'` | Execute one action; this example targets the bundled Orbit page |
| `scripts/showtime run examples/local-product.json --rehearse` | Rehearse a custom script after replacing the sample URL and selectors |
| `scripts/showtime run film.json --output artifacts/film.mp4` | Run and record a script; add `--no-wait` to return a job ID immediately |
| `scripts/showtime job JOB_ID` / `scripts/showtime wait JOB_ID` | Inspect progress or wait for completion |
| `scripts/showtime record start --output artifacts/take.mp4` | Start a manual or API-directed recording; finish with `record stop` |
| `scripts/showtime screenshot artifacts/frame.png` | Save the composed canvas, including camera, cursor, and text |
| `scripts/showtime stop` | Stop the active job and finalize recorded footage |
| `scripts/showtime mcp-config` | Print configuration for an MCP client |

### Connect an agent

Run `scripts/showtime mcp-config` and merge the output into a client that supports MCP stdio. The configuration uses local Python and an absolute script path; session credentials are discovered automatically.

Available tools are `showtime_status`, `showtime_inspect`, `showtime_open`, `showtime_act`, `showtime_run`, `showtime_job`, `showtime_record`, and `showtime_screenshot`. A typical workflow is to inspect elements, plan a script, rehearse, verify the result, and record.

### Write a script

Save this as `film.json` and use the `run` command above:

```json
{
  "version": 1,
  "name": "First take",
  "steps": [
    { "action": "open", "url": "showtime://demo" },
    { "action": "waitFor", "selector": "#new-project" },
    { "action": "move", "selector": "#new-project", "duration": 0.8 },
    { "action": "click", "selector": "#new-project" },
    { "action": "wait", "duration": 1.5 }
  ]
}
```

`caption` does not pause subsequent actions; add `wait` when text needs time on screen. See the [local product script](../examples/local-product.json), [cursor examples](../examples/cursor-styles.json), and [Orbit film](../Sources/Showtime/Resources/Scripts/orbit-launch.json) for fuller examples.

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
```

## Documentation

| Document | Contents |
| --- | --- |
| [中文 README](../README.md) | Chinese usage guide |
| [Example scripts](../examples/) | Local product demos and cursor configuration |
| [Version management](versioning.md) | Version source, synchronization, and release commands; Chinese |
| [Changelog](../CHANGELOG.md) | Changes by version |
| [GitHub Releases](https://github.com/nocoo/showtime/releases) | Published versions |
| [Showtime on Hexly](https://hexly.ai/logos/showtime) | Project overview and icon |

## License

[MIT](../LICENSE) © 2026 NOCOO
