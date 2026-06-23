# CLAUDE.md — aLima

> **This file is the first thing you read every session.** It is the operating contract for building *aLima*. Orient from here, follow the invariants in §4 without exception, and read the relevant source document before implementing any system.

**aLima** — a cozy AI-powered historical-restoration roguelite set in a Western Visayas junk shop. Built for the *AI Game On!* jam (AI Fest 2026, Iloilo City). Theme: *"Giving Our History a New Heartbeat through the Intelligence of Tomorrow."*

> **STACK CONTRACT:** The project targets **Godot 4.6.3 (GDScript) + a Node/Express backend**. The presentation is hybrid and trends **diegetic**: a 3D shop scene whose major actions (door, workbench, journal, phone, delivery) are **physical 3D interactables** the player hovers and clicks — not flat HUD buttons (SHELL-R1; HUD buttons survive only as labelled accessibility/fallback). **Restoration is a focused 3D object-manipulation interaction** (a manipulable 3D model the player orbits/rotates and cleans by working the tool across its surface), and its **cleaning tools are visible, selectable 3D props on the workbench** (REST-R9), framed by a 2D background + HUD overlay that is supportive only (meters, feedback, captions, accessibility) and must not replace the tactile 3D tool interaction; the **journal is hybrid 2D/3D** (a 2D book/paper UI that embeds 3D viewers for the Fragment Case and restored objects); **triage, scanner, dialogue, and Portal** flows are 2D `Control`/`CanvasLayer` screens. If the project moves to another engine or stack, stop and update §2, §3, §6, the PRD, and the phase tracker together.

---

## 1. Operating Contract (how you, Claude Code, work here)

- **Read before you build.** Use this authority order: `CLAUDE.md` §4 implementation invariants → `README.md` full-game GDD/product promises → `docs/PRD.md` testable build contract → `docs/phase-task.md` implementation order and proof. The PRD may clarify the GDD but may not omit or downgrade a promised feature. PRD §12 remains the complete Spawn Director / Echoes / carrier specification.
- **Invariants are law.** §4 lists rules that, if broken, break the game's design or its jam eligibility. Never violate them, even if a task seems to ask for it — flag the conflict instead.
- **Data-driven, always.** The final heritage artifact is **not yet chosen**. Never hardcode artifact/object specifics; everything lives in `data/` or Godot resources so the choice drops in without a refactor. See §4.
- **Log AI usage.** Whenever you introduce an AI tool or dependency (in-game LLM call, generated asset pipeline, AI-assisted code of note), append it to `docs/ai-disclosure.md`. Undisclosed AI use is a **disqualification risk** — treat this as non-optional.
- **Keep commits clean and incremental.** The repo must show a from-scratch build within the jam window. Conventional Commits (`feat:`, `fix:`, `refactor:`, `docs:`, `test:`). Small, working commits.
- **Test before "done."** Run the relevant tests/checks (§6) and report results. Don't declare a task complete on untested code.
- **Do not confuse the slice with the game.** Phase 11 completes the June 30 vertical slice only. The project is 100% complete only after every mandatory full-game phase, content minimum, platform gate, production deliverable, and final release check passes.
- **Update this file** when architecture or commands change. It is the source of truth; stale = dangerous.

---

## 2. Tech Stack

| Layer | Tech | Purpose |
|---|---|---|
| Game client | **Godot 4.6.3**, typed GDScript | hybrid 3D shop + focused 3D restoration + hybrid 2D/3D journal + 2D interfaces (triage, scanner, dialogue, Portal) |
| Backend | **Node.js + Express** | server-side LLM proxy (scanner, buyer chat), Portal API client. **All secrets live here, never in the client.** |
| Mock Portal | Node (Express) | local stand-in for the City-Wide Portal API; mirrors the real contract 1:1 |
| Object DB | **JSON** (+ Godot `.tres` resources) | artifact-agnostic object/echo/route definitions |
| Tests | **GUT** (Godot Unit Test) for game; Jest/Vitest for server | |

---

## 3. Repository Layout

