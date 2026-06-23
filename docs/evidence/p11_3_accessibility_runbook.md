# P11.3 Accessibility and Display Runbook

**Goal:** Verify that the June 30 vertical slice can be navigated and played without audio, at the target resolutions, with readable contrast and visible focus/hover states.

**Prerequisites**

- Windows Desktop build from `build/aLima.exe` (or run from the editor with the 4.7 console executable).
- A mouse. Optional: a controller or touch device for extended verification (mouse is the slice reference).
- Ability to mute system audio or disable the game audio bus.

## Procedure

### 1. Mouse-only navigation

1. Launch the game and reach `scenes/Shop.tscn`.
2. Without touching the keyboard (except to start the game):
   - Hover over each shop prop (Door, Workbench, Journal, Phone, Morning Delivery). Confirm a prompt label appears and the prop highlights.
   - Left-click each prop to open its overlay.
   - Close each overlay by clicking the on-screen Close button or the prop again.
   - Click through a visitor dialogue using only the mouse.
3. **Pass:** Every shop action can be reached and dismissed with the mouse only.

### 2. Muted-audio discovery

1. Mute the Master audio bus in the pause menu (`Settings > Audio`) or mute the system.
2. Start a loop where a carrier is present (use the F9 debug menu → **Placement Demo** or play until the Spawn Director places a carrier).
3. Walk the shop and watch the Echo HUD:
   - Confirm the resonance meter rises/falls as you approach/leave glowing objects.
   - Confirm captions show band names (`Hum`, `Melody`, `Voice`, `Heartbeat`) and proximity changes.
   - Confirm the carrier flickers at close range.
4. Locate the carrier using only the meter and captions.
5. **Pass:** The carrier is findable without audio.

### 3. Resolution and scaling

1. In the pause menu, set the resolution to **1920x1080** and enable fullscreen if possible.
   - Confirm all HUD text, buttons, and prompts are readable.
   - Confirm the journal pages and Echo HUD do not overlap critical UI.
2. Switch to **1280x720** windowed mode.
   - Confirm the shop HUD still fits inside the window.
   - Confirm dialogue text does not clip and buttons remain clickable.
3. **Pass:** No clipped text, unreachable buttons, or off-screen overlays at either resolution.

### 4. Contrast and focus/hover states

1. Hover over every interactive prop and every HUD button.
   - Confirm a visible highlight, outline, or color shift.
2. Tab through focusable UI (dialogue advance, menu buttons) and confirm a focused-state outline.
3. Check that text on the Echo HUD, scanner, and journal has sufficient contrast against the background.
4. **Pass:** Focus and hover states are distinguishable for all interactive elements.

## Evidence to capture

- Screenshot or short clip of mouse-only prop hover + prompt.
- Clip of muted Echo discovery showing the meter/captions leading to a flickering carrier.
- Side-by-side screenshots at 1920x1080 and 1280x720.
- Screenshot showing hover/focus state on at least one prop and one UI button.

## Notes

- The debug DemoMenu (F9 in debug builds) can force a carrier into the loop for the muted-audio test.
- If any prop or button cannot be reached with the mouse, file a bug and do not mark P11.3 complete.
