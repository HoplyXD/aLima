# aLima Prompt Context

Canonical repository context for agents that write implementation prompts for aLima.

## Use This First

- Read this file before producing any implementation prompt.
- Then inspect the current code, scene, data, test, and documentation files relevant to the requested work. This snapshot does not replace source inspection.
- Treat running code and assets as truth for what exists. Treat `CLAUDE.md` Section 4 as the design invariants, `docs/PRD.md` as the build contract, `README.md` as the GDD/narrative source, and `docs/phase-task.md` as the implementation order/status tracker.
- If source and docs disagree, report the disagreement. Do not silently rewrite behavior or requirements.
- Snapshot last audited 2026-06-15; refreshed after Phase 0 stabilization (controller/HUD consolidation, toolchain, hygiene). Those changes are in the working tree on `main`, not yet committed (base commit `779a515`). Refresh this file when implementation materially changes.

## Game Identity

- **Concept:** A cozy, single-player historical-restoration roguelite set in a family junk shop in Western Visayas. The player inherits a Chronos Emulsion journal after their Chronographer uncle vanishes.
- **Theme:** "Giving Our History a New Heartbeat through the Intelligence of Tomorrow."
- **Genre and audience:** Cozy restoration simulation plus narrative roguelite, aimed at teens and adults who enjoy tactile, story-rich games such as *Unpacking*, *PowerWash Simulator*, *Strange Horticulture*, and *Coffee Talk*.
- **Progression:** A repeating five-day loop. Money, ordinary stock, temporary tools/upgrades, listings, requests, and daily outcomes reset. Knowledge, journal/scanner/museum records, learned techniques, story clues, route completion, leads, legacy items, spawn history, and seated fragments persist.
- **Goal:** Recover five fragments of a real Western Visayas heritage artifact, seat them permanently in the journal case, complete the Master Artifact, end the loop, and recover the uncle.
- **Artifact status:** Not selected. The Heirloom Timepiece is the frontrunner. Keep all logic artifact-agnostic and authored through JSON or Godot resources.

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

## Platforms, Input, And Presentation

- **Target engine:** Godot 4.6.3 with typed GDScript.
- **Current project settings:** Godot feature `4.6`, GL Compatibility renderer, Jolt 3D physics, 1920x1080 viewport, fullscreen mode, Windows D3D12 driver setting.
- **Targets:** Windows is primary. HTML5/web is planned for the AI Fest exhibit and must be verified separately rather than assumed equivalent.
- **Presentation:** One stylized 3D shop with 2D `Control`/`CanvasLayer` screens for triage, restoration, scanner, journal, dialogue, and Portal flows.
- **Input:** Mouse-first. Controller and touch are goals, not verified features. Current dialogue advances with `ui_accept` or left mouse click.
- **Accessibility:** Echo discovery must remain playable muted through captions and a visual resonance meter. UI needs readable contrast, visible focus/hover states, 1920x1080 reference layout, and smaller-window scaling.
- **Performance:** No FPS, memory, draw-call, or download-size budget is documented. Prompts should avoid unnecessary scene churn, per-frame allocations, and heavyweight architecture, and must test Windows and web behavior when affected.

## Art, Audio, And UI Direction

- Planned art direction is warm golden-hour junk shop: rust, brass, varnished wood, dusty louvers, and painted 2D overlays.
- UI should feel diegetic: journal paper, masking tape, and ballpoint ink.
- Props should read as Filipino: weighing scales, soft-drink crates, sari-sari signage, santo figures, and capiz panels.
- Planned audio uses original, human-curated Western Visayas folk-inspired material, native-speaker voice where feasible, and shop ambience such as rain, a scale creak, and a passing tricycle.
- Current assets do not establish this direction. The repository contains a default Godot icon and one 1000x1000 chibi visitor placeholder with no documented provenance in the disclosure log. There are no audio files, shaders, animation resources, final environment assets, or final UI art.

## Verified Repository State

Verified with Godot `4.6.3.stable` on 2026-06-15 (after Phase 0 stabilization and minute-level clock update; changes are in the working tree, not yet committed):

- Godot 4.6.3 is installed at `C:\Users\roman\Downloads\Godot_v4.6.3-stable_win64_console.exe` and reports `4.6.3.stable.official.7d41c59c4`.
- The bare `godot` command currently resolves to the older 4.5.1 executable at `C:\Users\roman\Desktop\Godot` (`4.5.1.stable.official.f62fdbde1`). A 4.6.3 shim exists at `C:\Users\roman\tools\bin\godot.cmd`, but the `.cmd` file is shadowed by the earlier `godot.exe` on the effective PATH.
- `--headless --editor --path . --quit` and `--headless --path . --quit` complete with exit 0 and no error lines; the main scene `scenes/Shop.tscn` starts and the controller prints `[Shop] ready`.
- GUT 9.6.0 suite passes: `--headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit` → `16/16 passed` (54 asserts), including the smoke test and the new `tests/test_shop_clock.gd`.
- `gdformat --check scripts scenes dialogue tests` and `gdlint scripts scenes dialogue tests` pass (scoped to exclude vendored `addons/gut`).
- `dialogue/dialogue_box.tscn` loads. The `prototype/` directory (including the previously-broken `Main.tscn`) was removed during Phase 0.
- No tracked `.env`, secret, credential, or API-key file was found.

