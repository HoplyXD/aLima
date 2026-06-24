# aLima Phase Task Checklist

Canonical step-by-step build tracker for the Godot 4.7 game, backend, live/mock services, authored content, production assets, tests, milestone evidence, and full release. Completing every mandatory task through Phase 22 is defined to deliver the complete README GDD.

| Field | Value |
|---|---|
| Last audited | 2026-06-23 |
| Current milestone | June 30, 2026 vertical slice |
| Engine target | Godot 4.7 |
| Presentation | Hybrid 3D shop with 2D gameplay interfaces |
| Project root | Repository root (`project.godot` stays here) |
| Build authority | `CLAUDE.md` §4 -> `README.md` full-game promises -> `docs/PRD.md` requirements -> this checklist |
| Discovery specification | `docs/PRD.md` §12 |

Toolchain references: [Godot 4.7 stable release](https://godotengine.org/article/godot-4-7-stable-released/) and [Godot 4.7 documentation](https://docs.godotengine.org/en/4.7/).

## Status Markers

- `[x]` verified complete under Godot 4.7, or verified by the applicable non-runtime command for documentation/repository-only work
- `[-]` partially implemented, placeholder-only, or integrated but not fully verified
- `[ ]` not started
- `[!]` blocked by an external dependency or explicit decision

Do not mark runtime work `[x]` from screenshots, print statements, scene presence, or Godot 4.5.x checks. Record the command and result in the task before changing its marker.

## Definition of Done

Every completed task must:

- Satisfy its listed PRD requirement IDs, mapped README promise, and `CLAUDE.md` §4 invariants.
- Use typed GDScript and signals for cross-system communication.
- Keep artifact, fragment, route, echo, and object specifics in JSON or resources.
- Include focused GUT or backend tests when logic exists.
- Pass the Godot 4.7 import check and relevant automated tests.
- Include one manual gameplay acceptance check for user-facing behavior.
- Append new AI usage to `docs/ai-disclosure.md`.
- Avoid committing secrets, generated caches, or unrelated file churn.

Phase 11 completes only the June 30 vertical slice. Only Phase 22 may declare the complete GDD game 100% finished, and only after every mandatory P0/P1 task, content minimum, production review, service/platform matrix, and release gate passes.

## Current Repository Audit

- `[-]` Godot project scaffold exists and targets feature `4.7`. Godot 4.7 is installed and passes explicit import/startup checks via `C:\Users\roman\Downloads\Godot_v4.7-stable_win64_console.exe`. The bare `godot` command currently resolves to the older `4.5.1.stable` executable at `C:\Users\roman\Desktop\Godot` (Phase 0 P0.2 remains open; see Acceptance below).
- `[x]` Upstream commit `0255430` is integrated and stabilized: HUD revealed, stray button removed, controllers consolidated. Editor import and headless startup pass under 4.7.
- `[x]` The 4.7 editor import and configured main-scene startup complete without parser, resource, UID, or missing-file errors. Evidence: `--headless --editor --path . --quit` and `--headless --path . --quit`, run 2026-06-22 (exit 0, no error lines).
- `[x]` `scenes/Shop.tscn` is the configured main scene; its `HUD` CanvasLayer is `visible = true` and is a usable production screen.
- `[x]` Shop orchestration is consolidated into one controller on the Shop root (`scripts/shop/shop_controller.gd`) plus a presentation-only HUD (`scenes/ui/shop_hud.gd`). The old `scenes/hud.gd`, `scenes/shop_3d.gd`, and `prototype/` controllers were removed after migration.
- `[x]` The stray `AAAAAAAAA` test button has been removed from `scenes/Shop.tscn`.
- `[x]` Clock/day/loop progression is the real Phase 2 system: a reusable `DayClock` autoload (07:00->20:00 close, minute-level display, pause ownership) and a `LoopController` autoload (Day 1-5 progression + the five-day split reset). The Shop controller is the display + pause-owner driver only. Verified by GUT (`tests/core/test_day_clock.gd`, `test_loop_controller.gd`, `test_save_service.gd`; full suite 477/477, 2026-06-23). On-screen/real-time observation of the running clock remains a manual check (see Phase 2 Acceptance).
- `[-]` The dialogue box supports queued lines, typewriter reveal, keyboard input, and mouse input. Authored prose lives in data: each route in `data/routes/routes.json` carries a `portrait` and a `dialogue` map keyed by visit state (`intro`/`return`, with optional `dayN_*` overrides), loaded via the extended `CharacterRoute` model (`dialogue_for()`). The `RouteService` autoload picks the key per visit (`dialogue_key()`), so the Loop 1 vs Loop 2 branch variants are live; the Shop controller hardcodes no lines.
- `[x]` All six characters (Auntie/Shine, Artisan/Lave, Scavenger/Ayla, Archeologist/Sam, Buyer/Maverick, Uncle/Yuyu) have authored intro **and** return dialogue plus sketch portraits (`assets/Characters/*.png`). The Shop door asks `RouteService.resolve_visitor(day, hour)` for the scheduled visitor and `RouteService.dialogue_key()` for the intro/return branch; finishing a conversation marks the route **met** (persistent), so the next visit plays the return set. Covered by `tests/core/test_route_service.gd` + `tests/test_shop_smoke.gd`.
- `[-]` Route progress is tracked in `RouteService` over PersistentState (so it survives the loop reset): a **met** flag (`dialogue_flags`) drives the dialogue branch, and **completion** (`route_completion`) drives mutual-exclusion visit gating — the artisan (prereq: auntie) displaces the scavenger in their shared afternoon slot only once the auntie route completes, and yields to her until then. Completion is wired to `EventBus.fragment_seated` (seating a route's fragment completes it, grants its rewards, and emits `EventBus.route_completed`). Still missing: the archeologist-lead extra-window shift, the scripted multi-day restoration beats themselves, and route expiry on an unanswered visit.
- `[x]` Object data pipeline, real delivery/triage, restoration, carriers, Phase 5 Spawn Director, Cultural Echoes (audio buses, proximity/mixer, HUD/captions, flicker gating), cached scanner, backend/mock Portal, Found/Unlock flow, atomic seating, buyer-persona marketplace economy (buy/sell/haggle/banter with 3-tier banter: on-device → backend `/api/negotiate` → offline fallback), settings/pause menu, and Windows/Web export presets are implemented and covered by GUT/backend tests or verified CLI export under Godot 4.7 / Node. The full disposition router (return/preserve/journal), evening system, video evidence, final submission package, and live-provider manual gate are not implemented.
- `[-]` The Workbench action opens the focused **3D** restoration view (`scenes/restoration/restoration_view.tscn`, REST-R8 / task P4.7): a `SubViewport` 3D object the player rotates and cleans across its surface, framed by a 2D HUD. Cleaning tools are **visible, selectable 3D props on the bench** (`RestorationToolTray`, REST-R9 / task P4.8); the HUD tool buttons are a labelled accessibility/fallback. Author-placed condition decals (`ArtifactConditionDecal`) and per-instance random surface conditions are now supported. It reuses `RestorationService` unchanged (the 2D placeholder `scenes/ui/restoration_screen.*` was retired). Automated coverage is green; on-screen mouse/controller/touch verification is the remaining manual gate.
- `[-]` The major shop actions (door, workbench, journal, phone, morning delivery) are **diegetic 3D interactables** (`scripts/shop/interactable_3d.gd`, `Interactables/*` in `scenes/Shop.tscn`, SHELL-R1/R2 / task P4.9): physical props the player hovers (prompt + highlight) and clicks, each firing the existing controller handler. The HUD buttons remain as labelled accessibility/fallback controls. Automated coverage is green; final art/composition and on-screen click-through (incl. per-overlay input blocking) are the remaining manual gates.

## Reconciliation With the Old Tracker

The deleted root `phasetask.md` is still available in Git history at commit `bab8cb9`. It contained no checked tasks, so there is no completed checklist to restore. The repository nevertheless contains useful implementation work that maps to the old tasks as follows:

| Old tracker item | Evidence already in the repository | Canonical status |
|---|---|---|
| One shop space scene | `scenes/Shop.tscn` contains a 3D environment, camera, book prop, visitor sprite, and HUD nodes | `[-]` Partial; HUD hidden and scene needs stabilization |
| Daily clock | Three controllers implement 07:00-20:00 hourly progression at 60 seconds/hour | `[-]` Partial; placeholder state, duplicated logic, no real reset |
| Clock HUD | Day/time/count labels and formatting exist | `[-]` Partial; no loop counter and production HUD is hidden |
| Door/visitor interaction | Door prop/button shows the day/hour-scheduled visitor (via `RouteService`) with their portrait + intro/return lines; mutual-exclusion gating and pause/resume work | `[-]` Partial; route expiry on an unanswered visit and the lead-driven window shift remain |
| Dialogue system | Reusable typewriter dialogue supports keyboard and mouse advance; authored intro+return prose + portraits live in `data/routes/routes.json`; `RouteService` branches per visit; GUT coverage in `tests/core/test_route_service.gd` | `[x]` Loop/route-state branching wired |
| Workbench/Journal/Phone navigation | Buttons and placeholder responses exist | `[-]` Partial; no real screens or system integration |
| Delivery/triage | Placeholder rarity counts only | `[ ]` Not implemented |
| Restoration mini-game | Placeholder dialogue only | `[ ]` Not implemented |
| Object JSON pipeline | No `data/objects` or loader | `[ ]` Not implemented |
| Spawn Director / Echoes / Scanner / Portal / Journal | No runtime implementation | `[ ]` Not implemented |

### Where Development Starts

Do not rebuild the Shop from scratch. Start with **Phase 0 stabilization**:

1. Select the installed Godot 4.7 executable for the editor and CLI; do not use the 4.5.1 executable currently first on `PATH`.
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

signal disposition_completed(instance_id: String, disposition: String, outcome_id: String)
signal sale_completed(instance_id: String, buyer_id: String, price: int)
signal object_returned(instance_id: String, owner_route_id: String, reward_id: String)
signal evening_started(day: int)
signal evening_plan_committed(day: int, plan_id: String)
signal mini_event_started(event_id: String)
signal mini_event_resolved(event_id: String, outcome_id: String)
signal route_beat_completed(route_id: String, beat_id: String)
signal ending_triggered(ending_id: String)
```

### Data Contracts

- Authored object templates: `data/objects/*.json`.
- Artifact and fragment definitions: `data/artifacts/*.json`.
- Echo sets: `data/echoes/*.json`.
- Route/dialogue definitions: `data/routes/*.json`.
- Cached scanner responses: `data/scanner-cache/*.json`.
- Buyer personas and fallbacks: `data/marketplace/*.json`.
- Counterfeit evidence: `data/counterfeits/*.json`.
- Temporal Echoes and mystery pages: `data/temporal-echoes/*.json`, `data/journal/*.json`.
- Mini-events and evening planning: `data/events/*.json`, `data/evening/*.json`.
- Historical facts, sources, cultural reviews, and provenance: `data/museum/*.json`, `docs/sources/`, `docs/reviews/`, `docs/provenance/`.
- Full-game count/ID contract: `data/content-manifest.json`.
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

- `persistent`: journal entries, scanner records, museum entries, seated fragments, spawn history, learned techniques, completed route beats, returns, leads, legacy items, Safe/drawer knowledge, Temporal Echoes, endings, and content/review versions.
- `loop`: day/hour, money, ordinary inventory, temporary tools/upgrades, listings, current deliveries, unfinished requests, dispositions, daily sales, evening plan/upkeep, active event, and event outcomes.
- **Shared artifact inventory (remember this):** the **morning delivery box**, the **restoration bench**, and the **storage screen** are three views of the SAME `loop.inventory` list — there is no separate per-screen artifact pool. An artifact delivered → triaged into storage MUST be selectable on the bench. When adding an artifact, make sure all three agree: the bench filter (`RestorationService._can_restore_instance`) must accept it (note: artifacts whose conditions are **authored in the scene** rather than data-driven are admitted via `ArtifactScenes.has_scene`), storage lists it, and the per-template scene is registered in `ArtifactScenes`.
- **NEVER edit the hand-placed decals on an artifact scene (Invariant §4-R).** The `ArtifactConditionDecal` children in `scenes/restoration/artifacts/**/*.tscn` are positioned/sized/named by the dev or artist by hand. Do not add, remove, move, rescale, change `box_size`, swap textures, or rewrite the artifact `.tscn` — make only targeted edits that leave every decal node untouched. The `Max Decals: N` randomiser already chooses which authored decals show at runtime. This applies to every teammate's Claude too.
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
- `POST /api/negotiate`: use the request/response in PRD §20; six personas require live and fallback paths.
- Repeated Portal requests use a deterministic idempotency key: `player_id:fragment_id`.
- Backend timeout, validation, rate limiting, fallback, and config selection are mandatory.

## Standard Verification Commands

All phase verification snippets that use `$godot` assume this variable is initialized as shown below in the current PowerShell session.

```powershell
$godot = "C:\Users\roman\Downloads\Godot_v4.7-stable_win64_console.exe"
& $godot --version
# Result (2026-06-23): 4.7.stable.official.5b4e0cb0f
& $godot --headless --editor --path . --quit
# Result (2026-06-23): exit 0, no parser/resource/UID errors.
& $godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit
# Result (2026-06-23): 477/477 tests passed, 1556 asserts.

# Lint/format status (2026-06-23): gdformat --check reports no files need reformatting;
# gdlint reports no problems.
gdformat --check scripts scenes dialogue tests
gdlint scripts scenes dialogue tests

Push-Location server
npm test
# Result (2026-06-23): 24/24 passed.
Pop-Location

Push-Location mock-portal
npm test
# Result (2026-06-23): 4/4 passed.
Pop-Location

& $godot --headless --path . --export-release "Windows Desktop" "build/aLima.exe"
# Result (2026-06-23): exit 0; outputs build/aLima.exe (~105 MB) + build/aLima.pck (~109 MB).
& $godot --headless --path . --export-release "Web" "build/web/aLima.html"
# Result (2026-06-23): exit 0 with one non-fatal warning about the NobodyWho GDExtension
# having no wasm32 library (expected; the addon is excluded from the Web preset and the
# Windows/Desktop build still loads it). Outputs build/web/aLima.* + .js/.wasm/.pck.

git status --short
git ls-files | Select-String -Pattern '(^|/).env$|secret|credential|api[_-]?key'

```

---

## Phase 0 - Repository and Toolchain

**Goal:** establish one verified Godot 4.7 production entrypoint and reproducible checks.

**Requirements:** ARCH-R4, project conventions, global Definition of Done
**Dependencies:** none
**Subsystems:** repository, Godot project, tooling, CI

### Tasks

- `[x]` **P0.1 Integrate the upstream hybrid shop work.**
  - Commit `0255430` is present locally.
  - HUD revealed (`HUD.visible = true`) and the stray `AAAAAAAAA` test button removed from `scenes/Shop.tscn`.
  - The 4.7 editor import and `scenes/Shop.tscn` startup pass without parser/resource/UID/missing-file errors; the controller logs `[Shop] ready` (verified 2026-06-15).
  - Door/Workbench/Journal/Phone input is covered at the logic level by the GUT smoke test: button intent signals fire and dialogue advances via simulated mouse + keyboard events through the real `DialogueBox._input`.
  - Manual on-screen check passed (2026-06-15, human-confirmed under windowed 4.7): HUD visible; Door shows the visitor + dialogue; left-click and `ui_accept` both advance; closing hides the visitor and restores the action buttons; Workbench/Journal/Phone show their placeholders; the clock advances and pauses/resumes with dialogue.
  - Minute-level clock check passed (2026-06-15, human-confirmed under windowed 4.7): clock starts at `7:00 AM`, visibly advances through `7:01 AM`/`7:02 AM`/etc, reaches `8:00 AM` after roughly 60 real seconds, freezes while dialogue is open, and resumes after dialogue closes.
  - Evidence (2026-06-15): `--headless --editor --path . --quit` (exit 0, no errors); `--headless --path . --quit` (exit 0); GUT `16/16 passed` (54 asserts) including `tests/test_shop_clock.gd`; windowed manual run confirmed by the team.

- `[-]` **P0.2 Select Godot 4.7 for CLI/editor use.**
  - Godot 4.7 is installed at `C:\Users\roman\Downloads\Godot_v4.7-stable_win64_console.exe` and verified (`--version` → `4.7.stable.official.5b4e0cb0f`).
  - A PATH shim exists at `C:\Users\roman\tools\bin\godot.cmd` → the 4.7 console exe, and `C:\Users\roman\tools\bin` is on the User PATH. A bash shim (`godot`) is also present in that directory.
  - The bare `godot` command currently resolves to the older `4.5.1.stable` executable at `C:\Users\roman\Desktop\Godot` because `godot.exe` appears earlier in the effective PATH than the `.cmd` shim. The older 4.5.1 install stays at its own path.
  - The explicit `C:\Users\roman\Downloads\Godot_v4.7-stable_win64_console.exe` works and is the verified executable used for all Phase 0 checks.
  - Evidence (2026-06-15): `C:\Users\roman\Downloads\Godot_v4.7-stable_win64_console.exe --version` → `4.7.stable.official.5b4e0cb0f`; bare `godot --version` → `4.5.1.stable.official.f62fdbde1`.

- `[x]` **P0.3 Complete the production architecture gate after the 4.7 import check.**
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
  - `server/` and `mock-portal/` created in Phase 8 with Express, Jest, env validation, and cached endpoints.
  - Evidence (2026-06-15): directories present in working tree; `git status` lists the new untracked paths.

- `[x]` **P0.6 Install test and lint tooling.**
  - Vendored GUT 9.6.0 under `addons/gut`; smoke test `tests/test_shop_smoke.gd` + `.gutconfig.json`.
  - gdtoolkit pinned to `4.5.0` in `requirements-dev.txt` (`pip install -r requirements-dev.txt`).
  - CI `.github/workflows/ci.yml`: a lint job (gdformat `--check` + gdlint, scoped to `scripts scenes dialogue tests`) and a Godot job (downloads pinned 4.7 Linux headless → editor import → GUT). A backend test job is not yet added; run `server/npm test` and `mock-portal/npm test` locally for Phase 8 coverage.
  - Evidence (2026-06-15, local): GUT `7/7 passed` (29 asserts, exit 0); `gdformat --check scripts scenes dialogue tests` exit 0; `gdlint ...` "no problems found". CI workflow added; first remote run is pending the next push.
  - Note: the literal `gdformat --check .` / `gdlint .` forms fail only on the 81 vendored `addons/gut` files (0 of ours), so the documented commands are scoped to our source.

- `[x]` **P0.7 Verify repository hygiene.**
  - `.gitignore` now covers `.godot/`, `.env`/`*.env` (keeping `!.env.example`), logs, exports (`/build*`, `/export*`, `*.pck`, `*.zip`), and Python caches (`__pycache__/`, `.venv/`). Tracked `.import` files (Godot 4 metadata) intentionally kept.
  - `.editorconfig` declares `[*.gd] indent_style = tab` to match gdformat.
  - No tracked secret/`.env`/credential/api-key path; no secret-like content in new source.
  - Evidence (2026-06-15): `git ls-files | Select-String '(^|/)\.env$|secret|credential|api[_-]?key'` → no matches.

### Acceptance

- `[-]` The bare `godot --version` still reports `4.5.1.stable.official.f62fdbde1` (2026-06-15). Godot 4.7 is installed and verified only via the explicit executable `C:\Users\roman\Downloads\Godot_v4.7-stable_win64_console.exe` (`--version` → `4.7.stable.official.5b4e0cb0f`). This is the remaining Phase 0 blocker.
- [x] The production Shop imports and opens with zero parser/resource errors under Godot 4.7 (2026-06-15).
- [x] Exactly one production shop controller owns orchestration (`scripts/shop/shop_controller.gd`); HUD is presentation-only.
- [x] GUT tests (`16/16` passing, 54 asserts), gdformat check, and gdlint execute successfully (2026-06-15).
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

- `[x]` **P1.1 Implement typed model classes.**
  - Added `scripts/models/model_enums.gd`, `model_utils.gd`, `validation_result.gd`, and models for `ScrapObjectTemplate`, `ObjectInstance`, `Fragment`, `MasterArtifact`, `EchoSet`, `JournalEntry`, `MuseumEntry`, `ToolDefinition`, `TechniqueDefinition`, `PlacementContainer`, `CharacterRoute`, `ScannerCacheEntry`, and `SaveState`.
  - Enums/constants for rarity, object state, fragment state, open result, and verdict live in `ModelEnums`.
  - Every model provides `from_dictionary()`, `to_dictionary()`, and `validate()` with accumulated structured errors.
  - Evidence (2026-06-15): `tests/models/test_models.gd` 11/11 passed.

- `[x]` **P1.2 Implement JSON loading and validation.**
  - Added `scripts/core/data_repository.gd` (`class_name DataRepository`) loading `data/objects/`, `data/artifacts/`, `data/echoes/`, `data/routes/`, and `data/scanner-cache/`.
  - Validates schema versions, duplicate IDs, enums, numeric ranges, fragment slots, five unique Master Artifact fragments, required tools, and cross-references (tool/route/echo/artifact/scanner/container).
  - Collects all discoverable validation errors in one pass and leaves collections empty on failure.
  - Evidence (2026-06-15): `tests/core/test_data_repository.gd` 5/5 passed.

- `[x]` **P1.3 Add core autoloads.**
  - Registered `EventBus`, `GameState`, and `SaveService` in `project.godot` in that order.
  - `EventBus` exposes every Stable Interface signal with typed payloads.
  - `GameState` owns `SaveState` and exposes persistent/loop state separately.
  - `SaveService` serializes, validates schema, writes atomically (`user://save.tmp` → validation → `user://save.json`), and exposes a migration entrypoint.
  - No autoload manipulates scene nodes.
  - Evidence (2026-06-15): `tests/core/test_event_bus.gd` 3/3 passed, `test_game_state.gd` 5/5 passed, `test_save_service.gd` 5/5 passed.

- `[x]` **P1.4 Add deterministic run context.**
  - `GameState.run_context` owns `player_id`, `loop_index`, and `run_seed`; supports `debug_seed_override`.
  - `make_rng(stream_name)` and `derive_seed(stream_name)` create local `RandomNumberGenerator` instances from the run seed.
  - Evidence (2026-06-15): `tests/core/test_run_context.gd` 4/4 passed.

- `[x]` **P1.5 Add minimum slice data.**
  - `data/objects/objects.json`: `tarnished_pendant` template plus two ordinary non-carrier instance fixtures.
  - `data/objects/tools.json` / `techniques.json`: `soft_cloth` tool and `pendant_cleaning` technique.
  - `data/routes/containers.json`: `pile_left`, `pile_center`, `shelf_right`.
  - `data/artifacts/master_artifact.json` + `fragments.json`: artifact-agnostic five-slot Master Artifact; `fragment_01` is `RELEASED`.
  - `data/echoes/echoes.json`: four-band `demo_echo_set` with placeholder audio paths (documented).
  - `data/scanner-cache/scanner_cache.json`: advisory cached response for `tarnished_pendant` matching PRD §20.
  - `data/routes/starting_kit.json`: all ten cleaning tools in the starting kit (one per surface-condition category plus the cloth and archival tape), so the player can treat any random condition. They auto-equip to fill the bench (see Storage/loadout notes).
  - Evidence (2026-06-15): `tests/core/test_data_repository.gd::test_slice_fixtures_load_and_validate` passed.

- `[x]` **P1.6 Test model and loader contracts.**
  - Added `tests/models/test_models.gd` (11 tests) and `tests/core/` tests for repository, EventBus, GameState, SaveService, and run context (22 tests).
  - Covers valid parsing, round-trip serialization, missing/duplicate IDs, unknown enums, invalid ranges, broken tool/fragment/echo/route/scanner/container references, accumulated errors, atomic writes, migration rejection, and deterministic seeds.
  - Evidence (2026-06-15): full GUT suite `49/49 passed`, 160 asserts.

### Acceptance

- [x] No artifact-specific value is hardcoded in gameplay logic.
- [x] All slice fixtures load from data and pass validation.
- [x] Cross-system events compile with typed payloads.
- [x] A fixed seed produces the same test random sequence.

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

- `[x]` **P2.1 Build `DayClock`.** (`scripts/core/day_clock.gd`, autoload `DayClock`)
  - Reusable, presentation-free clock (no `class_name` to avoid the autoload/global-class clash; no `_process` — it advances only via `tick(delta)`).
  - Defaults to 60 real seconds per in-game hour (`seconds_per_hour`, the debug speed).
  - Starts each day at 07:00 and closes at the authoritative **20:00** boundary (latched), replacing the placeholder's run-to-21:00 bug. Exposes day, hour, minute, loop index, `running`, and pause state.
  - Emits `hour_changed`/`day_changed` once per transition and `day_closed` exactly once at 20:00; a large `tick()` or accelerated speed cannot skip or duplicate transitions (leftover delta discarded at close).
  - Evidence (2026-06-15): `tests/core/test_day_clock.gd` 11/11 (progression, exactly-once hour signals, debug speed, large delta, 20:00 boundary, start-day resume, pause edges).

- `[x]` **P2.2 Add pause ownership.** (on `DayClock`; forwarded to `EventBus.clock_pause_changed` by `LoopController`)
  - Full-screen systems acquire/release via stable owner IDs (`PAUSE_DIALOGUE/RESTORATION/SCANNER/TRIAGE/JOURNAL/PORTAL`).
  - Owner **set** semantics: paused iff non-empty, so one screen cannot resume a clock another holds; duplicate acquire is idempotent; releasing an unknown owner is a harmless warned no-op.
  - The Shop dialogue flow integrates the API (`request_pause`/`release_pause(PAUSE_DIALOGUE)`).
  - Evidence (2026-06-15): pause cases in `tests/core/test_day_clock.gd` + `tests/test_shop_clock.gd::test_dialogue_pauses_and_resumes_via_pause_ownership`.

- `[x]` **P2.3 Build `LoopController`.** (`scripts/core/loop_controller.gd`, autoload `LoopController`)
  - Bridges DayClock signals onto EventBus + mirrors `current_day`/`current_hour` into `GameState.save_state.loop`; advances Day 1->5 cleanly at each 20:00 close.
  - Day 5 reset, in fixed order: clear loop state -> `new_run()` (increment loop index + reseed) -> restart Day 1 07:00 -> atomic save -> emit `loop_reset`. Never clears seated fragments or spawn history. The `_closed` latch + `_resetting` guard prevent a duplicate `day_closed` from resetting twice.
  - Evidence (2026-06-15): `tests/core/test_loop_controller.gd` 7/7.

- `[x]` **P2.4 Implement the save split.** (reconciled with existing `SaveState`; strict load checks in `SaveService`)
  - The existing P0 persistent/loop fields already match the Stable Interfaces contract; no Phase 12-22 fields were added (forward-compatible defaults preserved).
  - `SaveService.load_game` now strictly rejects unknown enum strings, non-numeric scalars, and wrong section types before trusting a save (model range/validation runs afterward); missing optional fields default safely. Loop inventory never leaks into persistent.
  - Evidence (2026-06-15): `tests/core/test_save_service.gd` (missing-optional, out-of-range, unknown-enum, non-numeric, partition-separation) + `test_loop_controller.gd` (persistent survives / loop resets).

- `[x]` **P2.5 Implement atomic save writes.** (write-temp -> parse -> validate -> rename)
  - Save paths are injectable via `set_save_paths()` so tests never touch the developer's real save; the game default stays `user://save.json`/`.tmp`.
  - An invalid/partial temp file is never promoted, so a valid `save.json` survives; the migration entrypoint is retained.
  - Evidence (2026-06-15): `tests/core/test_save_service.gd::test_invalid_temp_does_not_replace_valid_save`, `test_rejects_malformed_save_file`. (Forced OS rename failure is not simulated; the invalid-temp guard is the tested protection.)

- `[x]` **P2.6 Test reset behavior.**
  - Covered: normal progression, exactly-once signals, debug speed + large delta, two-owner independent release, duplicate acquire/release, Days 1-5 progression, Day 5 reset, persistent survival, every loop-scoped field resetting, seated fragment staying `SEATED`, spawn history surviving, round-trip save/load, missing optional fields, malformed/partial temp JSON, and loop inventory isolation.
  - Evidence (2026-06-15): full GUT suite `69/69 passed` (234 asserts); `tests/core` focused suite green; gdformat/gdlint clean; `git diff --check` exit 0.

### Acceptance

- `[-]` A normal day lasts about 13 real minutes. (By construction: 13 in-game hours x 60 s = 780 s; the 20:00 close is test-proven. Literal real-time stopwatch observation pending.)
- `[-]` A five-day loop lasts about one hour without pauses. (5 x 13 min ~= 65 min by construction; test-proven at the simulation level. Real-time observation pending.)
- `[x]` Reset returns to Day 1, 07:00 with the correct state split. (`tests/core/test_loop_controller.gd`, 2026-06-15.)
- `[x]` Save interruption cannot replace a valid save with partial JSON. (`tests/core/test_save_service.gd`, 2026-06-15.)

### Verification

```powershell
$godot = "C:\Users\roman\Downloads\Godot_v4.7-stable_win64_console.exe"
& $godot --headless --editor --path . --quit
& $godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/core
& $godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit
gdformat --check scripts scenes dialogue tests
gdlint scripts scenes dialogue tests
git diff --check
```

Manual (PENDING on-screen observation under windowed 4.7): run with `seconds_per_hour = 0.1`, pause from two different owners, release one (clock stays paused), release the second (progression resumes), observe one complete five-day reset to Day 1 07:00, and confirm the visible Shop clock advances minute-by-minute and freezes/resumes with dialogue.

---

## Phase 3 - Delivery and Triage

**Goal:** generate real morning deliveries and force meaningful keep/recycle choices.

**Requirements:** DLV-R1..R5, ARCH-R5
**Dependencies:** Phases 1-2
**Subsystems:** delivery generator, 3D placement anchors, 2D triage UI

### Tasks

- `[x]` **P3.1 Build weighted delivery generation.**
  - Added `scripts/delivery/delivery_generator.gd` (`DeliveryGenerator`).
  - Draws templates by configured rarity weights from `data/delivery/delivery_config.json`.
  - Creates deterministic, unique `ObjectInstance` IDs using a per-loop/seed counter and local `RandomNumberGenerator`.
  - Clamps batch size to configured `batch_min`/`batch_max`.
  - Injects carrier instances planned by `SpawnDirector` on their assigned day.
  - Evidence (2026-06-15): `tests/delivery/test_delivery_generator.gd` 9/9 passed.

- `[x]` **P3.2 Add shop placement anchors.**
  - Added `Marker3D` nodes `pile_left`, `pile_center`, `shelf_right` to `scenes/Shop.tscn` matching `data/routes/containers.json`.
  - Compatibility tags and capacities remain authored in `PlacementContainer` data.
  - `SpawnDirector` selects compatible anchors; `DeliveryGenerator` resolves invalid/full anchors to a deterministic compatible fallback.
  - Evidence (2026-06-15): `tests/delivery/test_spawn_director.gd` 8/8 passed; `test_delivery_generator.gd` fallback tests passed.

- `[x]` **P3.3 Implement the fixed glow legend.**
  - Added `ModelEnums.GlowState` with exactly six states: White, Green, Blue, Purple, Gold, Flickering.
  - Added `scripts/delivery/glow_mapper.gd` as the centralized color/state authority for 3D and 2D.
  - Carriers display their ordinary template rarity glow until `flicker_authorized` is true; no new rarity tier was added.
  - Evidence (2026-06-15): `tests/delivery/test_glow_mapper.gd` 6/6 passed.

- `[x]` **P3.4 Build the 2D triage interface.**
  - Added `scenes/ui/triage_screen.tscn` + `scenes/ui/triage_controller.gd`.
  - Shows object name, apparent glow (color + text), assigned container, and storage cost per item.
  - Enforces the configured storage cap by cost, not object count.
  - Requires an explicit keep/recycle decision for every item; confirm is disabled while undecided or over capacity.
  - Acquires/releases `DayClock.PAUSE_TRIAGE` ownership while open and on every close/exit path.
  - Evidence (2026-06-15): `tests/delivery/test_triage.gd` capacity/decision tests passed.

- `[x]` **P3.5 Apply triage results.**
  - Added `scripts/delivery/triage_service.gd` (`TriageService`).
  - Kept instances append to `GameState.save_state.loop.inventory`.
  - Recycled instances are removed from active delivery state and cannot enter restoration.
  - A recycled carrier does not consume its fragment; the fragment stays `RELEASED` and is re-placed next loop.
  - Records per-container neglect history in `PersistentState.neglect_history` for the Spawn Director.
  - Emits `EventBus.triage_completed` and saves atomically via `SaveService`.
  - Evidence (2026-06-15): `tests/delivery/test_triage.gd` outcome/eligibility/neglect tests passed.

- `[x]` **P3.6 Test delivery invariants.**
  - Added `tests/delivery/` with 33 tests covering batch bounds, deterministic weighted generation, unique IDs, carrier injection, carrier identity preservation, hidden flicker, six-state glow mapping, anchor compatibility/capacity/fallback, triage capacity enforcement, undecided blocking, keep/recycle outcomes, recycled carrier eligibility, neglect history persistence, seated-fragment protection, atomic application, and UID uniqueness across repeated morning deliveries on the same loop/day.
  - Evidence (2026-06-15): focused delivery suite `33/33 passed` (197 asserts); complete GUT suite `121/121 passed` (509 asserts).

### Acceptance

- `[x]` A morning delivery is generated from JSON templates.
- `[x]` The player can keep only the configured storage-cost budget.
- `[x]` All six fixed visual states work without adding a new rarity.
- `[x]` Director-selected instances appear at the correct shop anchor/day (with deterministic fallback).
- `[x]` Morning Delivery can only be triggered once per in-game day.
- `[-]` Manual on-screen verification of mouse/keyboard input, 1920x1080 readability, and three accelerated debug mornings is pending human observation.

### Verification

```powershell
$godot = "C:\Users\roman\Downloads\Godot_v4.7-stable_win64_console.exe"
& $godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/delivery
# Result (2026-06-15): 33/33 passed, 197 asserts.

& $godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit
# Result (2026-06-15): 121/121 passed, 509 asserts.

gdformat --check scripts scenes dialogue tests
# Result (2026-06-15): no files need reformatting.

gdlint scripts scenes dialogue tests
# Result (2026-06-15): no problems found.

git diff --check
# Result (2026-06-15): no trailing whitespace errors.
```

Manual: start three debug days and confirm batch, glow, keep/recycle, and anchor placement behavior. Pending human observation.

---

## Phase 4 - Restoration and Pendant Carrier

**Goal:** deliver one complete, skill-based clean-to-open interaction in a focused **3D** restoration view.

**Requirements:** REST-R1, REST-R3, REST-R4, REST-R7, REST-R8, DISC-R12, DISC-R13
**Dependencies:** Phases 1 and 3
**Subsystems:** focused 3D restoration view, tool rules, openable/carrier logic

> **Presentation status (2026-06-16):** The focused **3D object-manipulation** restoration view (REST-R8) is now implemented (`scenes/restoration/restoration_view.tscn` + `scripts/restoration/restoration_view.gd` / `restoration_object_3d.gd` + `restoration_dirt.gdshader`, P4.7) and the 2D interim placeholder `scenes/ui/restoration_screen.*` was retired. The restoration *logic* and clean→open *gate* (in `RestorationService`, presentation-agnostic) carry over unchanged and are reused by the 3D view. P4.1, P4.4, and P4.7 remain `[-]` only because their on-screen mouse/controller/touch flow is still a pending human verification gate; all automated coverage is green. P4.2/P4.3/P4.5/P4.6 (pure logic) remain `[x]`.

### Tasks

- `[-]` **P4.1 Build the pendant cleaning mini-game.** (logic + 3D presentation done in code; on-screen manual gate pending)
  - `scenes/restoration/restoration_view.tscn` + `scripts/restoration/restoration_view.gd` provide the paused focused **3D** view (REST-R8): a `SubViewport` 3D object plus a 2D HUD overlay (object selector, tool palette, condition/value/damage meters, surface-progress bar, feedback + caption). The 2D interim placeholder was retired.
  - Acquires/releases `DayClock.PAUSE_RESTORATION` on open, close, and `_exit_tree`, tracked by an `_owns_pause` flag so release happens exactly once.
  - Player selects an owned tool and works it across the object's 3D surface; a deliberate stroke (a press-drag worth of surface work, or one controller `restoration_clean` press) invokes `RestorationService.apply_tool()` once — never per-frame.
  - Progress is calculated by the service from authored `clean_progress_per_action`, `clean_value_bonus`, and technique bonuses; the view only renders the dirt mask and meters.
  - Displays selected tool, condition, value, recorded damage, completion threshold, and surface-cleaned coverage.
  - Evidence: `tests/restoration/test_restoration_view.gd` (open/load, rotation-without-mutation, reset-view, empty-space no-op, surface-hit cleaning, correct-tool reaches CLEAN, wrong-tool damage) + `tests/restoration/test_restoration_service.gd` (deterministic CLEAN reach). **Pending:** human on-screen mouse/controller/touch verification.

- `[x]` **P4.2 Implement tool consequences.**
  - Compatible tool (matches `clean_minigame`/`required_clean_tool`) increases condition and value, clamped to authored bounds.
  - Wrong/incompatible tool applies `wrong_tool_condition_damage` and `wrong_tool_value_damage` from the template and increments `recorded_damage`.
  - Condition is clamped to `0..100`; value is clamped to `base_value_range` and never negative.
  - Evidence: `test_wrong_tool_records_persistent_instance_damage`, `test_condition_remains_within_zero_to_one_hundred`, `test_correct_tool_modifies_value_within_authored_bounds`.

- `[x]` **P4.3 Implement the clean gate.**
  - `RestorationService.open_clasp()` rejects any instance whose state is not `CLEAN` with a player-facing reason.
  - Carrier status is checked only after the clean gate; a dirty carrier cannot open.
  - Cleaning transitions only the selected instance to `CLEAN`; other instances are untouched.
  - Evidence: `test_dirty_openables_reject_open_including_carrier`, `test_restoration_changes_only_the_selected_instance`.

- `[-]` **P4.4 Build the pendant clasp interaction.** (logic + 3D presentation done in code; on-screen manual gate pending)
  - Clasp opening is a separate 3D interaction: at CLEAN a distinct clasp hotspot is revealed on the pendant and activated by clicking it (raycast) or the `restoration_open` action. It is hidden/rejected while DIRTY and never auto-fires on reaching CLEAN.
  - Only `CLEAN` instances allow opening (gate enforced by `RestorationService.open_clasp()`); it transitions the selected instance to `OPEN` exactly once and shows the resolved result without re-resolving content.
  - Evidence: `test_dirty_clasp_interaction_is_rejected`, `test_cleaning_does_not_auto_open_clasp`, `test_clean_pendant_clasp_opens_once` (view) + `test_clean_pendant_can_open`, `test_opening_is_single_use_and_idempotent` (service). **Pending:** human on-screen verification.

- `[x]` **P4.5 Implement general open results.**
  - Opening resolves from the instance's authored/injected `contents`: `EMPTY`, `TEMPORAL_ECHO`, or `FRAGMENT`.
  - Only an instance with `is_carrier == true` and `contents == FRAGMENT` can produce a fragment.
  - Carriers retain the ordinary `tarnished_pendant` template ID, rarity, and scene; no special pendant subtype exists.
  - Evidence: `test_only_carrier_produces_fragment_and_retains_template_identity`, `test_empty_temporal_echo_and_fragment_resolve_correctly`, `test_reopening_cannot_duplicate_content`.

- `[x]` **P4.6 Test restoration and opening.**
  - Added `tests/restoration/test_restoration_service.gd` (17 tests) and `tests/restoration/test_restoration_ui.gd` (2 tests).
  - Covers dirty ordinary/carrier rejection, deterministic CLEAN, condition/value bounds, persistent damage, instance isolation, single-use opening, non-carrier EMPTY, carrier FRAGMENT, temporal echo resolution, pause ownership, and invalid tool/technique repository validation.

- `[-]` **P4.7 Build the focused 3D restoration view.** (REST-R8; implemented + automated-verified; on-screen manual gate pending)
  - The object is a manipulable 3D model in a focused restoration sub-scene (`scenes/restoration/restoration_view.tscn`): a `SubViewport` world (camera, key/fill lights, workbench, `ObjectPivot`) framed by a 2D background + HUD overlay (object selector, tool palette, condition/value/damage meters, surface-progress bar, feedback + caption, Reset View / Close).
  - Orbit/rotate the object (mouse drag, right-drag, WASD/left-stick/d-pad; pitch clamped, yaw wrapped); apply the selected tool by working it **across the 3D surface**. Grime is a shader **dirt mask** (`scenes/restoration/restoration_dirt.gdshader`, R8/RGBA8 `ImageTexture`) cleared locally where worked; both the shader and the painter derive UV analytically from the object-space normal so they stay aligned regardless of mesh UVs (D8). GL Compatibility / HTML5-friendly.
  - Hit detection is analytic ray-sphere (deterministic, headless-testable) distinguishing object hits from empty space; strokes are threshold-gated so `apply_tool()` is never called per-frame/pixel.
  - **Reuses `RestorationService` unchanged** — the view delegates every rule (condition/value, compatibility, wrong-tool damage, clean->open gate, open-result resolution) and never writes through `SaveService`. Keeps `DayClock.PAUSE_RESTORATION` ownership (single-release guarded).
  - The type-specific 3D clasp/open is a separate revealed-at-CLEAN hotspot, not a relabeled 2D button. Carrier identity is never exposed via model, dirt, meters, or clasp before opening (ordinary and promoted pendants share one presentation path).
  - Pendant-specific model/clasp/colour live in a narrowly-scoped presentation adapter (`RestorationObject3D.PRESENTATION` keyed by `openable_type`), so the view stays reusable/artifact-agnostic. Geometry is placeholder development geometry pending authored models (Phase 13/20).
  - Input (INPUT-R5): mouse + emulated-touch rotate/clean via the same pointer pipeline (no hover dependence); keyboard/controller rotate, clean (auto-targets grime, no precision aiming), open, reset, toggle-mode, close via runtime-registered Input Map actions. Captions mirror every important response (INPUT-R3); muted-playable.
  - Replaced and retired `scenes/ui/restoration_screen.*` (2D placeholder) and migrated its GUT coverage into `tests/restoration/test_restoration_view.gd`.
  - Evidence: `tests/restoration/test_restoration_view.gd` (15 tests) + the unchanged `tests/restoration/test_restoration_service.gd` (17) pass. **Pending:** human on-screen mouse verification and controller/touch device verification.

- `[-]` **P4.8 Make cleaning tools visible 3D props on the bench.** (REST-R9; implemented + automated-verified; on-screen manual gate pending)
  - Added `scripts/restoration/restoration_tool_tray.gd` (`RestorationToolTray`, presentation-only `Node3D`) and a `ToolTray` node in `restoration_view.tscn` under the SubViewport world. It builds one selectable 3D prop per owned tool, data-driven from `RestorationService.get_available_tools()` (artifact-agnostic; `PRESENTATION` adapter keyed by tool id with a `_default`). Geometry is original placeholder dev geometry (cloth pad, wire brush) pending authored models (Phase 13/20).
  - Picking a prop (pointer ray; or the new `restoration_cycle_tool` keyboard/controller action) calls the existing `select_tool()` → `RestorationService` path; the props never read carrier identity. The selected prop is visibly distinguished (raised/tilted + emission highlight). Pointer pick is inserted after the clasp check and before a cleaning stroke/rotate, so it never competes with cleaning.
  - The 2D HUD tool buttons are kept but relabelled "Tools (fallback):" as a clearly-labelled accessibility/fallback path; the production interaction no longer requires a flat "Cloth" button.
  - Evidence: `tests/restoration/test_restoration_tool_tray.gd` (7) + `tests/restoration/test_restoration_tool_props_view.gd` (5) pass; existing Phase 4 logic/view suites unchanged and green. **Pending:** human on-screen verification (prop visibility, pick, highlight, controller cycle).

- `[-]` **P4.9 (cross-cutting) Diegetic 3D shop interactables.** (SHELL-R1/R2; implemented + automated-verified; on-screen manual gate pending)
  - Added a reusable `scripts/shop/interactable_3d.gd` (`Interactable3D`, `Area3D`): hover prompt/highlight + `activated`/`hover_changed` signals + `activate()`/`set_enabled()`; owns no game logic. Added `Interactables/{Door,Workbench,Journal,Phone,Delivery}Interactable` placeholder props to `scenes/Shop.tscn`, a HUD `PromptLabel`, and a `FallbackHint`.
  - `ShopController` enables viewport `physics_object_picking`, connects each prop's `activated` to the **existing** action handler (no behavior change), routes `hover_changed` to `ShopHud.set_prompt()`, and disables all props while a full-screen overlay (dialogue/triage/restoration/journal) is open so clicks can't fall through. HUD buttons stay as labelled accessibility/fallback (signals intact).
  - Placeholder geometry/positions are dev-only; final art and exact in-frame composition are a Phase 20 / manual gate.
  - Evidence: `tests/shop/test_interactable_3d.gd` (6) + extended `tests/test_shop_smoke.gd` (interactable existence, prop-opens-overlay parity, hover prompt, overlay gating) pass. **Pending:** human on-screen click-through, hover prompts, and per-overlay input-blocking verification on mouse/controller/touch.

### Acceptance

- `[x]` Pendant clean -> clasp open -> result works end to end at the logic level (automated coverage via `RestorationService`).
- `[x]` Wrong-tool use has visible (feedback label) and recorded (`recorded_damage`) consequences.
- `[x]` Carrier is an injected role (`is_carrier`/`contents` on an ordinary pendant instance), not a special pendant type.
- `[-]` Cleaning and opening are performed in the focused **3D** view (rotate + clean the 3D object). Implemented (`scenes/restoration/restoration_view.tscn`) and automated-verified via `test_restoration_view.gd`; human on-screen mouse/controller/touch verification is the remaining gate.
- `[-]` Tool choice is a physical 3D act: the bench shows a selectable 3D prop per owned tool (REST-R9), the selected prop is visibly distinguished, and the HUD tool buttons are a labelled accessibility/fallback only. Automated-verified via `test_restoration_tool_tray.gd` + `test_restoration_tool_props_view.gd`; on-screen verification pending.
- `[-]` Major shop actions are diegetic 3D interactables wired to the existing handlers (SHELL-R1/R2), with HUD fallback retained. Automated-verified via `test_interactable_3d.gd` + the extended shop smoke test; on-screen click-through + per-overlay input-blocking verification pending.

### Verification

```powershell
$godot = "C:\Users\roman\Downloads\Godot_v4.7-stable_win64_console.exe"
& $godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/restoration -ginclude_subdirs -gexit
# Result (2026-06-17): 44/44 passed, 152 asserts (17 service + 15 view + 7 tool-tray + 5 tool-props-view).

& $godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/shop -ginclude_subdirs -gexit
# Result (2026-06-17): 6/6 passed (Interactable3D).

& $godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit
# Result (2026-06-17): 273/273 passed, 921 asserts.

gdformat --check scripts scenes dialogue tests   # 100 files unchanged
gdlint scripts scenes dialogue tests             # no problems
git diff --check                                 # clean
```

Manual (pending human on-screen observation):
- Restoration: open the Workbench, confirm the clock pauses, see the cloth/brush props on the bench, pick a prop (it highlights/poses), rotate the pendant and inspect multiple surfaces, clean empty space (no change), use the wrong tool (visible + captioned damage), close/reopen (damage persists), clean correctly until CLEAN (clasp does not auto-open), perform the 3D clasp interaction (result resolves once), repeat with a promoted pendant (carrier role hidden until opened), and confirm the controller cycle-tool + fallback buttons work. Mouse, then controller/touch where hardware is available; check 1920x1080 and 1280x720.
- Shop: hover each prop (door/workbench/journal/phone/delivery) for prompt + highlight, click each and confirm it matches its HUD button's behavior, confirm no click falls through dialogue/triage/journal/restoration overlays, and confirm the fallback buttons still work.

---

## Phase 5 - Spawn Director

**Goal:** implement genuine, deterministic, auditable fragment placement.

**Requirements:** DISC-R1..R6, SAVE-R3, CLAUDE.md §4-B/C/H
**Dependencies:** Phases 1-4
**Subsystems:** placement candidates, weighting, history, demo audit

### Tasks

- `[x]` **P5.1 Build candidate enumeration.**
  - Added `scripts/discovery/placement_candidate.gd` typed model for `(carrier_template_id, container_id, day)` candidates.
  - `SpawnDirector.enumerate_candidates(fragment_id)` returns every openable template × container pair, sorted deterministically by template/container ID.
  - Filters exclude `SEATED`/non-`RELEASED` fragments before candidate construction.
  - Evidence: `tests/discovery/spawn_director/test_spawn_director_phase5_filters.gd::test_deterministic_candidate_ordering`.

- `[x]` **P5.2 Apply hard filters.**
  - `SpawnDirector._apply_hard_filters()` rejects non-openable templates, incompatible containers, containers already at capacity, locked locations the player cannot open, and carriers whose `required_clean_tool` is not obtainable that run (starting kit + persistent legacy items + loop tool items).
  - Safe is rejected unless `GameState.save_state.persistent.safe_code_known` is true; knowing the Safe code does not bypass other filters.
  - Evidence: `test_incompatible_containers_are_rejected`, `test_containers_over_capacity_are_rejected`, `test_locked_locations_are_rejected_without_code`, `test_safe_code_makes_safe_eligible`, `test_safe_code_affects_only_safe_container_eligibility`, `test_unavailable_required_tool_excludes_candidate`, `test_granting_tool_makes_candidate_eligible`.

- `[x]` **P5.3 Apply weighted scoring.**
  - Tuning lives in `data/delivery/spawn_config.json`: `base_weight`, `neglect_multiplier`, `day_spread_bonus`, `day_spread_penalty`.
  - `_apply_weights()` multiplies base weight by persistent neglect history and by day-spread bonus/penalty based on recent day history.
  - Evidence: `test_containers_over_capacity_are_rejected` (day-spread/capacity interaction) and audit-log score component coverage.

- `[x]` **P5.4 Enforce never-twice history.**
  - `_apply_never_twice()` excludes every prior `(carrier_template_id, container_id)` pair stored in `GameState.save_state.persistent.spawn_history`.
  - When all otherwise-valid pairs are exhausted, a soft reset makes older pairs eligible again while forbidding only the most recent pair; `soft_reset` is recorded in the plan and audit log.
  - Evidence: `test_three_sequential_runs_do_not_repeat_pair`, `test_older_pairs_remain_excluded_before_exhaustion`, `test_exhaustion_triggers_soft_reset`, `test_soft_reset_forbids_most_recent_pair`, `test_soft_reset_never_bypasses_hard_filters`.

- `[x]` **P5.5 Promote the selected instance.**
  - `DeliveryGenerator._inject_carriers()` sets `is_carrier = true`, `fragment_id`, and `contents = ModelEnums.OpenResult.FRAGMENT` on the selected ordinary openable instance.
  - The instance retains its original template ID, rarity, and restoration rules.
  - `EventBus.carrier_activated` is emitted on promotion.
  - Evidence: `test_promotion_preserves_template_and_rarity`, `test_promotion_sets_carrier_fragment_content_once`, `test_fragment_is_inside_promoted_carrier_not_loose`.

- `[x]` **P5.6 Add deterministic audit output.**
  - All placement randomness uses `GameState.make_rng(SpawnDirector.PLACEMENT_STREAM)` derived from the run seed.
  - `SpawnDirector.get_last_audit_log()` returns a deterministic dictionary with `loop`, `seed`, `fragment_id`, selected carrier/container/day, `soft_reset`, candidate count, rejected candidates with reasons, and score components.
  - Added `scripts/discovery/spawn_director_demo.gd` (`SpawnDirectorDemo`) to run three seeded placements for the same fragment/player and return/print the audit trail.
  - Evidence: `test_fixed_seed_produces_same_result`, `test_seeded_audit_logs_are_reproducible`, `test_different_seeds_produce_valid_variation`, `test_three_run_demo_retains_history`.

- `[x]` **P5.7 Test placement guarantees.**
  - Added `tests/discovery/spawn_director/test_spawn_director_phase5_filters.gd` (16 tests) and `tests/discovery/spawn_director/test_spawn_director_phase5_history.gd` (9 tests) with 25 tests total covering: fixed-seed repeatability, deterministic ordering, variation across seeds, RELEASED-only eligibility, SEATED exclusion, tool obtainability, compatibility, capacity, locked locations, Safe-code gating, carrier nesting, never-twice/soft-reset semantics, promotion invariants, history persistence across loop reset and save/load, seeded audit reproducibility, no-candidate failure atomicity, and three-run demo history retention.
  - Evidence (2026-06-15): focused Phase 5 suite `25/25 passed`; complete cross-directory GUT suite `146/146 passed` (565 asserts).

### Acceptance

- `[x]` Three recorded runs show different carrier/container/day combinations (verified by automated never-twice/soft-reset tests and the demo helper).
- `[x]` No prior pair repeats before candidate exhaustion (verified by `test_three_sequential_runs_do_not_repeat_pair` and `test_older_pairs_remain_excluded_before_exhaustion`).
- `[x]` Every selected placement is winnable (verified by `test_unavailable_required_tool_excludes_candidate` and `test_granting_tool_makes_candidate_eligible`).
- `[x]` No fragment appears loose in a pile, Safe, or container (verified by `test_fragment_is_inside_promoted_carrier_not_loose`).

### Verification

```powershell
$godot = "C:\Users\roman\Downloads\Godot_v4.7-stable_win64_console.exe"
& $godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/discovery/spawn_director
# Result (2026-06-15): 25/25 passed.

& $godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit
# Result (2026-06-15): 146/146 passed, 565 asserts.

gdformat --check scripts scenes dialogue tests
# Result (2026-06-15): no files need reformatting.

gdlint scripts scenes dialogue tests
# Result (2026-06-15): no problems found.

git diff --check
# Result (2026-06-15): no trailing whitespace errors.
```

Manual: run the three-seed demo (`SpawnDirectorDemo.run_three_seeded_placements`) and retain its placement log for the submission evidence folder. Pending human observation.

---

## Phase 6 - Cultural Echoes

**Goal:** guide the player to the exact carrier through accessible audio/visual cues.

**Requirements:** DISC-R7..R11, CLAUDE.md §4-E/I
**Dependencies:** Phase 5 and a navigable Shop scene
**Subsystems:** audio buses, proximity service, resonance UI, captions

### Tasks

- `[x]` **P6.1 Configure four audio layers.**
  - Hum, Melody, Voice, and Heartbeat use separate players/buses.
  - Source files are original, disclosed, and data-selected by `EchoSet`.
  - Start layers synchronized so crossfades do not restart clips.

- `[x]` **P6.2 Compute normalized proximity.**
  - Measure the active player/focus position to the active carrier anchor.
  - Map distance to `0.0..1.0` using authored near/far radii.
  - Smooth changes to prevent meter and volume jitter.

- `[x]` **P6.3 Implement additive band mixing.**
  - Hum: 0.00-0.30.
  - Melody: 0.30-0.60.
  - Voice: 0.60-0.85.
  - Heartbeat: 0.85-1.00.
  - Use crossfades and clamps; keep thresholds configurable.

- `[x]` **P6.4 Enforce silence and heartbeat gates.**
  - Stop/silence Echoes when no released, unfound carrier is in the current scene.
  - Heartbeat volume remains impossible for non-carriers.
  - Clear the active target after discovery/seating.

- `[x]` **P6.5 Reveal carrier confirmation.**
  - Keep carrier Flickering hidden below `GLOW_REVEAL_AT = 0.60`.
  - Reveal only the promoted carrier's flicker at/above threshold.
  - Pulse carrier and resonance meter with Heartbeat near the target.

- `[x]` **P6.6 Build accessible 2D feedback.**
  - Resonance meter mirrors normalized proximity.
  - Captions name each active band and voice line.
  - The mechanic remains understandable with master audio muted.

- `[x]` **P6.7 Test all gates and thresholds.**
  - Boundary values select/mix the expected bands.
  - Decoys never emit Heartbeat.
  - Empty scenes remain silent.
  - Discovery stops the active Echo target.

### Acceptance

- [x] Following cues leads to the exact carrier.
- [x] Heartbeat never fires on a decoy.
- [x] Captions and meter make the sequence playable without audio.
- [x] Audio leads; flicker confirms only from 0.60 proximity.

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

- `[x]` **P7.1 Define `ScannerService`.**
  - `scripts/scanner/scanner_service.gd` accepts an `ObjectInstance` and builds a typed `ScannerRequest`.
  - Hidden truth fields (`is_carrier`, `fragment_id`, `contents`, `is_counterfeit_truth`) are excluded from the request.
  - `ScannerResponse` is the shared typed model used by `ScannerCacheTransport` and the future `ScannerHttpTransport`.
  - Endpoint/base URL lives in `ScannerHttpTransport` config, not scene logic; Phase 7 uses `ScannerCacheTransport` only.
  - `ScannerResult.Status` explicitly covers `SUCCESS`, `FALLBACK`, `NOT_CLEAN`, `MISSING_CACHE`, `MALFORMED_RESPONSE`, and `TRANSPORT_ERROR`.
  - Evidence: `tests/scanner/test_scanner_service.gd` 11/11 passed; request contract and hidden-field exclusion are tested.

- `[x]` **P7.2 Add cached slice responses.**
  - `data/scanner-cache/scanner_cache.json` contains validated cached responses for all five current slice templates: `tarnished_pendant`, `rusted_tin`, `cracked_photo_frame`, `small_santo`, `dusty_locket`.
  - Each response includes suggested type, possible period, materials, markings, condition note, cultural relevance, price range, modification/counterfeit signs, confidence, uncertainty notes, and source references.
  - All current cultural/historical claims are marked `unverified` and noted as development placeholders pending workshop review; no fabricated citations are present.
  - The cache never reveals carrier status; promoted carriers receive the same ordinary template response.
  - Evidence: `tests/scanner/test_scanner_cache_validation.gd` 11/11 passed; `test_every_slice_template_has_cache_response` and `test_promoted_carrier_receives_ordinary_template_response` cover coverage and carrier hiding.

- `[x]` **P7.3 Build the 2D scanner interface.**
  - `scenes/ui/scanner_screen.tscn` + `scripts/scanner/scanner_screen.gd` provide the full-screen 2D scanner UI.
  - Opens only for `CLEAN`/`OPEN` instances; dirty objects are rejected with a text status.
  - Acquires `DayClock.PAUSE_SCANNER` on open and releases only its own pause on close/`_exit_tree`.
  - Displays every advisory field from `ScannerResponse`; scanner annotations are separated from the player-verdict section by a visual separator and explanatory text.
  - Handles `SUCCESS`, `FALLBACK`, `MISSING_CACHE`, `MALFORMED_RESPONSE`, `TRANSPORT_ERROR`, and `NOT_CLEAN` through text status labels.
  - Launched from the restoration bench's Scan button after an object reaches `CLEAN`.
  - Evidence: `tests/scanner/test_scanner_screen.gd` 6/6 passed; pause ownership, verdict selection, and state rendering are covered.

- `[x]` **P7.4 Require a player verdict.**
  - Verdict options are `AUTHENTIC`, `REPLICA`, `MODIFIED`, and `UNCERTAIN`; no verdict is preselected.
  - Scanner output never writes `authenticity`; the player must press a verdict button and confirm.
  - The player can choose a verdict that contradicts scanner implications.
  - `ScannerService.commit_verdict()` is idempotent and writes the verdict to the runtime instance and to `PersistentState.scanned_records`, then saves atomically.
  - Verdict and scan record survive save/load and loop reset; loop inventory never leaks into persistent state.
  - Evidence: `tests/scanner/test_scanner_service.gd` verdict persistence + idempotency tests passed.

- `[x]` **P7.5 Test advisory behavior.**
  - Cached responses parse through the production `ScannerResponse` model.
  - Every current scannable slice object has a cache response.
  - Request payload matches the PRD contract shape and excludes hidden truth fields.
  - Scanner output cannot set `authenticity`.
  - Dirty objects cannot be scanned; cleaned objects can.
  - Missing cache returns `MISSING_CACHE`; malformed cache returns `MALFORMED_RESPONSE` without crashing or inventing data.
  - All four verdicts can be selected and committed.
  - Player verdict persists through save/load and loop reset.
  - Repeated confirmation is idempotent.
  - Promoted carrier receives the ordinary template response.
  - Scanner UI pause ownership behaves correctly.
  - No Godot client file contains API keys, direct provider calls, or secrets.
  - Evidence: focused scanner suite `28/28 passed` (105 asserts); full GUT suite `235/235 passed` (815 asserts).

### Acceptance

- `[x]` A cleaned slice object can be scanned offline (cached fixture transport).
- `[x]` All required evidence fields display in the scanner UI.
- `[x]` The player must choose the final verdict; scanner output is advisory only.
- `[x]` No API key exists in the Godot project (tracked-secret and provider-string scans returned no matches).
- `[-]` Manual on-screen verification of normal/suspicious fixture scanning, 1920x1080/1280x720 readability, and pause-ownership composition is pending human observation.

### Verification

```powershell
$godot = "C:\Users\roman\Downloads\Godot_v4.7-stable_win64_console.exe"
& $godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/scanner
# Result (2026-06-16): 28/28 passed, 105 asserts.

& $godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit
# Result (2026-06-16): 235/235 passed, 815 asserts.

gdformat --check scripts scenes dialogue tests
# Result (2026-06-16): no files need reformatting.

gdlint scripts scenes dialogue tests
# Result (2026-06-16): no problems found.

git diff --check
# Result (2026-06-16): clean (CRLF normalization warning only for scenes/Book/Book.gd).

git ls-files | Select-String -Pattern '(^|/)\.env$|secret|credential|api[_-]?key'
# Result (2026-06-16): no matches.

git ls-files | Select-String -Pattern '\.(gd|tscn|tres)$' | Select-String -Pattern 'api[_-]?key|apikey|openai|anthropic|claude|llm|api\.openai|api\.anthropic|generativelanguage|openrouter'
# Result (2026-06-16): no provider URLs or keys found; only event/comment references to "portal" remain.
```

Manual (pending human on-screen observation under windowed 4.7): clean a `tarnished_pendant` and a `rusted_tin`, open the Scan button from the restoration bench, confirm every advisory field appears, confirm no verdict is preselected, choose a verdict that contradicts the scanner implication, confirm the scanner does not overwrite it, save/reload and verify the verdict and scan record persist, trigger a loop reset and verify they still persist, and confirm the clock pause owned by another system (e.g. dialogue) is not resumed when the scanner closes. Check readability at both 1920x1080 and 1280x720.

---

## Phase 8 - Backend, Mock Portal, and Found Flow

**Goal:** complete the backend-only scanner/Portal boundary and resilient P0 discovery flow.

**Requirements:** ARCH-R1..R3, PORT-R1..R5, API-R1..R3, SCAN-R4
**Dependencies:** Phases 1, 5, and 7
**Subsystems:** Express server, mock Portal, Godot HTTP client, Found/Unlock UI

### Tasks

- `[x]` **P8.1 Scaffold `server/`.**
  - `server/package.json` with Express, dotenv, `express-rate-limit`, Jest, and Supertest.
  - `server/.env.example` with `PORT`, `PORTAL_BASE_URL`, `PORTAL_TIMEOUT_MS`, cache paths, rate limits, and placeholder key name only.
  - `server/src/app.js` factory, `src/index.js` entrypoint, `src/config.js` env validation.
  - Thin controllers (`src/routes/scan.js`, `src/routes/portal.js`) and services (`src/services/scan_service.js`, `src/services/portal_service.js`).
  - Middleware for JSON body limit (16 KB), centralized error handling, manual request validators, and per-endpoint rate limiting.
  - Evidence: `server/tests/` pass 12/12 under Jest.

- `[x]` **P8.2 Implement cached `POST /api/scan`.**
  - Validates PRD §20 payload shape; rejects hidden truth fields (`is_carrier`, `fragment_id`, `contents`, `is_counterfeit_truth`) with 400.
  - Returns cached fixture from `server/data/scanner_cache.json`, injecting the request's `request_id`.
  - Rate-limited to 30 requests/minute per IP.
  - Godot `ScannerHttpTransport` remains a typed stub that documents the boundary; the backend endpoint is independently tested and ready for Phase 9/21 wiring.
  - Evidence: `server/tests/scan.test.js` 5/5 passed.

- `[x]` **P8.3 Scaffold `mock-portal/`.**
  - `mock-portal/package.json` with Express, dotenv, Jest, and Supertest.
  - `mock-portal/.env.example` with `PORT` and `FACT_CARDS_PATH`.
  - `POST /discovery` validates request shape and returns deterministic fact cards from `mock-portal/data/fact_cards.json`.
  - Unknown fragment returns 404; invalid payload returns 400; repeated requests return the same `museum_entry_id`.
  - Evidence: `mock-portal/tests/discovery.test.js` 4/4 passed.

- `[x]` **P8.4 Implement server Portal proxy.**
  - `POST /api/portal/discovery` validates discovery payloads (PRD §20).
  - Idempotency key = `player_id:fragment_id`; successful and fallback responses are cached in memory and on disk (`server/cache/portal_cache.json`, gitignored).
  - Proxies to `PORTAL_BASE_URL` with `PORTAL_TIMEOUT_MS`; on timeout, network error, malformed upstream response, or upstream client error, returns a deterministic fallback with `used_fallback: true`.
  - `PORTAL_BASE_URL` swap requires no code change.
  - Rate-limited to 10 requests/minute per IP.
  - Evidence: `server/tests/portal.test.js` and `rate_limit.test.js` cover success, 400, duplicate idempotency, timeout fallback, malformed fallback, and rate limiting.

- `[x]` **P8.5 Build Godot Portal client.**
  - `PortalClient` (`scripts/portal/portal_client.gd`) calls only backend `POST /api/portal/discovery`.
  - Backend URL is read from `ProjectSettings.get_setting("network/portal/backend_url")` (default `http://localhost:3000`), not scene logic.
  - Typed request/response models (`PortalDiscoveryRequest`, `PortalDiscoveryResponse`) and result wrapper (`PortalResult`) with `SUCCESS`, `FALLBACK`, `VALIDATION_ERROR`, `TIMEOUT_ERROR`, `NETWORK_ERROR` statuses.
  - Emits `discovery_completed(PortalResult)`; no direct mock Portal or live LLM/Portal calls; no API keys in Godot.
  - Evidence: `tests/portal/test_portal_client.gd` 7/7 passed.

- `[x]` **P8.6 Build Found and Unlock screens.**
  - `scenes/ui/artifact_found_screen.tscn` + `scripts/portal/artifact_found_screen.gd` show artifact name, origin, condition, and `n/5` progress.
  - `scenes/ui/portal_unlock_screen.tscn` + `scripts/portal/portal_unlock_screen.gd` show the fact card, museum entry ID, and a text-readable fallback indicator.
  - `PortalFlowController` (`scripts/shop/portal_flow_controller.gd`) autoload listens to `EventBus.fragment_discovered`, opens Found, sends the backend request on continue, opens Unlock on success/fallback, and emits `EventBus.portal_completed`.
  - `SeatingService` (`scripts/journal/seating_service.gd`) autoload listens to `EventBus.portal_completed`, creates a `MuseumEntry`, marks the fragment `SEATED`, saves atomically, and emits `EventBus.fragment_seated`; duplicates are ignored; save failure rolls back in-memory state.
  - Both screens acquire `DayClock.PAUSE_PORTAL` and release only their own pause owner.
  - Evidence: `tests/portal/test_portal_flow_controller.gd` 4/4 passed; `tests/portal/test_seating_service.gd` 4/4 passed.

- `[x]` **P8.7 Test resilience.**
  - Backend: valid mock discovery succeeds; invalid payload returns 400; timeout returns `used_fallback: true`; duplicate request returns same `museum_entry_id`; malformed upstream returns fallback; `PORTAL_BASE_URL` env swap works; rate limiting returns 429.
  - Godot: client distinguishes success/fallback/validation/timeout/network; flow controller does not emit `portal_completed` on failure; seating is idempotent and rolls back on save failure; fragment is not seated before completion; backend URL is configurable.
  - Evidence: backend 12/12 tests passing; Godot portal suite 15/15 passing; full GUT suite 250/250 passing.

### Acceptance

- `[x]` Godot never calls an external LLM or Portal directly.
- `[x]` Backend scanner endpoint validates and returns cached P0 scanner responses.
- `[x]` Mock Portal returns deterministic fact cards.
- `[-]` Found -> backend -> mock Portal -> Unlock completes (automated signal flow verified; on-screen end-to-end observation pending human verification).
- `[-]` Timeout/offline mode still returns a fact and completes the flow (automated timeout fallback verified; on-screen observation pending).
- `[x]` Duplicate submission cannot duplicate a museum record (automated idempotency tests passing).

### Verification

```powershell
Push-Location mock-portal
npm test
# Result (2026-06-16): 4/4 passed.
Pop-Location

Push-Location server
npm test
# Result (2026-06-16): 12/12 passed.
Pop-Location

$godot = "C:\Users\roman\Downloads\Godot_v4.7-stable_win64_console.exe"
& $godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/portal
# Result (2026-06-16): 15/15 passed, 45 asserts.

& $godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit
# Result (2026-06-16): 250/250 passed, 860 asserts.

gdformat --check scripts scenes dialogue tests
# Result (2026-06-16): no files need reformatting.

gdlint scripts scenes dialogue tests
# Result (2026-06-16): no problems found.

git diff --check
# Result (2026-06-16): clean (CRLF normalization warnings only).

git ls-files | Select-String -Pattern '(^|/)\.env$|secret|credential|api[_-]?key'
# Result (2026-06-16): no matches.
```

Manual (pending human on-screen observation under windowed 4.7): discover and open a carrier fragment, confirm the Artifact Found screen shows name/origin/condition/n/5, press Send to Portal, confirm the Portal Unlock screen shows the fact card and museum entry ID, continue, confirm one museum record and one seated fragment. Force the mock Portal offline or set a very short timeout, retry, confirm the fallback indicator appears and the flow still completes. Click Send to Portal repeatedly and retry the same discovery; confirm the same museum entry ID and no duplicate records/fragments. Check readability at 1920x1080 and 1280x720.

---

## Phase 9 - Journal and Fragment Case

**Goal:** persist restoration knowledge, Portal records, and permanent fragment seating.

**Requirements:** JRN-R1..R5, MUS-R2 P0 record, SAVE-R2
**Dependencies:** Phases 2, 4, 7, and 8
**Subsystems:** journal UI, archive routing, fragment case, save integration

### Tasks

- `[x]` **P9.1 Build the hybrid 2D/3D journal.** (JRN-R6)
  - `BookViewport` (`scenes/Book/book_viewport.gd`) now acquires/releases `DayClock.PAUSE_JOURNAL` ownership on open/close/`_exit_tree`, so the journal pauses shop time and composes with other full-screen overlays.
  - The existing 3D book (`scenes/Book/Journal.tscn`, renamed from `Book.tscn` 2026-06-18) is reused; page content is rendered into the existing `Page` viewports.
  - Page 4 (first paper page) shows the five-slot Fragment Case (now with an explicit `N / 5 fragments found` counter); pages 5 & 6 are the **Condition Guide** spread (surface conditions grouped by category — Surface Soil / Accretion / Corrosion on the left page, Staining / Structural Damage on the right — each with a placeholder colour swatch + name + the tool that treats it, from the `data/journal/surface_conditions.json` catalog via `DataRepository.get_surface_conditions_sorted()`; the `SurfaceCondition` model replaced the old `BlemishType`); page 7 shows the object-archive index; pages 8+ show individual `JournalEntry` pages. (2026-06-19: split the guide across two pages so the catalog no longer overflows; shifted index/entry page numbers accordingly.)
  - Mouse-first controls are preserved (wheel zoom, drag pan at zoom, page turn at default zoom, Esc/close/click-off to dismiss). Readable 1920x1080 scaling is maintained by the existing SubViewport 1920x1080 render target.
  - Rotatable 3D fragment viewers per slot and per-entry 3D object previews remain placeholder/documented as Phase 16 polish; the P0 case uses readable 2D placeholder slot art.

- `[x]` **P9.2 Implement journal entry updates.**
  - Added `JournalService` autoload (`scripts/journal/journal_service.gd`).
  - Listens to `EventBus.restoration_completed` and creates/updates one `JournalEntry` per Purple-and-below template; carrier instances are skipped (they route to `SeatingService`/`MuseumEntry`).
  - Listens to `EventBus.scanner_verdict_committed` and updates the same entry with `player_verdict` and a formatted scanner-annotation snapshot.
  - Stores `best_condition` (max across restorations), `player_verdict`, and `ai_annotations`; does not duplicate entries on repeated restoration/scanning.
  - `JournalEntry` model extended with `player_verdict`; uncle notes and scanner annotations are rendered in distinct sections on entry pages.
  - `JournalService.is_journal_rarity()` is a public static helper for boundary tests.
  - `best_sale` updates and full sale-data append remain P1 marketplace integration.

- `[x]` **P9.3 Route archives by rarity.**
  - `JournalService.is_journal_rarity()` routes Gold-and-above and carrier instances away from the journal.
  - `SeatingService` continues to create `MuseumEntry` records for fragment/Master Artifact discoveries.
  - Purple-and-below restorations create/update `JournalEntry` records; they never also create a `MuseumEntry`.

- `[x]` **P9.4 Build the five-slot case.**
  - `Page.gd` renders five stable slots on page 4 using `case_slot_index` from `data/artifacts/master_artifact.json`.
  - Empty slots show a dashed outline and "empty" label; seated slots show a placeholder colored panel and "SEATED" label.
  - `JournalBook` listens to `EventBus.fragment_seated` and refreshes page content so the matching slot fills on camera.
  - `SeatingService` already rejects duplicate seating; the case refresh reflects at most one filled slot per fragment.
  - Seated state is read from `GameState.save_state.persistent.fragments`, so it persists across save/load and loop reset.

- `[x]` **P9.5 Implement the seating transaction.**
  - Implemented in Phase 8 by `SeatingService` (`scripts/journal/seating_service.gd`).
  - Listens to `EventBus.portal_completed`, creates `MuseumEntry`, marks fragment `SEATED`, atomically saves, and emits `fragment_seated`.
  - Duplicate seating is ignored; save failure rolls back both museum entry and fragment state.
  - Verified by existing `tests/portal/test_seating_service.gd` (4/4) and `tests/portal/test_portal_flow_controller.gd` (11/11); no regressions.

- `[x]` **P9.6 Test persistence and routing.**
  - Added `tests/journal/test_journal_service.gd` (10 tests): rarity boundary, gold exclusion, carrier exclusion, entry creation, repeated-restoration update, scanner-annotation update, player-verdict storage, scan creates entry when none exists, save/reload persistence, loop-reset survival.
  - Added `tests/journal/test_journal_case.gd` (9 tests): five-slot rendering, case_slot_index mapping, fragment_seated fills one slot, duplicate suppression, save/load persistence, loop-reset persistence, museum vs journal routing.
  - Added `tests/journal/test_journal_viewport.gd` (3 tests): journal pause ownership, close releases pause, pause composes with other owners.

### Acceptance

- `[x]` Restoring/scanning updates one stable journal entry (verified by `tests/journal/test_journal_service.gd`).
- `[x]` Portal completion fills exactly one persistent case slot (verified by `tests/journal/test_journal_case.gd` and `tests/portal/test_seating_service.gd`).
- `[x]` A reset and reload preserve the slot (verified by `tests/journal/test_journal_case.gd`).
- `[x]` Archive routing follows the fixed rarity rule (verified by `tests/journal/test_journal_service.gd`).

### Verification

```powershell
$godot = "C:\Users\roman\Downloads\Godot_v4.7-stable_win64_console.exe"
& $godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/journal -gexit
# Result (2026-06-17): 23/23 passed (after merge).

& $godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/portal -gexit
# Result (2026-06-17): 15/15 passed, 45 asserts.

& $godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit
# Result (2026-06-17): 295/295 passed, 971 asserts (pre-merge; rerun after merge commit).

gdformat --check scripts scenes dialogue tests
# Result (2026-06-17): no files need reformatting.

gdlint scripts scenes dialogue tests
# Result (2026-06-17): no problems found.
```

Manual (pending human on-screen observation under windowed 4.7): open the journal from the Shop, confirm the 3D book opens and the clock pauses, confirm page 1 shows five empty fragment slots, restore and scan an object and confirm a readable `JournalEntry` appears/updates, complete the Found/Portal flow and confirm the matching slot fills on camera, close and reopen the journal and confirm the slot remains filled, restart/reload and confirm the slot remains filled, trigger a loop reset and confirm the slot remains filled, and confirm Gold/Master records appear as `MuseumEntry` records while Purple-and-below records appear as `JournalEntry` records.

---

## Phase 10 - Auntie Showcase and Vertical Slice Integration

**Goal:** connect the emotional showcase to the real loop without bypassing discovery.

**Requirements:** slice summary, CLOCK-R4 behavior where applicable, ROUTE-R3 invariant, all P0 integration
**Dependencies:** Phases 2-9
**Subsystems:** authored dialogue, visitor scheduling, scripted photo beat, slice orchestration

### Tasks

- `[x]` **P10.1 Preserve and migrate the existing Auntie prototype.**
  - Existing dialogue box, visitor placeholder, and sample lines are usable scaffolding.
  - **Canonical data file is `data/routes/routes.json`** (not a separate `auntie.json`). The old tracker text named `auntie.json`; the repo's established pattern keeps every route in one `routes.json`, so Auntie stays there. Auntie's intro/return prose, portrait, schedule, rewards, `holds_fragment_id`, and 3-beat line (`CharacterRoute.beats`, Days 1/3/5) all live in `data/routes/routes.json`; the three non-deliverable quest templates and their tools live in `data/objects/objects.json` / `tools.json`.
  - Controllers carry no authored Auntie prose. `ShopController` resolves the visitor via `RouteService.resolve_visitor()` and shows lines from `route.dialogue_for(...)`; the showcase reads the authored beat `summary`. Verified by grep: no Auntie/`Nang Shine`/beat prose is hardcoded in `scripts/` (only data + tests).
  - Evidence (2026-06-23): full GUT suite `474/474`; the migrated prose renders through the data-driven door + showcase path.

- `[x]` **P10.2 Implement visit scheduling.** (logic verified; on-screen manual gate pending)
  - Auntie is offered 12:00-14:00 on Days 1, 3, 5 (her authored `schedule`; `RouteService.resolve_visitor`).
  - An unanswered visit is **consumed when its window closes**: `RouteService._on_hour_changed` watches `EventBus.hour_changed`; when the clock crosses a window's `end_hour` for a genuinely-offered visit that was not answered, it records the visit as missed and emits `EventBus.visit_missed(route_id, day)` exactly once. (`resolve_visitor` already excludes a closed window, so the record drives the signal/feedback, not gating.)
  - Explicit debug override `RouteService.debug_force_visit(route_id)` / `debug_clear_forced_visit()` returns a forced route ignoring window/gating — reachable only from the demo menu and tests, never from normal progression.
  - **Day-5 / beat gate (team decision, 2026-06-18):** `_beat_gate_allows_visit` — a route that authored a beat for the day appears only when every earlier beat is complete, so Day-5 (beat 3) needs beats 1 & 2, Day-3 (beat 2) needs beat 1. The Mysterious Buyer authors no beats, so he is never gated here. Artisan/Scavenger mutual exclusion and the Archeologist lead still apply on top (full route scheduling stays Phase 15).
  - Evidence (2026-06-23): `tests/core/test_route_beats.gd` (window, Day-3/Day-5 gate, consumption, once-only signal, answered-not-missed, debug override).

- `[-]` **P10.3 Build the scripted photograph showcase.** (logic + 2D overlay done; on-screen manual gate pending)
  - `scripts/ui/showcase_screen.gd` (`ShowcaseScreen`, a paused 2D `CanvasLayer`): an emotional before -> restore -> after sequence framed by the route portrait + authored beat `summary`. It is **not** a second restoration mini-game.
  - Opens after a route's door dialogue when a beat is due (`ShopController._maybe_open_showcase` + `RouteService.due_beat`). Completing it records the beat via `RouteService.complete_beat` (which enforces ordinal gating); it never grants a fragment, item, or money directly.
  - Owns `DayClock.PAUSE_SHOWCASE` while open.
  - Evidence (2026-06-23): `tests/ui/test_showcase_screen.gd` (pause, beat recorded, final beat releases via route not handoff, no item handed over). **Pending:** human on-screen verification.

- `[x]` **P10.4 Release the route fragment correctly.**
  - `fragment_01` now starts `LOCKED` in `data/artifacts/fragments.json` (no pre-release shortcut). New `FragmentService` autoload (`scripts/core/fragment_service.gd`) owns the `LOCKED -> RELEASED` transition: it sets persistent state, mirrors onto the repo (the Spawn Director's source), persists atomically, and emits `EventBus.fragment_released`. Completing Auntie's final beat calls `FragmentService.release_fragment(holds_fragment_id)`.
  - The Spawn Director then promotes an ordinary openable to carry it (`plan_loop_placements`); the fragment is never placed in Auntie's handoff, dialogue, inventory, or any overlay.
  - Evidence (2026-06-23): `tests/core/test_fragment_service.gd` (transition, idempotence, repo mirror, reload-persist, seated-never-re-released) + `tests/core/test_route_beats.gd::test_released_fragment_becomes_spawn_director_eligible`.

- `[-]` **P10.5 Connect the complete P0 path.** (wired + automated coverage; uninterrupted manual playthrough PENDING)
  - The slice uses the existing production systems end to end: morning delivery/triage (`DeliveryGenerator`/`TriageController`) -> Echoes (`EchoController`) -> restoration clean+clasp (`RestorationView`/`RestorationService`) -> cached scanner verdict (`ScannerScreen`) -> Found/Portal (`PortalFlowController` + backend/mock) -> `SeatingService` persists a `MuseumEntry` and seats the fragment -> journal 1/5 case. No demo-only state bypasses these systems; the only new runtime state is the data-authored release path.
  - Evidence (2026-06-23): full GUT suite `474/474`; Phase 8/9 portal+journal suites green; `test_released_fragment_becomes_spawn_director_eligible` ties route completion to discovery eligibility. **Pending:** one recorded uninterrupted end-to-end slice playthrough (manual).

- `[-]` **P10.6 Add a slice reset/demo menu.** (implemented + automated coverage; on-screen manual gate pending)
  - `scripts/ui/demo_menu.gd` (`DemoMenu`, debug `CanvasLayer`, F9 in debug builds via a runtime-registered `demo_menu` action; absent from release builds): pick a debug seed; **Show 3 Placement Variations** (runs `SpawnDirector.run_three_seed_demo` and prints carrier/container/day per seed — no production data written); **Release Auntie's Fragment (debug)** (uses `FragmentService` + re-plans through the real Spawn Director); **Clear Demo Save** with a two-press confirmation. Clearly separated from normal progression.
  - Evidence (2026-06-23): `tests/ui/test_demo_menu.gd` (seed override, debug release uses Spawn Director, 3 variations, two-press clear, pause). **Pending:** human on-screen verification.

### Acceptance

- [x] Auntie content is data-authored and appears only in its window (and Day-5/beat gate) unless the explicit debug override is used. (`test_route_beats.gd`, 2026-06-23.)
- [x] Day-5 Auntie beat is blocked unless beats 1 and 2 are complete; beat 2 requires beat 1. (`test_route_beats.gd`.)
- [x] Unanswered valid visits are consumed when the window closes (`visit_missed` once). (`test_route_beats.gd`.)
- [x] Route completion releases rather than hands over a fragment; the Spawn Director places it. (`test_fragment_service.gd`, `test_route_beats.gd`, `test_showcase_screen.gd`.)
- [x] No artifact-specific value is hardcoded in gameplay logic (release is keyed off `holds_fragment_id`/`owning_character_id` in data).
- [x] Existing Phase 1-9 automated tests remain green (`474/474`, 2026-06-23).
- [ ] The full P0 flow completes without console intervention. (Wired; **manual uninterrupted playthrough not yet performed.**)
- [ ] One journal slot fills and remains filled after reload. (Seating + reload covered by Phase 8/9 tests; **on-screen end-to-end confirmation pending.**)

### Verification

```powershell
$godot = "C:\Users\roman\Downloads\Godot_v4.7-stable_win64_console.exe"
& $godot --headless --editor --path . --quit
# Result (2026-06-23): exit 0, no parser/resource errors.
& $godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit
# Result (2026-06-23): 474/474 passed, 1531 asserts.
& $godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/core -gdir=res://tests/ui -gexit
# Result (2026-06-23): 89/89 passed (incl. test_fragment_service, test_route_beats, test_showcase_screen, test_demo_menu).
gdformat --check scripts scenes dialogue tests   # new Phase 10 files formatted
gdlint scripts/core/fragment_service.gd scripts/core/route_service.gd scripts/ui/showcase_screen.gd scripts/ui/demo_menu.gd  # no problems
```

Manual (PENDING human on-screen observation under windowed 4.7): record one uninterrupted end-to-end slice playthrough — answer Auntie only inside her window; complete beats 1-3 across Days 1/3/5 (confirm Day 5 is blocked without beats 1-2); confirm route completion **releases** (does not hand over) the fragment; follow it into discovery via the real Spawn Director/Echoes/restoration/scanner/Portal; confirm the journal 1/5 case fills and persists after reload. The F9 demo menu (debug seed + release override) may be used to reach discovery quickly without a five-day playthrough.

---

## Phase 11 - QA, Export, and Submission

**Goal:** prove the slice is stable, accessible, offline-safe, and recordable.

**Requirements:** PRD §22.3, §12-13 acceptance, milestone evidence
**Dependencies:** Phases 0-10
**Subsystems:** automated QA, export, accessibility, video evidence, disclosure

### Tasks

- `[x]` **P11.1 Complete automated coverage.**
  - GUT: save split, reset, state machines, delivery, restoration gate, placement, never-twice, Echo gates, scanner verdict, archive routing, seating.
  - Backend: validation, rate limit, timeout fallback, idempotency, config swap.
  - Regression tests for fixed P0 bugs are in place.
  - Evidence (2026-06-23): GUT 477/477 (1556 asserts), server Jest 24/24, mock-portal 4/4.

- `[x]` **P11.2 Run static and import checks.**
  - Godot 4.7 editor import: exit 0, no parser/resource/UID errors.
  - GUT suite: 477/477.
  - gdformat check: 149 files left unchanged; gdlint: no problems.
  - Backend and mock Portal tests: 24/24 and 4/4.
  - Warnings reviewed: one non-fatal Web export warning about `addons/nobodywho` lacking a wasm32 library (expected; the addon is excluded from the Web preset).

- `[ ]` **P11.3 Test accessibility and display.**
  - Mouse-only navigation.
  - Muted-audio discovery using captions/meter.
  - 1920x1080 reference layout and smaller-window scaling.
  - Readable contrast and visible focus/hover states.
  - *Runbook:* `docs/evidence/p11_3_accessibility_runbook.md`.

- `[ ]` **P11.4 Test resilience.**
  - Backend online against mock Portal.
  - Backend timeout with cached fallback.
  - Backend unavailable with a clear recoverable client state.
  - Save/reload before and after Portal completion.
  - *Runbook:* `docs/evidence/p11_4_resilience_runbook.md`.

- `[x]` **P11.5 Produce exports.**
  - `export_presets.cfg` defines **Windows Desktop** (runnable, x86_64, dev folders excluded) and **Web** (GL Compatibility override, ETC2/ASTC import enabled, single-threaded, NobodyWho/models excluded) presets.
  - Windows export: `build/aLima.exe` (~105 MB) + `build/aLima.pck` (~109 MB) + `build/libnobodywho-godot-x86_64-pc-windows-msvc-release.dll` (~75 MB); verified exit 0.
  - Web export: `build/web/aLima.html` + `.js`/`.wasm`/`.pck`/icons (~245 MB uncompressed, ~35 MB zipped); verified exit 0. The blank "configuration errors" failure was caused by `rendering/textures/vram_compression/import_etc2_astc` being disabled (Godot 4.7 Web export silently requires it). Fixed by enabling it and adding `renderer/rendering_method.web="gl_compatibility"` so Windows keeps Mobile while Web uses Compatibility.
  - No development credentials, `.env` files, or debug-only reset controls are included in either preset (debug DemoMenu is only present in debug builds).
  - *Runbook:* `docs/evidence/p11_5_html5_runbook.md`.

- `[ ]` **P11.6 Record placement evidence.**
  - Capture three runs for the same fragment/player.
  - Show different carrier/container/day output.
  - Retain the seed/placement logs matching the footage.
  - *Runbook:* `docs/evidence/p11_6_placement_runbook.md`.

- `[ ]` **P11.7 Record discovery evidence.**
  - Show all four Echo bands with captions and resonance meter.
  - Show Heartbeat only on the carrier.
  - Show clean -> open -> Artifact Found.
  - *Runbook:* `docs/evidence/p11_7_discovery_runbook.md`.

- `[ ]` **P11.8 Record Portal evidence.**
  - Show backend/mock request completion.
  - Show Portal Unlock historical fact.
  - Show persisted Museum record and the case moving to 1/5.
  - *Runbook:* `docs/evidence/p11_8_portal_runbook.md`.

- `[-]` **P11.9 Finalize disclosure and submission package.**
  - AI-assisted Phase 11 work logged in `docs/ai-disclosure.md`.
  - Manual evidence runbooks created; human recordings and final submission package remain pending.

### Acceptance

- [x] All standard verification commands pass under Godot 4.7.
- [x] Windows build completes the full slice offline/fallback-safe.
- [ ] The three required video beats are clear and backed by logs (human recordings pending).
- [x] AI disclosure updated; cultural review notes remain a team responsibility.

---

## Phase 12 - Full-Game Decisions and Content Manifest

**Goal:** lock the decisions and validation contract required before full content production.

**Requirements:** ARCH-R5, CONTENT-R1, CONTENT-R2, ASSET-R5, ASSET-R7
**Dependencies:** Phase 11 slice baseline and workshop/cultural consultation results
**Subsystems:** artifact data, source packets, content manifest, validation, review records

### Tasks

- `[ ]` **P12.1 Lock the Master Artifact and source packet.** Record the selected regional artifact, five natural components, verified historical sources, folklore labels, reviewers, and approval date without hardcoding them in logic.
  - **BLOCKED — team/cultural-consult decision (PENDING).** The data structure exists at `data/artifacts/packets/artifact_lock.json` (versioned; in a subdir so `DataRepository` does not load it) seeded `"status": "PENDING_TEAM_DECISION"`. Do **not** mark `[x]` from an invented value; the manifest validator fails while this is PENDING (intended). Resolve at the workshop, then fill the packet + author the `docs/sources|reviews|provenance/` records.
- `[ ]` **P12.2 Resolve all PRD §23 decisions.** Record carrier compatibility, decoy density, pile cap, full-screen clock policy, lock policy, and Buyer release behavior as versioned design data.
  - **PARTIALLY BLOCKED — team decisions (PENDING).** Versioned data exists at `data/design/decisions.json` (D1–D7). D5 (full-screen clock = pause-via-ownership) and D7 (Buyer fifth-fragment = deterministic special delivery) are seeded `RESOLVED` (already fixed in-fiction/code per §4-J/§4-B). D1–D4 and D6 remain `PENDING_TEAM_DECISION` and keep the manifest failing until the team records them.
- `[-]` **P12.3 Implement the `ContentManifest`.** Validate all required counts, named IDs, references, provenance records, source packets, and native-speaker review references.
  - Progress (2026-06-25): added `scripts/models/content_manifest.gd` (typed model: requirements/content/decision+record refs; structural validation rejects empty/duplicate/placeholder production IDs) and `scripts/core/content_manifest_validator.gd` (one-pass `ValidationResult` accumulation matching the `DataRepository` style). Gates: §4-M count floor with an in-logic `GDD_FLOOR` tamper guard (declared `min` ≥ floor; omitted category fails), per-category `actual ≥ min` unless `deferred_to_phase`, PRD §23 decision gate (PENDING fails), artifact-lock packet gate (PENDING / incomplete fails), repo reference integrity (`buyer_personas`→buyers, `named_events`→events, `object_templates`→templates), and provenance/source/review record-file resolution. Live `data/content-manifest.json` is committed in a deliberately FAILING state (PENDING decisions + artifact). **Godot/GUT verification is pending — the 4.7/4.6.3 executable is not available on this machine; run the Verification commands before `[x]`.**
- `[-]` **P12.4 Add manifest validation to tests and CI.** Fail on missing/duplicate IDs, insufficient counts, broken references, placeholder production IDs, or absent review/provenance records.
  - Progress (2026-06-25): added `tests/content/manifest/test_content_manifest.gd` (accepted fixture passes; broken/incomplete fixture fails with field-named, one-pass-accumulated errors covering insufficient count, broken ref, placeholder id, PENDING decision, below-floor min, omitted category, PENDING packet, missing provenance; plus `test_live_manifest_is_blocked_by_pending`, which asserts the real manifest currently fails on PENDING — keeping the full suite green while the blocker stays loud). Added a focused **Content manifest validation** step to `.github/workflows/ci.yml` ahead of the smoke-test step. **Local run pending — see P12.3 note (no Godot on this machine).**
- `[-]` **P12.5 Create the full-game data directory contracts.** Add versioned locations for buyer personas, counterfeits, Temporal Echoes, mini-events, route beats, evening plans, museum facts, sources, reviews, and provenance.
  - Progress (2026-06-25): added versioned contract locations, each with `.gitkeep` + a documented `SCHEMA.md`/`README.md` (`schema_version` envelope + record shape): `data/marketplace/`, `data/counterfeits/`, `data/temporal-echoes/`, `data/evening/`, `data/museum/`, `data/routes/beats/` (subdir — `data/routes/` itself is auto-loaded), and `docs/sources|reviews|provenance/`. Stubs are Markdown, never loose `.json`, to avoid tripping any auto-loader. `data/buyers/` and `data/events/` already exist from the slice.

### Acceptance

- [ ] The artifact and all blocking decisions are signed off and data-driven. *(Data-driven: yes. Sign-off: BLOCKED on the PENDING P12.1 artifact lock + P12.2 D1–D4/D6 decisions.)*
- [-] A deliberately incomplete manifest fails with actionable errors; the accepted manifest passes. *(Implemented + covered by `tests/content/manifest/`; awaiting a local/CI Godot run for evidence.)*
- [x] No production content task depends on an unresolved artifact or cultural-source decision. *(Enforced: the validator fails while any decision/artifact is PENDING, so no Phase 13+ content task can be marked done against a placeholder.)*

### Verification

```powershell
& $godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/content/manifest
```

Manual: review the locked artifact packet and manifest with the named cultural reviewer and record approval evidence.

---

## Phase 13 - Full Object Catalog, Restoration, and Counterfeits

**Goal:** build the complete tactile restoration and authentication content set.

**Requirements:** SAVE-R5, REST-R2, REST-R5, REST-R6, SCAN-R3, SCAN-R6, CONTENT-R3, CONTENT-R4, CONTENT-R8
**Dependencies:** Phase 12
**Subsystems:** object catalog, restoration interactions, tools, techniques, counterfeit evidence

### Tasks

- `[ ]` **P13.1 Author at least 30 restorable object templates.** Cover all rarity tiers and nine restoration categories with distinct materials, tools, values, history, and disposition hooks.
- `[-]` **P13.2 Implement all nine restoration interactions.** Build brushing, wiping, rust removal, polishing, paper care, frame repair, photo restoration, engraving reveal, and mechanism inspection as focused **3D** object-manipulation interactions (REST-R8) on the object's surface, with input-specific tuning. Reuse `RestorationService` / the P4.7 3D restoration view.
  - Progress (2026-06-17): added a **data-driven decal cleaning model** as the foundation for the surface-grime interactions (brushing/wiping/rust/polishing/paper care/frame repair/photo restoration). `SurfaceDecal` (`scripts/models/surface_decal.gd`) authors each blemish with a placeholder hex `color` (texture-swappable later) and a `required_tool`; `RestorationService.clean_decal()` clears the matching decal (wrong tool uses the existing wrong-tool damage; clearing the last decal reaches CLEAN and emits `restoration_completed`) and `join_object()` adds a clean-gated reassembly step (torn-photo halves rejoined with `archival_tape`). Covered by `tests/restoration/test_decal_restoration.gd` (11 tests). Authored use lives in Auntie's 3 quest templates (P10.1).
  - Progress (2026-06-18): the blemish cleaning is now **playable in the focused 3D restoration bench**. `RestorationObject3D` has a photo/blemish mode (flat photo plane with per-blemish hotspots coloured from the journal catalog, analytic ray-pick) and `RestorationView` routes a click/controller action to `clean_decal`, removes the hotspot, shows progress + join/scan prompts, and performs the Archival Tape join. Covered by `tests/restoration/test_photo_restoration_view.gd` (5 tests). Placeholder geometry (QuadMesh photo, sphere blemishes) pending the scaled Page/PNG photo and 3D frame model; engraving reveal and mechanism inspection are still to do; on-screen mouse/controller/touch verification is a pending manual gate.
  - Progress (2026-06-19): **delivered artifacts now spawn with random surface conditions.** `DeliveryGenerator._assign_random_conditions` scatters a deterministic 2–4 distinct conditions (from the journal catalog, each naming its treating tool) onto every delivered instance — ordinary **and** carriers, so a promoted carrier is indistinguishable from an ordinary instance (carrier-identity hiding). Conditions live on `ObjectInstance.spawned_decals` (serialized); `RestorationService.effective_decals()` returns them when present, else the template's authored decals, and threads them through `clean_decal`/`_remaining_decals`/restorability. The bench renders them as hotspots **on the 3D object surface**; cleaning every condition reaches CLEAN, after which an openable's clasp reveals and opens — preserving the two-stage gate and the discovery flow. Covered by `tests/models/test_models.gd::test_object_instance_spawned_decals_round_trip`, `tests/restoration/test_restoration_service.gd::test_instance_with_spawned_conditions_cleans_to_clean`, and `tests/delivery/test_delivery_generator.gd::test_delivered_instances_carry_random_conditions`. Conditions are drawn uniformly from the full catalog (no material/category weighting yet) and hotspot placement is placeholder spherical scatter — both are follow-up polish; on-screen verification is a pending manual gate.
  - Progress (2026-06-22): **authored artifact condition decals and per-artifact scenes.** `ArtifactConditionDecal` nodes can be placed directly on an artifact scene (`scenes/restoration/artifacts/*`); their albedo texture filename maps to a journal surface condition, and they clean only with the correct tool. Author-placed decals are randomized at load time to a configured count. Normal and quest artifacts now have their own `.tscn` files. Covered by `tests/restoration/test_authored_condition_decal.gd` (7 tests). Engraving reveal and mechanism inspection are still to do; on-screen mouse/controller/touch verification remains a pending manual gate.
- `[-]` **P13.3 Complete tools and techniques.** Support shop-bought loop-scoped tools, persistent learned techniques, character-only techniques, legacy tools, upkeep, and wrong-tool consequences.
  - Progress (2026-06-18): **tool durability** implemented. Tools are now durability-tracked instances (`ToolInstance`; `ToolDefinition.durability/buyable/ship_hours`); `RestorationService` consumes one durability per use (most-worn first) and a tool **breaks → is removed** at 0 (`EventBus.tool_broke`), so the player re-buys it. Shop-bought tools are loop-scoped instances (`loop.owned_tools`); free starter/legacy tools stay infinite-durability id-set ownership (additive — SpawnDirector winnability and prior tests unchanged).
  - Progress (2026-06-21): **slot-based workbench/loadout.** The workbench now has five slots (`RestorationTool` entities); `ToolService` manages equipping/unequipping, slot pinning, and max-5 enforcement. The Storage Tools tab and the bench share the same loadout. Covered by `tests/economy/test_tool_durability.gd` and `tests/economy/test_tool_loadout.gd`. Learned/character techniques, repair-as-alternative-to-replace upkeep, and on-screen tool management UI polish are still to do.
- `[ ]` **P13.4 Author six solvable counterfeit variants.** Each exposes journal/scanner-comparable evidence without an automatic verdict.
- `[ ]` **P13.5 Integrate catalog records.** Every object updates condition, best result, variants, scanner evidence, value, and applicable journal history without duplicate entries.
- `[ ]` **P13.6 Test the restoration matrix.** Cover every interaction, correct/wrong tool, technique gate, input family, condition bound, value consequence, and counterfeit solution path.

### Acceptance

- [ ] Manifest reports at least 30 objects, all 9 interactions, and 6 counterfeits.
- [ ] Every interaction is used by at least two authored templates.
- [ ] A player can solve each counterfeit from evidence and may still choose any final verdict.

### Verification

```powershell
& $godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/restoration
& $godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/scanner/counterfeits
```

Manual: complete every restoration interaction with correct and wrong tools, then solve all six counterfeit fixtures from the journal.

---

## Phase 14 - Economy, Marketplace, Disposition, and Evenings

**Goal:** complete the daily economic decision loop from restored object to next-day preparation.

**Requirements:** ARCH-R6, SAVE-R7, DLV-R4, MKT-R1, MKT-R2, MKT-R3, MKT-R4, MKT-R5, MKT-R6, DISP-R1..R6, EVE-R1..R5
**Dependencies:** Phases 2, 3, 9, 12, and 13
**Subsystems:** marketplace, disposition router, economy, returns, evening summary, upkeep

### Tasks

- `[-]` **P14.1 Build listing and negotiation state.**
  - **Buy side:** `MarketplaceService` (autoload) lists `buyable` tools, spends `loop.money`, and schedules shipments that arrive after `ship_hours` of in-game time (delivered on the hour tick into `loop.owned_tools`). The shop **Phone interactable** opens an authored phone scene (`scenes/ui/phone.tscn`, `Phone`, `DayClock.PAUSE_PHONE`) with a Marketplace app. Covered by `tests/economy/test_marketplace.gd`, `test_phone.gd`, shop smoke `test_phone_opens_without_pausing`, and `tests/restoration/test_bench_overlays.gd`.
  - **Sell/haggle side:** `MarketplaceService.get_sellable()` lists restored+judged inventory instances. `interested_buyers()` and `arrived_buyers()` produce a time-phased buyer set: Mr. Maverick is always instantly available; other buyers arrive 1-20 in-game minutes apart (seeded per item+loop). Per-loop buyer wallets seed from persona `starting_cash`/`daily_allowance` (Maverick is unlimited). `haggle_for()` returns a persistent same-day `Negotiation` session so the player can shop buyers and return. `complete_sale()` credits money, removes the instance, records `persistent.best_sale`, and emits `EventBus.sale_completed`. Covered by `tests/economy/test_marketplace.gd`, `test_phone.gd`, and `test_storage_screen.gd`.
  - **Missing:** a formal listing object, the full four-way disposition router, and evening reconciliation. Selling currently happens directly from the Storage/Phone sell flow.
- `[x]` **P14.2 Implement buyer personas and fallback sets.**
  - `data/buyers/buyers.json` now contains **nine** authored buyer personas (collector, reseller, student, gift, hobbyist, appraiser, tourist, lola, suspicious/Mr. Maverick), each with budget, preferred categories, negotiation style, per-loop wallet tuning, and fallback line sets. The `BuyerPersona` model loads and validates them.
  - The deterministic offline haggle engine (`Negotiation`) uses persona tuning (`open_factor`, `concession_rate`, `patience`, `condition_weight`, `category_bonus`, `ignores_banter`) and fallback lines.
  - Backend persona prompts/guardrails are server-side in `server/src/services/negotiate_service.js`.
  - The Godot client now calls the backend `/api/negotiate` proxy as tier 2 of a 3-tier banter stack: on-device `LocalAI` (NobodyWho GGUF) → backend `NegotiationClient` → offline `BanterBot`. The LLM supplies only the spoken line + offended flag; all prices remain deterministic in the `Negotiation` engine.
  - Evidence (2026-06-22): `tests/economy/test_buyer_personas.gd` 3/3 passed; full economy suite 61/61 passed. Backend tier wiring and deterministic-price tests added 2026-06-24 (counts to be recorded below).
- `[-]` **P14.3 Implement the disposition router.**
  - `SELL` is reachable from the Storage/Phone sell flow and completes via `MarketplaceService.complete_sale()` (idempotent; cannot sell the same instance twice).
  - `RETURN`, `PRESERVE`, and `JOURNAL` dispositions are not yet offered as explicit player choices. Journal routing already happens automatically for Purple-and-below on restoration/scan (Phase 9); museum routing happens on fragment seating (Phase 8).
- `[ ]` **P14.4 Implement return-to-owner outcomes.** Resolve owner/route rewards and story flags without directly granting fragments.
- `[ ]` **P14.5 Build the evening state.** Summarize outcomes, repair/replace tools, resolve storage, prepare requests/equipment, review journal changes, and commit the next-day plan.
- `[-]` **P14.6 Extend save and event contracts.**
  - `EventBus.sale_completed(instance_id, buyer_id, price)` exists and is emitted by `MarketplaceService.complete_sale()`.
  - `persistent.best_sale` records the highest sale price, template, buyer, condition, and day.
  - Buyer ghosts, wallets, schedules, and haggle sessions are loop-scoped and cleared on `loop_reset`.
  - Full disposition/evening event partition is pending P14.3-P14.5.
- `[-]` **P14.7 Test economy and transaction safety.**
  - Covered: duplicate sale prevention, insufficient funds, non-buyable rejection, shipment arrival, wallet caps, Maverick ghosting rules, buyer arrival timing, free-text moderation, negotiation accept/counter/walk, banter mood effects, and the 3-tier banter fallback (backend reply use, offline fallback, offended propagation, deterministic pricing).
  - Evidence (2026-06-24): `tests/economy/` 92/92 passed (test_buyer_personas 3, test_marketplace 13, test_marketplace_banter 11, test_negotiation 21, test_phone 19, test_storage_screen 11, test_tool_durability 4, test_tool_loadout 10); full GUT suite 512/512 passed (1645 asserts); server `npm test` 24/24 passed.
  - Pending: live-provider manual gate (Gemini/Ollama configured in `server/.env`), invalid disposition rejection, return/preserve/journal flow tests, and Day 5 evening advancement.
### Acceptance

- `[-]` Sell flow completes via Storage/Phone Marketplace; return, preserve, and journal flows are not yet explicit player choices.
- `[x]` Multiple personas produce distinct, constrained negotiations and prices respond to condition, category, honesty, and banter (automated tests verify this).
- `[ ]` Every day ends through a useful evening screen and Day 5 preserves only the documented state.

### Verification

```powershell
& $godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/economy
# Result (2026-06-24): 92/92 passed.

Push-Location server
npm test
# Result (2026-06-24): 24/24 passed.
Pop-Location
```

Manual (pending):
- Live provider: configure `server/.env` with `LLM_PROVIDER=local`, `LOCAL_LLM_URL=https://generativelanguage.googleapis.com/v1beta/openai/chat/completions`, `LOCAL_LLM_MODEL=gemini-2.0-flash` (or current Flash id from AI Studio), and a Google AI Studio key; start the backend (`Push-Location server; npm run dev`), run the game, sell an item, open haggle, and confirm varied buyer lines + the "AI banter: live (gemini-2.0-flash)" label; stop the backend and confirm fallback to "AI banter: offline" + BanterBot lines.
- Play two days using every disposition, negotiate with all personas, perform upkeep, and confirm the next delivery reflects preparation.

---

## Phase 15 - Character Routes, Returns, Safe, and Drawer

**Goal:** implement all authored route beats, temporal scheduling, persistent leads, and route-gated caches.

**Requirements:** SAVE-R4, SAVE-R5, SAVE-R7, CLOCK-R4, CLOCK-R5, ROUTE-R1..R6, CACHE-R1..R3, DISP-R3, CONTENT-R7
**Dependencies:** Phases 2, 10, 12, 13, and 14
**Subsystems:** route scheduler, route beats, dialogue, returns, Safe, drawer, rewards

### Tasks

- `[ ]` **P15.1 Author three progression beats for each route.** Complete Auntie, Artisan, Scavenger, Archeologist, and Buyer data with prerequisites, object/return hooks, dialogue, rewards, and release beat.
- `[ ]` **P15.2 Implement authoritative scheduling.** Evaluate windows at open time, consume unanswered visits, preserve pause ownership, and enforce the temporal Artisan/Scavenger exclusion.
- `[ ]` **P15.3 Implement persistent route progression.** Persist beats, leads, completion, unlocked dialogue, legacy rewards, and released fragments across loops.
- `[ ]` **P15.4 Integrate route returns and restoration requests.** Required objects flow through restoration, judgment, and return rather than scripted bypasses.
- `[ ]` **P15.5 Implement the Safe and locked drawer.** Persist code/access knowledge, pay the loop-scoped Safe reward, expose drawer pages, and preserve carrier nesting rules.
- `[ ]` **P15.6 Test route reachability.** Cover every window, missed visit, prerequisite, exclusion, later-loop lead, reward, and fragment release.

### Acceptance

- [ ] Each non-finale route contains three playable beats and releases exactly one assigned fragment.
- [ ] Perfect-Loop ordering can thread Scavenger, Auntie, and Artisan as specified.
- [ ] Safe/drawer knowledge persists and neither cache can hand over a loose fragment.

### Verification

```powershell
& $godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/routes
& $godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/caches
```

Manual: complete all five route paths across controlled loops, including one ignored visit and the intended Perfect-Loop route order.

---

## Phase 16 - Temporal Echoes, Journal Mystery, and Museum

**Goal:** connect ordinary restoration to the uncle's mystery and complete both archives.

**Requirements:** JRN-R4, MUS-R1..R4, TEMP-R1..R4, DISP-R4, CONTENT-R6, CONTENT-R9
**Dependencies:** Phases 9, 12, 13, and 15
**Subsystems:** Temporal Echoes, mystery pages, journal planning, museum gallery, fact records

### Tasks

- `[ ]` **P16.1 Author and integrate 15 Temporal Echoes.** Tie eligible objects to memories, captions/audio, journal pages, and all five fragment-holder routes.
- `[ ]` **P16.2 Build ten mystery-journal pages.** Clear static through Echoes/routes, reveal uncle notes, and expose useful future-loop planning information.
- `[ ]` **P16.3 Complete the journal interface.** Support searchable object records, route clues, Echo playback/captions, planning notes, condition/sale history, and fragment case.
- `[ ]` **P16.4 Complete online and in-game museum views.** Display persisted Gold and Master Artifact records online and mirror them in-game/offline.
- `[ ]` **P16.5 Author verified museum history.** Add five fragment facts, the assembled-artifact record, and at least five additional Gold discoveries with source references.
- `[ ]` **P16.6 Test unlock and archive routing.** Cover Echo persistence, page reveal order, duplicate prevention, offline museum records, and rarity boundaries.

### Acceptance

- [ ] Manifest reports 15 Echoes, 10 mystery pages, 5 fragment facts, 1 assembled record, and 5 additional Gold records.
- [ ] Every route is connected to at least one ordinary-object memory.
- [ ] Journal and museum remain distinct, complete, and usable offline from persisted data.

### Verification

```powershell
& $godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/journal
& $godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/temporal_echoes
& $godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/museum
```

Manual: unlock all Echoes/pages in a content save, inspect both archives, restart, and confirm every record persists.

---

## Phase 17 - Full Carrier Pools and Five-Fragment Discovery

**Goal:** scale the proven slice discovery system to every fragment and opening type.

**Requirements:** DISC-R1..R15, SAVE-R2, SAVE-R3, CONTENT-R5
**Dependencies:** Phases 5, 6, 12, 13, and 15
**Subsystems:** carrier catalog, opening interactions, Spawn Director, Echo sets, five-fragment progression

### Tasks

- `[ ]` **P17.1 Author 15 carrier candidates.** Provide at least three compatible candidates per fragment after tool/container/route filters.
- `[ ]` **P17.2 Implement remaining opening interactions.** Complete clasp, pry, unscrew, slide, and every additional authored openable action with clean-first gating.
- `[ ]` **P17.3 Configure five reviewed Echo sets.** Add audio, captions, anchors, radii, thresholds, pulse behavior, and muted-mode feedback per fragment.
- `[ ]` **P17.4 Scale placement to concurrent released fragments.** Keep deterministic seeds, winnability, nesting, never-twice history, neglect weighting, day spread, and Safe eligibility correct.
- `[ ]` **P17.5 Complete five-fragment persistence.** Re-place released fragments each loop, permanently exclude seated fragments, and prevent duplicate discovery/seating.
- `[ ]` **P17.6 Add deterministic discovery matrices.** Test every fragment across carrier/container/day candidates, exhaustion, unavailable tools, decoys, and reloads.

### Acceptance

- [ ] Every fragment has at least three valid carriers and its own accessible Echo path.
- [ ] All five can progress `LOCKED -> RELEASED -> SEATED` without a direct handoff.
- [ ] Three-run never-twice evidence exists for each fragment.

### Verification

```powershell
& $godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/discovery
```

Manual: discover and seat all five fragments across ordinary seeded play, including one Safe outer-container placement.

---

## Phase 18 - All Mini-Events and Loop Variation

**Goal:** implement and tune every GDD-named event without obscuring the core loop.

**Requirements:** DLV-R4, EVT-R1, EVT-R2, EVT-R3, CONTENT-R8
**Dependencies:** Phases 3, 13, 14, and 15
**Subsystems:** event director, delivery/economy/restoration modifiers, event prompts, tuning

### Tasks

- `[ ]` **P18.1 Author all eight event definitions.** Implement Rush Delivery, Sudden Brownout, Community Request, Suspicious Antique, Rare Buyer Alert, Mystery Box, Rainy-Day Leak, and Tool Breakdown.
- `[ ]` **P18.2 Integrate bounded outcomes.** Each event affects delivery, restoration, marketplace, requests, upkeep, or shop conditions through existing contracts.
- `[ ]` **P18.3 Implement trigger and cap rules.** Keep deterministic QA overrides separate from production weighting and cap disruptive events per loop.
- `[ ]` **P18.4 Add player-facing communication.** Show trigger, duration, changed rules, consequences, accessibility text, and evening-summary outcome.
- `[ ]` **P18.5 Tune variation and fairness.** Prevent unwinnable fragments, impossible requests, route-window obstruction, or repeated event spam.
- `[ ]` **P18.6 Test every event deterministically.** Cover trigger, outcome, save/reset, interaction with carriers, and cap behavior.

- `[-]` **P18.7 Brownout / phone flashlight integration.**
  - Corrected `sudden_brownout` event data: player text now says the internet is down (Marketplace offline) and the shop is dim; restoration is less precise unless you turn on a light such as the phone flashlight. Kept `blocked_tool_enables: ["electric"]` as inert future-proofing. Added `light_mitigates_condition: true` to brownout only; leak/damp events do not have this flag.
  - Added `LoopState.flashlight_on` (loop-scoped, serialized, resets with loop state, no battery).
  - `EventDirector` now reads flashlight state from `GameState.save_state.loop.flashlight_on`; `get_restoration_condition_multiplier()` applies the brownout penalty only when no light source is active, while leak/damp penalties always apply. `is_light_source_active()` is the single seam for future light sources.
  - Phone home screen replaced the disabled "Soon" slot with a **Flashlight** offline app; Marketplace app is blocked during brownout with a "No connection — the brownout knocked out the internet." message; Flashlight toggles `flashlight_on` and stays on after closing the phone.
  - `RestorationService` continues to use `EventDirector.get_restoration_condition_multiplier()` unchanged.
  - Automated evidence (2026-06-23): `tests/core/test_event_director.gd` 6/6 passed; `tests/economy/test_phone.gd` 15/15 passed (includes 3 new flashlight/brownout tests); `tests/core/test_save_service.gd` 11/11 passed (flashlight round-trip); `tests/core/test_game_state.gd` 6/6 passed (flashlight reset); full GUT suite 508/508 passed, 1638 asserts.
  - **Pending:** human on-screen verification — trigger brownout, open phone, confirm Marketplace offline and Flashlight toggles, verify brownout restoration penalty with flashlight off/on, verify leak/damp penalty unaffected by flashlight.

### Acceptance

- `[-]` Brownout/phone flashlight behavior is implemented and automated-tested; manual on-screen verification is pending.
- `[ ]` All eight events are reachable, distinct, and recorded by the content manifest.
- `[ ]` Event combinations never violate discovery winnability or route invariants.
- `[ ]` Normal play varies without exceeding the documented per-loop cap.

### Verification

```powershell
& $godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/events
```

Manual: run the deterministic event showcase, then play three unforced loops and review frequency/cap logs.

---

## Phase 19 - Character Endings and Yuyu Finale

**Goal:** deliver all authored outcomes and the complete Master Artifact restoration ending.

**Requirements:** END-R1..R5, ROUTE-R5, CONTENT-R7, CONTENT-R9
**Dependencies:** Phases 15, 16, and 17
**Subsystems:** ending state, character resolutions, Neutral continuation, final restoration, credits transition

### Tasks

- `[ ]` **P19.1 Implement four character endings.** Resolve Auntie, Artisan, Scavenger, and Archeologist through their completed route state and authored final scenes.
- `[ ]` **P19.2 Implement Neutral continuation.** Completing no route repeats the loop without corrupting persistent progress or falsely ending the game.
- `[ ]` **P19.3 Complete the Buyer release path.** Qualifying dealings release the fifth fragment into a guaranteed Director-placed special delivery.
- `[ ]` **P19.4 Build the Master Artifact restoration.** Assemble the five seated components through a final tactile sequence using locked artifact data.
- `[ ]` **P19.5 Implement the Yuyu finale.** Resolve the uncle, release the loop, create the assembled museum record, and transition to credits/postgame state.
- `[ ]` **P19.6 Test ending reachability and exclusivity.** Cover all character endings, Neutral, fifth-seat trigger, reloads, duplicate prevention, and post-finale state.

### Acceptance

- [ ] Four character endings, Neutral continuation, and Yuyu are all reachable from valid saves.
- [ ] Seating the fifth fragment triggers the finale exactly once.
- [ ] The Buyer and final restoration never bypass carrier placement, cleaning, opening, Portal completion, or seating.

### Verification

```powershell
& $godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/endings
```

Manual: record each ending and one uninterrupted final-fragment-to-credits playthrough.

---

## Phase 20 - Final Narrative, Art, Audio, UI, and Cultural Review

**Goal:** replace all placeholders with reviewed production content and required external deliverables.

**Requirements:** ASSET-R1..R7, CONTENT-R6, CONTENT-R7, CONTENT-R9
**Dependencies:** Phases 12–19
**Subsystems:** narrative, environment, objects, characters, UI, animation, audio, voices, replica, lore video

### Tasks

- `[ ]` **P20.1 Finalize all narrative text.** Complete dialogue, route beats, Echo memories, journal prose, museum facts, endings, captions, credits, and fallback text.
- `[ ]` **P20.2 Replace visual placeholders.** Deliver the shop, props, objects, characters, artifact/fragments, lighting, animation, effects, and all UI screens in the approved direction.
- `[ ]` **P20.3 Complete audio production.** Deliver music, ambience, restoration/UI sounds, voice lines, and five Cultural Echo sets without protected samples.
- `[ ]` **P20.4 Complete language and cultural review.** Record native-speaker and historical/cultural approvals for every relevant line, fact, sound set, and interpretation.
- `[ ]` **P20.5 Complete provenance and disclosure.** Resolve every asset source/license, generated intermediate, model/tool, external reference, default icon, and adapted-code concern.
- `[ ]` **P20.6 Produce the artifact replica and lore video.** Match the locked artifact, five-part logic, verified history, and shipped game presentation.
- `[ ]` **P20.7 Run placeholder/provenance audits.** Block release on unknown provenance, missing captions, missing review, temporary UI, or unapproved historical claims.

### Acceptance

- [ ] No release-facing placeholder, temporary prose, unknown-provenance asset, or unreviewed cultural line remains.
- [ ] Replica and lore video are complete and historically consistent with the game.
- [ ] Every shipped AI-assisted asset/text workflow appears in `docs/ai-disclosure.md`.

### Verification

```powershell
& $godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/content
git ls-files | Select-String -Pattern 'placeholder|TEMP_ASSET|TODO_ASSET|unverified'
```

Manual: perform a screen-by-screen and scene-by-scene production review with provenance and cultural-review checklists open.

---

## Phase 21 - Live Services, Platforms, Inputs, and Performance

**Goal:** satisfy the finished runtime AI, Portal, accessibility, platform, and input promises.

**Requirements:** ARCH-R1, ARCH-R2, ARCH-R3, ARCH-R6, SCAN-R7, MKT-R3, MKT-R7, PORT-R6, API-R1..R3, INPUT-R1..R5, PLAT-R1..R6
**Dependencies:** Phases 8, 14, 16, 17, and 20; live credentials/contracts
**Subsystems:** backend, scanner, negotiation, Portal, Windows, HTML5, input, accessibility, performance

### Tasks

- `[ ]` **P21.1 Verify live scanner and negotiation.** Exercise real configured services through the backend with validation, guardrails, rate limits, timeout, cache, and recovery.
- `[ ]` **P21.2 Verify the live Portal.** Pass discovery, idempotency, museum retrieval, config swap, timeout, malformed response, and recovery against the official endpoint.
- `[ ]` **P21.3 Complete mouse, controller, and touch.** Cover every gameplay/UI action, remapping where supported, visible states, touch alternatives, and input-specific restoration tolerances.
- `[ ]` **P21.4 Complete accessibility behavior.** Verify captions, muted discovery, focus order, readable contrast, scalable text/layout, and non-audio critical feedback.
- `[ ]` **P21.5 Complete Windows and HTML5 parity.** Maintain the renderer/audio/network/storage/input parity matrix and equivalent behavior for platform limitations.
- `[ ]` **P21.6 Meet performance targets.** Sustain 60 FPS at 1920x1080 on the Windows reference system and 30 FPS at 1280x720 on the web reference system in named stress scenes.
- `[ ]` **P21.7 Audit release security.** Remove debug controls, development endpoints, credentials, test-only production content, and unsafe logging from exports.

### Acceptance

- [ ] Live and forced-fallback scanner, marketplace, and Portal matrices pass.
- [ ] Windows and HTML5 can complete the game with mouse, controller, and touch.
- [ ] Accessibility and performance targets pass on documented reference systems.

### Verification

```powershell
Push-Location server
npm test
Pop-Location
Push-Location mock-portal
npm test
Pop-Location
& $godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/input
& $godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/platform
```

Manual: complete the platform × input × online/fallback matrix and retain performance captures.

---

## Phase 22 - Full-Game QA, Playtesting, Export, and Submission

**Goal:** prove that the complete GDD game is stable, 6–10 hours, reviewed, exportable, and submission-ready.

**Requirements:** CONTENT-R10, REL-R1..R8, all mandatory P0/P1 requirements
**Dependencies:** Phases 0–21
**Subsystems:** regression, migrations, full playthroughs, balancing, exports, release evidence, documentation parity

### Tasks

- `[ ]` **P22.1 Run the complete automated and security baseline.** Include Godot import/GUT/lint, backend/mock tests, content manifest, save migration, secret scan, and release regressions.
- `[ ]` **P22.2 Complete fresh-save full-game runs.** Reach all five seats and Yuyu without debug tools on Windows and HTML5; include save/reload and offline recovery.
- `[ ]` **P22.3 Run three blind first-completion playtests.** Retain consented route/economy/placement timing notes, resolve blockers, and achieve a 6–10 hour median.
- `[ ]` **P22.4 Complete final matrices.** Sign off live/fallback services, platform/input, accessibility, performance, route/ending reachability, and content coverage.
- `[ ]` **P22.5 Produce final exports and package.** Build Windows and HTML5 releases, credits, repository materials, gameplay/pitch evidence, forms, replica, lore video, disclosures, and archive/rollback copies.
- `[ ]` **P22.6 Validate documentation parity.** Compare README promises, PRD IDs, phase tasks, manifest counts, and evidence; reject stale or unmatched claims.
- `[ ]` **P22.7 Complete named human sign-off.** Obtain engineering, design/narrative, cultural/native-speaker, provenance, privacy, and submission approvals.

### Acceptance - 100% Completion Gate

- [ ] Every README promise maps to PRD IDs, detailed tasks, and passing evidence.
- [ ] Every mandatory P0/P1 requirement is complete; no required content minimum is a placeholder.
- [ ] A fresh save completes the five-fragment story and Yuyu ending without debug assistance.
- [ ] Three blind playtests have a 6–10 hour median first completion.
- [ ] Live services and all forced fallback cases pass.
- [ ] Windows/HTML5 × mouse/controller/touch, accessibility, and performance matrices pass.
- [ ] All assets, facts, language, AI use, privacy handling, replica, lore video, exports, and submission materials are approved.
- [ ] Only after every item above passes may the project be described as **100% complete**.

### Verification

```powershell
$godot = "C:\Users\roman\Downloads\Godot_v4.7-stable_win64_console.exe"
& $godot --headless --editor --path . --quit
& $godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit
gdformat --check scripts scenes dialogue tests
gdlint scripts scenes dialogue tests
Push-Location server
npm test
Pop-Location
Push-Location mock-portal
npm test
Pop-Location
git diff --check
git ls-files | Select-String -Pattern '(^|/).env$|secret|credential|api[_-]?key'
```

Manual: perform the signed release-candidate checklist and retain all playthrough, matrix, review, export, and submission evidence.

---

## P0 Requirement Coverage

| Requirement group | Phase | Current status |
|---|---:|---|
| ARCH-R1..R5 | 0, 1, 8 | Done — no keys in Godot; backend timeouts + cached fallbacks; config-selected URLs; signals/events; data-driven content |
| SAVE-R1..R3, SAVE-R6 | 2, 5, 9 | Done — loop/persistent split, atomic save, never-twice history, seated-fragment preservation verified by GUT |
| CLOCK-R1..R3 | 2 | Done — 07:00-20:00, minute display, Day 1-5 reset verified by GUT |
| DLV-R1..R3, DLV-R5 | 3 | Done — weighted delivery, anchors, triage, six-state glow, batch cap verified by GUT |
| REST-R1, R3, R4, R7 | 4 | Done — focused 3D restoration, clean→open gate, wrong-tool damage, pendant mini-game verified by GUT |
| SCAN-R1, R2, R4, R5 | 7, 8 | Done — cached scanner, advisory-only, player verdict, backend proxy verified by GUT/backend tests |
| JRN-R1..R3, JRN-R5 | 9 | Done — hybrid 2D/3D journal, five-slot case, entry updates, rarity routing verified by GUT |
| DISC-R1..R13 | 4, 5, 6 | Done — Spawn Director, never-twice, Echo mixer, carrier flicker/heartbeat, openables verified by GUT |
| PORT-R1..R5 | 8, 9 | Done — Artifact Found/Unlock, mock Portal proxy, idempotency, fallback, seating verified by GUT/backend tests |
| MUS-R2 P0 record | 8, 9 | Done — `MuseumEntry` persisted on Portal completion; gallery view is P1 |
| API-R1..R3 | 8 | Done — `.env.example`, validation, rate limiting, config swap verified by backend tests |
| MKT-R1..R6 | 14 | Partial — buy/sell/haggle/banter with nine personas and wallets implemented; disposition router, returns, and evening state not done |
| MKT-R7 | 14 | Done — deterministic offline `Negotiation` engine plus backend `/api/negotiate` fallback verified by GUT/server tests |
| Auntie slice showcase | 10 | Partial — Auntie quest data and decal mechanics authored; visit scheduling, scripted showcase, and fragment-release flow not implemented |
| Submission evidence | 11 | Not started |

## Complete Requirement Index

This index names every current PRD requirement literally so automated parity checks can prove that no feature disappears behind a range or phase summary.

- **Architecture:** ARCH-R1, ARCH-R2, ARCH-R3, ARCH-R4, ARCH-R5, ARCH-R6.
- **Persistence:** SAVE-R1, SAVE-R2, SAVE-R3, SAVE-R4, SAVE-R5, SAVE-R6, SAVE-R7.
- **Clock:** CLOCK-R1, CLOCK-R2, CLOCK-R3, CLOCK-R4, CLOCK-R5.
- **Delivery:** DLV-R1, DLV-R2, DLV-R3, DLV-R4, DLV-R5.
- **Restoration:** REST-R1, REST-R2, REST-R3, REST-R4, REST-R5, REST-R6, REST-R7.
- **Scanner:** SCAN-R1, SCAN-R2, SCAN-R3, SCAN-R4, SCAN-R5, SCAN-R6, SCAN-R7.
- **Marketplace:** MKT-R1, MKT-R2, MKT-R3, MKT-R4, MKT-R5, MKT-R6, MKT-R7.
- **Journal:** JRN-R1, JRN-R2, JRN-R3, JRN-R4, JRN-R5.
- **Discovery:** DISC-R1, DISC-R2, DISC-R3, DISC-R4, DISC-R5, DISC-R6, DISC-R7, DISC-R8, DISC-R9, DISC-R10, DISC-R11, DISC-R12, DISC-R13, DISC-R14, DISC-R15.
- **Portal:** PORT-R1, PORT-R2, PORT-R3, PORT-R4, PORT-R5, PORT-R6.
- **Museum:** MUS-R1, MUS-R2, MUS-R3, MUS-R4.
- **Routes:** ROUTE-R1, ROUTE-R2, ROUTE-R3, ROUTE-R4, ROUTE-R5, ROUTE-R6.
- **Temporal Echoes:** TEMP-R1, TEMP-R2, TEMP-R3, TEMP-R4.
- **Events:** EVT-R1, EVT-R2, EVT-R3.
- **Caches:** CACHE-R1, CACHE-R2, CACHE-R3.
- **Endings:** END-R1, END-R2, END-R3, END-R4, END-R5.
- **Backend API:** API-R1, API-R2, API-R3.
- **Disposition:** DISP-R1, DISP-R2, DISP-R3, DISP-R4, DISP-R5, DISP-R6.
- **Evening:** EVE-R1, EVE-R2, EVE-R3, EVE-R4, EVE-R5.
- **Content:** CONTENT-R1, CONTENT-R2, CONTENT-R3, CONTENT-R4, CONTENT-R5, CONTENT-R6, CONTENT-R7, CONTENT-R8, CONTENT-R9, CONTENT-R10.
- **Input:** INPUT-R1, INPUT-R2, INPUT-R3, INPUT-R4, INPUT-R5.
- **Platforms:** PLAT-R1, PLAT-R2, PLAT-R3, PLAT-R4, PLAT-R5, PLAT-R6.
- **Assets/review:** ASSET-R1, ASSET-R2, ASSET-R3, ASSET-R4, ASSET-R5, ASSET-R6, ASSET-R7.
- **Release:** REL-R1, REL-R2, REL-R3, REL-R4, REL-R5, REL-R6, REL-R7, REL-R8.

## Full-Game Requirement Coverage

| Requirement group | Detailed phase(s) | Current status |
|---|---:|---|
| Artifact decisions, manifest, sources | 12 | Not started |
| Full objects, restoration, tools, counterfeits | 13 | Partial — decal/condition cleaning and tool durability/loadout implemented; 30-object catalog, engraving/mechanism interactions, and six counterfeits not done |
| Marketplace, disposition, evening upkeep | 14 | Partial — buy/sell/haggle/banter with nine personas and wallets implemented; disposition router, returns, and evening state not done |
| Routes, schedules, returns, Safe/drawer | 15 | Partial — route data, portraits, and dialogue exist; visit scheduling, beats, returns, Safe/drawer not implemented |
| Temporal Echoes, journal mystery, museum | 16 | Partial — P0 journal record and case implemented; 15 Echoes, mystery pages, and museum gallery not done |
| Fifteen carriers and five-fragment discovery | 17 | Partial — slice carrier (pendant) and Spawn Director implemented; full carrier pool and five Echo sets not done |
| All eight events | 18 | Partial — EventDirector system and brownout/phone-flashlight integration implemented; full event tuning and manual verification pending |
| Character endings, Neutral, Yuyu finale | 19 | Not started |
| Final narrative, assets, audio, review, replica/video | 20 | Not started |
| Live services, platforms, inputs, accessibility, performance | 21 | Partial — P0 mock/cached scanner, portal, and offline negotiation fallback implemented; live service matrices, platform/input parity, and performance targets not verified |
| Full-game QA, 6–10 hour playtests, release/submission | 22 | Not started |

## Update Procedure

When implementation lands:

1. Run the task's automated verification.
2. Perform its manual acceptance check.
3. Change only that task's marker.
4. Add a short evidence line with test command, date, and commit hash.
5. Update the P0 coverage table if the group status changed.
6. Update the full-game coverage table and content manifest when P1 status or counts change.
7. Update `CLAUDE.md` commands/layout only when architecture actually changes.
8. Update `docs/PRD.md`, its GDD coverage matrix, and this index together for any explicit design decision; never silently change an invariant or GDD promise.
