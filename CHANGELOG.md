# Changelog

## [Unreleased]

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