### Current Playable State

- `project.godot` launches `scenes/Shop.tscn`.
- The scene contains a camera, extremely simple quad-based background/book placeholders, a billboard visitor sprite, and a CanvasLayer HUD.
- The production HUD is now `visible = true` and the stray `AAAAAAAAA` test button is gone, so the main scene is a usable production screen.
- Orchestration lives in `scripts/shop/shop_controller.gd` (attached to the Shop root): placeholder rarity counts, a 07:00-20:00 timer, Day 1-5 wrapping, visitor visibility, and the hardcoded placeholder Auntie/"coming soon" dialogue. Presentation lives in `scenes/ui/shop_hud.gd` (`class_name ShopHud`), which emits typed intent signals and exposes `set_*`/`start_dialogue`/`set_actions_visible` and owns no game state.
- Door opens the dialogue queue (with the visitor). Workbench, Journal, and Phone only show "coming soon" dialogue. No real navigation or game systems are connected.
- Dialogue supports queued String/Dictionary lines, BBCode, typewriter reveal, skip/advance, keyboard, mouse, and a completion signal.
- The clock shows minute-level placeholder progression (`7:00 AM` → `7:01 AM` → …), pauses during dialogue, and resumes without skipping partial-hour time. There is no loop reset transaction, save file, route schedule, or persistent state.
- The dialogue lifecycle (open → clock pause + visitor show; advance via mouse/keyboard → close → clock resume + visitor hide) is verified headlessly by the GUT smoke test. On-screen mouse hit-testing/visuals under a real display remain a manual human check.

### Implemented Or Reusable Pieces

- Root Godot project and configured hybrid Shop scene (HUD visible; single controller on the root).
- Production controller/HUD separation (`scripts/shop/shop_controller.gd` + `scenes/ui/shop_hud.gd`) and the Phase 0 source layout.
- Reusable `DialogueBox` component in `dialogue/`.
- Placeholder clock/count formatting and button flow; minute-level clock display with configurable `seconds_per_hour`.
- Toolchain: vendored GUT 9.6.0 + smoke test, pinned gdtoolkit (gdformat/gdlint), and a GitHub Actions CI workflow.
- Twine/Chapbook narrative and economy prototype in `aLima.twee`, with generated `aLima.html`.
- Detailed PRD, invariants, data contracts, phase plan, and disclosure process.

### Missing Runtime Systems

- Typed models, JSON/resource data, validation, EventBus, GameState, SaveService, and deterministic run context.
- Real day clock, loop controller, split/atomic persistence, and migrations.
- Delivery generation, 3D placement anchors, triage, inventory, and rarity glow behavior.
- Pendant cleaning mini-game, tool consequences, clean/open state machine, and general open results.
- Spawn Director, placement history, demo seeds/logging, Cultural Echo audio/meter/captions, and carrier flicker.
- Cached scanner, verdict UI, Node/Express backend, mock Portal, Godot HTTP clients, Found/Unlock flow, museum record, journal, and fragment case.
- Auntie scheduling and scripted photo showcase.
- Backend tests, export presets, Windows/web exports, and submission evidence. (GUT 9.6.0, pinned gdtoolkit, and a GitHub Actions CI workflow now exist as of Phase 0.)
- `scripts/`, `data/`, `resources/`, `tests/`, and `addons/gut/` now exist (Phase 0); `server/` and `mock-portal/` still do not (Phase 8).
- No npm package manifests or lockfiles exist yet; `requirements-dev.txt` pins the Python gdtoolkit version.

## Important Files