`project.godot` stays at the repository root. New systems follow this layout as they are implemented. The `prototype/` experiments were removed at the Phase 0 cleanup gate (their useful controller/UI-split behavior was migrated into `scripts/shop/` + `scenes/ui/`); the reusable dialogue component remains in `dialogue/`.

```
alima/
├── CLAUDE.md                  ← you are here
├── README.md                  ← GDD / narrative and design source
├── project.godot              ← Godot 4.6.3 project root; autoloads EventBus, GameState, SaveService, DayClock, FragmentService, LoopController, EchoController, PortalFlowController, SeatingService, JournalService, MarketplaceService, RouteService
├── docs/
│   ├── PRD.md                 ← build requirements; §12 is the discovery spec
│   ├── phase-task.md          ← canonical implementation checklist/status
│   ├── PROMPT_CONTEXT.md      ← verified context and prompt contract for agents
│   └── ai-disclosure.md       ← running AI-usage log (APPEND when AI is used)
├── scenes/                    ← production .tscn scenes (Shop.tscn) + ui/, restoration/ (focused 3D restoration view: restoration_view.tscn + restoration_dirt.gdshader; the manipulable artifact model lives in its own reusable restoration_artifact.tscn — an @tool RestorationObject3D devs can open standalone to view/iterate models — instanced under restoration_view's World; the old 2D placeholder scenes/ui/restoration_screen.* was retired in P4.7)
├── scripts/                   ← shop, core, models, delivery, discovery, restoration, scanner, journal, portal
│   ├── core/                  ← EventBus, GameState, SaveService, DataRepository, DayClock, LoopController
│   ├── models/                ← typed data contracts + enums + validation
│   └── delivery/              ← DeliveryGenerator, SpawnDirector v1, glow mapping, triage logic
├── dialogue/                  ← reusable dialogue scene and script
├── addons/gut/                ← vendored GUT 9.6.0 (Godot Unit Test) runner
├── resources/                 ← Godot .tres definitions
├── assets/                    ← original art/audio only
├── tests/                     ← GUT tests (test_*.gd)
│   ├── models/                ← model round-trip/validation tests
│   ├── core/                  ← repository, autoload, save, run-context tests
│   ├── delivery/              ← delivery generation, placement, glow, triage tests
│   └── journal/               ← journal entries, fragment case, and BookViewport pause tests
├── .github/workflows/ci.yml   ← CI: 4.6.3 import + GUT + gdformat + gdlint
├── requirements-dev.txt       ← pinned gdtoolkit (gdformat/gdlint)
├── server/                    ← Express: LLM proxy + portal client (Phase 8; cached `/api/scan`, `/api/portal/discovery` proxy, `.env.example`, Jest tests)
├── mock-portal/               ← mock City-Wide Portal API (Phase 8; deterministic fact cards, Jest tests)
└── data/                      ← objects, artifacts, echoes, routes, scanner-cache, delivery (JSON; artifact-agnostic)
```

---

## 4. Invariants — DO NOT VIOLATE

**A. The loop persistence rule (the most important invariant).**
The game runs in repeating **five-day loops**. In-fiction this is the *Chronos Emulsion* journal sitting outside time. On reset:

| Resets every loop | Persists forever (in the Chronos-bound journal) |
|---|---|
| money, temporary upgrades | journal entries & learned techniques |
| ordinary inventory | scanned object records |
| marketplace listings | digital-museum entries |
| unfinished customer requests | story clues & unlocked dialogue |
| daily event outcomes | **seated fragments**, legacy items, leads |

Save/reset code must honor this split exactly. Persistent data is keyed to the player/save, not the loop.

**B. Fragment lifecycle:** `LOCKED` → (route completed, persists) → `RELEASED` → (cleaned + opened + seated) → `SEATED` (permanent, never spawns again). A `RELEASED` fragment is **re-placed by the Spawn Director every loop** until found. No character directly hands over a fragment: the Buyer's qualifying Day 5 encounter releases the fifth fragment into a guaranteed special delivery.

