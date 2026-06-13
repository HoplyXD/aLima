# aLima — Phase Tasks

Task breakdown for the **current development phase**, derived from the GDD
([README.md](README.md)) — Section 13 (Development Roadmap) and Section 14 (The
June 30 Vertical Slice).

- **Current phase:** Sprint 1 — core slice
- **Window:** June 12–19, 2026
- **Builds toward:** 50% submission / June 30 Vertical Slice
- **Engine:** Godot 4.x ([project.godot](project.godot)) — Twine/Chapbook draft
  ([aLima.twee](aLima.twee)) is the design reference for flow and tuning.

> Scope rule for this phase: build **exactly** what the June 30 gameplay video
> must demonstrate. Defer the rest rather than dilute it (README §14).

---

## 0. Milestone Definition of Done (June 30)

The gameplay video must show all three beats (README §14):

- [ ] The artifact spawning in **different locations** across multiple runs
- [ ] The player **finding the item** using the four-band "Echo" cues
- [ ] The **API notification** showing the "Portal Unlock"

Everything below feeds one of these three beats or the playable slice around them.

---

## 1. Sprint 1 — Core Slice (June 12–19)

The four Sprint 1 deliverables from README §13.

### 1.1 Shop scene
- [ ] One shop space scene (single room, golden-hour junk-shop framing per §12)
- [ ] Daily clock: 1 real minute = 1 in-game hour, day runs 07:00–20:00 (§6)
- [ ] Clock HUD (day N of 5, current hour, loop counter) — mirrors the Twee `Shop` header
- [ ] "End the day" / advance-time flow (`End Day` → `Day Start` parity with Twee)

### 1.2 Delivery & triage
- [ ] Morning delivery: spawn ~5–9 objects weighted by glow rarity (§9.1)
- [ ] Glow tiers White→Green→Blue→Purple→Gold + Flickering (story) (§9.1)
- [ ] Triage UI: limited slots force keep/recycle choices
- [ ] Port the Twee rarity weights as first-pass tuning (`Day Start` passage)

### 1.3 Restoration mini-games (2 of them)
- [ ] Mini-game A — pick one tactile type (e.g. brushing/dust) (§9.2)
- [ ] Mini-game B — second type (e.g. rust lift or photo restoration)
- [ ] Skill-based outcome (replaces the Twee luck roll); wrong tool / failure
      permanently lowers or destroys value (§9.2)
- [ ] Success releases a Temporal Echo hook (stub OK this phase) (§9.12)

### 1.4 Object data pipeline
- [ ] JSON-defined object database — keep design artifact-agnostic (§11)
- [ ] Schema: id, type, materials, weight range, glow, clean method, price range
- [ ] Loader in Godot + a few seed objects to drive the slice
- [ ] Artifact defined as data: name, five components, history record, echo set (§8)

---

## 2. Vertical-Slice Systems (Sprint 2 work pulled in for the slice, §14)

These are listed in §14 as *included in the slice* and are what the three video
beats depend on. Start scaffolding once Section 1 is stable.

### 2.1 Spawn Director v1 (Beat 1 — "different locations")
- [ ] Placement spaces: piles, shelving, containers, days/times, nested-in-object (§9.8)
- [ ] Constraint-weighted selection (route state, owned tools, container fit, history)
- [ ] Per-player spawn-history exclusion → never-twice guarantee
- [ ] Repeatable seed control for the side-by-side video runs

### 2.2 Cultural Echoes v1 (Beat 2 — "Echo cues")
- [ ] Four proximity bands: Hum → Melody → Voice → Heartbeat (§9.9)
- [ ] Audio bus mixing by proximity (Godot audio buses, §11)
- [ ] Subtitle captions + visual resonance meter (accessibility, §9.9)

### 2.3 Artifact Found + mock Portal API (Beat 3 — "Portal Unlock")
- [ ] "Artifact Found" screen: item render, name, origin, condition, fragment count (§9.10)
- [ ] API call → "Portal Unlock" notification → real-world fact card → museum entry
- [ ] Local mock service mirroring the official ADK/API contract 1:1 (§9.10, §11)
- [ ] Single-endpoint swap design so live portal drops in later

### 2.4 Scanner v1 (cached)
- [ ] AI scanner proposes type/period/materials/markings/condition/price (§9.4)
- [ ] Cached annotations (offline-safe for booth, §11) — no live LLM yet

### 2.5 Journal v1
- [ ] Records restored objects (Purple-and-below) (§9.3)
- [ ] Fragment case on first page; seated fragments persist across loops (§9.3, §9.6)

### 2.6 Emotional showcase
- [ ] Elderly-Auntie photograph beat playable end-to-end (§14, route §9.7)

---

## 3. Workshop & Submission Gates

- [ ] **June 20 — Workshop 1:** apply feedback; review artifact candidates (§8, §13)
- [ ] **June 27 — Workshop 2:** lock final artifact; clarify ADK/API contract
- [ ] **June 28–30:** record the three video beats, finalize AI disclosure log
- [ ] **June 30:** submit gameplay video + public repo

---

## 4. Cross-Cutting / Always-On

- [ ] Maintain AI usage log from day one, submit with milestone (§10, §15)
- [ ] Original assets only; public-domain cultural references (§15)
- [ ] Public GitHub commit history demonstrating build-from-scratch (§11)
- [ ] Keep Twee draft and Godot tuning in sync as the flow reference

---

## Deferred (NOT this phase — documented, not built; §14)

- Full five-day loop economy
- Live marketplace negotiation AI (§9.5)
- Remaining four character routes (Artisan, Scavenger, Archeologist, Buyer) (§9.7)
- Museum gallery polish (§9.10)
