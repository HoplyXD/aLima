# P11.6 Placement Evidence Runbook

**Goal:** Record three different placements of the same fragment for the same player, proving the Spawn Director produces real, logged, non-repeating carrier/container/day outcomes.

**Prerequisites**

- Windows Desktop build or editor run under Godot 4.7.
- The same `player_id` for all three runs (use the default local player or set a fixed name).
- The placement demo writes to `docs/evidence/placement_logs/phase5_three_run_demo.json`.

## Procedure

### 1. Generate three-run placement evidence

1. Launch the game.
2. Open the F9 **DemoMenu** (only available in debug builds).
3. Select **Placement Demo** (three-seed Spawn Director run).
4. The demo runs three seeds and writes an audit log to:
   ```
   docs/evidence/placement_logs/phase5_three_run_demo.json
   ```
5. Open the log file and confirm it contains three entries with different values for at least one of:
   - `carrier_template_id`
   - `container_id`
   - `day`
6. **Pass:** The same fragment appears in three different carrier/container/day combinations.

### 2. Manual three-run capture (alternative if not using debug menu)

1. Start the game and note the loop seed (if exposed) or use a fixed seed.
2. Play until Auntie's route releases `fragment_01` and the Spawn Director places it.
3. Record the carrier object, container, and in-game day.
4. Start a new run with a different seed and repeat.
5. Do this three times.
6. Confirm no two runs used the exact same `carrier_template_id` + `container_id` pair.
7. **Pass:** Three visibly different placements are observed.

### 3. Match footage to logs

1. While recording each run, capture:
   - The moment the carrier object is revealed (clean → open → fragment).
   - The container the object was in (e.g., left pile, center pile, shelf).
   - The in-game day shown on the HUD.
2. Cross-check the footage against the JSON log entries.
3. **Pass:** Every clip corresponds to a unique log line.

## Evidence to capture

- `docs/evidence/placement_logs/phase5_three_run_demo.json` (or equivalent manual log).
- Three short clips, one per run, showing the carrier object and its container.
- A screenshot of the HUD showing the day for each run.

## Notes

- The Spawn Director's "never-twice" rule prevents the same `carrier_template_id` + `container_id` pair from repeating until candidates are exhausted.
- If the demo menu is unavailable, build a debug version (`--export-debug "Windows Desktop"`) or run from the editor.