**C. Carrier is a *role*, not an object type.** Never model a fragment as a special object. The Spawn Director **promotes an ordinary openable instance** to "carrier" for the run (injects the fragment, binds the heartbeat, enables close-range flicker). Any pendant *could* be a carrier; almost none are. See PRD §12.

**D. Two-stage gate:** a carrier must be **cleaned before it can be opened**. No exceptions — this is why discovery flows through the restoration loop. Both stages are 3D object-manipulation steps (clean the surface, then perform the type-specific open); the modality does not relax the gate.

**E. Glow legend is fixed.** `white` common · `green` uncommon · `blue` antique · `purple` rare · `gold` historically significant · `flickering` = story/route-connected. **Do not add new glow states.** The carrier reuses `flickering`; the **heartbeat audio band** (carrier-only) is the disambiguator, not a glow. Flicker only becomes visible at proximity ≥ `GLOW_REVEAL_AT` so the audio leads.

**F. Two archives by rarity:** `gold` finds + the Master Artifact → **online API museum**; `purple`-and-below → **the journal**. Route accordingly.

**G. AI assists; the player judges.** The scanner **suggests** identification/authenticity — it never auto-renders a final verdict. Counterfeits must be detectable only by cross-referencing. The player's call is final.

**H. Spawn Director guarantees:** never place the same `(carrier, container)` twice for a player (per-player history, soft-reset to avoid deadlock); never place a fragment behind a tool the player can't obtain that run (must stay winnable). A known Safe code can make the Safe eligible as an outer container, but the fragment still sits inside a promoted ordinary carrier. See PRD §12.

**I. Echoes run only for a `RELEASED`, unfound carrier in the current scene.** Silence otherwise. The **Heartbeat band is gated to `is_carrier == true`** — it must be physically impossible for it to sound on a decoy.

**J. Daily clock:** 1 real minute = 1 in-game hour; shop day 07:00–20:00 (~13 min real); ~1 hour per loop. NPCs knock only in fixed windows (per-character in GDD §9.7); an unanswered visitor moves on and may open/close a route.

**K. Security (non-negotiable).** All LLM/API keys and calls live in the **backend only** — never embedded in the Godot client. Backend rate-limits LLM calls and ships **cached fallbacks** so the exhibit build never depends on venue internet.

**L. Jam content rules.**
- **Original assets only.** No third-party IP. Audio is original/folk-*inspired* — **never sample real recordings** of traditional songs.
- **Folklore is framed as folklore, never as archaeological fact.** Scanner "facts" derive from verified records.
- Excluded as source-of-fact: the **Code of Kalantiaw** (documented 20th-c. hoax). Maragtas may flavor lore but is treated as oral tradition.

**M. Full-GDD parity and content manifest.** Every product promise in `README.md` must map to a PRD requirement ID and a phase task. The validated full-game content manifest must enforce at least 30 object templates, all 9 restoration interactions, 15 openable carrier candidates with at least 3 compatible candidates per fragment, 6 counterfeits, 15 Temporal Echoes, 10 mystery pages, 3 authored beats for each of the five non-finale routes, 6 buyer personas, all 8 named events, 5 fragment fact cards, 1 assembled-artifact record, and 5 additional Gold discoveries. Do not mark the full game complete by substituting placeholders, duplicated content, or unreviewed generated material.

**N. Disposition and evening loop are mandatory.** After restoration and judgment, eligible objects must support the authored choice to sell, return to an owner, preserve in the museum, or archive in the journal. Outcomes update economy, route/story state, and records consistently. Each day ends through an evening summary that exposes upkeep, tool/storage management, journal changes, and next-day preparation; these are not flavor-only screens.

**O. Live services plus fallbacks.** The finished game must verify live backend scanner, marketplace negotiation, and Portal integrations through environment-selected services. Cached/offline fallbacks are also mandatory, but a mock-only or cache-only implementation does not satisfy full-game completion. Missing credentials or an unavailable official contract is an explicit blocker, not permission to mark the task complete.

