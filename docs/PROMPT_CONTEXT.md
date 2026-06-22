# aLima Prompt Context

Canonical repository context for agents that write implementation prompts for aLima.

## Use This First

- Read this file before producing any implementation prompt.
- Then inspect the current code, scene, data, test, and documentation files relevant to the requested work. This snapshot does not replace source inspection.
- Treat running code and assets as truth for what exists. Authority is `CLAUDE.md` Section 4 implementation invariants -> `README.md` full-game promises -> `docs/PRD.md` testable build contract -> `docs/phase-task.md` implementation order and evidence. The PRD may clarify but may not omit a GDD promise.
- If source and docs disagree, report the disagreement. Do not silently rewrite behavior or requirements.
- Snapshot last audited 2026-06-22. This refresh covers the Mobile renderer switch with gl_compatibility fallback, the SettingsService / global pause menu, the local-AI stack (on-device NobodyWho GGUF + backend Ollama/Anthropic proxy + deterministic offline fallback), the nine-persona marketplace economy (buy/sell/haggle/banter/wallets), the Storage/phone UI, authored artifact condition decals and per-artifact scenes, and the updated verification counts. Rotatable 3D fragment viewers and per-entry 3D object previews remain Phase 16 polish; the P0 five-slot case and stable entry system are complete. Repository branch is `main`. Refresh this file when implementation materially changes.

## Game Identity

- **Concept:** A cozy, single-player historical-restoration roguelite set in a family junk shop in Western Visayas. The player inherits a Chronos Emulsion journal after their Chronographer uncle vanishes.
- **Theme:** "Giving Our History a New Heartbeat through the Intelligence of Tomorrow."
- **Genre and audience:** Cozy restoration simulation plus narrative roguelite, aimed at teens and adults who enjoy tactile, story-rich games such as *Unpacking*, *PowerWash Simulator*, *Strange Horticulture*, and *Coffee Talk*.
- **Progression:** A repeating five-day loop. Money, ordinary stock, temporary tools/upgrades, listings, requests, and daily outcomes reset. Knowledge, journal/scanner/museum records, learned techniques, story clues, route completion, leads, legacy items, spawn history, and seated fragments persist.
- **Goal:** Recover five fragments of a real Western Visayas heritage artifact, seat them permanently in the journal case, complete the Master Artifact, end the loop, and recover the uncle.
- **Artifact status:** Not selected. The Heirloom Timepiece is the frontrunner. Keep all logic artifact-agnostic and authored through JSON or Godot resources.
- **Completion rule:** Phase 11 completes only the June 30 vertical slice. The full game is 100% complete only after mandatory Phases 12–22 and every P0/P1 requirement, content minimum, production review, service/platform matrix, and release gate pass.

## Core Play

Planned daily loop:

1. Receive a morning scrap delivery.
2. Triage under storage, time, and money limits.
3. Restore selected objects through skill-based interactions; wrong tools can cause permanent damage.
4. Scan cleaned objects for advisory evidence, then let the player choose the authenticity verdict.
5. Sell, return, journal, or preserve discoveries in the museum.
6. Review journal progress and prepare for the next day or loop.

Slice-critical discovery flow:

`Hum -> Melody -> Voice -> carrier flicker + Heartbeat -> select object -> clean -> scan and judge -> open -> fragment -> Artifact Found -> backend/mock Portal -> Portal Unlock -> museum record -> journal case seat`

## Full-Game Content Minimums

- 30 authored restorable object templates across all nine restoration interactions.
- 15 openable carrier candidates, with at least three compatible candidates per fragment.
- 6 journal-solvable counterfeit variants.
- 15 Temporal Echo memories and 10 mystery-journal pages.
- 3 progression beats each for Auntie, Artisan, Scavenger, Archeologist, and Buyer.
- 4 character endings, Neutral continuation, and the Yuyu finale.
- 6 buyer personas with live negotiation and deterministic offline fallback.
- All 8 named mini-events.
- 5 fragment fact cards, 1 assembled-artifact record, and at least 5 additional Gold discoveries.
- Original production art/audio/UI/voices, five reviewed Cultural Echo sets, subtitles, provenance, cultural/native-speaker review, artifact replica, and lore video.
- Three blind first-completion playtests with a 6–10 hour median.

## Non-Negotiable Rules

Prompts must preserve these invariants from `CLAUDE.md` and `docs/PRD.md`:

