# Changelog

## [Unreleased]

- Add transparent HTML/React animation overlays driven by the CLI/MCP `overlay` action, with source loading, props, frame callbacks, timed hiding, setup preloading, and parallel tracks. Preserve native webpage clicks and keyboard focus; composite the same layer in previews, PNGs, and full-resolution MP4s. Include a bundled-React example, authoring guides, and native/video integration checks.
- Add a project-demo skill for collecting missing creative settings, producing Remotion bookends, timing narration/subtitles, and mixing optional music while preserving approved footage. Expose it through `showtime guide project-demo` and the MCP help topic, and include it in explicit agent-tool installation and package validation.
- Clarify audio-only demo edits: reuse existing media without capture prerequisites, explicitly map video/audio/subtitle streams, and preserve the source video format and timing.

## [1.4.0] - 2026-09-11

- Separate Agent design previews from locally executed rehearsal and recording scripts. Share one action grammar across CLI, MCP, setup, and timed steps; replace public live recording commands with script playback.
- Add explicit setup and inclusive playback ranges by original step number or ID, whole-script preflight, stable playback controls, and job feedback with setup position, current action, errors, screenshots, and capture statistics.
- Add camera zoom-out, translation, rotation, and horizontal/vertical mirroring, sharing preview, export, and inverse input transforms. Hold design captions for screenshot review while preserving timed playback captions.
- Bundle a Showtime directing skill and discoverable action schemas, include them in one-click Agent instructions and explicit tool updates, and document the new workflow with native CLI/MCP and video tests.
- Add compact Back, Forward, and Stop loading controls with native history and loading states, matching menu shortcuts, and reliable fragment navigation and load cancellation.
- Preserve the original backdrops and add presentation gray and five pale candy colors. Add optional central glow with adjustable falloff radius and core size, shared by preview and export and exposed through scripts, CLI, MCP, and the bundled skill.
- Add a keyboard-accessible Camera offset pad alongside close-up, using the same combined, animated scale and translation as script playback.
- Simplify capture preset menus and recording controls and derive storyboard names from the loaded script.
- Use standard JSON encoding and copying, remove unused Orbit icons, styles, and overlay state, and consolidate short-window layout rules.

## [1.3.4] - 2026-09-10

- Replace the generic MacBook and older Pro drawing with 2026 MacBook Neo and 16-inch MacBook Pro geometry, including updated screen proportions, rounded upper screen corners, sculpted front lips, feet, and an uninterrupted 16:10 Pro screen. Remove the old lower-bezel wordmarks and use indigo for the dark Neo finish.
- Remove iPhone SE and iPad mini from Studio, CLI, and MCP choices. Migrate their saved names to iPhone 16 Pro and iPad Pro 11-inch, and `macbook` to `macbook-neo`, while preserving capture settings.
- Add Content width to Frame settings, scripts, CLI, and MCP. Set an exact inner screen width with a centered device and proportional height; None follows the Canvas ratio. Preserve existing layouts with Auto and keep export capture density independent of content size.
- Show and validate the maximum content width against the full device and Canvas, reject sizes that do not fit, and apply inset only in Auto mode. Save the chosen width and include it in AI Director instructions.

## [1.3.3] - 2026-09-10

- Make LIVE and ON AIR prominent uppercase broadcast badges with a lit indicator and stronger contrast in both Studio themes.
- Center the Stop Take button's icon and text vertically with an explicit, consistently sized layout.
- Add a 4K Canvas preset and raise custom Canvas limits to 3840 × 2160 across Studio, scripts, and MCP.
- Add a 16-inch, 16:10 MacBook Pro frame with a modern flat chassis, small corner radii, and a centered lower-bezel wordmark, without a notch or browser title bar.
- Apply Light silver and Dark space-black finishes to all device frames, including metal rims, side buttons, and laptop bases, consistently in preview and export.
- Use device geometry only for proportions and fit the webpage viewport to the Canvas screen area, removing fixed device-resolution limits. Keep live input, camera, and exported content aligned.
- Capture WebKit content at Export pixel density, including camera zoom, and render browser chrome at the required output scale for sharp 4K composition.
- Use regular San Francisco lettering for MacBook and MacBook Pro wordmarks and center their visible glyphs within the lower bezel.
- Composite video content into encoder buffers off the main thread and overlap one pending WebKit capture with rendering, preserving full export resolution and frame-specific effects.
- Use Core Animation for preview zoom, continuous native scroll gestures, and a steady animation cadence. Reserve cue text space so Theater does not resize between short and long descriptions.
- Include effectiveCaptureFPS in recording results alongside captured and duplicated frame counts.

