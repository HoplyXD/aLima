# CLAUDE.md — aLima

> **This file is the first thing you read every session.** It is the operating contract for building *aLima*. Orient from here, follow the invariants in §4 without exception, and read the relevant source document before implementing any system.

**aLima** — a cozy AI-powered historical-restoration roguelite set in a Western Visayas junk shop. Built for the *AI Game On!* jam (AI Fest 2026, Iloilo City). Theme: *"Giving Our History a New Heartbeat through the Intelligence of Tomorrow."*

> **STACK CONTRACT:** The project targets **Godot 4.6.3 (GDScript) + a Node/Express backend**. The presentation is hybrid: a 3D shop scene with 2D `Control`/`CanvasLayer` screens for triage, restoration, scanner, journal, dialogue, and Portal flows. If the project moves to another engine or stack, stop and update §2, §3, §6, the PRD, and the phase tracker together.

---

## 1. Operating Contract (how you, Claude Code, work here)

- **Read before you build.** Use this authority order: `CLAUDE.md` §4 invariants → `docs/PRD.md` build requirements → `README.md` GDD/narrative design → `docs/phase-task.md` implementation order and status. PRD §12 is the complete Spawn Director / Echoes / carrier specification.
- **Invariants are law.** §4 lists rules that, if broken, break the game's design or its jam eligibility. Never violate them, even if a task seems to ask for it — flag the conflict instead.
- **Data-driven, always.** The final heritage artifact is **not yet chosen**. Never hardcode artifact/object specifics; everything lives in `data/` or Godot resources so the choice drops in without a refactor. See §4.
- **Log AI usage.** Whenever you introduce an AI tool or dependency (in-game LLM call, generated asset pipeline, AI-assisted code of note), append it to `docs/ai-disclosure.md`. Undisclosed AI use is a **disqualification risk** — treat this as non-optional.
- **Keep commits clean and incremental.** The repo must show a from-scratch build within the jam window. Conventional Commits (`feat:`, `fix:`, `refactor:`, `docs:`, `test:`). Small, working commits.
- **Test before "done."** Run the relevant tests/checks (§6) and report results. Don't declare a task complete on untested code.
- **Update this file** when architecture or commands change. It is the source of truth; stale = dangerous.

---

## 2. Tech Stack

| Layer | Tech | Purpose |
|---|---|---|
| Game client | **Godot 4.6.3**, typed GDScript | hybrid 3D shop + 2D gameplay interfaces |
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
├── project.godot              ← Godot 4.6.3 project root
├── docs/
│   ├── PRD.md                 ← build requirements; §12 is the discovery spec
│   ├── phase-task.md          ← canonical implementation checklist/status
│   └── ai-disclosure.md       ← running AI-usage log (APPEND when AI is used)
├── scenes/                    ← production .tscn scenes (Shop.tscn) + ui/, restoration/
├── scripts/                   ← shop, core, models, discovery, restoration, scanner, journal, portal
├── dialogue/                  ← reusable dialogue scene and script
├── addons/gut/                ← vendored GUT 9.6.0 (Godot Unit Test) runner
├── resources/                 ← Godot .tres definitions
├── assets/                    ← original art/audio only
├── tests/                     ← GUT tests (test_*.gd)
├── .github/workflows/ci.yml   ← CI: 4.6.3 import + GUT + gdformat + gdlint
├── requirements-dev.txt       ← pinned gdtoolkit (gdformat/gdlint)
├── server/                    ← Express: LLM proxy + portal client (Phase 8; not yet created)
├── mock-portal/               ← mock City-Wide Portal API (Phase 8; not yet created)
└── data/                      ← objects, artifacts, echoes, routes, scanner-cache (JSON; artifact-agnostic)
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

**D. Two-stage gate:** a carrier must be **cleaned before it can be opened**. No exceptions — this is why discovery flows through the restoration loop.

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

---

## 5. The Core Loop (what the code serves)

**Daily:** morning delivery → triage (limited storage/time/money) → restore (clean mini-game) → scan & judge (AI suggests, player decides) → decide (sell / return / museum) → evening (journal, upkeep).

**Discovery (the headline mechanic):**
> Hum (far) → Melody (area) → Voice (pile) → carrier flickers + Heartbeat spikes → pick up → **clean** → **open** → fragment inside → **Artifact Found** screen → **Portal API** → **Portal Unlock** fact → fragment **seats in journal case** (permanent).