- Only `LoopState` resets. Persistent knowledge and seated fragments never reset.
- Fragment lifecycle is `LOCKED -> RELEASED -> SEATED`. Routes release fragments into the scrap stream; characters never hand fragments directly to the player.
- A carrier is an ordinary openable object instance promoted at runtime. It is a role, not a special object type.
- Carriers must be cleaned before opening. Discovery cannot bypass restoration.
- The only glow states are White, Green, Blue, Purple, Gold, and Flickering. Heartbeat, not a new glow, identifies the true carrier.
- Purple-and-below finds belong in the Journal. Gold finds and the Master Artifact produce museum records.
- The scanner suggests evidence but never sets authenticity. The player chooses `AUTHENTIC`, `REPLICA`, `MODIFIED`, or `UNCERTAIN`.
- Spawn placement must be deterministic from a run-local seed, compatible, obtainable that run, logged, and never repeat the same carrier-template/container pair for that player until candidate exhaustion. Soft reset only excludes the most recent pair.
- Echoes are silent unless a released, unfound carrier is present. Heartbeat must be impossible for decoys. Flicker appears only at proximity `>= 0.60`.
- The clock target is one real minute per game hour, 07:00-20:00, five days per loop. Full-screen interfaces currently default to pausing time.
- All LLM and Portal calls go through the Node/Express backend. Never put keys, provider calls, or secrets in Godot. External calls require validation, timeout, rate limiting where applicable, and cached fallback behavior.
- Historical claims require verified sources. Folklore must be labeled as folklore. The Code of Kalantiaw is excluded as a source of fact.
- Use original assets only. Folk-inspired audio must not sample or imitate protected/traditional recordings. Kinaray-a/Hiligaynon content requires subtitles and cultural/native-speaker review.
- The finished game requires live scanner, marketplace, and Portal verification plus cached/offline fallbacks. Mock-only or cache-only service behavior is not full completion.
- Sell, return, preserve, and journal dispositions plus evening upkeep/preparation are mandatory parts of the daily loop.
- Windows and HTML5 must complete the game with mouse, controller, and touch; target 60 FPS at 1920x1080 on Windows and 30 FPS at 1280x720 on web reference systems.

## Platforms, Input, And Presentation

- **Target engine:** Godot 4.6.3 with typed GDScript.
- **Current project settings:** Godot feature `4.6`, **Mobile** renderer (Vulkan/Forward+) with `gl_compatibility` fallback for low-end/mobile/web, Jolt 3D physics, 1920x1080 viewport, fullscreen mode, Windows D3D12 driver setting. `SettingsService` persists resolution/fullscreen/renderer/artifact-preview choices to `user://settings.cfg`; renderer changes apply on relaunch.
- **Targets:** Windows is primary. HTML5/web is planned for the AI Fest exhibit and must be verified separately rather than assumed equivalent.
- **Presentation:** One stylized 3D shop. **Restoration is a focused 3D object-manipulation interaction** (rotate the 3D object and clean its surface, framed by a 2D background + HUD overlay; REST-R8) — implemented in `scenes/restoration/restoration_view.tscn` (a `SubViewport` 3D object + 2D HUD, shader dirt mask or authored `ArtifactConditionDecal` hotspots, reusing `RestorationService`). **Cleaning tools are visible, selectable 3D props on the workbench** (`RestorationToolTray`, REST-R9): picking a prop chooses the tool; the HUD tool buttons are a labelled accessibility/fallback only. **The major shop actions are diegetic 3D interactables** (`Interactable3D` props for door/workbench/journal/phone/delivery, SHELL-R1/R2): the player hovers (prompt + highlight) and clicks the prop, which fires the same `ShopController` handler as the HUD fallback button. The **journal is hybrid 2D/3D** (a 2D book embedding the five-slot Fragment Case and object viewers; JRN-R6) and is implemented in `scenes/Book/Journal.tscn` / `BookViewport`. Triage, scanner, dialogue, and Portal flows are 2D `Control`/`CanvasLayer` screens.
- **Input:** Mouse-first presentation, but mouse, controller, and touch are mandatory full-game targets. Current dialogue advances with `ui_accept` or left mouse click; broader input support is not implemented yet.
- **Accessibility:** Echo discovery must remain playable muted through captions and a visual resonance meter. UI needs readable contrast, visible focus/hover states, 1920x1080 reference layout, and smaller-window scaling.
- **Performance:** Full-game targets are 60 FPS at 1920x1080 on the documented Windows reference system and 30 FPS at 1280x720 on the documented web reference system. Memory/download budgets still require measurement during Phase 21.

## Art, Audio, And UI Direction

- Planned art direction is warm golden-hour junk shop: rust, brass, varnished wood, dusty louvers, and painted 2D overlays.
- UI should feel diegetic: journal paper, masking tape, and ballpoint ink.
- Props should read as Filipino: weighing scales, soft-drink crates, sari-sari signage, santo figures, and capiz panels.
- Planned audio uses original, human-curated Western Visayas folk-inspired material, native-speaker voice where feasible, and shop ambience such as rain, a scale creak, and a passing tricycle.
- Current assets do not establish this direction. The repository contains a default Godot icon and one 1000x1000 chibi visitor placeholder with no documented provenance in the disclosure log. There are no audio files, shaders, animation resources, final environment assets, or final UI art.

## Verified Repository State