**P. Platform, input, and accessibility parity.** Windows and HTML5 must complete the full game with mouse, controller, and touch. All actionable UI exposes focus, hover/pressed, and touch states; input actions are remappable where the platform permits. Cultural Echo discovery remains playable muted through captions and the resonance meter. Target performance is 60 FPS at 1920x1080 on the Windows reference system and 30 FPS at 1280x720 on the web reference system.

**Q. Production and cultural review are part of done.** Final art, UI, animation, lighting, audio, voices, subtitles, artifact replica, lore video, provenance records, verified historical citations, native-speaker review, AI disclosure, exports, and submission materials belong to the phase checklist. A system-complete build with placeholder assets or unreviewed cultural content is not 100% complete.

---

## 5. The Core Loop (what the code serves)

**Daily:** morning delivery → triage (limited storage/time/money) → restore (**3D clean mini-game** — rotate and clean the actual 3D object) → scan & judge (AI suggests, player decides) → decide (sell / return / museum) → evening (journal, upkeep).

**Discovery (the headline mechanic):**
> Hum (far) → Melody (area) → Voice (pile) → carrier flickers + Heartbeat spikes → pick up → **clean** → **open** → fragment inside → **Artifact Found** screen → **Portal API** → **Portal Unlock** fact → fragment **seats in journal case** (permanent).

Full detail: `docs/PRD.md` §12.

---

## 6. Commands

Use the **explicit Godot 4.6.3 console executable** for reliable CI/automation: `C:\Users\roman\Downloads\Godot_v4.6.3-stable_win64_console.exe`. A PATH shim exists at `C:\Users\roman\tools\bin\godot.cmd`, but the bare `godot` command currently resolves to the older 4.5.1 executable at `C:\Users\roman\Desktop\Godot` because its `godot.exe` appears earlier in the effective PATH than the `.cmd` shim. Open a fresh shell after any PATH change.

```powershell
# --- Game (Godot 4.6.3; project.godot is in this directory) ---
$godot = "C:\Users\roman\Downloads\Godot_v4.6.3-stable_win64_console.exe"
godot --version                                      # currently 4.5.1.stable; diagnostic only
& $godot --version                                   # expect 4.6.3.stable
& $godot --editor --path .
& $godot --headless --editor --path . --quit         # import/build check
& $godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit

# Focused Phase 1 suites
& $godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/models
& $godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/core

# --- Lint/format (gdtoolkit; pinned in requirements-dev.txt: pip install -r requirements-dev.txt) ---
# Scope to our source — vendored addons/gut is third-party and not formatted by us.
gdformat --check scripts scenes dialogue tests
gdlint scripts scenes dialogue tests

# --- Backend (LLM proxy + portal client; Phase 8) ---
Push-Location server
npm install
Copy-Item .env.example .env     # fill in keys locally; NEVER commit .env
# Required: PORT, PORTAL_BASE_URL, PORTAL_TIMEOUT_MS (see server/.env.example)
npm run dev                     # run in a dedicated terminal
npm test                        # 12/12 passing as of 2026-06-16 (uses --forceExit due to open Supertest handles)
Pop-Location

# --- Mock Portal (Phase 8) ---
Push-Location mock-portal
npm install
Copy-Item .env.example .env     # optional; defaults in config
npm start                       # run in a dedicated terminal
npm test                        # 4/4 passing as of 2026-06-16
Pop-Location

# --- Full local end-to-end (run server + mock-portal first) ---
Push-Location mock-portal; npm start   # terminal A
Push-Location server; npm run dev      # terminal B (PORTAL_BASE_URL=http://localhost:3001 or mock-portal port)
& $godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/portal -gexit
```

> If a command above doesn't exist yet (early in the build), create the missing scaffolding (test runner, lint config, scripts) as part of the task and update this section.

---

## 7. Conventions

**GDScript**
- **Typed GDScript everywhere** (`var x: int`, `func f() -> void`). Static types catch real bugs.
- `snake_case` files & funcs · `PascalCase` for `class_name` and nodes · `UPPER_SNAKE` consts.
- One class per file; `class_name` when reused across the project.
- **Signals for cross-system communication** — keep systems decoupled (Spawn Director ↔ Echoes ↔ Carriers ↔ Journal talk via signals/events, not hard references).
- **No business logic in `.tscn`** — logic lives in scripts; scenes are composition only.
- Data lives in `resources/` (`.tres`) or `data/` (JSON), never hardcoded in logic.

