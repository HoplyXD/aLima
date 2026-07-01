# Plan: REST-FIX-005 — Zoom-Independent Camera Pan with Consistent Limit

## Context
Middle-mouse pan in `RestorationView` is currently gated to zoom stage 2 (lens-zoom FOV tighter than default). The clamp is screen-relative (`distance * tan(FOV/2) * aspect`), so the effective world-unit limit shrinks as you zoom in. At max zoom the limit becomes too small, making the artifact immovable. Pan also resets to zero when leaving stage 2.

## Goal
Pan works identically at every zoom level with a single, symmetric, fixed world-unit limit of **1.6** around the camera's original centre. Zooming out keeps the offset clamped to the same limit.

## Key Decision
- **D1 (CONFIRMED):** `CAMERA_PAN_MAX = 1.6` world units. Keep the original value, remove zoom scaling.

## Phases

### Phase 1 — Remove zoom-stage gating
- In `_pan_camera()`: remove `if not _is_zoom_stage_2(): return` guard.
- In `_handle_mouse_button()` (middle-mouse): remove `_is_zoom_stage_2()` from `_pan_down` assignment.
- In `_set_fov()`: remove the branch that zeros `_camera_pan` and `_pan_down` when leaving stage 2. Pan must survive across stage transitions.
- In `zoom_by()`: remove the `_is_zoom_stage_2()` guard around `_clamp_pan()` / `_apply_camera_offset()`.

### Phase 2 — Replace clamp with fixed world-unit limit
- Add `const CAMERA_PAN_MAX: float = 1.6` (replacing the screen-relative `CAMERA_PAN_SCREEN_FRAC = 0.25` semantic; the constant name can stay on the old line or be replaced).
- Rewrite `_clamp_pan()`:
  - Clamp `_camera_pan.length()` to `CAMERA_PAN_MAX`.
  - Clamp each axis to `[-CAMERA_PAN_MAX, CAMERA_PAN_MAX]`.
  - Remove all distance/FOV/aspect computations.

### Phase 3 — Re-clamp pan after zoom changes
- In `zoom_by()`: at the end, unconditionally call `_clamp_pan()` and `_apply_camera_offset()` (after `_object.position.z = _zoom_z`).
- In `_reset_zoom()`: after setting `_camera_pan = Vector2.ZERO`, call `_clamp_pan()` and `_apply_camera_offset()` (already zeroed, but keeps the contract). Actually `_reset_zoom()` already sets `_camera.h_offset = 0.0` and `_camera.v_offset = 0.0`, but we should ensure `_apply_camera_offset()` is called so the FOV lean is also applied correctly. Wait, `_reset_zoom()` zeros `_fov_lean_ndc` so `_apply_camera_offset()` would just set offsets to zero. That's fine.
- In `_set_fov()`: when staying in or entering stage 2, remove the `old_tan / new_tan` scaling of `_camera_pan`. Just call `_clamp_pan()` and `_apply_camera_offset()`.

### Phase 4 — Update tests
- Remove / replace tests that assert stage-2-only pan:
  - `test_pan_is_ignored_in_stage_1_and_active_in_stage_2` → replace with `test_pan_enabled_at_all_zoom_levels`.
  - `test_pan_clamps_to_screen_fraction_at_full_zoom` → replace with `test_pan_limit_is_fixed_across_zoom`.
  - `test_pan_limit_at_rest_zoom_is_tight` → remove (no longer applicable).
  - `test_pan_resets_when_leaving_stage_2` → remove (no longer applicable).
  - `test_pan_recentres_on_zoom_out` → update (with fixed limit, pan should NOT shrink when zooming out; it stays at the boundary if already at max).
- Add `test_pan_enabled_at_all_zoom_levels`: at rest, mid, and full zoom, assert `_camera_pan` changes after a drag.
- Add `test_pan_limit_is_fixed_across_zoom`: at rest and full zoom, huge drag, assert `abs(_camera_pan.x) == CAMERA_PAN_MAX` and same for y.
- Remove `_pan_limit_h` and `_pan_limit_v` helper functions from test file (no longer needed).
- Update any remaining assertions that expect pan to be zero at stage 1.

### Phase 5 — Run checks
- `gdformat --check scripts/restoration/restoration_view.gd tests/restoration/test_restoration_view.gd`
- `gdlint scripts/restoration/restoration_view.gd tests/restoration/test_restoration_view.gd`
- Headless import: `& $godot --headless --editor --path . --quit`
- GUT restoration suite: `& $godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/restoration -ginclude_subdirs -gexit`
- Full GUT suite: `& $godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit`

### Phase 6 — Doc update
- Append evidence row to `docs/phase-task.md` and `docs/PROMPT_CONTEXT.md`.

## Guardrails
- Do NOT leave pan disabled at any zoom level.
- Do NOT leave the limit varying with zoom.
- Do NOT leave existing tests red.
- Do NOT change zoom speed, FOV, or rotation.
- Do NOT auto-center on every frame.