Verified with Godot `4.6.3.stable` on 2026-06-22:

- Godot 4.6.3 is installed at `C:\Users\roman\Downloads\Godot_v4.6.3-stable_win64_console.exe` and reports `4.6.3.stable.official.7d41c59c4`.
- The bare `godot` command currently resolves to the older 4.5.1 executable at `C:\Users\roman\Desktop\Godot` (`4.5.1.stable.official.f62fdbde1`). Use the explicit 4.6.3 executable for all verification.
- `--headless --editor --path . --quit` completes with exit 0; `--headless --path . --quit` starts `scenes/Shop.tscn` without parser, resource, UID, or missing-file errors.
- GUT 9.6.0 suite passes: `--headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit` → `444/444 passed` (1442 asserts), including Phase 0–2 core, Phase 3 delivery/triage, Phase 4 restoration/opening/3D-view/tool-props, Phase 5 Spawn Director, Phase 6 Cultural Echoes, Phase 7 cached scanner, Phase 8 portal/Found/Unlock/seating, Phase 9 journal/Fragment Case, and Phase 13/14 economy/marketplace/tool-durability coverage.
- Focused suites (2026-06-22): `-gdir=res://tests/models` → `11/11 passed`; `-gdir=res://tests/core` → `~45/45 passed`; `-gdir=res://tests/delivery` → `~33/33 passed` (197 asserts); `-gdir=res://tests/restoration -ginclude_subdirs` → `~80+/80+` (decal/photo/condition/artifact-scene coverage); `-gdir=res://tests/shop -ginclude_subdirs` → `6/6 passed`; `-gdir=res://tests/discovery/spawn_director` → `25/25 passed`; `-gdir=res://tests/scanner` → `28/28 passed` (105 asserts); `-gdir=res://tests/journal` → `~30/30 passed`; `-gdir=res://tests/portal` → `15/15 passed` (45 asserts); `-gdir=res://tests/economy` → `61/61 passed`.
- `gdformat --check scripts scenes dialogue tests` reports 28 files that would be reformatted; `gdlint scripts scenes dialogue tests` reports `max-line-length`, `class-definitions-order`, and `max-public-methods` warnings. These are pre-existing in the working tree and are not being fixed by this documentation pass.
- Backend suites pass (2026-06-22): `server/npm test` → `22/22 passed`; `mock-portal/npm test` → `4/4 passed`.
- `dialogue/dialogue_box.tscn` loads. The `prototype/` directory was removed during Phase 0.
- No tracked `.env`, secret, credential, or API-key file was found; no Godot source file contains API keys, provider URLs, or direct LLM calls. `.gitignore` excludes `node_modules/` and `server/cache/`.

### Current Playable State

- `project.godot` launches `scenes/Shop.tscn`.
- The scene contains a camera, 3D environment/background placeholders, a billboard visitor sprite, diegetic interactable props, and a CanvasLayer HUD.
- The production HUD is `visible = true` and the stray `AAAAAAAAA` test button is gone, so the main scene is a usable production screen.
- Orchestration lives in `scripts/shop/shop_controller.gd` (attached to the Shop root); presentation lives in `scenes/ui/shop_hud.gd` (`class_name ShopHud`), which emits typed intent signals and exposes `set_*`/`start_dialogue`/`set_actions_visible` and owns no game state.
- Each action is reachable two ways: a diegetic 3D prop in the shop (`Interactables/{Door,Workbench,Journal,Phone,Delivery}Interactable`, hover prompt + highlight + click) and a labelled HUD accessibility/fallback button — both fire the same handler. Door opens the dialogue queue (with the visitor). Journal opens the hybrid 2D/3D book viewer. Phone opens an authored phone frame (`scenes/ui/phone.tscn`) with a Marketplace app. The Workbench opens the focused **3D** restoration view (`scenes/restoration/restoration_view.tscn`) whose bench shows selectable 3D tool props. Storage opens a three-tab inventory/loadout screen. "Morning Delivery" triggers one delivery per in-game day. Props are disabled while a full-screen overlay is open so clicks don't fall through.
- The global pause menu (`scenes/ui/pause_menu.tscn` / `scripts/ui/pause_menu.gd`) opens on Space/Esc and hosts display settings (resolution, fullscreen, renderer, online services, artifact previews). It pauses the game tree while open and persists choices through `SettingsService`.
- Dialogue supports queued String/Dictionary lines, BBCode, typewriter reveal, skip/advance, keyboard, mouse, and a completion signal.
- The clock is the real Phase 2 `DayClock` autoload (07:00–20:00, minute-level display, configurable `seconds_per_hour`), driven by the Shop's `_process` and frozen via pause ownership during overlays. The `LoopController` autoload advances Days 1–5 and performs the five-day split reset (clear loop, increment loop, restart Day 1, atomic save, emit `loop_reset`). Save files persist via `SaveService` (atomic, validated).
- The restoration lifecycle (select instance → rotate/inspect → select tool → work the 3D surface/decal hotspots → reach CLEAN → activate the 3D clasp → resolve EMPTY/TEMPORAL_ECHO/FRAGMENT) runs in the focused 3D view and is verified headlessly by `tests/restoration/`. Author-placed `ArtifactConditionDecal` nodes and per-instance random surface conditions are supported. On-screen rendered visuals and the mouse/controller/touch manual flow remain a human verification gate.
- The cached scanner (Phase 7) is wired to the restoration bench: after an object reaches `CLEAN`, the Scan button opens `scenes/ui/scanner_screen.tscn`, which displays advisory evidence, requires an explicit `AUTHENTIC/REPLICA/MODIFIED/UNCERTAIN` verdict, and persists the choice. The scanner uses offline fixture data from `data/scanner-cache/scanner_cache.json`; no API keys or direct LLM calls exist in Godot.
- The Found/Unlock flow (Phase 8) is implemented: opening a carrier emits `EventBus.fragment_discovered`, which triggers `PortalFlowController`; the backend `/api/portal/discovery` (via `PortalClient`) returns a fact card or deterministic fallback; `SeatingService` seats the fragment and persists a `MuseumEntry`.
- The marketplace economy (Phase 14) is implemented for buy/sell/haggle/banter: `MarketplaceService` sells `buyable` tools with `ship_hours` delivery; `BuyerPersona` loads nine personas from `data/buyers/buyers.json`; `Negotiation` provides deterministic offline haggling; `LocalAI` optionally runs an on-device GGUF via the NobodyWho addon; the backend `/api/negotiate` proxy supports Anthropic and local OpenAI-compatible (Ollama) providers; `ContentModeration` guards free-text input. Selling currently happens through the Storage/Phone sell flow. Disposition router (return/preserve) and evening state are not implemented.

