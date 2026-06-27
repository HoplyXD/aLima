# Plan: Save-Slot + Seeded New Game + Real Main Menu + Pause Save & Quit

## Context

The current title screen has a single "Play" button that calls `SpaceManager.go_to_shop()`. The shop then calls `LoopController.begin_session()`, which starts Day 1 but never seeds a new run, so `GameState.run_seed` stays 0 and every fresh boot produces the same procedural world. The pause menu has Resume / Return-to-Title / Exit, but Return-to-Title does not save, and there is no Save & Quit. Saves are stored in a single fixed file `user://save.json`.

## Goal

Implement a real main menu (New Game / Continue / Options / Quit), three save slots, a numeric seed entry, and an in-game pause menu with Save & Quit, while preserving the existing SaveService architecture, the persistent/loop split, and test isolation.

## Files to change

1. `scripts/models/save_state.gd` — bump schema to 2, add `run_seed` and `loop_index` to the top-level save contract.
2. `scripts/core/save_service.gd` — add 3-slot API, v1→v2 migration, restore `GameState.run_seed/loop_index` on load, extend raw validation.
3. `scripts/core/game_state.gd` — expose `restore_run_context(seed, loop_index)`, keep `new_run()` intact.
4. `scripts/core/space_manager.gd` — no structural change; `go_to_shop()` will be called after seed+slot setup by the title screen.
5. `scripts/ui/title_screen.gd` + `scenes/ui/title_screen.tscn` — replace Play with New Game / Continue, add slot picker + seed entry screens, preserve backdrop parallax.
6. `scripts/ui/pause_menu.gd` + `scenes/ui/pause_menu.tscn` — add Save, Save & Quit, seed display; wire Esc to open pause without breaking overlay Esc-to-close.
7. `tests/core/test_save_service.gd` — add v1→v2 migration, slot selection/summary, run_seed round-trip tests.
8. `tests/core/test_game_state.gd` — add run context restoration test.
9. `tests/core/test_title_screen.gd` (new) — headless tests for seed parsing, slot overwrite confirm, New Game flow seam.
10. `docs/phase-task.md`, `docs/PROMPT_CONTEXT.md`, `docs/ai-disclosure.md` — update evidence and snapshot date.

## Implementation steps

### A. Save contract (SaveState + SaveService)

- Bump `SaveState.CURRENT_SCHEMA_VERSION` to 2.
- Add `run_seed: int = 0` and `loop_index: int = 0` to `SaveState`, serialized in `to_dictionary` / `from_dictionary` / `validate`.
- Implement `_migrate` v1→v2: inject `run_seed=0`, `loop_index=0` when `from_version == 1`.
- Extend `_validate_raw_payload` to require numeric `run_seed` and `loop_index`.
- On `load_game()`, after populating `save_state`, call `GameState.restore_run_context(save_state.run_seed, save_state.loop_index)` (new helper) so RNG determinism matches the saved run.

### B. Slot-aware SaveService

- Add constants `SLOT_COUNT = 3`, `DEFAULT_SLOT = 0`.
- Add `_slot_index: int = DEFAULT_SLOT` and derived paths `user://save_slot_<i>.json` / `.tmp`.
- Add `select_slot(index: int)`, `slot_count()`, `is_slot_valid(i)`, `slot_exists(i)`, `delete_slot(i)`.
- Add `slot_summary(i: int) -> Dictionary` that reads only top-level metadata (`schema_version`, `player_id`, `run_seed`, `loop_index`, `loop.current_day`, `loop.current_hour`, `persistent` length hints, `last_played` timestamp if present) without full validation; returns `{}` on missing/corrupt.
- Keep `set_save_paths()` and `DEFAULT_SAVE_PATH`/`DEFAULT_TEMP_PATH` intact for tests; slot selection sets the same `save_path`/`temp_path` fields.
- `delete_save_files()` continues to delete the active slot's files.

### C. GameState run-context restoration

- Add `restore_run_context(seed: int, index: int) -> void` that sets `run_seed`, `loop_index`, and refreshes `run_context`.
- Keep `new_run(seed)` as the only path that increments loop index and reseeds; New Game calls it, Continue calls `restore_run_context`.
- In `initialize()`, keep the existing fresh-state path (used by tests and New Game setup), but remove the automatic `_new_run_context` that currently leaves seed at 0. New Game will explicitly call `new_run(seed)`.

### D. Title screen rework

