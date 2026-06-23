# P11.4 Live Resilience Runbook

**Goal:** Prove the slice recovers gracefully when the backend and Portal behave badly, and that Portal progress survives a save/reload.

**Prerequisites**

- Windows Desktop build `build/aLima.exe`.
- Node.js installed.
- `mock-portal/` and `server/` checked out at the same commit as the build.

## Procedure

### 1. Backend online against mock Portal

1. In one terminal:
   ```powershell
   cd mock-portal
   npm install
   npm start
   ```
2. In a second terminal:
   ```powershell
   cd server
   npm install
   Copy-Item .env.example .env
   # Edit .env so PORTAL_BASE_URL=http://localhost:3001
   npm run dev
   ```
3. Launch the game and play through to a carrier discovery:
   - Clean and open the carrier.
   - When **Artifact Found** appears, proceed to Portal Unlock.
4. Confirm the Portal Unlock screen shows a historical fact card returned by the mock Portal.
5. Confirm the fragment is seated and the journal case shows `1/5`.
6. **Pass:** Mock Portal path completes end-to-end and persists.

### 2. Backend timeout with cached fallback

1. With the server still running, edit `server/.env`:
   ```
   PORTAL_TIMEOUT_MS=1
   ```
   Restart the server.
2. Start a fresh loop and discover another carrier (or use the debug release to force a fragment).
3. Proceed to Portal Unlock.
4. Confirm the game shows a clear fallback state: a deterministic fact card or an explicit "using offline record" message instead of hanging or crashing.
5. **Pass:** The slice remains playable and the player can continue after timeout fallback.

### 3. Backend unavailable with recoverable client state

1. Stop both `server` and `mock-portal`.
2. Launch the game and attempt a Portal Unlock.
3. Confirm:
   - The game does not crash.
   - The player sees an informative message (e.g., "Portal unavailable — using offline record").
   - The fragment can still be seated and the case updates.
4. **Pass:** No hard lock-up; the player can keep playing offline.

### 4. Save/reload before and after Portal completion

1. Start a loop and reach a carrier before opening it.
2. Save the game (the save is automatic on close; you can also force-close after seating).
3. Complete the Portal flow and seat the fragment.
4. Exit to desktop.
5. Relaunch the game and load.
6. Open the journal and confirm:
   - The fragment is still seated (`1/5` or higher).
   - The museum entry exists in the object-archive page.
7. **Pass:** Portal result and seated fragment survive a full quit/relaunch cycle.

## Evidence to capture

- Clip showing mock Portal request and fact-card response.
- Clip showing timeout fallback.
- Clip showing backend-offline fallback.
- Before/after screenshots of the journal case and museum entry across a reload.
- `user://save.json` (or the save file path) before and after, if safe to share.

## Notes

- The deterministic fallback is implemented in `server/src/services/portal_service.js` and `scripts/shop/portal_flow_controller.gd`.
- Do not commit a real `.env` with live keys for this test.
