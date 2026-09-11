---
name: showtime-project-demo
description: Create or finish narrated project demos with real Showtime webpage recordings, Remotion intro/outro bookends, subtitles, and optional background music. Use for project introduction videos, bilingual demos, 项目演示视频、贴片、配音、配乐, or adding sound to an existing MP4.
---

# Showtime project demo

Tell a useful product story with real website interactions. Showtime captures the webpage;
Remotion renders brand bookends; speech and music are mixed into the final MP4 with FFmpeg.
Showtime itself currently exports silent video. Do not claim it records microphone or system audio.
For an audio-only revision, reuse the approved picture and bookends instead of recording again.

## Collect the missing brief first

Read the conversation, repository README, supplied brand assets, and `showtime status` before
asking. Retain every explicit preference, including later corrections. A pasted generic
45-second Orbit example does not replace the user's actual project or requested duration.

Ask the user about missing dimensions and visual style **before designing or recording**.
Bundle the missing choices into one short brief or at most three focused questions. Offer
the current Showtime settings as a concrete option, rather than silently choosing new ones.
Continue repository research and script planning while awaiting the answers. Do not ask
again about settings the user has supplied or approved, and do not make an audio-only edit
depend on a new visual approval.

| Area | Record in the production brief |
| --- | --- |
| Story | Audience, product purpose, most useful workflow, required features, closing invitation |
| Timing | Total duration **including** intro/outro, number of films, languages |
| Picture | Canvas width/height, export width/height, frame rate, aspect ratio |
| Website fit | `contentWidth` or Auto, device frame, inset when Auto, actual CSS viewport |
| Style | Backdrop, frame Light/Dark, center glow on/off, radius and size, calm or energetic pacing |
| Titles | Caption language/style/placement, subtitles, safe margins, typography |
| Brand | Approved logos, exact intro/outro names and URL, backgrounds, motion reference, lengths |
| Website | Actual capture URL, displayed URL if explicitly requested, login/demo data, allowed actions |
| Voice | Narration on/off, language/accent, voice preference, tone/rate, existing speech to preserve |
| Music | On/off, supplied or freely licensed track, mood, vocals/no vocals, intensity, attribution requirements |
| Delivery | New output folder/filenames, reusable source, archive location, Git/media policy |

Suggested intake wording: “I have the project and languages. Should I keep the current
4K/30 fps Canvas and device frame? What intro/outro branding and background would you like?
For sound, do you want narration, background music, or both?” Omit questions already answered.
Do not use this example's dimensions as defaults without the user's brief.

If the user says “配音” for a film that already contains speech, inspect the audio stream and
clarify whether they want replacement narration or background music. Preserve existing valid
speech while preparing the optional music; never stack two narrators by accident.

## Connect to the current Showtime tools

Use `showtime_help(topic: "workflow")` and `showtime_help(topic: "project-demo")` when MCP is
available. Query `script`, `camera`, `caption`, and each action's current schema. Otherwise:

```sh
export PATH="$HOME/Library/Application Support/Showtime/bin:$PATH"
showtime status
showtime guide
showtime guide project-demo
showtime schema script
showtime schema camera
showtime schema caption
```

The project-demo guide is bundled with the CLI/MCP tools and works without a source checkout.
The app's **AI Director → Agent integration → Install / Update tools** button installs updates.
Do not copy tools into a signed app, silently replace installed tools, change shell profiles,
or use an old CLI path from a downloaded artifact. An older installed tool may not have the
`project-demo` topic yet; read this skill directly while using that installation's actual
`guide`/`schema`. A source checkout can exercise its own `scripts/showtime` during development.
Reading either guide does not require a running app or install dependencies.

Keep Showtime open, foreground, and the macOS session unlocked during webpage playback.
`ready: true` alone does not establish that WebKit is visible or its entrance animations ran.
Use Theater for the take. Save status/settings and the resolved viewport in the production.

## Write the story and production files

Explain the product from evidence in its README and implementation. Record the source commit
and supporting paths for feature claims. Use a clear opening, three to five main moments,
and an invitation. Group small secondary features into a short supporting scene.
Show the result and the method behind it; avoid claims that the capture does not demonstrate.
An upload button is not evidence that a large upload completed.

Create a timestamped production inside the target project, separate from Showtime's application
dependencies. Keep `brief.json`, `story.json`, `run.json`, `films/`, `bookends/`, `scripts/`,
`public/audio/`, `process/`, and `verification/` together. Use a new run or checkpoint for a
meaningful revision. Existing reviewed media must never be overwritten.