**Backend**
- Typed where possible; thin controllers, logic in services.
- Every external call (LLM, Portal) wrapped with timeout + cached fallback.
- Validate/sanitize all inputs; the buyer-chat LLM runs behind persona + guardrail prompts.

**General**
- Small functions, clear names, comments only where intent isn't obvious.
- Keep the artifact-agnostic boundary clean: if a change requires knowing the specific artifact, it belongs in data, not code.

---

## 8. Current Milestone — June 30 Vertical Slice (50%)

Build the discovery loop **once, end-to-end, deep not wide.** Priorities:

1. Shop scene + delivery/triage.
2. **One** carrier fully built — the **pendant** (clean → clasp-open → fragment) as a focused **3D** object-manipulation interaction. Stub other open-interactions.
3. **Spawn Director v1** with *genuine* carrier + container + day rolls and per-player never-twice (this is the beat the video proves — must be real, not faked).
4. **Echo mixer v1** — 4 bands + resonance meter + captions.
5. **Cached scanner v1** — evidence and suggestions only; the player sets the verdict.
6. **Artifact Found → mock Portal API → Portal Unlock → persisted museum record → journal seat.** Five-slot case, one slot fills on camera.

The 50% gameplay video must show three beats: (a) the artifact spawning in different locations, (b) finding it via Echo cues, and (c) the Portal Unlock notification. See PRD §12 acceptance, §13 acceptance, and `docs/phase-task.md` Phase 11 for the cut-line and shot checklist.

**Mandatory after the slice:** Phases 12–22 expand the slice into the complete GDD game: artifact/content lock; full restoration catalog; economy, disposition, and evenings; all routes; Temporal Echoes and museum; all fragments/carriers; all events; endings; production assets and cultural review; live services plus fallbacks; Windows/HTML5 and all inputs; then full-game QA, playtesting, exports, replica, lore video, and submission. These phases are deferred from the June 30 slice, not optional for 100% completion.

---

## 9. Project Facts

- **Team:** Francis Gabriel Austria (lead dev), Om Shanti Limpin (dev/design/narrative), Jorge Maverick Acidre (dev/design). WVSU, Iloilo City.
- **Artifact:** undecided; frontrunner is the **Heirloom Timepiece** (escapement·dial·hands·gear-train·pendulum). Keep all systems artifact-agnostic until locked (post-workshop, before asset production).
- **Engine verification:** `project.godot` targets Godot 4.6. Official Godot 4.6.3 console build is installed at `C:\Users\roman\Downloads\Godot_v4.6.3-stable_win64_console.exe` and verified (`--version` → `4.6.3.stable.official.7d41c59c4`). A 4.6.3 PATH shim exists at `C:\Users\roman\tools\bin\godot.cmd`, but the bare `godot` command currently resolves to the older 4.5.1 executable at `C:\Users\roman\Desktop\Godot` (`4.5.1.stable.official.f62fdbde1`) because its `godot.exe` appears earlier in the effective PATH. Use the explicit 4.6.3 executable for all verification. The editor import, main-scene startup, complete GUT suite (`295/295` passing, 971 asserts as of 2026-06-17, including Phases 0–9), focused model/core/delivery/restoration/spawn/echo/scanner/portal/journal suites, and the Phase 2 `DayClock`/`LoopController` clock-loop-persistence behavior pass under 4.6.3. Backend suites also pass: `server/npm test` → 12/12; `mock-portal/npm test` → 4/4. Runtime tasks (including on-screen/real-time clock observation, restoration mouse/controller/touch flow, journal/case readability, and the full Found → Unlock end-to-end observation) still require their own acceptance checks before `[x]`.

---

*Read `README.md` for promised full-game scope, `docs/PRD.md` for testable requirements and the full discovery spec, and `docs/phase-task.md` for implementation order and evidence. When in doubt, §4 governs implementation and the GDD promise must remain covered.*
