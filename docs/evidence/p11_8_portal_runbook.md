# P11.8 Portal Evidence Runbook

**Goal:** Record the Portal Unlock beat proving backend/mock request completion, historical fact display, persisted museum record, and the journal case moving to `1/5`.

**Prerequisites**

- Windows Desktop build.
- Backend and mock Portal running (see P11.4 for startup commands).
- A discovered fragment ready to seat.

## Procedure

### 1. Backend/mock request completion

1. After **Artifact Found**, proceed to the Portal flow.
2. Capture the screen showing the backend/mock request in progress or completed.
   - In the editor build you can also inspect the server terminal for the `POST /api/portal/discovery` request log.
3. Confirm the request uses the idempotency key `player_id:fragment_id`.
4. **Pass:** A Portal request is made and returns a fact card.

### 2. Portal Unlock historical fact

1. On the Portal Unlock screen, capture the historical fact card text.
2. Confirm the fact card is marked as verified or, if it is a development placeholder, that it is labeled `unverified`.
3. Click to unlock/seat the fragment.
4. **Pass:** The fact card is readable and the unlock succeeds.

### 3. Persisted museum record

1. Open the journal (`J` or click the Journal prop).
2. Navigate to the object-archive/museum page.
3. Confirm the fragment has a museum entry with the same fact card summary.
4. **Pass:** A museum record exists and matches the Portal fact.

### 4. Case moves to 1/5

1. Navigate to the Fragment Case page in the journal.
2. Confirm the first slot is filled and the counter reads `1 / 5 fragments seated`.
3. **Pass:** The case counter increments and the slot is visually occupied.

### 5. Save/reload persistence

1. Exit to desktop after seating the fragment.
2. Relaunch and load the save.
3. Reopen the journal and confirm the seated fragment and museum entry are still present.
4. **Pass:** Portal progress survives reload.

## Evidence to capture

- Clip of the Artifact Found → Portal request → Portal Unlock fact card flow.
- Screenshot of the server terminal showing the `POST /api/portal/discovery` call.
- Screenshot of the journal Fragment Case showing `1/5`.
- Screenshot of the museum/object-archive entry.
- Before/after clip across a reload proving persistence.

## Notes

- The Portal client is `scripts/portal/portal_client.gd`; the flow controller is `scripts/shop/portal_flow_controller.gd`.
- To test fallback, repeat the flow with the server stopped or `PORTAL_TIMEOUT_MS=1` (see P11.4).
