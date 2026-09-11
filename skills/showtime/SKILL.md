---
name: showtime
description: Design webpage films in the Showtime macOS app, then rehearse and record JSON scripts through its CLI or MCP tools. Use for Showtime page inspection, visual previews, script authoring, partial playback, and MP4 export.
---

# Showtime

Use two phases: explore the design with individual actions and screenshots, then run a written script for rehearsal and recording. The App executes every script action and wait locally, so model thinking and Agent round trips do not insert gaps. Webpage loads and responses can still vary; use waitFor and assert for those conditions.

## Connect and discover syntax

Keep Showtime open. If its MCP tools are available, use `showtime_help` with `topic: "workflow"`, `"script"`, or an action name. Otherwise, after the user has installed the bundled tools in AI Director:

```sh
export PATH="$HOME/Library/Application Support/Showtime/bin:$PATH"
showtime status
showtime guide
showtime schema caption
showtime schema camera
showtime schema script
```

Read the schema for actions you use. `showtime schema` lists every action and the script schema. CLI and MCP share these definitions. No source checkout is needed. Tool installation and updates happen through the App's explicit Install / Update tools button; copying this brief does not install them.

## Design

Use `showtime design ACTION_JSON` or `showtime_design(step: ACTION_OBJECT)` to experiment. An action object can be copied unchanged into `setup` or `steps`. This includes native input, camera transforms, and captions.

```sh
showtime design '{"action":"open","url":"showtime://demo"}'
showtime inspect
showtime design '{"action":"caption","text":"A clear headline","style":"title","position":"center","duration":3}' --screenshot /tmp/showtime-preview-new.png
showtime design '{"action":"camera","scale":1.4,"x":700,"y":350,"offsetX":40,"flipX":false,"duration":0.6}'
showtime design '{"action":"caption","text":""}'
```

The example opens bundled Orbit; use the website in the user's brief for their film. Choose new output paths for every screenshot and movie. `design @action.json` resolves image paths relative to that file. MCP design can return the screenshot image with its result.

Design captions remain visible until cleared or playback begins, even if the Agent takes time to inspect a screenshot. In playback, the same caption obeys its duration. Camera values and page changes persist between design actions. `camera` supports scale (0.25–4), pivot (`selector` or `x/y`), translation (`offsetX/offsetY`), rotation in degrees, and horizontal/vertical mirroring (`flipX/flipY`). Omitted camera fields keep their current values. Device frames and captions stay outside this webpage transform.

The Camera pad in Canvas edits the same `offsetX/offsetY` values shown by `showtime status`; positive X moves content right and positive Y moves it down. Put `scale`, `offsetX`, and `offsetY` in one `camera` action to animate them together over `duration` (default 1 second). Do not send separate live commands during rehearsal or recording.

Canvas backdrops are `mist` (the original green), `pearl`, `midnight`, `silver` (presentation gray), and pale candy colors `cloud`, `sky`, `mint`, `rose`, `butter`. Optional `glow` adds central light behind the frame. `glowSize` is the bright core diameter (0–1, default .3); `glowRadius` is its outer fade distance (.1–1.5, default .75), both relative to the Canvas short edge. Glow defaults off for existing designs; its subtle intensity follows frame Light/Dark and dark backdrops, independently of the Studio theme. All these fields work in script `canvas`, `showtime_settings(canvas: {...})`, and CLI settings:

```sh
showtime settings --backdrop silver --glow --glow-radius 0.75 --glow-size 0.3
showtime settings --no-glow
showtime design '{"action":"camera","scale":1.5,"offsetX":90,"offsetY":-40,"duration":1.2}'
```

Inspect visible controls before choosing targets. Mouse/keyboard actions use native browser input. Coordinates are original, untransformed webpage CSS pixels with a top-left origin; they stay the same under camera transforms. Re-inspect after changing Canvas, content width, device frame, or inset. Frames change proportions and appearance, not browser platform emulation.

## Write the script

Use an explicit `setup` for navigation and preparation. It runs before every selected range, outside the MP4. Put the timed film in `steps`, with short labels and unique nonnumeric IDs for useful entry points.

```json
{
  "version": 1,
  "name": "Orbit feature",
  "canvas": {"width": 1920, "height": 1080, "inset": 32, "frame": "none"},
  "recording": {"width": 1920, "height": 1080, "fps": 30},
  "setup": [
    {"action": "open", "url": "showtime://demo"},
    {"action": "waitFor", "selector": "#new-project"},
    {"action": "cursor", "style": "hand", "size": 36}
  ],
  "steps": [
    {"id": "intro", "action": "caption", "text": "A little more momentum", "style": "title", "position": "center", "duration": 2},
    {"action": "wait", "duration": 2},
    {"id": "feature", "action": "parallel", "label": "Focus on the feature", "steps": [
      {"action": "camera", "selector": "#new-project", "scale": 1.4, "duration": 0.8},
      {"action": "move", "selector": "#new-project", "duration": 0.8}
    ]},
    {"action": "wait", "duration": 1},
    {"id": "closing", "action": "camera", "scale": 1, "duration": 0.8}
  ]
}
```

Preserve the user's current Canvas and video settings unless their brief calls for changes. Capture dimensions must be even and match the Canvas aspect ratio. Script-local assets and output paths resolve relative to the script file. Inline MCP scripts resolve relative to the bridge's working directory; use absolute paths when that directory is unknown.

Captions do not block playback: add `wait` to keep them on screen. `parallel` combines one camera/zoom track, one pointer move, one caption, and waits. Use `assert` to verify page outcomes and `screenshot` steps for checkpoints. `evaluate` reads JavaScript results; prefer native actions for interaction.

## Rehearse, then record

```sh
showtime validate film.json
showtime rehearse film.json --screenshot /tmp/showtime-rehearsal-new.png
showtime rehearse film.json --from feature --to closing
showtime validate film.json --mode record --output /tmp/showtime-film-new.mp4
showtime record film.json --output /tmp/showtime-film-new.mp4 --no-wait
showtime job JOB_ID
showtime wait JOB_ID
```

MCP equivalents are `showtime_validate`, `showtime_rehearse`, and `showtime_record`, with exactly one of `script` or `path`, plus optional `from`/`to`. CLI playback waits by default; `--no-wait` returns a job ID. MCP playback returns a job ID by default; `wait: true` waits. Follow it with `showtime_job`; use `includeImage: true` to retrieve a requested final screenshot.

`from` and `to` are inclusive, one-based top-level step numbers or step IDs. They select executable steps, not a video timecode. Earlier steps are never implicitly replayed. Before setup, the App resets the camera and captions and hides the cursor; cursor appearance settings persist. The existing webpage remains unless setup or selected steps navigate. Express any required page state in setup or prepare it during design. Setup can have real side effects, so make repeated preparation appropriate for the target site.

During rehearsal or recording, use status/job queries, screenshots, or stop. Design actions and capture-setting edits are rejected while playback is active. All motion, page waits, and pauses belong in the script. `showtime stop` / `showtime_stop` cancels the job; interrupted recordings finalize a playable partial MP4. Stopping CLI waiting with Ctrl+C or a timeout leaves the App's job running.

Job feedback includes mode, phase, selected range, setup position, original step numbers/IDs, action results and durations, errors, final screenshot, and recording statistics. Validation checks structure, values, and range; only rehearsal can establish whether live selectors and conditions work. Confirm job completion, inspect the exported MP4, and return its path with the reusable script. Exports contain only the film Canvas and currently have no audio.