Plan the full timeline before recording. For example, a **requested** one-minute film may
allocate 2 seconds to the intro, 54 to the website, and 4 to the outro. Bookend lengths,
scene boundaries, speech slots, subtitle times, and music cues use this same final timeline.
Translate for natural speech rather than equal word counts. Generate and measure the speech
before locking website timing; shorten copy or adjust scene allocation when it overruns.

## Design, rehearse, and capture the real site

1. Open the actual website and `inspect` visible controls before choosing selectors. Read
   current schemas; use native `move`, `click`, `scroll`, `type`, and `key` for interactions.
   Demo setup and repeated submissions can have real side effects. Use the authorized demo
   workspace and retain the IDs of examples this production creates.
2. Preview individual `design` actions and composed screenshots. Set the agreed Canvas,
   content width, frame, backdrop and glow. Re-inspect after layout changes. MacBook Pro is
   a visual frame, not browser/device emulation. Fixed content width overrides Auto inset
   fitting; export resolution and webpage CSS viewport are different measurements.
3. Write JSON with `version: 1`, `name`, `canvas`, `recording`, `setup`, and `steps`. Preserve
   agreed settings exactly. Give scenes `marker` actions, short labels, and unique nonnumeric
   IDs. `setup` runs before each selected range, outside the movie; skipped earlier steps
   are not replayed. Make its navigation and preparation repeatable.
4. Use deliberate cursor moves, real arrow/hand or a focus ring, and click feedback. Use
   short camera moves to guide attention, then hold still long enough to read. Camera targets
   are original untransformed CSS coordinates. Set scale and offsets together; omitted camera
   fields persist. Device frames and captions stay outside the webpage camera transform.
5. Caption duration does not pause playback. Add explicit waits. `parallel` may combine one
   camera track, one move, one caption, and waits. Keep all actions, waits and transitions in
   the JSON so agent round trips cannot create timing gaps. Use `waitFor` and `assert` for
   actual page responses instead of relying only on fixed delays.

```sh
showtime validate films/demo.json
showtime rehearse films/demo.json --from discovery --to discovery-end
showtime rehearse films/demo.json --screenshot /ABSOLUTE/NEW/rehearsal.png
showtime validate films/demo.json --mode record --output /ABSOLUTE/NEW/raw.mp4
showtime record films/demo.json --output /ABSOLUTE/NEW/raw.mp4 --no-wait
showtime job JOB_ID
```

Wait for `completed` and retain the full job JSON. MCP record/rehearse returns a job by default;
use `showtime_job`. Ranges include both endpoints and refer to steps/IDs, not timecodes.
During playback use status/job queries, composed screenshots, or stop. Do not send live design
or settings edits. A stopped job may have a playable partial movie; it is not a completed take.

Lessons from real captures:

- Recheck route and visible content after filtering/navigation. Reset the camera and inspect
  again if a transient menu or native click becomes unreliable; do not replace clicks with JS.
- A returned scroll action may precede the final scroll position. Add a short scripted settle
  before a consequential button, then assert the resulting state.
- Prefer a production build or the site's native “hide development tools” setting. If a local
  development overlay resets, a documented, temporary stylesheet may hide **only that chrome**.
  Do not hide product errors, remove business content, or change the app just to fake a demo.
- Record `effectiveCaptureFPS`, `capturedFrames`, and `duplicatedFrames`. A 30 fps encoded
  timeline can contain repeated captures. Inspect actual motion and disclose material limits.
- Avoid full Studio diagnostic screenshots during a timing-sensitive take; they can delay
  capture. Inspect representative frames decoded from the finished MP4 as well as previews.

For small page-response drift, conform scenes individually to the planned timeline using
measured scene clocks or verified edit boundaries. Save the alignment and reject large speed
changes; a useful starting tolerance is 0.9–1.2× for picture only. Never stretch speech to hide
an incomplete or badly timed take. Exact-duration films need integer frame counts.

## Render the Remotion bookends

Use a separate small Remotion project with a pinned lockfile; do not add Node dependencies to
Showtime's root package. Keep every Remotion package on the same version. A verified baseline
is Remotion / `@remotion/cli` 4.0.520, React 19.2.3, and TypeScript 5.9.3.
Use approved local SVG/raster logos and local fonts with recorded source URLs and hashes.
Load assets with `staticFile`, images with `Img`, and await font readiness with
`delayRender` / `continueRender`; failed font loads must fail the render.