### Implemented Or Reusable Pieces

- Root Godot project and configured hybrid Shop scene (HUD visible; single controller on the root). Renderer is **Mobile** (`Vulkan/Forward+`) with `gl_compatibility` fallback; `SettingsService` + global pause menu persist resolution/fullscreen/renderer/online/previews.
- Production controller/HUD separation (`scripts/shop/shop_controller.gd` + `scenes/ui/shop_hud.gd`) and the Phase 0 source layout.
- Reusable `DialogueBox` component in `dialogue/`.
- Phase 2 clock: minute-level display with configurable `seconds_per_hour`, `DayClock` pause ownership, and `LoopController` five-day split reset.
- Phase 1 typed models, enums, validation, and serialization round-trips in `scripts/models/`.
- Phase 1 `DataRepository` (`scripts/core/data_repository.gd`) loading and validating `data/objects/`, `data/artifacts/`, `data/echoes/`, `data/routes/`, `data/scanner-cache/`, `data/delivery/`, `data/journal/`, and `data/buyers/`.
- Core autoloads (`project.godot`): `EventBus`, `GameState`, `SaveService`, `DayClock`, `LoopController`, `EchoController`, `PortalFlowController`, `SeatingService`, `JournalService`, `RouteService`, `MarketplaceService`, `SettingsService`, `PauseMenu`, `LocalAI`.
- Phase 1 deterministic run context owned by `GameState` using local `RandomNumberGenerator` instances.
- Phase 1 slice fixtures: pendant template (now with authored cleaning tuning), ordinary instance fixtures, tools/techniques, containers, Master Artifact + five fragments, Echo set, cached scanner responses, starting kit, delivery config, and spawn config.
- Phase 5 Spawn Director (`scripts/delivery/spawn_director.gd`), typed `PlacementCandidate` model (`scripts/discovery/placement_candidate.gd`), deterministic audit log, and a three-seed demo helper (`scripts/discovery/spawn_director_demo.gd`).
- Phase 13 restoration surface model: `SurfaceDecal`/`BlemishType` catalog (`data/journal/blemishes.json`), per-instance random conditions, author-placed `ArtifactConditionDecal` nodes, per-artifact scenes under `scenes/restoration/artifacts/`, and the journal Blemish Guide page.
- Phase 13/14 economy: durability-tracked `ToolInstance`s, `ToolService` workbench loadout, `MarketplaceService` buy/sell/haggle/wallets, authored phone Marketplace (`scenes/ui/phone.tscn`), Storage screen (`scenes/ui/storage_screen.tscn`), nine buyer personas (`data/buyers/buyers.json`), deterministic `Negotiation` engine, free-text `ContentModeration`, `negotiation_client.gd` backend proxy, and `LocalAI` on-device GGUF support via the NobodyWho addon.
- Node/Express backend (`server/`) with cached `POST /api/scan`, `POST /api/portal/discovery`, and `POST /api/negotiate` (Anthropic + local OpenAI-compatible/Ollama providers, with deterministic fallback). Separate mock Portal (`mock-portal/`).
- Toolchain: vendored GUT 9.6.0 + smoke tests, pinned gdtoolkit (gdformat/gdlint), GitHub Actions CI workflow, `requirements-dev.txt`, `server/package.json`, `mock-portal/package.json`.
- Twine/Chapbook narrative and economy prototype in `aLima.twee`, with generated `aLima.html`.
- Detailed PRD, invariants, data contracts, phase plan, prompt context, and disclosure process.