- Replace the single VBoxContainer Play/Options/Quit with a screen stack:
  - Main screen: New Game, Continue, Options, Quit.
  - Slot screen: 3 slot buttons (show empty / summary), Back.
  - Seed screen: LineEdit (digits only), Randomize button, Start, Back.
  - Overwrite-confirm dialog (AcceptDialog or custom panel) for occupied slots.
- Preserve the backdrop camera parallax animation.
- All screens use Buttons with `grab_focus()` for controller/keyboard nav; headless-safe `get_node_or_null` usage.
- New Game flow:
  1. Show slot screen; pick empty or occupied slot.
  2. If occupied, confirm overwrite; on confirm delete the slot.
  3. Show seed screen; player types digits or presses Randomize.
  4. Validate seed in `[0, 2147483646]`; blank or Randomize picks `randi_range(0, 2147483646)`.
  5. `GameState.initialize("local-player")`, `SaveService.select_slot(slot)`, `GameState.new_run(seed)`, initial `SaveService.save_game()`, then `SpaceManager.go_to_shop()`.
- Continue flow:
  1. If no slots exist, disable Continue or show "No saves".
  2. Show slot screen; pick a slot with a save.
  3. `SaveService.select_slot(slot)`; `load_game()`; surface load errors in status label.
  4. On success, `SpaceManager.go_to_shop()`.
- Options/Quit unchanged.

### E. Pause menu rework

- Add Esc to the `pause` action (or open on `back` when no overlay consumed it). Current `_unhandled_input` already handles `pause` (Space) and `back` when open; add Esc as an additional `pause` event and keep overlays calling `set_input_as_handled()` so Esc-to-close wins.
- Add a `SaveButton` and `SaveAndQuitButton`; keep Resume and rename Return-to-Title to "Return to Title (unsaved)" or add a save warning.
- `save_game()` writes to the active slot; update `_status_label` with success/failure.
- `save_and_quit_to_title()` saves, then `SpaceManager.return_to_title()`.
- Add a seed readout label showing "Seed: N" and "Slot: N".
- Ensure the menu remains headless-safe (DisplayServer checks already present).

### F. Tests

- `test_run_seed_and_loop_index_round_trip`: set seed/index, save, load into fresh state, assert restored.
- `test_v1_migration_injects_run_seed_loop_index`: write a v1 payload, load, assert schema 2 and defaults 0/0.
- `test_slot_selection_uses_distinct_files`: select slot 0, save, select slot 1, different state, assert each loads independently.
- `test_slot_summary_reads_metadata_without_full_load`: write saves, assert summary returns expected seed/day without running full validation.
- `test_new_game_seed_produces_deterministic_day1_delivery`: use redirected paths, run New Game flow with fixed seed, generate day-1 delivery, assert identical on second run; different seed diverges.
- `test_continue_restores_seed_for_same_rolls`: start a run, save, continue from slot, assert `run_seed` and placement/delivery RNG reproduce.
- Headless title-screen tests for seed parsing and overwrite dialog.

### G. Documentation

- `docs/phase-task.md`: add a new Phase 0/2 follow-up task or append under Phase 2 evidence; reference SAVE-R1, DISC-R6, INPUT-R1, PLAT-R4; leave manual gates unchecked.
- `docs/PROMPT_CONTEXT.md`: refresh snapshot date, document slot saves, schema v2, New Game/Continue, pause Save & Quit.
- `docs/ai-disclosure.md`: append AI-assisted code row.

## Verification

```powershell
$godot = "C:\Users\roman\Downloads\Godot_v4.7-stable_win64_console.exe"
& $godot --headless --editor --path . --quit
& $godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/core -gexit
& $godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit
gdformat --check scripts scenes dialogue tests
gdlint scripts scenes dialogue tests
git diff --check
```

## Risks and mitigations

- **Existing tests using `set_save_paths`**: slot selection routes through the same `save_path`/`temp_path` fields; tests that set explicit paths keep working. Default paths stay `user://save.json`/`user://save.tmp` when no slot is selected.
- **LoopController `begin_session` currently resets clock but does not seed**: title screen will now own the `new_run` call; `begin_session` will only start the clock after a run context exists. This fixes the reported bug.
- **Overwriting slots**: require explicit confirmation; never silently delete.
- **Headless safety**: title screen checks `DisplayServer.get_name() == "headless"` for mouse-parallax; buttons still exist and are testable.
- **Persistent/loop split**: `run_seed`/`loop_index` live at the top-level save contract, not inside `loop`, so loop reset never wipes the seed.