Create `Intro` and `Outro` compositions matching the final export dimensions and fps.
Derive motion from `useCurrentFrame()` and `useVideoConfig()`, not wall-clock time, CSS
animation, or unseeded randomness. Work in a centered logical 1920 × 1080 layout and scale
with `Math.min(width / 1920, height / 1080)` for a matching landscape direction; deliberately
recompose for portrait/square instead of cropping the logo and title.

The restrained bookend recipe is a small upward reveal, slight scale, staggered opacity,
and a clean hold. The tested reference uses `Easing.bezier(0.22, 1, 0.36, 1)` and a clamped
spring (`damping: 24`, `stiffness: 115`, `mass: 1`, `overshootClamping: true`). If reusing cues
authored at 24 fps, evaluate their local reference frame as `frame * 24 / fps`.

| Cue | Reference frames at 24 fps | Appearance |
| --- | --- | --- |
| Intro logo | 1–10 fade; spring starts at 1 | Rise 28 logical px; scale 0.90 → 1 |
| Intro name | 5–18 | Rise 22 px, reveal |
| Intro URL | 11–24 | Rise 12 px, reveal |
| Outro logo | 5–30 | Rise 16 px; scale 0.94 → 1 |
| Outro name | 11–36 | Rise 16 px, reveal; hold through final frame |

Keep the user's exact brand text. Microsoft Teams is an optional requested closing identity,
not a default sponsor for every product. Use its unchanged official logo only when requested.
For a pure-white outro, paint an opaque `#FFFFFF` full canvas, without residual Sky tint,
vignette or center glow. Finish the voice early enough to leave a clean closing hold.

To match Showtime **Sky**, reproduce its background in sRGB with an SVG diagonal gradient
from `(0,0)` to `(width,height)`: `#D5E5EE` at 0, `#ECF3F6` at 0.55, `#CEDFEA` at 1. Overlay
a white radial gradient centered at `(0.75 * width, 0)`, radius `0.65 * width`, opacity 0.4 → 0.
This Sky highlight is distinct from the optional Canvas center glow. When that glow is also
requested, match the current Showtime compositor or an inspected reference; do not guess its
geometry from the UI percentages. Check current `SceneCompositor.swift` when updating this recipe.

Render a first/settled/last frame and a short motion sample before the full bookends:

```sh
# Inside the independent bookend project, after installing its pinned dependencies.
bunx remotion still src/index.tsx Intro /ABSOLUTE/NEW/intro-frame.png --frame=40
bunx remotion render src/index.tsx Intro /ABSOLUTE/NEW/intro.mp4 --codec=h264 --pixel-format=yuv420p
bunx remotion render src/index.tsx Outro /ABSOLUTE/NEW/outro.mp4 --codec=h264 --pixel-format=yuv420p
```

Check output paths first and retain earlier renders. Use the same props for stills and video.
Match fps, dimensions, pixel format, color range and BT.709 metadata across bookends and footage
before joining them; flatten transparent bookends over the intended background.

## Narration and subtitles

Treat **voice**, **music**, and optional sound effects as separate stems. Probe an existing MP4
before choosing an operation. Preserve approved speech for a music-only revision; replacement
speech must replace the old narration track. If speech and music are already mixed and no
stems exist, describe that limitation instead of promising lossless voice separation.

Use the user's supplied voice/provider first. Otherwise offer a natural Microsoft neural voice:
`zh-CN-XiaoxiaoNeural` (a starting rate of +4%, pitch +1 Hz) or `en-US-JennyNeural` (+0%, +0 Hz).
These are selectable examples, not mandatory voices. Microsoft speech through pinned
`edge-tts==7.2.8` is a practical option when available; do not send confidential scripts to an
unapproved external service. Keep provider failures visible and retain valid cached speech.

For each scene, save the exact text, voice, rate, pitch, audio, measured duration, sentence
boundaries, and a hash of the request. A cache is reusable only when all match. Stream into a
temporary file and promote it only after success; measure with ffprobe. Retry transient errors
with a bounded backoff. Keep the audio and boundary timing together, in seconds on the final
timeline. Leave room for sentence endings rather than speaking right up to each cut.

Use `edge_tts.Communicate(text=..., voice=..., rate=..., pitch=..., boundary="SentenceBoundary")`
in a small production script when accurate per-scene timing is needed. Boundary offsets are
100-nanosecond units: divide by 10,000,000. Translate them by each scene's final start time,
clamp small overlaps, and reject speech that exceeds its slot. Generate SRT/VTT from those
measured boundaries. Keep short visual captions separate from full narration subtitles.