### Missing Runtime Systems

- (Phase 2 implemented) Real day clock, loop controller, pause ownership, and split/atomic persistence reset exist as `DayClock`/`LoopController` autoloads with strict-validated `SaveService` writes (GUT-verified; on-screen/real-time observation pending).
- (Phase 3 implemented) Weighted delivery generation, `Marker3D` anchors, full-screen keep/recycle triage, storage-cost inventory enforcement, and the six-state glow legend. Manual on-screen verification pending.
- (Phase 4 implemented — logic) `RestorationService` (presentation-agnostic), authored pendant/tin tuning, deterministic tool consequences, the `DIRTY -> CLEAN -> OPEN` state machine, and `EMPTY | TEMPORAL_ECHO | FRAGMENT` resolution. Carrier identity is an injected role on an ordinary instance.
- (Phase 4 implemented — P4.7 3D presentation) The **focused 3D restoration view** (`RestorationView` + `RestorationObject3D` + `scenes/restoration/restoration_view.tscn`): `SubViewport` 3D object, shader dirt mask, analytic ray/UV hit-testing, threshold-gated strokes, revealed-at-CLEAN clasp, decal/blemish hotspots, and author-placed `ArtifactConditionDecal` support. Automated verification passes; on-screen mouse/controller/touch verification pending.
- (Phase 4 implemented — P4.8 / REST-R9) **Visible 3D cleaning tool props** (`RestorationToolTray` / `ToolTray`): data-driven selectable props; HUD buttons are a labelled accessibility/fallback.
- (Implemented — P4.9 / SHELL-R1/R2) **Diegetic 3D shop interactables** (`Interactable3D` props in `scenes/Shop.tscn`): door/workbench/journal/phone/delivery fire `ShopController` handlers; props disabled under overlays. Placeholder geometry; final art + on-screen click-through pending.
- (Phase 9 implemented) **Hybrid 2D/3D journal** (`BookViewport`/`JournalBook`/`Page`, `scenes/Book/Journal.tscn`): five-slot Fragment Case, object-archive index, individual `JournalEntry` pages, and Blemish Guide. Seated fragments persist. Rotatable 3D fragment viewers and per-entry 3D previews remain Phase 16 polish.
- (Phase 5 implemented) Full Spawn Director with candidate enumeration, hard/weighted filters, never-twice history, soft reset, and deterministic audit log.
- (Phase 6 implemented) Cultural Echo audio/meter/captions and proximity-authorized carrier flicker; four-band additive mixer.
- (Phase 7 implemented) Cached scanner + verdict UI; offline-safe fixture responses and persistence of player verdicts.
- (Phase 8 implemented) Node/Express backend (`server/`) with cached `/api/scan`, Portal proxy `/api/portal/discovery`; mock Portal (`mock-portal/`); `PortalFlowController`, Artifact Found/Unlock screens, and `SeatingService`.
- (Phase 13/14 implemented) Durability-tracked tools, workbench loadout, nine-persona marketplace, deterministic haggling, free-text moderation, backend and on-device local AI for buyer banter, Storage/Phone UIs. Engraving reveal, mechanism inspection, full 30-object catalog, six counterfeits, learned techniques, and repair/upkeep are still pending.
- Still missing: full disposition router (`RETURN`/`PRESERVE` as explicit player choices), return-to-owner rewards, evening summary/upkeep, Auntie scheduling/scripted showcase, all route beats/scheduling, Safe/drawer, 15 Temporal Echoes / mystery pages / museum gallery, 15 carriers / five-fragment discovery, eight mini-events, character endings/Yuyu finale, production assets/audio/review, live service matrix verification, platform/input parity, exports, and submission evidence.

### Mandatory Phase Map

- **Phases 0–11:** June 30 vertical slice, mock/cached integration, evidence, and slice exports only.
- **Phase 12:** artifact/source decisions and validated content manifest.
- **Phase 13:** 30-object catalog, all nine restoration interactions, tools/techniques, and counterfeits.
- **Phase 14:** economy, six-persona marketplace, dispositions, returns, and evening upkeep.
- **Phase 15:** all route beats/schedules, persistent leads, Safe, and drawer.
- **Phase 16:** Temporal Echoes, mystery journal, verified museum, and in-game mirror.
- **Phase 17:** 15 carriers, five Echo sets, and complete five-fragment discovery.
- **Phase 18:** all eight mini-events and tuning.
- **Phase 19:** character endings, Neutral continuation, Master Artifact restoration, and Yuyu finale.
- **Phase 20:** final narrative, art, audio, UI, language/cultural review, provenance, replica, and lore video.
- **Phase 21:** live services plus fallbacks, Windows/HTML5, all inputs, accessibility, security, and performance.
- **Phase 22:** full regression, fresh-save completion, 6–10 hour blind playtests, exports, submission, and documentation parity. Only this phase can declare 100% completion.

