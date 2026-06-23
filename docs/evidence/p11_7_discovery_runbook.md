# P11.7 Discovery Evidence Runbook

**Goal:** Capture the full sensory discovery beat: Echo bands leading to a carrier, Heartbeat identifying it, then clean → open → Artifact Found.

**Prerequisites**

- Windows Desktop build or editor run.
- Audio enabled (so the clip can also serve as a normal-play evidence video).
- A carrier present in the shop (use the F9 debug menu → **Debug Release** or play until the Spawn Director places one).

## Procedure

### 1. Echo band introduction

1. Start in the shop with the carrier somewhere in the environment.
2. Walk the perimeter while watching the Echo HUD.
3. Capture:
   - `Hum` band activating at distance.
   - `Melody` band rising as you enter the general area.
   - `Voice` band appearing near the correct pile/container.
   - Captions updating with each band transition.
4. **Pass:** All four bands (Hum, Melody, Voice, Heartbeat) are visible on the meter/captions during the search.

### 2. Heartbeat only on the carrier

1. Approach multiple glowing objects in the same area.
2. Show that decoy objects never trigger the `Heartbeat` band and never flicker.
3. Approach the true carrier.
4. Show the `Heartbeat` band spiking and the carrier beginning to flicker at close proximity (>= 0.60).
5. **Pass:** Heartbeat and flicker are exclusive to the carrier.

### 3. Clean → open → Artifact Found

1. Select the carrier and enter the restoration bench.
2. Clean it (remove grime or blemishes) until it reaches `CLEAN`.
3. Activate/open the object.
4. Confirm the **Artifact Found** screen appears with the discovered fragment.
5. **Pass:** The discovery loop completes from Echo cues to Artifact Found.

## Evidence to capture

- One continuous clip showing:
  - Distant Hum → Melody → Voice → carrier flicker + Heartbeat.
  - A nearby decoy that does **not** show Heartbeat/flicker.
  - Picking up the carrier, cleaning it, opening it, and the Artifact Found screen.
- Screenshots of the Echo HUD at each band stage.

## Notes

- The Echo system is implemented in `scripts/discovery/echo_controller.gd` and `scripts/discovery/echo_proximity_service.gd`.
- The debug menu can force-release a fragment if you do not want to play the full five-day loop.