## [1.3.0] - 2026-09-10

- Add an optional Frame inspector with three iPhones, three iPads, and a front-facing MacBook. Devices set a real responsive WebKit viewport while preserving Canvas and video dimensions; hardware, safe areas, camera, and pointer positions match Live Preview and exported PNG/MP4.
- Keep None as the default and preserve older JSON scripts. Expose device selection through CLI, MCP, capture settings, and the AI Director brief.
- Adapt the bundled Orbit site to phone and tablet viewports and add native device/input/video checks.
- Add optional CLI / MCP installation and updates in AI Director, with an explicit Python check and download guidance. Opening the app or copying a brief never installs tools or launches dependency installers.
- Use a stable per-user CLI, add `showtime mcp`, and make agent instructions and MCP configuration independent of developer paths, temporary downloads, and the app's install location. Find an existing Python 3.10+ even with a minimal GUI PATH, without invoking Apple's installer shim.

## [1.2.1] - 2026-09-10

- Start every launch on the bundled Orbit demo, remove the old website restore preference, and stop saving visited URLs for the next launch.
- Remove developer-specific website addresses from public examples and testing instructions.
- Add a native startup check for old preferences, Orbit interaction, and reopening after visiting another page.
- Include per-app quarantine removal commands in README installation, signing, and release instructions.

## [1.2.0] - 2026-09-10

- Redesigned the green Studio with a unified native toolbar, simpler header, larger controls, and icon-led settings.
- Kept native traffic lights, titlebar double-click behavior, minimize, zoom, full screen, and window restoration.
- Increased the default window by 20% to 1872 × 1248 pt, centered on launch and fitted to the current screen's usable area.
- Added an animated sidebar toggle beside the wordmark and Theater mode for a larger preview.
- Made Rehearse and Record distinct, single-line buttons and removed the redundant Director sidebar heading.
- Applied the approved black-and-white clapperboard identity to the toolbar and macOS app icon, with transparent and green README masters in the repository root.
- Added agent window controls and full Studio screenshots, including the native toolbar; overlapping full-screen operations are rejected until AppKit finishes its animation.
- Added a prominent real-website entry point. Record captures the current page; storyboard recording is an explicit action, and the Orbit example is loaded on request.
- Added persistent Canvas presets/custom dimensions, video resolution, and 24/30/60 fps controls, shared by the UI, CLI, and MCP. Canvas changes fit the output aspect ratio; invalid settings leave the session unchanged.
- Set new-session Canvas size to 1920 × 1080 and center the camera on the actual page dimensions, including restored and scripted canvases.
- Organized the sidebar in filming order: Canvas, Cursor, Text, then Export.
- Added independent light/dark Studio and browser title bar themes, a more compact 56 px browser header, and consistent 38 pt dropdown, input, button, and segmented controls.
- Simplified the film browser to a site icon, title, address, and reload control. Page favicons appear in both the preview and exported video, with a globe fallback.
- Added an illustrated AI Director page with an editable brief and one-click agent instructions that include the current website and capture settings.
- Added live Theater cue cards with scene names, current/next actions, progress, and export completion, plus animated window-level notifications with safe replacement and dismissal timing.
- Standardized local builds on Apple Development signing with a stable team and bundle identifier; CI uses an explicit temporary signing override. Builds verify their signatures and signing team instead of silently falling back.
- Added universal Apple Silicon / Intel builds, self-contained app packaging, CLI version reporting, and a release archive pipeline that verifies resources, signatures, notarization, stapling, Gatekeeper, and SHA-256.
- Documented development, testing, versioning, signing, and GitHub binary release procedures in CLAUDE.md.

## [1.0.0] - 2026-09-10

- Native SwiftUI demo browser with a real WebKit page and optional title/address overrides.
- Agent control through loopback HTTP, CLI, and MCP; repeatable JSON storyboards and H.264 MP4 export.
- Native pointer input, system and custom cursor styles, camera zoom, and animated captions.
- Fresh grass green studio theme, larger typography, neutral browser chrome, and a visible app version.
- Interactive Orbit demo website and complete product launch film script.