## Important Files

- `CLAUDE.md`: operating contract, invariants, target architecture, commands, conventions.
- `README.md`: full-game GDD and promised product scope.
- `docs/PRD.md`: testable requirement IDs, canonical contracts, full-game completion requirements, and GDD coverage matrix; Section 12 is the complete discovery specification.
- `docs/phase-task.md`: canonical task order, evidence, full-game phase map, and 100% completion gate. Start at the first incomplete dependency-safe task.
- `docs/ai-disclosure.md`: append-only AI usage log and milestone review gate.
- `project.godot`: engine, renderer, viewport, and main scene configuration.
- `scenes/Shop.tscn`: production entry scene; HUD now visible, stray test button removed, controller on the root.
- `scripts/shop/shop_controller.gd`: the single production Shop controller (orchestration + placeholder clock/state) on the Shop root.
- `scenes/ui/shop_hud.gd`: presentation-only HUD (`class_name ShopHud`); typed intent signals + `set_*` API, no game state.
- `dialogue/dialogue_box.gd` and `.tscn`: reusable dialogue implementation.
- `tests/test_shop_smoke.gd` + `.gutconfig.json`: GUT smoke test for the Shop/HUD boundary.
- `tests/models/test_models.gd`: model round-trip and validation tests.
- `tests/core/test_data_repository.gd`, `test_event_bus.gd`, `test_game_state.gd`, `test_save_service.gd`, `test_run_context.gd`: Phase 1 core tests (`test_save_service.gd` extended in Phase 2).
- `tests/core/test_day_clock.gd`, `test_loop_controller.gd`: Phase 2 clock/loop tests; `tests/test_shop_clock.gd` migrated to DayClock-backed display/pause integration.
- `tests/delivery/`: Phase 3 tests for delivery generation, glow mapping, spawn director, and triage logic.
- `scripts/models/`: `model_enums.gd`, `model_utils.gd`, `validation_result.gd`, `scrap_object_template.gd`, `object_instance.gd`, `fragment.gd`, `master_artifact.gd`, `echo_set.gd`, `journal_entry.gd`, `museum_entry.gd`, `tool_definition.gd`, `technique_definition.gd`, `placement_container.gd`, `character_route.gd`, `scanner_cache_entry.gd`, `save_state.gd`, `delivery_config.gd`.
- `scripts/core/`: `event_bus.gd`, `game_state.gd`, `save_service.gd`, `data_repository.gd`, `day_clock.gd`, `loop_controller.gd`, `route_service.gd`, `settings_service.gd`.
- `scripts/delivery/`: `delivery_generator.gd`, `spawn_director.gd`, `glow_mapper.gd`, `triage_state.gd`, `triage_service.gd`.
- `scripts/discovery/`: `echo_controller.gd`, `echo_audio.gd`, `echo_mixer.gd`, `echo_proximity_service.gd`, `spawn_director_demo.gd`.
- `scripts/restoration/`: `restoration_service.gd` (presentation-agnostic rules), `restoration_view.gd` (`RestorationView`, the focused 3D view controller + HUD + input + pause), `restoration_object_3d.gd` (`RestorationObject3D`, the manipulable 3D model, dirt mask, analytic ray/UV, clasp; presentation-only), `restoration_tool_tray.gd` (`RestorationToolTray`, the visible/selectable 3D tool props; presentation-only, data-driven, analytic ray pick; REST-R9).
- `scenes/restoration/`: `restoration_view.tscn` (the production Workbench 3D view: `SubViewport` world with `ObjectPivot` + `ToolTray` + 2D HUD) and `restoration_dirt.gdshader` (the GL-Compatibility/HTML5 surface dirt-mask shader, REST-R8 / D8). The 2D placeholder `scenes/ui/restoration_screen.*` was retired in P4.7.
- `scripts/shop/`: `shop_controller.gd` (orchestration + clock/pause driver + interactable wiring/gating), `interactable_3d.gd` (`Interactable3D`, reusable diegetic 3D shop prop: hover prompt/highlight + `activated` signal; SHELL-R1), `portal_flow_controller.gd`.
- `tests/restoration/`: Phase 4 restoration/opening tests — `test_restoration_service.gd` (rules) + `test_restoration_view.gd` (3D presentation boundary) + `test_restoration_tool_tray.gd` (tool-prop unit) + `test_restoration_tool_props_view.gd` (tool-prop view integration). `tests/shop/test_interactable_3d.gd` covers the shop interactable component; `tests/test_shop_smoke.gd` covers the diegetic-prop ↔ controller wiring.
- `tests/discovery/spawn_director/`: Phase 5 Spawn Director tests.
- `scripts/portal/`: `portal_client.gd` and discovery models. `tests/portal/`: Phase 8 portal client, flow controller, and seating service tests.
- `scripts/economy/`: `marketplace_service.gd`, `tool_service.gd`, `negotiation.gd`, `negotiation_client.gd`, `content_moderation.gd`, `local_ai.gd`, `storage_screen.gd`, `phone.gd`. `tests/economy/`: marketplace, negotiation, banter, phone, storage, tool durability/loadout tests.
- `scripts/journal/`: `journal_service.gd`, `seating_service.gd`. `scenes/Book/`: `Journal.tscn`, `BookViewport.tscn`, `book_viewport.gd`, `Page.gd`, `Book.gd`. `tests/journal/`: journal service, fragment case, blemish catalog tests.
- `scripts/ui/`: `pause_menu.gd`. `scenes/ui/`: `pause_menu.tscn`, `phone.tscn`, `storage_screen.tscn`, `scanner_screen.tscn`, `artifact_found_screen.tscn`, `portal_unlock_screen.tscn`.
- `data/buyers/buyers.json`: nine authored buyer personas. `data/journal/blemishes.json`: surface-condition catalog.
- `data/objects/`, `data/artifacts/`, `data/echoes/`, `data/routes/`, `data/scanner-cache/`, `data/delivery/`, `data/journal/`, `data/buyers/`: authored JSON fixtures (schema_version = 1), including `data/delivery/spawn_config.json` and `data/buyers/buyers.json`.
- `scripts/models/`: includes `placement_candidate.gd`.
- `server/` and `mock-portal/`: Node/Express backend and mock Portal services with Jest tests.
- `addons/gut/`: vendored GUT 9.6.0. `requirements-dev.txt`: pinned gdtoolkit. `.github/workflows/ci.yml`: CI (4.6.3 import + GUT + lint).
- `aLima.twee`: old interactive design prototype. Useful for route prose/tuning history, but subordinate to current invariants and PRD.