Render subtitles with local fonts. If FFmpeg lacks libass/drawtext, render caption PNGs or an
alpha MOV with Chrome/Remotion, then overlay it in a safe region outside the device frame.
Verify glyphs, line wrapping, contrast, and the beginning/end of each sentence at full size.
Offer a sidecar SRT and optionally an embedded `mov_text` track. Do not replace useful titles
with a wall of spoken text. An audio-only revision can retain existing burned subtitles
only when the narration words and timings are unchanged.

## Background music and mastering

When requested, choose music for the brief: for a calm product film, start with an instrumental
ambient/piano/celesta bed, sparse percussion, and no vocals competing with speech. Prefer a supplied
track or search for an existing freely licensed recording. Compose or generate music only when
the user explicitly requests that option. “Find music” does not authorize composing a substitute.
For an openly licensed track, prefer CC0 or CC BY when it fits the intended use; preserve the
actual license and any attribution. Record title, author
or generator, source/license/attribution where applicable, file hash, edit, and cue times.
Do not infer reuse rights from a download button. A synthesized score must be identified as
such rather than described as a licensed recording or a human performance.

Fit the score to the **whole film**, including bookends. Give the opening room, make any
transition accents restrained, and resolve/fade naturally at the outro. Avoid abrupt looping
or an ending cut mid-note. Keep the WAV music master, a listening copy, and its source/MIDI/
generation script. Never add default music when the user has chosen silence.

Mix speech prominently, usually with music 14–20 dB below active speech as a starting point.
Measure the stems; a track's file volume alone is not a useful balance. Fade music in/out and
optionally duck it with a sidechain compressor keyed by the clean narration. Keep a nonzero
music floor and a slow release so brief pauses do not pump. Inspect/listen to the opening,
dense speech, transitions, and closing. Numerical loudness checks do not establish pronunciation
or taste; never label them a human listening review.

Use FFmpeg from a reproducible production script with argument arrays, `-n`, and fresh output
paths. For picture edits, join the checked intro, website footage and outro, then overlay
subtitles and add timed voice. For an audio-only revision, `-c:v copy` preserves the approved
video without another encode; preserve optional subtitle streams too (`-map 0:s? -c:s copy`).
Do not accidentally mix the source's existing speech twice.

An audio graph typically resamples stems to 48 kHz stereo, aligns speech to scene starts,
pads/trims to final duration, applies music gain/fades/ducking, then uses
`amix=inputs=2:normalize=0`. Master the combined mix with **two-pass** `loudnorm`, using measured
I/TP/LRA/threshold and offset in the second pass; a useful target is −16 LUFS with a −1.5 dBTP
ceiling. Re-measure the encoded AAC, since encoding can alter the true peak. Export H.264
`yuv420p`, AAC 48 kHz stereo and `+faststart`, with even dimensions matching Canvas aspect ratio.

Do not hardcode 60 seconds, 4K, or eight scenes into a reusable helper. Read the accepted brief
and actual media duration. Preserve voice speed. Keep the exact filter graph, FFmpeg commands,
normalization measurements, stream probes, input/output hashes and the selected Showtime job.

## Verify, archive, and deliver

Require a completed recording job before treating a new capture as final. Verify codec,
dimensions, fps, frame count/duration, audible stream presence, subtitle tracks, and full
audio/video decode. For audio-only changes, compare video packet hashes or decoded frame
hashes with the input so unchanged picture is established, not assumed.

Inspect representative final frames, captions, every scene transition, and the closing color.
Play the exported MP4 in a real browser/player, seek to chapters and verify sound/subtitles
and downloads. Check voice/music balance with an actual listening review where supported,
and state which audio checks were numerical only. Do not count stale reports from another
movie hash as verification of this output. Audio-only work need not repeat unrelated UI tests.

Keep source, scripts, timing, speech caches, music stems, raw captures, prior masters, and
verification together in the agreed timestamped archive. An interruption should resume from
`run.json` and the last completed job, rather than discard the whole production. Store secrets,
connection files, and private website captures outside public source. In Showtime's repository,
use ignored `artifacts/` for actual customer films; public examples use Orbit or localhost.

When the user asks for source in Git, stage only the authorized production source and reports;
ignore MP4/MOV, audio, screenshots, downloaded fonts and dependency caches. Preserve these
ignored resources in the local archive. Inspect staged paths and sizes, run relevant checks,
and use normal hooks. A video task alone does not authorize an app release or deployment.

Return the verified new MP4(s), reusable Showtime JSON, the story/transcript, this skill or its
source location, and a concise description of actual checks. Mention retained speech, chosen
music and any material recording limitation. Complete the authorized export before handing back.