- `CLAUDE.md`: operating contract, invariants, target architecture, commands, conventions.
- `docs/PRD.md`: requirement IDs and canonical system contracts; Section 12 is the complete discovery specification.
- `README.md`: GDD, narrative, routes, art/audio direction, roadmap, and milestone description.
- `docs/phase-task.md`: canonical task order and status. Start at Phase 0 stabilization.
- `docs/ai-disclosure.md`: append-only AI usage log and milestone review gate.
- `project.godot`: engine, renderer, viewport, and main scene configuration.
- `scenes/Shop.tscn`: production entry scene; HUD now visible, stray test button removed, controller on the root.
- `scripts/shop/shop_controller.gd`: the single production Shop controller (orchestration + placeholder clock/state) on the Shop root.
- `scenes/ui/shop_hud.gd`: presentation-only HUD (`class_name ShopHud`); typed intent signals + `set_*` API, no game state.
- `dialogue/dialogue_box.gd` and `.tscn`: reusable dialogue implementation.
- `tests/test_shop_smoke.gd` + `.gutconfig.json`: GUT smoke test for the Shop/HUD boundary.
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
2. Name the phase, PRD requirement IDs, and `CLAUDE.md` invariants being implemented.
3. Describe verified current behavior separately from planned behavior and assumptions.
4. Scope work to the actual Godot/Node architecture and current milestone. Preserve typed GDScript, signals, data-driven content, and the hybrid 3D/2D presentation.
5. Avoid unnecessary architecture changes and unrelated refactors. Reuse the existing Shop and DialogueBox where sensible; migrate behavior before deleting prototypes.
6. Specify files/systems likely to change without pretending they already exist.
7. Include concrete acceptance criteria covering relevant gameplay, game feel, controls, UX, audio, accessibility, performance, persistence, offline resilience, and security.
8. Include automated commands plus a manual gameplay check. Never permit "works" or `[x]` status without running the relevant checks and reporting results.
9. Require `docs/phase-task.md` evidence/status updates only after its stated automated and manual gates pass under Godot 4.6.3.
10. Require `docs/ai-disclosure.md` updates for new tools/models, generated assets/audio/text, runtime AI, or materially AI-assisted workflows.
11. Require `CLAUDE.md` updates when layout, commands, stack, or architecture changes. Change PRD requirements only for an explicit design decision.
12. Optimize for a polished, stable, offline-safe, recordable June 30 slice before P1 breadth.

## Verification Baseline

Target commands from the repository:

```powershell
godot --version
godot --headless --editor --path . --quit
godot --headless --path . --quit
godot --headless --path . -s addons/gut/gut_cmdln.gd
gdformat --check .
gdlint .

Push-Location server
npm test
Pop-Location

Push-Location mock-portal
npm test
Pop-Location

git status --short
git ls-files | Select-String -Pattern '(^|/).env$|secret|credential|api[_-]?key'
```

Current limitations: Godot 4.6.3 is installed and verified via the explicit executable, but the bare `godot` command still selects the older 4.5.1 executable. GUT, gdformat, and gdlint are present; `server/` and `mock-portal/` are absent, so prompts must add and verify only the tooling required by their phase and report every command that could not run.

## Hackathon And Submission Priorities

- Current milestone: June 30, 2026 vertical slice/50% submission.
- Required gameplay-video proof: the same fragment placed differently across at least three seeded runs; discovery through all four Echo bands with captions/resonance feedback; and Artifact Found -> mock Portal -> Portal Unlock -> persisted museum/case result.
- Planned dates documented in the repo: Workshop 1 on June 20; Workshop 2 and final artifact lock on June 27; recording/submission June 28-30; Top 10 announcement July 7; mentoring July 11; AI Fest August 3-5 with judging August 4.
- Submission materials documented in the repo include the public repository, gameplay video, finalized AI disclosure, a physical/visual artifact replica, and an artifact lore video.
- Judging emphasis inferred from the documented mechanics: theme integration, genuine procedural variation, usable Cultural Echo discovery, API/Portal proof, cultural responsibility, and a polished playable slice. No separate scoring rubric is stored in the repository.

## Risks, Contradictions, And Unknowns

- The bare `godot` command now resolves to 4.6.3 via a PATH shim (Phase 0). The change lives in the User PATH, so it applies to fresh shells and this machine only — CI and other machines must still select 4.6.3 explicitly (the CI workflow downloads it).
- Nearly every P0 gameplay and submission system is unimplemented with 15 days remaining until June 30, 2026.
- The README says the public repository was initialized June 1; Git history begins June 13, 2026. Correct the claim or document external evidence before submission.
- The Twine intro starts the player with one fragment, while current design requires only the journal and all five fragments hidden. Current PRD/invariants win.
- The old tracker requested two restoration mini-games; the current slice requires one complete pendant cleaning/opening interaction. Current PRD/phase tracker win.
- Twine uses random success and automatic sales; Godot requires skill-based restoration, player judgment, and explicit sell/return/museum decisions.
- Twine route names/logic are useful draft content but current PRD route lifecycle and schedules are authoritative.
- (Resolved in Phase 0) The Shop HUD is now visible, the stray test button is gone, orchestration is a single controller on the Shop root, the duplicate controllers and the whole `prototype/` directory were removed, and `prototype/Main.tscn`'s broken script path no longer exists.
- Asset provenance, licensing, cultural review, final artifact choice, Portal/ADK access, and exact live Portal contract are not verified.
- The default Godot icon, placeholder visitor art, and dialogue code adapted from named external references need provenance/license review against the jam's original-asset and disclosure rules.
- No explicit performance budget, final controller/touch scheme, web compatibility result, judging score rubric, or completed export process is documented.