## Coding And Architecture Conventions

- Typed GDScript. `snake_case` files/functions, `PascalCase` classes/nodes, `UPPER_SNAKE_CASE` constants.
- One reusable class per file; use `class_name` where appropriate.
- Cross-system communication uses typed signals/events. Autoloads own services/state and do not manipulate scene nodes directly.
- Scenes compose nodes; business logic belongs in scripts.
- Authored object, artifact, fragment, route, echo, and scanner-cache details live in versioned JSON or `.tres`, not gameplay logic.
- Use stable string IDs and top-level `schema_version`; validate duplicate IDs, enums, ranges, and references.
- Use local `RandomNumberGenerator` instances, explicit seeds, and auditable placement logs.
- Backend controllers stay thin; services own validation, external calls, fallbacks, and idempotency.
- Prefer focused changes that follow existing phase boundaries. Do not introduce a new framework, state library, DI layer, or generalized abstraction without demonstrated need.
- Conventional Commits are expected. Preserve unrelated work in a dirty tree.

## Prompt Requirements

Every future implementation prompt for this repository must:

1. Begin by requiring the agent to read `docs/PROMPT_CONTEXT.md`, then inspect the exact relevant source/docs before editing.
2. Name the phase, mapped README/GDD promise, PRD requirement IDs, and `CLAUDE.md` invariants being implemented.
3. Describe verified current behavior separately from planned behavior and assumptions.
4. Scope work to the actual Godot/Node architecture and current milestone. Preserve typed GDScript, signals, data-driven content, and the hybrid 3D/2D presentation.
5. Avoid unnecessary architecture changes and unrelated refactors. Reuse the existing Shop and DialogueBox where sensible; migrate behavior before deleting prototypes.
6. Specify files/systems likely to change without pretending they already exist.
7. Include concrete acceptance criteria covering relevant gameplay, game feel, controls, UX, audio, accessibility, performance, persistence, offline resilience, and security.
8. Include automated commands plus a manual gameplay check. Never permit "works" or `[x]` status without running the relevant checks and reporting results.
9. Require `docs/phase-task.md` evidence/status updates only after its stated automated and manual gates pass under Godot 4.6.3.
10. Require `docs/ai-disclosure.md` updates for new tools/models, generated assets/audio/text, runtime AI, or materially AI-assisted workflows.
11. Require `CLAUDE.md` updates when layout, commands, stack, architecture, or invariants change. Change a GDD promise or PRD requirement only through an explicit design decision that updates the coverage matrix and phase index together.
12. Respect the active milestone: optimize for the polished June 30 slice through Phase 11, then implement mandatory full-GDD Phases 12–22 without treating deferred slice work as optional.

## Verification Baseline