Full detail: `docs/PRD.md` §12.

---

## 6. Commands

Use the **explicit Godot 4.6.3 console executable** for reliable CI/automation: `C:\Users\roman\Downloads\Godot_v4.6.3-stable_win64_console.exe`. A PATH shim exists at `C:\Users\roman\tools\bin\godot.cmd`, but the bare `godot` command currently resolves to the older 4.5.1 executable at `C:\Users\roman\Desktop\Godot` because its `godot.exe` appears earlier in the effective PATH than the `.cmd` shim. Open a fresh shell after any PATH change.

```powershell
# --- Game (Godot 4.6.3; project.godot is in this directory) ---
godot --version                                      # currently 4.5.1.stable; use the explicit 4.6.3 exe below
$C:\Users\roman\Downloads\Godot_v4.6.3-stable_win64_console.exe --version  # expect 4.6.3.stable
# For each command, replace `godot` with `$godot = "C:\Users\roman\Downloads\Godot_v4.6.3-stable_win64_console.exe"` until the bare command is fixed.
godot --editor --path .
godot --headless --editor --path . --quit            # import/build check
godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit

# --- Lint/format (gdtoolkit; pinned in requirements-dev.txt: pip install -r requirements-dev.txt) ---
# Scope to our source — vendored addons/gut is third-party and not formatted by us.
gdformat --check scripts scenes dialogue tests
gdlint scripts scenes dialogue tests

# --- Backend (LLM proxy + portal client; Phase 8, not yet scaffolded) ---
cd server && npm install
cp .env.example .env            # fill in keys locally; NEVER commit .env
npm run dev                     # dev server
npm test                        # backend tests

# --- Mock Portal (Phase 8, not yet scaffolded) ---
cd mock-portal && npm install && npm start
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
2. **One** carrier fully built — the **pendant** (clean → clasp-open → fragment). Stub other open-interactions.
3. **Spawn Director v1** with *genuine* carrier + container + day rolls and per-player never-twice (this is the beat the video proves — must be real, not faked).
4. **Echo mixer v1** — 4 bands + resonance meter + captions.
5. **Cached scanner v1** — evidence and suggestions only; the player sets the verdict.
6. **Artifact Found → mock Portal API → Portal Unlock → persisted museum record → journal seat.** Five-slot case, one slot fills on camera.

The 50% gameplay video must show three beats: (a) the artifact spawning in different locations, (b) finding it via Echo cues, and (c) the Portal Unlock notification. See PRD §12 acceptance, §13 acceptance, and `docs/phase-task.md` Phase 11 for the cut-line and shot checklist.

**Deferred (finalist phase):** full economy, live marketplace AI, the other character routes, museum polish, remaining carrier open-interactions, live Portal endpoint (single-URL swap).

---

## 9. Project Facts

- **Team:** Francis Gabriel Austria (lead dev), Om Shanti Limpin (dev/design/narrative), Jorge Maverick Acidre (dev/design). WVSU, Iloilo City.
- **Artifact:** undecided; frontrunner is the **Heirloom Timepiece** (escapement·dial·hands·gear-train·pendulum). Keep all systems artifact-agnostic until locked (post-workshop, before asset production).
- **Engine verification:** `project.godot` targets Godot 4.6. Official Godot 4.6.3 console build is installed at `C:\Users\roman\Downloads\Godot_v4.6.3-stable_win64_console.exe` and verified (`--version` → `4.6.3.stable.official.7d41c59c4`). A 4.6.3 PATH shim exists at `C:\Users\roman\tools\bin\godot.cmd`, but the bare `godot` command currently resolves to the older 4.5.1 executable at `C:\Users\roman\Desktop\Godot` (`4.5.1.stable.official.f62fdbde1`) because its `godot.exe` appears earlier in the effective PATH. Use the explicit 4.6.3 executable for all verification. The editor import, main-scene startup, GUT suite (`16/16` passing), and minute-level clock behavior all pass under 4.6.3. Runtime tasks still require their own acceptance checks before `[x]`.

---

*Read `README.md` for the GDD, `docs/PRD.md` for build requirements and the full discovery spec, and `docs/phase-task.md` for implementation order. When in doubt, the invariants in §4 win.*
