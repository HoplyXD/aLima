# P11.5 HTML5 Runtime Verification Runbook

**Goal:** Confirm the Web export boots in a browser, reaches the shop, and remains playable for the vertical slice.

**Prerequisites**

- Web export artifacts in `build/web/`:
  - `aLima.html`, `aLima.js`, `aLima.wasm`, `aLima.pck`, `aLima.png`
  - `aLima.audio.worklet.js`, `aLima.audio.position.worklet.js`
- A local static-file web server (Python `http.server`, Node `npx serve`, or the Godot `serve.py` script).
- A Chromium-based browser or Firefox with WebGL 2.0 support.

## Procedure

### 1. Serve the export

1. Open a terminal in `build/web/`.
2. Start a local server:
   ```powershell
   python -m http.server 8080
   # or
   npx serve --cors
   ```
3. Open `http://localhost:8080/aLima.html`.
4. Open the browser's developer console (F12).

### 2. Boot and console check

1. Wait for the loading bar to complete.
2. Watch the console for **red errors** during startup.
   - One expected category: warnings about audio autoplay policies are normal until the player clicks.
   - Any `WebGL` context loss, missing file, or GDExtension load error is a failure.
3. Confirm the game canvas appears and shows the shop scene.
4. **Pass:** Boot completes with no critical console errors.

### 3. Audio and input

1. Click or press a key on the canvas to satisfy the browser autoplay policy.
2. Confirm audio begins (or at least that the audio context resumes without error).
3. Click a shop prop and confirm the overlay opens.
4. Close the overlay and confirm the game resumes.
5. **Pass:** Mouse input reaches the game and audio context initializes after interaction.

### 4. Canvas resize

1. Resize the browser window.
2. Confirm the canvas resizes to fill the window (`html/canvas_resize_policy=2` in the Web preset).
3. **Pass:** No black bars or clipped viewport after resize.

### 5. Compatibility/renderer confirmation

1. The Web build uses the Compatibility (OpenGL/WebGL) renderer because of `renderer/rendering_method.web="gl_compatibility"`.
2. Visually confirm decals/blemishes and the shop environment render recognizably.
   - Some Mobile-renderer effects (e.g., certain decal modes) may fall back to simpler visuals; this is expected.
3. **Pass:** The slice is visually playable in WebGL 2.0.

### 6. Discovery smoke test (optional but recommended)

1. Use the F9 debug menu if running a debug build, or play until a carrier spawns.
2. Confirm the Echo HUD, scanner, and Artifact Found/Portal Unlock flows run in the browser.
3. **Pass:** The discovery loop is functional in the browser.

## Evidence to capture

- Screenshot of the loading-complete canvas.
- Screenshot of the browser console showing no critical errors.
- Short clip of clicking a prop and opening/closing an overlay.
- Clip of window resize behavior.
- If available, clip of the discovery loop running in the browser.

## Notes

- Thread support is disabled in the Web preset (`variant/thread_support=false`) for broad hosting compatibility.
- The NobodyWho addon is excluded from the Web preset; a non-fatal "no wasm32 library" warning during export is expected.
- Do not test by double-clicking `aLima.html` directly — browsers block local file fetches for the `.pck`/`.wasm` files.
