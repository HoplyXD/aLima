# aLima Phase Task Checklist

Canonical step-by-step build tracker for the Godot 4.6.3 game, backend, mock Portal, tests, and milestone evidence.

| Field | Value |
|---|---|
| Last audited | 2026-06-15 |
| Current milestone | June 30, 2026 vertical slice |
| Engine target | Godot 4.6.3 |
| Presentation | Hybrid 3D shop with 2D gameplay interfaces |
| Project root | Repository root (`project.godot` stays here) |
| Build authority | `CLAUDE.md` §4 -> `docs/PRD.md` -> `README.md` -> this checklist |
| Discovery specification | `docs/PRD.md` §12 |

Toolchain references: [Godot 4.6.3 maintenance release](https://godotengine.org/article/maintenance-release-godot-4-6-3/) and [Godot 4.6 documentation](https://docs.godotengine.org/en/4.6/).

## Status Markers

- `[x]` verified complete under Godot 4.6.3, or verified by the applicable non-runtime command for documentation/repository-only work
- `[-]` partially implemented, placeholder-only, or integrated but not fully verified
- `[ ]` not started
- `[!]` blocked by an external dependency or explicit decision

Do not mark runtime work `[x]` from screenshots, print statements, scene presence, or Godot 4.5.x checks. Record the command and result in the task before changing its marker.

## Definition of Done

Every completed task must:

- Satisfy its listed PRD requirement IDs and `CLAUDE.md` §4 invariants.
- Use typed GDScript and signals for cross-system communication.
- Keep artifact, fragment, route, echo, and object specifics in JSON or resources.
- Include focused GUT or backend tests when logic exists.
- Pass the Godot 4.6.3 import check and relevant automated tests.
- Include one manual gameplay acceptance check for user-facing behavior.
- Append new AI usage to `docs/ai-disclosure.md`.
- Avoid committing secrets, generated caches, or unrelated file churn.

## Current Repository Audit

- `[x]` Godot project scaffold exists and targets feature `4.6`. Godot 4.6.3 passes explicit import/startup checks, and the bare `godot` command now resolves to `4.6.3.stable` via a PATH shim (Phase 0 P0.2; the older 4.5.1 stays at its own path).
- `[-]` Upstream commit `0255430` is integrated and stabilized: HUD revealed, stray button removed, controllers consolidated. Editor import and headless startup pass under 4.6.3; on-screen manual UI click-through remains for human confirmation.
- `[x]` The 4.6.3 editor import and configured main-scene startup complete without parser, resource, UID, or missing-file errors. Evidence: `--headless --editor --path . --quit` and `--headless --path . --quit`, run 2026-06-15 (exit 0, no error lines).
- `[x]` `scenes/Shop.tscn` is the configured main scene; its `HUD` CanvasLayer is now `visible = true` and is a usable production screen.
- `[x]` Shop orchestration is consolidated into one controller on the Shop root (`scripts/shop/shop_controller.gd`) plus a presentation-only HUD (`scenes/ui/shop_hud.gd`). The old `scenes/hud.gd`, `scenes/shop_3d.gd`, and `prototype/` controllers were removed after migration.
- `[x]` The stray `AAAAAAAAA` test button has been removed from `scenes/Shop.tscn`.
- `[-]` Clock/day progression exists only as placeholder state in the Shop controller. There is no reusable loop controller or split persistence (Phase 2).
- `[-]` The dialogue box supports queued lines, typewriter reveal, keyboard input, and mouse input, but the placeholder lines are still hardcoded in the Shop controller (Phase 10 moves prose to `data/routes/`).
- `[-]` The Auntie beat has placeholder dialogue and a visitor sprite. Scheduling, route state, and the scripted photo sequence do not exist.
- `[ ]` Object data pipeline, real delivery/triage, restoration, carriers, Spawn Director, Cultural Echoes, cached scanner, backend, mock Portal, journal, museum record, feature tests (beyond the Phase 0 smoke test), and exports are not implemented.
- `[ ]` Print-only Workbench, Journal, and Phone actions are not complete features.

## Reconciliation With the Old Tracker

The deleted root `phasetask.md` is still available in Git history at commit `bab8cb9`. It contained no checked tasks, so there is no completed checklist to restore. The repository nevertheless contains useful implementation work that maps to the old tasks as follows:

| Old tracker item | Evidence already in the repository | Canonical status |
|---|---|---|
| One shop space scene | `scenes/Shop.tscn` contains a 3D environment, camera, book prop, visitor sprite, and HUD nodes | `[-]` Partial; HUD hidden and scene needs stabilization |
| Daily clock | Three controllers implement 07:00-20:00 hourly progression at 60 seconds/hour | `[-]` Partial; placeholder state, duplicated logic, no real reset |
| Clock HUD | Day/time/count labels and formatting exist | `[-]` Partial; no loop counter and production HUD is hidden |
| Door/visitor interaction | Door button, visitor sprite, dialogue queue, and pause/resume behavior exist | `[-]` Partial; hardcoded content and no visit schedule |
| Dialogue system | Reusable typewriter dialogue supports keyboard and mouse advance | `[-]` Partial; no authored dialogue data or automated tests |
| Workbench/Journal/Phone navigation | Buttons and placeholder responses exist | `[-]` Partial; no real screens or system integration |
| Delivery/triage | Placeholder rarity counts only | `[ ]` Not implemented |
| Restoration mini-game | Placeholder dialogue only | `[ ]` Not implemented |
| Object JSON pipeline | No `data/objects` or loader | `[ ]` Not implemented |
| Spawn Director / Echoes / Scanner / Portal / Journal | No runtime implementation | `[ ]` Not implemented |

### Where Development Starts

Do not rebuild the Shop from scratch. Start with **Phase 0 stabilization**:

1. Select the installed Godot 4.6.3 executable for the editor and CLI; do not use the 4.5.1 executable currently first on `PATH`.
2. Make the existing `scenes/Shop.tscn` HUD visible and remove the stray test button.
3. Consolidate the duplicated controllers into one Shop controller plus one presentation-only HUD.
4. Verify all four buttons, dialogue input, visitor visibility, and clock pause/resume.
5. Then begin Phase 1 with typed models, JSON loading, and core autoloads.

## Stable Interfaces

Implement these contracts before feature code so phases can integrate without hard cross-references.

### Event Bus

Create `scripts/core/event_bus.gd` as an autoload named `EventBus`.

```gdscript
signal hour_changed(day: int, hour: int)
signal day_changed(day: int)
signal loop_reset(loop_index: int)
signal clock_pause_changed(is_paused: bool, owner_id: String)

signal delivery_generated(day: int, instance_ids: Array[String])
signal triage_completed(kept_ids: Array[String], recycled_ids: Array[String])
signal restoration_completed(instance_id: String, condition: float, tool_id: String)
signal object_opened(instance_id: String, result: String, content_id: String)

signal carrier_activated(instance_id: String, fragment_id: String)
signal echo_proximity_changed(instance_id: String, proximity: float, band: String)
signal fragment_discovered(fragment_id: String, instance_id: String)
signal portal_completed(fragment_id: String, museum_entry_id: String, used_fallback: bool)
signal fragment_seated(fragment_id: String, slot_index: int)
```

### Data Contracts

- Authored object templates: `data/objects/*.json`.
- Artifact and fragment definitions: `data/artifacts/*.json`.
- Echo sets: `data/echoes/*.json`.
- Route/dialogue definitions: `data/routes/*.json`.
- Cached scanner responses: `data/scanner-cache/*.json`.
- Runtime instances are generated from templates and never overwrite authored files.
- Every JSON file has a top-level `schema_version` and stable string IDs.

### Save Contract

```json
{
  "schema_version": 1,
  "player_id": "local-player",
  "persistent": {},
  "loop": {}
}
```

- `persistent`: journal entries, scanner records, museum entries, seated fragments, spawn history, learned techniques, completed routes, leads, legacy items, Safe/drawer knowledge.
- `loop`: day/hour, money, ordinary inventory, temporary tools/upgrades, listings, current deliveries, unfinished requests, event outcomes.
- Save writes use `user://save.tmp`, validate the complete payload, then replace `user://save.json`.
- Future schema changes increment `schema_version` and add an explicit migration.

### State Contracts

- Fragment: `LOCKED -> RELEASED -> SEATED`.
- Object: `DIRTY -> CLEAN -> OPEN` for openables.
- Open result: `EMPTY | TEMPORAL_ECHO | FRAGMENT`.
- Player verdict: `AUTHENTIC | REPLICA | MODIFIED | UNCERTAIN`.
- Route: `INACTIVE -> AVAILABLE -> IN_PROGRESS -> COMPLETED`, with unanswered expiry back to `INACTIVE`.

### Seed and Placement Log

Each placement audit writes one JSON line:

```json
{"loop":1,"seed":12345,"fragment_id":"fragment_01","carrier_template_id":"tarnished_pendant","carrier_instance_id":"obj_0042","container_id":"pile_left","day":2,"soft_reset":false}
```

### API Contracts

- `POST /api/scan`: use the request/response in PRD §20; output is advisory only.
- `POST /api/portal/discovery`: use the request/response in PRD §20.
- Repeated Portal requests use a deterministic idempotency key: `player_id:fragment_id`.
- Backend timeout, validation, rate limiting, fallback, and config selection are mandatory.

## Standard Verification Commands

```powershell
godot --version
godot --headless --editor --path . --quit
godot --headless --path . -s addons/gut/gut_cmdln.gd
gdformat --check .
gdlint .

Push-Location server
npm test
Pop-Location

git status --short
git ls-files | Select-String -Pattern '(^|/).env$|secret|credential|api[_-]?key'
```

---

## Phase 0 - Repository and Toolchain

**Goal:** establish one verified Godot 4.6.3 production entrypoint and reproducible checks.

**Requirements:** ARCH-R4, project conventions, global Definition of Done
**Dependencies:** none
**Subsystems:** repository, Godot project, tooling, CI

### Tasks

- `[-]` **P0.1 Integrate the upstream hybrid shop work.**
  - Commit `0255430` is present locally.
  - HUD revealed (`HUD.visible = true`) and the stray `AAAAAAAAA` test button removed from `scenes/Shop.tscn`.
  - The 4.6.3 editor import and `scenes/Shop.tscn` startup pass without parser/resource/UID/missing-file errors; the controller logs `[Shop] ready` (verified 2026-06-15).
  - Door/Workbench/Journal/Phone input is covered at the logic level by the GUT smoke test: button intent signals fire and dialogue advances via simulated mouse + keyboard events through the real `DialogueBox._input`.
  - **Remaining gate (manual):** on-screen click-through under a real display (mouse hit-testing/visuals) — to be confirmed by a human. Kept `[-]` until then.
  - Evidence (2026-06-15): `Godot_v4.6.3-stable_win64_console.exe --headless --editor --path . --quit` (exit 0, no errors); `--headless --path . --quit` (exit 0); GUT `7/7 passed`.

- `[x]` **P0.2 Select Godot 4.6.3 for CLI/editor use.**
  - A PATH shim (`C:\Users\roman\tools\bin\godot.cmd` → the 4.6.3 console exe) is prepended to the User PATH ahead of the older 4.5.1 install (which stays at its own path). A bash shim (`godot`) is included for Git Bash.
  - `godot --version` now reports `4.6.3.stable.official.7d41c59c4` in a fresh shell.
  - The explicit `C:\Users\roman\Downloads\Godot_v4.6.3-stable_win64_console.exe` still works for the current/unrefreshed session.
  - Evidence (2026-06-15): fresh-shell `godot --version` → `4.6.3.stable.official.7d41c59c4`; resolved to `C:\Users\roman\tools\bin\godot.cmd`.

- `[x]` **P0.3 Complete the production architecture gate after the 4.6.3 import check.**
  - `scripts/shop/shop_controller.gd` (extends `Node3D`) is attached to the Shop root and owns orchestration + clock state.
  - `scenes/ui/shop_hud.gd` (`class_name ShopHud`, extends `CanvasLayer`) is the presentation-only HUD: it emits typed intent signals and exposes `set_*`/`start_dialogue`/`set_actions_visible`, holding no game state, timers, or visitor/flow logic.
  - Cross-boundary communication is via typed signals (ARCH-R4).
  - Evidence (2026-06-15): editor import exit 0, registers `ShopHud`/`DialogueBox` global classes; main-scene startup exit 0.

- `[x]` **P0.4 Consolidate duplicate shop controllers.**
  - `scenes/Shop.tscn` is the only production main scene.
  - `scripts/shop/shop_controller.gd` owns shop orchestration; `scenes/ui/shop_hud.gd` is the presentation-only HUD (intent signals, no game state) — the prototype's controller/UI split promoted to production.
  - Useful behavior (clock, day wrap, counts, visitor/dialogue flow, placeholder prose) migrated from `scenes/hud.gd`, `scenes/shop_3d.gd`, and `prototype/shop.gd` + `prototype/shop_ui.gd`.
  - Obsolete files deleted after verification: `scenes/hud.gd`, `scenes/shop_3d.gd` (+ `.uid`), and the entire `prototype/` directory (including the broken `Main.tscn`). `dialogue/` preserved.
  - Evidence (2026-06-15): clean import + startup + GUT `7/7` after deletion; `git status` shows the 13 removals.

- `[x]` **P0.5 Establish the root layout.**
  - Added `scripts/{core,models,shop,delivery,restoration,discovery,scanner,journal,portal}`.
  - Added `scenes/{ui,restoration}`, `resources`, `data/{objects,artifacts,echoes,routes,scanner-cache}`, and `tests`.
  - Empty dirs keep a `.gitkeep`; `scripts/shop`, `scenes/ui`, and `tests` hold real files instead.
  - `server` and `mock-portal` intentionally not created (Phase 8).
  - Evidence (2026-06-15): directories present in working tree; `git status` lists the new untracked paths.

- `[x]` **P0.6 Install test and lint tooling.**
  - Vendored GUT 9.6.0 under `addons/gut`; smoke test `tests/test_shop_smoke.gd` + `.gutconfig.json`.
  - gdtoolkit pinned to `4.5.0` in `requirements-dev.txt` (`pip install -r requirements-dev.txt`).
  - CI `.github/workflows/ci.yml`: a lint job (gdformat `--check` + gdlint, scoped to `scripts scenes dialogue tests`) and a Godot job (downloads pinned 4.6.3 Linux headless → editor import → GUT). No backend job by design (server/mock-portal not created yet — Phase 8).
  - Evidence (2026-06-15, local): GUT `7/7 passed` (29 asserts, exit 0); `gdformat --check scripts scenes dialogue tests` exit 0; `gdlint ...` "no problems found". CI workflow added; first remote run is pending the next push.
  - Note: the literal `gdformat --check .` / `gdlint .` forms fail only on the 81 vendored `addons/gut` files (0 of ours), so the documented commands are scoped to our source.

- `[x]` **P0.7 Verify repository hygiene.**
  - `.gitignore` now covers `.godot/`, `.env`/`*.env` (keeping `!.env.example`), logs, exports (`/build*`, `/export*`, `*.pck`, `*.zip`), and Python caches (`__pycache__/`, `.venv/`). Tracked `.import` files (Godot 4 metadata) intentionally kept.
  - `.editorconfig` declares `[*.gd] indent_style = tab` to match gdformat.
  - No tracked secret/`.env`/credential/api-key path; no secret-like content in new source.
  - Evidence (2026-06-15): `git ls-files | Select-String '(^|/)\.env$|secret|credential|api[_-]?key'` → no matches.

### Acceptance

- [x] `godot --version` reports 4.6.3 (`4.6.3.stable.official.7d41c59c4`, fresh shell, 2026-06-15).
- [x] The production Shop imports and opens with zero parser/resource errors under Godot 4.6.3 (2026-06-15).
- [x] Exactly one production shop controller owns orchestration (`scripts/shop/shop_controller.gd`); HUD is presentation-only.
- [x] GUT smoke test (7/7), gdformat check, and gdlint execute successfully (2026-06-15).
- [x] No secret or real `.env` is tracked.

### Verification

```powershell
godot --version
godot --headless --editor --path . --quit
godot --headless --path . --quit
godot --headless --path . -s addons/gut/gut_cmdln.gd
gdformat --check .
gdlint .
git ls-files | Select-String -Pattern '(^|/).env$|api[_-]?key|credential|secret'
```

---

## Phase 1 - Core Architecture and Data

**Goal:** create typed, data-driven contracts used by every gameplay system.

**Requirements:** ARCH-R1..R5, PRD §4 models
**Dependencies:** Phase 0
**Subsystems:** models, loaders, autoloads, test fixtures

### Tasks

- `[ ]` **P1.1 Implement typed model classes.**
  - Create models for `ScrapObjectTemplate`, `ObjectInstance`, `Fragment`, `MasterArtifact`, `EchoSet`, `JournalEntry`, `MuseumEntry`, `ToolDefinition`, and `TechniqueDefinition`.
  - Use enums/constants for rarity, object state, fragment state, open result, and verdict.
  - Provide `from_dictionary()`, `to_dictionary()`, and validation methods.

- `[ ]` **P1.2 Implement JSON loading and validation.**
  - Load each data directory through one typed repository/service.
  - Reject duplicate IDs, unknown enum values, invalid ranges, missing tools, and broken references.
  - Report all validation errors together so content authors can fix a batch.

- `[ ]` **P1.3 Add core autoloads.**
  - `EventBus`: signals listed in Stable Interfaces.
  - `GameState`: owns current loop and persistent state in memory.
  - `SaveService`: serialization, validation, atomic writes, and migration entrypoint.
  - Autoloads do not directly manipulate scene nodes.

- `[ ]` **P1.4 Add deterministic run context.**
  - Store `player_id`, `loop_index`, and `run_seed`.
  - Accept a debug seed override for recorded demo runs.
  - Use local `RandomNumberGenerator` instances; never depend on global random state for placement.

- `[ ]` **P1.5 Add minimum slice data.**
  - One tarnished pendant template used by ordinary instances and carriers.
  - At least two non-carrier pendant decoys.
  - At least three compatible outer containers/piles.
  - One `RELEASED` demo fragment definition.
  - One four-band echo set and cached scanner response.
  - Required pendant cleaning tool in the slice starting kit.

- `[ ]` **P1.6 Test model and loader contracts.**
  - Valid fixtures load.
  - Missing/duplicate IDs fail.
  - Broken references fail.
  - Round-trip serialization preserves fields and types.

### Acceptance

- [ ] No artifact-specific value is hardcoded in gameplay logic.
- [ ] All slice fixtures load from data and pass validation.
- [ ] Cross-system events compile with typed payloads.
- [ ] A fixed seed produces the same test random sequence.

### Verification

```powershell
godot --headless --editor --path . --quit
godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/models
```

---

## Phase 2 - Clock, Loop, and Persistence

**Goal:** implement the real five-day loop and exact persistence split.

**Requirements:** SAVE-R1..R6, CLOCK-R1..R5
**Dependencies:** Phase 1
**Subsystems:** clock, loop controller, state, save service

### Tasks

- `[ ]` **P2.1 Build `DayClock`.**
  - Default to 60 real seconds per in-game hour.
  - Start Day 1 at 07:00 and close each day after 20:00.
  - Expose day, hour, loop index, running state, and debug speed.
  - Emit hour/day signals exactly once per transition.

- `[ ]` **P2.2 Add pause ownership.**
  - Full-screen systems request pause using a stable owner ID.
  - Use a set/reference count so one screen cannot resume a clock paused by another.
  - Dialogue, restoration, scanner, triage, journal, and Portal overlays release their pause on close.

- `[ ]` **P2.3 Build `LoopController`.**
  - Advance Day 1 through Day 5.
  - At Day 5 close, save persistent progress, clear loop state, increment loop index, and restart Day 1 at 07:00.
  - Do not clear seated fragments or spawn history.

- `[ ]` **P2.4 Implement the save split.**
  - Serialize the exact persistent and loop fields listed in Stable Interfaces.
  - Validate loaded values and recover from missing optional fields.
  - Never copy loop inventory into persistent state.

- `[ ]` **P2.5 Implement atomic save writes.**
  - Write and parse-check `user://save.tmp`.
  - Replace `user://save.json` only after validation.
  - Retain or report the previous valid save when replacement fails.

- `[ ]` **P2.6 Test reset behavior.**
  - Seed both state sections.
  - Trigger a Day 5 reset.
  - Assert persistent values survive and every loop-scoped value resets.
  - Assert a seated fragment never returns to `RELEASED`.

### Acceptance

- [ ] A normal day lasts about 13 real minutes.
- [ ] A five-day loop lasts about one hour without pauses.
- [ ] Reset returns to Day 1, 07:00 with the correct state split.
- [ ] Save interruption cannot replace a valid save with partial JSON.

### Verification

```powershell
godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/core
```

Manual: run with `seconds_per_hour = 0.1`, pause from two owners, release them separately, and observe one complete reset.

---

## Phase 3 - Delivery and Triage

**Goal:** generate real morning deliveries and force meaningful keep/recycle choices.

**Requirements:** DLV-R1..R5, ARCH-R5
**Dependencies:** Phases 1-2
**Subsystems:** delivery generator, 3D placement anchors, 2D triage UI

### Tasks

- `[ ]` **P3.1 Build weighted delivery generation.**
  - Draw templates by apparent rarity weights.
  - Create unique `ObjectInstance` IDs.
  - Clamp batch size to the configured cap.
  - Inject due carrier instances without replacing their ordinary template identity.

- `[ ]` **P3.2 Add shop placement anchors.**
  - Author stable IDs for piles, shelves, and outer containers in the 3D shop.
  - Store compatibility tags and capacity in data/resources.
  - Keep visual nodes separate from placement logic.

- `[ ]` **P3.3 Implement the fixed glow legend.**
  - White, Green, Blue, Purple, Gold, and Flickering only.
  - Glow represents appearance, not truth.
  - Carrier flicker remains hidden until the Echo phase authorizes it.

- `[ ]` **P3.4 Build the 2D triage interface.**
  - Show each object, apparent rarity, container/pile, and storage cost.
  - Enforce a storage-slot cap.
  - Require an explicit keep/recycle decision before completion.
  - Support mouse-first input and readable 1920x1080 scaling.

- `[ ]` **P3.5 Apply triage results.**
  - Kept instances enter loop inventory.
  - Recycled instances are removed from the loop and cannot be restored later.
  - A carrier may be recycled; the released fragment remains eligible for placement next loop.
  - Persist neglect history used by the Spawn Director.

- `[ ]` **P3.6 Test delivery invariants.**
  - Batch sizes and weights remain within configured bounds.
  - Unique IDs never collide.
  - Due carriers appear on the assigned day.
  - Recycled instances are inaccessible after triage.

### Acceptance

- [ ] A morning delivery is generated from JSON templates.
- [ ] The player can keep only the configured number of objects.
- [ ] All six fixed visual states display correctly without adding a new rarity.
- [ ] Director-selected instances appear at the correct shop anchor/day.

### Verification

```powershell
godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/delivery
```

Manual: start three debug days and confirm batch, glow, keep/recycle, and anchor placement behavior.

---

## Phase 4 - Restoration and Pendant Carrier

**Goal:** deliver one complete, skill-based clean-to-open interaction.

**Requirements:** REST-R1, REST-R3, REST-R4, REST-R7, DISC-R12, DISC-R13
**Dependencies:** Phases 1 and 3
**Subsystems:** restoration UI, tool rules, openable/carrier logic

### Tasks

- `[ ]` **P4.1 Build the pendant cleaning mini-game.**
  - Open as a paused 2D full-screen interface over the 3D shop.
  - Let the player select the cleaning tool and apply controlled strokes/actions.
  - Increase condition from authored tuning rather than a luck roll.
  - Provide visual progress and a clear completion threshold.

- `[ ]` **P4.2 Implement tool consequences.**
  - Correct tool increases condition/value within tuned bounds.
  - Wrong tool reduces condition or permanent value and records the damage.
  - Prevent condition from exceeding 100 or dropping below 0.

- `[ ]` **P4.3 Implement the clean gate.**
  - Dirty openables reject Open with a clear player-facing reason.
  - Completing restoration transitions only that instance to `CLEAN`.
  - Carrier status does not bypass the gate.

- `[ ]` **P4.4 Build the pendant clasp interaction.**
  - Make clasp opening distinct from cleaning.
  - Allow it only for clean pendant instances.
  - Transition the instance to `OPEN` once.

- `[ ]` **P4.5 Implement general open results.**
  - Resolve `EMPTY`, `TEMPORAL_ECHO`, or `FRAGMENT` from instance content state.
  - Only a Director-promoted carrier can produce `FRAGMENT`.
  - Ordinary pendants use the same template and scene as the carrier.

- `[ ]` **P4.6 Test restoration and opening.**
  - Dirty carrier cannot open.
  - Correct tool reaches clean state.
  - Wrong tool causes persistent instance damage.
  - Non-carrier pendant cannot produce a fragment.
  - Reopening cannot duplicate content.

### Acceptance

- [ ] Pendant clean -> clasp open -> result works end to end.
- [ ] Wrong-tool use has visible and recorded consequences.
- [ ] Carrier is an injected role, not a special pendant type.

### Verification

```powershell
godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/restoration
```

Manual: restore one ordinary pendant and one promoted pendant, including one wrong-tool attempt.

---

## Phase 5 - Spawn Director

**Goal:** implement genuine, deterministic, auditable fragment placement.

**Requirements:** DISC-R1..R6, SAVE-R3, CLAUDE.md §4-B/C/H
**Dependencies:** Phases 1-4
**Subsystems:** placement candidates, weighting, history, demo audit

### Tasks

- `[ ]` **P5.1 Build candidate enumeration.**
  - Find ordinary openable instances compatible with the fragment.
  - Pair each candidate with eligible outer containers and days.
  - Exclude seated fragments and fragments not in `RELEASED`.

- `[ ]` **P5.2 Apply hard filters.**
  - Reject unavailable required tools.
  - Reject container incompatibility and over-capacity.
  - Reject locked locations the player cannot open that run.
  - Treat the known Safe code as eligibility for the Safe outer container only.

- `[ ]` **P5.3 Apply weighted scoring.**
  - Add neglect weight from player behavior.
  - Add day-spread weight to avoid always selecting the same day.
  - Keep tuning values in data/config.

- `[ ]` **P5.4 Enforce never-twice history.**
  - Exclude every prior `(carrier_template_id, container_id)` pair for the fragment.
  - If all valid pairs are exhausted, soft-reset by forbidding only the most recent pair.
  - Record whether a soft reset occurred.

- `[ ]` **P5.5 Promote the selected instance.**
  - Set `is_carrier`, `fragment_id`, and content result on the runtime instance.
  - Do not change its base template, apparent rarity, or normal restoration rules.
  - Save the selected pair to persistent history.

- `[ ]` **P5.6 Add deterministic audit output.**
  - Use the run-local RNG and seed.
  - Write the log shape defined in Stable Interfaces.
  - Add a debug command/menu that generates three runs for the same fragment/player.

- `[ ]` **P5.7 Test placement guarantees.**
  - Fixed seed repeats exactly.
  - Different seeds produce valid variation.
  - Three runs do not repeat a pair.
  - Exhaustion triggers only the documented soft reset.
  - Unobtainable-tool candidates are never selected.

### Acceptance

- [ ] Three recorded runs show different carrier/container/day combinations.
- [ ] No prior pair repeats before candidate exhaustion.
- [ ] Every selected placement is winnable.
- [ ] No fragment appears loose in a pile, Safe, or container.

### Verification

```powershell
godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/discovery/spawn_director
```

Manual: run the three-seed demo and retain its placement log for the submission evidence folder.

---

## Phase 6 - Cultural Echoes

**Goal:** guide the player to the exact carrier through accessible audio/visual cues.

**Requirements:** DISC-R7..R11, CLAUDE.md §4-E/I
**Dependencies:** Phase 5 and a navigable Shop scene
**Subsystems:** audio buses, proximity service, resonance UI, captions

### Tasks

- `[ ]` **P6.1 Configure four audio layers.**
  - Hum, Melody, Voice, and Heartbeat use separate players/buses.
  - Source files are original, disclosed, and data-selected by `EchoSet`.
  - Start layers synchronized so crossfades do not restart clips.

- `[ ]` **P6.2 Compute normalized proximity.**
  - Measure the active player/focus position to the active carrier anchor.
  - Map distance to `0.0..1.0` using authored near/far radii.
  - Smooth changes to prevent meter and volume jitter.

- `[ ]` **P6.3 Implement additive band mixing.**
  - Hum: 0.00-0.30.
  - Melody: 0.30-0.60.
  - Voice: 0.60-0.85.
  - Heartbeat: 0.85-1.00.
  - Use crossfades and clamps; keep thresholds configurable.

- `[ ]` **P6.4 Enforce silence and heartbeat gates.**
  - Stop/silence Echoes when no released, unfound carrier is in the current scene.
  - Heartbeat volume remains impossible for non-carriers.
  - Clear the active target after discovery/seating.

- `[ ]` **P6.5 Reveal carrier confirmation.**
  - Keep carrier Flickering hidden below `GLOW_REVEAL_AT = 0.60`.
  - Reveal only the promoted carrier's flicker at/above threshold.
  - Pulse carrier and resonance meter with Heartbeat near the target.

- `[ ]` **P6.6 Build accessible 2D feedback.**
  - Resonance meter mirrors normalized proximity.
  - Captions name each active band and voice line.
  - The mechanic remains understandable with master audio muted.

- `[ ]` **P6.7 Test all gates and thresholds.**
  - Boundary values select/mix the expected bands.
  - Decoys never emit Heartbeat.
  - Empty scenes remain silent.
  - Discovery stops the active Echo target.

### Acceptance

- [ ] Following cues leads to the exact carrier.
- [ ] Heartbeat never fires on a decoy.
- [ ] Captions and meter make the sequence playable without audio.
- [ ] Audio leads; flicker confirms only from 0.60 proximity.

### Verification

```powershell
godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/discovery/echoes
```

Manual: complete one discovery with audio, then repeat muted using only captions and the resonance meter.

---

## Phase 7 - Cached Scanner

**Goal:** ship the P0 advisory scanner using offline-safe cached responses.

**Requirements:** SCAN-R1, SCAN-R2, SCAN-R4, SCAN-R5
**Dependencies:** Phases 1 and 4; final backend wiring in Phase 8
**Subsystems:** scanner UI, client service, cache fixtures, verdict state

### Tasks

- `[ ]` **P7.1 Define `ScannerService`.**
  - Accept an `ObjectInstance` payload matching PRD §20.
  - Return the same typed response model for fixture and HTTP transports.
  - Keep endpoint/base URL in config, never in scene logic.

- `[ ]` **P7.2 Add cached slice responses.**
  - Create a response for every slice object.
  - Include type, period, materials, markings, condition note, cultural relevance, price range, and modification signs.
  - Cite verified source references in data metadata for cultural/historical facts.

- `[ ]` **P7.3 Build the 2D scanner interface.**
  - Show the object and every advisory field.
  - Visually separate scanner annotations from journal notes.
  - Provide loading, success, fallback, and malformed-response states.

- `[ ]` **P7.4 Require a player verdict.**
  - Present `AUTHENTIC`, `REPLICA`, `MODIFIED`, and `UNCERTAIN`.
  - Never auto-select or overwrite the verdict from scanner output.
  - Store the player's choice in the object/journal record.

- `[ ]` **P7.5 Test advisory behavior.**
  - Cached responses parse through the production response model.
  - Scanner fields cannot set authenticity.
  - Player verdict persists.
  - Missing cache produces a controlled error/fallback state.

### Acceptance

- [ ] A cleaned slice object can be scanned offline.
- [ ] All required evidence fields display.
- [ ] The player must choose the final verdict.
- [ ] No API key exists in the Godot project.

### Verification

```powershell
godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/scanner
```

Manual: scan one normal and one suspicious fixture, then choose different verdicts than the suggested interpretation.

---

## Phase 8 - Backend, Mock Portal, and Found Flow

**Goal:** complete the backend-only scanner/Portal boundary and resilient P0 discovery flow.

**Requirements:** ARCH-R1..R3, PORT-R1..R5, API-R1..R3, SCAN-R4
**Dependencies:** Phases 1, 5, and 7
**Subsystems:** Express server, mock Portal, Godot HTTP client, Found/Unlock UI

### Tasks

- `[ ]` **P8.1 Scaffold `server/`.**
  - Add Express, environment validation, JSON size limits, request validation, rate limiting, and tests.
  - Add `.env.example` with `PORTAL_BASE_URL`, timeouts, and placeholder keys.
  - Keep controllers thin; put scan/Portal logic in services.

- `[ ]` **P8.2 Implement cached `POST /api/scan`.**
  - Validate the PRD §20 payload.
  - Return the cached response for P0.
  - Preserve the service boundary for a P1 live LLM implementation.
  - Rate-limit even though the current response is cached.

- `[ ]` **P8.3 Scaffold `mock-portal/`.**
  - Implement `POST /discovery` with the response shape in PRD §20.
  - Return deterministic fact cards for test fragment IDs.
  - Support idempotent repeated requests.

- `[ ]` **P8.4 Implement server Portal proxy.**
  - Validate discovery payloads.
  - Add `player_id:fragment_id` idempotency.
  - Apply timeout and cached fallback.
  - Select mock/live base URL from environment only.

- `[ ]` **P8.5 Build Godot Portal client.**
  - Call only the backend `/api/portal/discovery`.
  - Expose success, fallback, and validation failures through typed signals.
  - Do not seat a fragment before a success/fallback completion event.

- `[ ]` **P8.6 Build Found and Unlock screens.**
  - Artifact Found: render, name, origin, condition, and `n/5`.
  - Loading state while the backend request is active.
  - Portal Unlock: fact card, fallback indicator when applicable, and continue action.
  - Make repeated clicks/retries unable to duplicate records or fragments.

- `[ ]` **P8.7 Test resilience.**
  - Valid mock request succeeds.
  - Invalid payload returns a controlled 4xx.
  - Timeout returns cached fallback.
  - Duplicate request returns the same museum entry ID.
  - Changing `PORTAL_BASE_URL` requires no code change.

### Acceptance

- [ ] Godot never calls an external LLM or Portal directly.
- [ ] Found -> backend -> mock Portal -> Unlock completes.
- [ ] Timeout/offline mode still returns a fact and completes the flow.
- [ ] Duplicate submission cannot duplicate a museum record.

### Verification

```powershell
Push-Location mock-portal
npm test
Pop-Location

Push-Location server
npm test
Pop-Location

godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/portal
```

Manual: run success, forced-timeout fallback, and duplicate-click scenarios.

---

## Phase 9 - Journal and Fragment Case

**Goal:** persist restoration knowledge, Portal records, and permanent fragment seating.

**Requirements:** JRN-R1..R5, MUS-R2 P0 record, SAVE-R2
**Dependencies:** Phases 2, 4, 7, and 8
**Subsystems:** journal UI, archive routing, fragment case, save integration

### Tasks

- `[ ]` **P9.1 Build the full-screen 2D journal.**
  - Pause through the clock ownership API.
  - Provide first-page Fragment Case and object-entry navigation.
  - Support mouse-first controls and readable scaling.

- `[ ]` **P9.2 Implement journal entry updates.**
  - Create an entry after first restoration.
  - Update best condition, verdict, scanner annotations, and later sale data without duplicating entries.
  - Keep uncle notes visually distinct from scanner annotations.

- `[ ]` **P9.3 Route archives by rarity.**
  - Purple-and-below goes to Journal entries.
  - Gold and Master Artifact discoveries produce persisted `MuseumEntry` records.
  - The polished gallery remains P1.

- `[ ]` **P9.4 Build the five-slot case.**
  - Map stable fragment IDs to stable slot indices from artifact data.
  - Show empty, pending-discovery, and seated states.
  - Reject duplicate seating.

- `[ ]` **P9.5 Implement the seating transaction.**
  - Receive `portal_completed`.
  - Persist the museum record and fragment `SEATED` state together.
  - Emit `fragment_seated` after a successful atomic save.
  - Clear active Echo/carrier state and prevent future respawn.

- `[ ]` **P9.6 Test persistence and routing.**
  - Purple item creates Journal entry only.
  - Gold discovery creates Museum entry.
  - Seated slot survives a loop reset and application restart.
  - Seated fragment is excluded from Spawn Director candidates.

### Acceptance

- [ ] Restoring/scanning updates one stable journal entry.
- [ ] Portal completion fills exactly one persistent case slot.
- [ ] A reset and reload preserve the slot.
- [ ] Archive routing follows the fixed rarity rule.

### Verification

```powershell
godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/journal
```

Manual: seat the demo fragment, restart the game, trigger a loop reset, and confirm it remains seated and cannot respawn.

---

## Phase 10 - Auntie Showcase and Vertical Slice Integration

**Goal:** connect the emotional showcase to the real loop without bypassing discovery.

**Requirements:** slice summary, CLOCK-R4 behavior where applicable, ROUTE-R3 invariant, all P0 integration
**Dependencies:** Phases 2-9
**Subsystems:** authored dialogue, visitor scheduling, scripted photo beat, slice orchestration

### Tasks

- `[-]` **P10.1 Preserve and migrate the existing Auntie prototype.**
  - Existing dialogue box, visitor placeholder, and sample lines are usable scaffolding.
  - Move lines out of shop controllers into `data/routes/auntie.json`.
  - Keep the controller responsible for flow, not prose.

- `[ ]` **P10.2 Implement visit scheduling.**
  - Offer Auntie from 12:00-14:00 on Days 1, 3, and 5.
  - Consume an unanswered visit when the window closes.
  - Add an explicit debug/demo override that is excluded from normal progression.

- `[ ]` **P10.3 Build the scripted photograph showcase.**
  - Present a short authored interaction using the existing dialogue UI and 2D overlays.
  - Treat it as an emotional showcase, not a second full restoration mini-game.
  - Record route completion/reward state without directly granting a fragment.

- `[ ]` **P10.4 Release the route fragment correctly.**
  - Transition the assigned fragment from `LOCKED` to `RELEASED`.
  - Let the Spawn Director place it in a later/current eligible delivery according to data.
  - Do not put the fragment in Auntie's handoff or dialogue reward.

- `[ ]` **P10.5 Connect the complete P0 path.**
  - Start Shop -> morning delivery -> triage.
  - Follow Echoes to the carrier.
  - Keep the pendant -> clean -> scan and judge -> clasp open.
  - Show Artifact Found -> backend/mock Portal -> Portal Unlock.
  - Persist Museum record -> seat fragment -> show 1/5 case.

- `[ ]` **P10.6 Add a slice reset/demo menu.**
  - Select a debug seed.
  - Clear only demo save data with an explicit confirmation.
  - Start the three placement runs without editing production data.

### Acceptance

- [ ] Auntie content is data-authored and appears only in its window without debug override.
- [ ] Route completion releases rather than hands over a fragment.
- [ ] The full P0 flow completes without console intervention.
- [ ] One journal slot fills and remains filled after reload.

### Verification

Manual only after all automated phase tests pass: record one uninterrupted end-to-end slice playthrough.

---

## Phase 11 - QA, Export, and Submission

**Goal:** prove the slice is stable, accessible, offline-safe, and recordable.

**Requirements:** PRD §22.3, §12-13 acceptance, milestone evidence
**Dependencies:** Phases 0-10
**Subsystems:** automated QA, export, accessibility, video evidence, disclosure

### Tasks

- `[ ]` **P11.1 Complete automated coverage.**
  - GUT: save split, reset, state machines, delivery, restoration gate, placement, never-twice, Echo gates, scanner verdict, archive routing, seating.
  - Backend: validation, rate limit, timeout fallback, idempotency, config swap.
  - Add regression tests for every fixed P0 bug.

- `[ ]` **P11.2 Run static and import checks.**
  - Godot 4.6.3 editor import.
  - GUT suite.
  - gdformat check and gdlint.
  - Backend and mock Portal tests.
  - Resolve all errors and review warnings.

- `[ ]` **P11.3 Test accessibility and display.**
  - Mouse-only navigation.
  - Muted-audio discovery using captions/meter.
  - 1920x1080 reference layout and smaller-window scaling.
  - Readable contrast and visible focus/hover states.

- `[ ]` **P11.4 Test resilience.**
  - Backend online against mock Portal.
  - Backend timeout with cached fallback.
  - Backend unavailable with a clear recoverable client state.
  - Save/reload before and after Portal completion.

- `[ ]` **P11.5 Produce exports.**
  - Configure and test Windows export first.
  - Configure HTML5 separately.
  - Record unsupported HTML5 features or renderer differences instead of assuming parity.
  - Ensure exports contain no development credentials or debug-only reset controls.

- `[ ]` **P11.6 Record placement evidence.**
  - Capture three runs for the same fragment/player.
  - Show different carrier/container/day output.
  - Retain the seed/placement logs matching the footage.

- `[ ]` **P11.7 Record discovery evidence.**
  - Show all four Echo bands with captions and resonance meter.
  - Show Heartbeat only on the carrier.
  - Show clean -> open -> Artifact Found.

- `[ ]` **P11.8 Record Portal evidence.**
  - Show backend/mock request completion.
  - Show Portal Unlock historical fact.
  - Show persisted Museum record and the case moving to 1/5.

- `[ ]` **P11.9 Finalize disclosure and submission package.**
  - Review every AI-assisted commit and asset.
  - Update `docs/ai-disclosure.md`.
  - Confirm public repository history, video, artifact/lore materials, and required forms.

### Acceptance

- [ ] All standard verification commands pass under Godot 4.6.3.
- [ ] Windows build completes the full slice offline/fallback-safe.
- [ ] The three required video beats are clear and backed by logs.
- [ ] AI disclosure and cultural review notes are complete.

---

## Phase 12 - Finalist P1 and Polish P2

**Goal:** expand the proven P0 architecture without weakening its invariants.

**Dependencies:** Phase 11 slice baseline
**Subsystems:** economy, routes, content, museum, endings, polish

### P1 Backlog

- `[ ]` **P12.1 Full tools/techniques and restoration set:** SAVE-R5, REST-R2, REST-R5, REST-R6.
- `[ ]` **P12.2 Live verified scanner:** SCAN-R3, SCAN-R6.
- `[ ]` **P12.3 Marketplace AI and economy:** MKT-R1..R5.
- `[ ]` **P12.4 Full journal mystery progression:** JRN-R4.
- `[ ]` **P12.5 Polished online museum/gallery:** MUS-R1, MUS-R2 gallery portion, MUS-R4.
- `[ ]` **P12.6 All character schedules and route logic:** CLOCK-R4, ROUTE-R1..R6.
- `[ ]` **P12.7 Temporal Echo memories:** TEMP-R1..R4.
- `[ ]` **P12.8 At least two mini-events:** EVT-R1, EVT-R2.
- `[ ]` **P12.9 Safe and locked drawer:** CACHE-R1..R3.
- `[ ]` **P12.10 Character endings and Yuyu finale:** END-R1..R5.
- `[ ]` **P12.11 Remaining carrier opening interactions and live Portal config swap.**

### P2 Backlog

- `[ ]` **P12.12 Event frequency/cap tuning:** EVT-R3.
- `[ ]` **P12.13 Suspicious Buyer route depth:** MKT-R6.
- `[ ]` **P12.14 In-game museum mirror:** MUS-R3.
- `[ ]` **P12.15 Clock-consumption and pause polish:** CLOCK-R5 using the P0 default that full-screen interfaces pause time.
- `[ ]` **P12.16 Additional accessibility, animation, audio, lighting, controller, touch, and exhibit polish.**

### Final Acceptance

- [ ] Every P1/P2 requirement has tests or a documented manual acceptance case.
- [ ] All five fragments follow `LOCKED -> RELEASED -> SEATED`.
- [ ] The Buyer and Safe never bypass carrier placement, cleaning, opening, or seating.
- [ ] Seating the fifth persistent fragment triggers the Yuyu finale.

---

## P0 Requirement Coverage

| Requirement group | Phase | Current status |
|---|---:|---|
| ARCH-R1..R5 | 0, 1, 8 | Phase 0 done (toolchain, signals/ARCH-R4, layout); Phase 1/8 not started |
| SAVE-R1..R3, SAVE-R6 | 2, 5, 9 | Not started |
| CLOCK-R1..R3 | 2 | Placeholder only |
| DLV-R1..R3, DLV-R5 | 3 | Not started |
| REST-R1, R3, R4, R7 | 4 | Not started |
| SCAN-R1, R2, R4, R5 | 7, 8 | Not started |
| JRN-R1..R3, JRN-R5 | 9 | Not started |
| DISC-R1..R13 | 4, 5, 6 | Not started |
| PORT-R1..R5 | 8, 9 | Not started |
| MUS-R2 P0 record | 8, 9 | Not started |
| API-R1..R3 | 8 | Not started |
| Auntie slice showcase | 10 | Placeholder only |
| Submission evidence | 11 | Not started |

## Complete Requirement Index

This index names every current PRD requirement explicitly so no feature disappears behind a phase summary.

- **Phase 0-1 architecture:** ARCH-R1, ARCH-R2, ARCH-R3, ARCH-R4, ARCH-R5.
- **Phase 2 core loop/save:** SAVE-R1, SAVE-R2, SAVE-R6, CLOCK-R1, CLOCK-R2, CLOCK-R3.
- **Phase 3 delivery:** DLV-R1, DLV-R2, DLV-R3, DLV-R5.
- **Phase 4 restoration/opening:** REST-R1, REST-R3, REST-R4, REST-R7, DISC-R12, DISC-R13.
- **Phase 5 placement:** SAVE-R3, DISC-R1, DISC-R2, DISC-R3, DISC-R4, DISC-R5, DISC-R6.
- **Phase 6 Echoes:** DISC-R7, DISC-R8, DISC-R9, DISC-R10, DISC-R11.
- **Phase 7-8 scanner:** SCAN-R1, SCAN-R2, SCAN-R4, SCAN-R5.
- **Phase 8 Portal/backend:** PORT-R1, PORT-R2, PORT-R3, PORT-R4, PORT-R5, API-R1, API-R2, API-R3.
- **Phase 9 archives:** JRN-R1, JRN-R2, JRN-R3, JRN-R5, MUS-R2.
- **Phase 10 slice route integration:** ROUTE-R3.
- **Phase 12 persistence/scheduling:** SAVE-R4, SAVE-R5, CLOCK-R4, CLOCK-R5, DLV-R4.
- **Phase 12 restoration/scanner:** REST-R2, REST-R5, REST-R6, SCAN-R3, SCAN-R6.
- **Phase 12 marketplace:** MKT-R1, MKT-R2, MKT-R3, MKT-R4, MKT-R5, MKT-R6.
- **Phase 12 journal/museum:** JRN-R4, MUS-R1, MUS-R3, MUS-R4.
- **Phase 12 routes:** ROUTE-R1, ROUTE-R2, ROUTE-R4, ROUTE-R5, ROUTE-R6.
- **Phase 12 Temporal Echoes/events:** TEMP-R1, TEMP-R2, TEMP-R3, TEMP-R4, EVT-R1, EVT-R2, EVT-R3.
- **Phase 12 caches/endings:** CACHE-R1, CACHE-R2, CACHE-R3, END-R1, END-R2, END-R3, END-R4, END-R5.

## Update Procedure

When implementation lands:

1. Run the task's automated verification.
2. Perform its manual acceptance check.
3. Change only that task's marker.
4. Add a short evidence line with test command, date, and commit hash.
5. Update the P0 coverage table if the group status changed.
6. Update `CLAUDE.md` commands/layout only when architecture actually changes.
7. Update `docs/PRD.md` requirement wording only through an explicit design decision; never silently change an invariant.
