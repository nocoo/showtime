# React animation overlay

A frame-driven like reaction over a real Orbit project-creation workflow. The native app loads `index.html`; `like.jsx` renders the host-supplied frame with React's `flushSync`.

```sh
cd examples/overlay-react
bun install --frozen-lockfile
bun run build
showtime rehearse demo.json
showtime record demo.json --output ~/Movies/Showtime/react-overlay-new.mp4
```

Keep Showtime open and visible. From this directory, source developers can use `../../scripts/showtime` instead of the installed `showtime`. Use a fresh output path for each take.

Change `visible`, `label`, `count`, `color`, `x`, and `y` through an `overlay` action's `props`. Coordinates are Canvas pixels, independent of the underlying webpage camera. Omitted x/y place the reaction near the bottom-right. `duration` triggers the exit fade; omitting it keeps the reaction visible. Props updates restart the animation and replace the entire object.

Dependencies and build output stay inside this example; the App does not need Bun or React to load an already built HTML page. For the callback contract, timing, asset loading, and realtime capture limits, read `showtime guide` or [the overlay guide](../../docs/overlays.md).