Target commands from the repository:

```powershell
$godot = "C:\Users\roman\Downloads\Godot_v4.6.3-stable_win64_console.exe"
& $godot --version
& $godot --headless --editor --path . --quit
& $godot --headless --path . --quit
& $godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit
gdformat --check scripts scenes dialogue tests
gdlint scripts scenes dialogue tests

Push-Location server
npm test
Pop-Location

Push-Location mock-portal
npm test
Pop-Location

git status --short
git ls-files | Select-String -Pattern '(^|/).env$|secret|credential|api[_-]?key'
```

Current state (2026-06-22): Godot 4.6.3 is installed and verified via the explicit executable, but the bare `godot` command selects the older 4.5.1 executable. GUT, gdformat, and gdlint are present. `server/` and `mock-portal/` are present and tested (`npm test` passes 22/22 and 4/4 respectively). gdformat reports 28 files that would be reformatted and gdlint reports max-line-length/class-definitions-order/max-public-methods warnings; these are pre-existing and not blockers.

## Hackathon And Submission Priorities

- Current milestone: June 30, 2026 vertical slice/50% submission.
- Required gameplay-video proof: the same fragment placed differently across at least three seeded runs; discovery through all four Echo bands with captions/resonance feedback; and Artifact Found -> mock Portal -> Portal Unlock -> persisted museum/case result.
- Planned dates documented in the repo: Workshop 1 on June 20; Workshop 2 and final artifact lock on June 27; recording/submission June 28-30; Top 10 announcement July 7; mentoring July 11; AI Fest August 3-5 with judging August 4.
- Submission materials documented in the repo include the public repository, gameplay video, finalized AI disclosure, a physical/visual artifact replica, and an artifact lore video.
- Judging emphasis inferred from the documented mechanics: theme integration, genuine procedural variation, usable Cultural Echo discovery, API/Portal proof, cultural responsibility, and a polished playable slice. No separate scoring rubric is stored in the repository.
- The post-slice completion target is the full README GDD, not a reduced finalist core. Phase 22 requires fresh-save Windows/HTML5 completion, live-plus-fallback services, all inputs, reviewed production assets, a 6–10 hour median, the artifact replica, and lore video.

## Risks, Contradictions, And Unknowns

- The bare `godot` command currently resolves to 4.5.1 because `C:\Users\roman\Desktop\Godot\godot.exe` precedes the 4.6.3 `.cmd` shim. Use the explicit 4.6.3 executable; CI and other machines must also select 4.6.3 explicitly.
- P0 gameplay systems (clock/loop, delivery/triage, restoration/opening, scanner/judgment, Cultural Echoes, portal/seating, journal/Fragment Case, marketplace buy/sell/haggle, settings/pause) are implemented and automated tests pass. Remaining P0 gaps: full disposition/evening, live-service verification, on-screen input verification, exports, and submission evidence.
- Repository-history wording is reconciled: proposal planning is dated June 1, while public Git history begins June 13, 2026. Preserve that distinction in submission materials.
- The Twine intro starts the player with one fragment, while current design requires only the journal and all five fragments hidden. Current PRD/invariants win.
- The old tracker requested two restoration mini-games; the current slice requires one complete pendant cleaning/opening interaction. Current PRD/phase tracker win.
- **Restoration 3D presentation resolved (2026-06-16):** REST-R8's focused **3D** restoration view is implemented (`scenes/restoration/restoration_view.tscn`, P4.7); the 2D placeholder was retired. The **journal hybrid 2D/3D** presentation (JRN-R6 / Phase 9) is implemented (`scenes/Book/Journal.tscn` / `BookViewport`). Rotatable 3D fragment viewers and per-entry 3D object previews remain Phase 16 polish.
- **Renderer note (2026-06-22):** `project.godot` now targets the **Mobile** renderer for Decal-based condition decals, with `gl_compatibility` as the low-end/web fallback. `SettingsService` detects fallback and locks the Mobile option when Compatibility was forced.
- Twine uses random success and automatic sales; Godot requires skill-based restoration, player judgment, and explicit sell/return/museum decisions.
- Twine route names/logic are useful draft content but current PRD route lifecycle and schedules are authoritative.
- (Resolved in Phase 0) The Shop HUD is now visible, the stray test button is gone, orchestration is a single controller on the Shop root, the duplicate controllers and the whole `prototype/` directory were removed, and `prototype/Main.tscn`'s broken script path no longer exists.
- Asset provenance, licensing, cultural review, final artifact choice, Portal/ADK access, and exact live Portal contract are not verified.
- The default Godot icon, placeholder visitor art, and dialogue code adapted from named external references need provenance/license review against the jam's original-asset and disclosure rules.
- Performance targets, controller/touch completion, and Windows/HTML5 parity are now mandatory PRD gates, but reference hardware details, measured results, judging score rubric, and completed export evidence do not yet exist.
