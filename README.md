# aLima

### *A Cozy AI-Powered Historical-Restoration Roguelite*

> *"Every object remembers. Someone just has to listen."*

**Game Design Document** — AI Game On! IV • AI Fest 2026
Team **DECYFER** • Region VI – Western Visayas • Iloilo City • West Visayas State University
*Theme: "Giving Our History a New Heartbeat through the Intelligence of Tomorrow."*

> **About this document.** This GDD describes aLima's design and the systems the team is building in the project repository. Core gameplay systems (the five-day loop, restoration, scanner, marketplace, procedural placement, Cultural Echoes, and the Portal/found flow) are implemented; the walkable outdoor scrapyard and several full-game systems are in active development (Section 14). **The narrative, dialogue, character arcs, and the final heritage artifact are still being finalized and will be locked for the game's release.** This document fixes the *structure, mechanics, and roles* — not the final script.

---

## Contents

1. Executive Summary
2. Theme Alignment
3. Game Overview
4. Narrative Premise
5. Design Pillars
6. Core Gameplay Loop
7. Compliance with Official Jam Mechanics
8. The Regional Heritage Artifact
9. Game Systems
10. AI Integration & Disclosure
11. Technical Overview
12. Art & Audio Direction
13. Development Roadmap
14. Current Build Status & Scope
15. Ethics, Copyright & Cultural Responsibility
16. Team
17. Closing
- Appendix A — Glossary

---

## 1. Executive Summary

aLima is a cozy, narrative-driven restoration roguelite set in a small family-owned junk shop in Western Visayas. The player inherits a journal bound in **Chronos Emulsion** — a substance that exists outside the flow of time — from an uncle who vanished while trying to restore a regional heritage object. That object, the **Master Artifact**, shattered into **five fragments**, and the journal now holds the shop and its surroundings in a repeating **five-day loop**. Set into its first page is an empty case shaped for five fragments; until the case is filled, the week cannot truly end.

The game is played across **two connected 3D spaces**, joined by the shop's front door: a **seated shop interior**, where the player restores, authenticates, and trades objects, and a **walkable outdoor scrapyard**, where the player forages raw scrap and tracks hidden fragments down by ear. Each day, the player forages scrap, hands it to the yard's scrap-hauler to be sorted into a delivery, triages the incoming batch, and restores what is worth saving — then scans it, judges it, and decides its fate.

AI is woven through the experience as live, diegetic systems: an AI scanner suggests identifications, AI-driven buyers negotiate in natural language, an AI placement system hides each fragment somewhere new for every player and run, and AI-generated **Cultural Echoes** — regional soundscapes — grow louder as the player nears a hidden fragment.

Progression is built on **knowledge, not resources**. Each loop resets money and stock, but everything learned — journal entries, restoration techniques, scanned records, and recovered fragments — persists, because the Chronos-bound journal sits outside time. Across loops, the player completes the routes of five local characters who each guard one fragment, recovers and seats all five, and finally breaks the loop.

aLima's answer to the theme is structural rather than decorative: preservation is not a side activity but the central mechanic, the narrative engine, and the means by which both history and time itself are restored.

---

## 2. Theme Alignment

*"Giving Our History a New Heartbeat through the Intelligence of Tomorrow"*

- **A new heartbeat, literally.** The final cue that a fragment is within reach is a soft heartbeat layered into the scrapyard's soundscape. Every restoration revives an object that was one step from being scrapped.
- **The intelligence of tomorrow, in service of yesterday.** AI in aLima is diegetic, not a development shortcut: it identifies and contextualizes objects, negotiates as buyers, hides the artifact anew for every player, and generates the soundscapes that guide discovery.
- **History passed hand to hand.** *Alima* is the Kinaray-a word for "hand"; hidden inside it is *lima* — "five." Five days, five fragments, five characters. The player passes recovered history forward into a shared digital museum.
- **From junk shop to living museum.** The scrapyard destroys objects; the museum saves them. That tension is the playable core of the game.

---

## 3. Game Overview

| Attribute | Detail |
|---|---|
| Working title | aLima |
| Genre | Cozy restoration sim × narrative roguelite |
| Platform | Windows (primary); HTML5/web build for the AI Fest exhibit booth |
| Engine | Godot 4.7 (typed GDScript) + Node.js/Express backend |
| Spaces | Seated 3D shop interior + walkable 3D outdoor scrapyard |
| Mode | Single-player |
| Session length | ~13 min real per in-game day (1 real min = 1 in-game hour); ~1 hour per five-day loop |
| Target audience | Teens and adults; players of *Unpacking*, *PowerWash Simulator*, *Strange Horticulture*, *Coffee Talk* |
| Input | Mouse-first; free-roam walking outdoors; full mouse, controller, and touch support |
| Language | English UI; Kinaray-a and Hiligaynon cultural lines, always subtitled |
| Team size | 3 members (Section 16) |

---

## 4. Narrative Premise

*(High-level premise. Specific arcs, dialogue, and the final artifact are in development — see the note at the top of this document.)*

The player helps run a family junk shop. Their uncle — **Yuyu**, a "Chronographer" who studied the memories held within objects — disappeared, leaving only a worn journal bound in Chronos Emulsion. Before vanishing, he had entrusted five fragments of a regional heritage object to five people he trusted.

The game opens on **Day 0**, the day Yuyu disappears: the player (named at save creation; never shown on screen, gender left to the player's perception) arrives on Panay Island to visit Tito Yuyu's house and junkshop and learn about the artifacts of Panay. Across one clockless guided day Yuyu teaches the whole craft — foraging the scrapyard, handing scrap to Ayla, triage, cleaning, scanning, selling — then sends the player alone on a tricycle delivery to town. They return to an empty shop and a journal that wasn't there that morning; touching it blacks the world out, and the player wakes into Day 1 of the loop. Day 0 never repeats (a skip is offered in the pause menu), and time itself only begins with Day 1.

The journal sits outside the flow of time: it is both what keeps the surrounding days looping and the one thing that survives each reset. New writing sometimes appears in it on its own. Inside its cover is an empty case cut for the five fragments. To break the loop, the player must complete the five characters' story routes — which release the fragments back into the local scrap stream — then track each fragment down, restore and open the ordinary object hiding it, and seat all five in the journal's case.

---

## 5. Design Pillars

| Pillar | What it means in play |
|---|---|
| **History in your hands** | Restoration is tactile and skill-based. AI can identify an object, but only the player's hands can bring it back — and careless hands can destroy it. |
| **Knowledge is the only currency that survives** | The five-day loop wipes money and stock, never learning. The journal, techniques, records, and recovered fragments persist; the player gets stronger by understanding, not hoarding. |
| **AI assists; the player judges** | The scanner suggests, flags, and contextualizes, but counterfeits ensure it is never blindly trusted. The final verdict is always the player's. |
| **Every find feeds the museum** | Culturally significant discoveries flow through a City-Wide Portal into a shared digital museum, turning private play into public memory. |

---

## 6. Core Gameplay Loop

**The two spaces.** aLima runs across two connected 3D spaces joined by the shop's front door. **Inside** is the seated shop: the player sits at the restoration corner, and the major actions are diegetic 3D interactables they hover and click — the door, the workbench, the journal, the phone. **Outside** is the walkable scrapyard: stepping out the door drops the player into a small open-air lot they explore on foot. The clock runs in both spaces, and only one space is active at a time.

**Daily loop (one in-game day, ~13 real minutes):**

1. **Forage (outside).** Walk the scrapyard and gather raw **scrap**, each piece showing an apparent rarity tier.
2. **Hand off & sort (outside).** Give chosen scrap to the scrap-hauler; she sorts it into a delivery. Richer scrap improves the odds of a better haul but never guarantees it.
3. **Triage (inside).** She knocks at the shop door with the sorted batch; limited storage, time, and money force the player to choose which objects to keep before the rest is recycled.
4. **Restore (inside).** Clean each kept object in a focused 3D restoration view — rotating it and working the right tool across its surface. The wrong tool can permanently lower value.
5. **Scan & judge (inside).** The AI scanner proposes an identification; the player cross-references the journal to confirm, doubt, or overrule it.
6. **Decide (inside).** Sell on the marketplace, return an object to its owner, preserve it in the museum, or archive it in the journal.
7. **Evening (inside).** Journal updates, upkeep, and preparation for the next day.

**Meta loop (across five-day cycles).** Money and stock reset; knowledge and seated fragments persist. Across loops the player completes the five characters' routes — which release fragments into the scrap stream — then tracks each fragment down in the scrapyard, until all five are seated and the loop breaks.

**Discovery (the headline mechanic).** When a fragment is in play, the scrapyard begins to sound different. The player follows Cultural Echoes that intensify with proximity → finds the ordinary object hiding the fragment → carries it inside → cleans it → opens it → recovers the fragment → the Artifact Found screen and Portal Unlock fire → the fragment seats permanently in the journal's case.

---

## 7. Compliance with Official Jam Mechanics

This section maps every required AI Game On! mechanic to its concrete implementation in aLima.

| Official requirement | Implementation in aLima |
|---|---|
| **Hidden AI Heritage Artifact** — a secret, story-driven relic | The Master Artifact, a regional heritage object shattered into five fragments. None is handed to the player; each is hidden in the game world and physically discovered, then seated in the journal's case. Finding one unlocks a real-world historical fact via the Portal. |
| **AI Procedural Placement** — never in the same spot twice | The **Spawn Director**: a constraint-weighted placement system that hides each fragment at a different spot across the walkable scrapyard for every player and run, with per-player history so it never repeats. |
| **Cultural Echoes** — AI-generated audio clues | A four-band proximity audio system — a low hum, a folk-style melody, Kinaray-a phrases and ambient sound, and a heartbeat — that grows louder and clearer as the player nears the hidden fragment, fully captioned. |
| **Digital Museum + discovery screen** — portal call + found screen | A custom **Artifact Found** screen fires the exact moment a fragment is recovered, calls the City-Wide Portal API, reveals the real-world fact in a **Portal Unlock** notification, and saves the find and its history to a persistent museum record. |
| **Artifact upload + lore video** | The team will produce a physical/visual artifact replica and a lore video on the chosen artifact's history and its five-way division. |

---

## 8. The Regional Heritage Artifact

The final artifact is intentionally **not yet locked**. It is being selected through cultural research and consultation during the official workshops and will be confirmed before final asset production. Because every system references "the artifact" as a data definition — a name, five components, a history record, and an echo set — the final choice carries no architectural cost.

Candidates under consideration are time-themed Western Visayas heritage objects that divide naturally into five physically-reassembled parts:

| Candidate | Five-part logic |
|---|---|
| Heirloom Timepiece *(frontrunner)* — a mantel/pendulum clock from an Ilonggo *bahay-na-bato* | escapement · dial · hands · gear train · pendulum |
| The Ampolleta — a Manila-galleon sand-glass | upper bulb · lower bulb · base plate · top plate · pillar frame |
| The Belfry Clockwork — a tower-clock movement | mainspring · gear train · escapement · dial · strike hammer |
| The Mariner's Astrolabe — a brass sky-clock | mater · rete · alidade · rule · throne ring |

**Selection criteria:** cultural verifiability with local sources; respectful representation (folklore framed as folklore, history as history); a natural five-part division; strength as a physical upload and lore-video subject; and visual readability in game. Documented hoaxes (e.g., the Code of Kalantiaw) are excluded as sources of fact.

---

## 9. Game Systems

### 9.1 Foraging, Sorting & Triage

The scrapyard is the game's source of material. The player walks the yard and gathers loose **scrap**, each piece carrying an apparent rarity tier. The player then hands chosen scrap to the scrap-hauler, who **sorts** it into the day's delivery of restorable objects. The sort is **weighted toward the scrap's own rarity tier**, with only a slim chance of yielding something rarer, so high-rarity finds stay scarce; each scrap sorts into one to three outcomes — a restorable object, a minor item, or trash. There is no free automatic delivery: the player earns each batch by foraging.

Storage, time, and money are limited, so every kept object is a bet. Each object shows an **apparent** rarity glow — *apparent*, because the glow reflects how an object looks, not what it is. Counterfeits can shine; treasures can look like trash.

| Glow | Apparent meaning |
|---|---|
| White | Common object |
| Green | Uncommon find |
| Blue | Potentially valuable antique |
| Purple | Rare or unusual object |
| Gold | Historically significant find |
| Flickering | Connected to a hidden story or route |

### 9.2 Restoration

Restoration is a focused **3D object-manipulation** interaction: the object is rendered as a manipulable 3D model the player orbits and rotates to inspect, then cleans by working a tool across its surface. Cleaning tools are chosen from a tool sidebar — each row a rotating 3D model of the tool with the surface conditions it treats and a durability bar — and the selected tool then follows the cursor as the player works, so the cleaning stays a tactile 3D act. Each object type demands its own technique: brushing, wiping, rust removal, polishing, paper care, frame repair, photo restoration, engraving reveal, and mechanism inspection. The wrong tool can erase detail or permanently reduce value. Better tools are bought with profits; some delicate techniques can only be learned from people, not shops.

### 9.3 The Uncle's Journal & Fragment Case

The journal is the player's archive, guide, and progression system in one, presented as a **hybrid 2D/3D** interface: a paper book whose pages hold entries, notes, and annotations, with a 3D viewer for the Fragment Case and restored objects. Every restored object earns an entry — estimated origin, materials, cleaning method, counterfeit indicators, historical context, price ranges, and the player's own records — distinguishing the uncle's handwritten notes from AI annotations drawn from verified records. **Purple-rarity-and-below finds are archived in the journal**; Gold finds and the Master Artifact go to the museum.

The journal's first page holds the **five-slot Fragment Case**. Each recovered fragment is seated here, and — because the journal is bound in Chronos Emulsion and sits outside time — seated fragments persist across every reset. This is the in-fiction reason recovered fragments and all journal knowledge survive each loop while money and stock do not.

### 9.4 The AI Object Scanner

After cleaning, the player scans an object with an in-fiction phone app, which proposes **suggestions**: object type, possible period, detected materials, visible markings, condition, cultural relevance, a suggested price range, and signs of modification or counterfeiting. The scanner is an assistant, not an oracle — it never sets the verdict itself. For suspicious items the player cross-references the journal (a fake may betray itself through wrong weight, modern fasteners, artificial wear, poorly copied engravings, or suspicious history) and decides whether an object is authentic, a replica, modified, or uncertain. Scanner calls run server-side; the build ships cached responses so the exhibit never depends on venue internet.

### 9.5 The AI-Driven Marketplace

Restored items are sold through an AI-driven chat with buyers of distinct personalities, budgets, and motives. The player accepts, rejects, or haggles; accurate descriptions and honest restoration raise achievable prices. Negotiation runs through the backend behind persona and guardrail prompts, with deterministic offline fallbacks so the booth demo always works. Profit is not always the right answer — some objects should be preserved, not sold.

### 9.6 The Five-Day Loop & Persistence

At the end of Day 5, the week restarts. The cause is the Chronos-bound journal itself, which anchors the surrounding days until its fragment-case is filled. The loop is the roguelite engine: early runs reveal opportunities too late; later runs prepare for them in advance.

| Resets each loop | Persists forever |
|---|---|
| Money and temporary upgrades | Journal entries and techniques |
| Ordinary inventory | Scanned object records |
| Marketplace listings | Digital-museum entries |
| Unfinished customer requests | Story clues and unlocked progress |
| Daily event outcomes | Seated fragments, legacy items, leads |

### 9.7 Character Routes

*Structure decided; specific characters, schedules, arcs, dialogue, rewards, and endings are in active development and will be finalized for release.*

Five characters each guard one of the five fragments; a sixth thread — the uncle's — is the finale. Completing a character's story route **releases** that fragment into the local scrap stream for the placement system to hide — characters never hand a fragment to the player directly. The scrap-hauler who sorts the player's scrap is also one of the fragment-guardians, met daily out in the yard. Routes can **interlock**: a tool or lead earned from one character's route can unlock another's. The intended pacing is roughly **one route completion per loop**, so the five fragments are gathered across several loops, with the last fragment seated in the loop that finally breaks the cycle.

### 9.8 Fragment Release & AI Procedural Placement (the Spawn Director)

Story gates *when*; AI decides *where*. Completing a route never hands the player a fragment; instead the fragment enters the local scrap stream, and from that moment the **Spawn Director** takes over.

- **Placement space:** hiding spots across the walkable scrapyard (under tarps, inside scrap heaps, in the delivery bay) — always nested inside an ordinary restorable object, never loose, so discovery flows through the core restoration loop.
- **Carrier is a role, not a special object:** the Director promotes an ordinary openable object to "carrier" for the run. Almost any such object *could* be a carrier; only one per fragment is. Identical objects sit beside it as decoys.
- **Constraint-weighted, never-twice:** placement weighs container compatibility, owned tools, and the player's own behavior history, and records each placement so it never repeats the same spot for that player.
- **Demonstrability:** the placement is seeded and logged, so side-by-side runs show the same fragment hidden in different spots.

### 9.9 Cultural Echoes (Discovery Cues)

While an unfound fragment is hidden in the scrapyard, the yard sounds different — AI-generated, human-curated audio layers mixed by the player's proximity as they walk:

| Band | Proximity | What the player hears |
|---|---|---|
| 1. The Hum | Far | A low ambient hum, barely separable from yard noise |
| 2. The Melody | Closer | An original folk-style melody in a Western Visayas idiom |
| 3. The Voice | Near | Kinaray-a phrases and ambient sounds tied to the artifact |
| 4. The Heartbeat | At the object | A soft heartbeat — the object is here |

The **heartbeat plays only at the true carrier** — it is the disambiguator that separates the fragment from its decoys. On pickup, the overwhelming heartbeat resolves into a soft carried aura that fades to silence once the fragment is cleaned, opened, and seated. Every band has subtitle captions and a visual resonance meter, so discovery is fully playable without audio.

### 9.10 Portal Unlock & the Digital Museum

The found sequence: discovery → a custom **Artifact Found** screen (item render, name, origin, condition, fragment count) → a backend call to the **City-Wide Portal API** → a **Portal Unlock** notification revealing the real-world historical fact → a persisted museum record → the fragment seats in the journal's case.

Two archives, by rarity: **Gold finds and the Master Artifact** populate the online museum (fact cards, photographs, regional stories); **Purple-and-below** stay in the journal. Until official portal access is granted, a local mock service mirrors the documented contract one-to-one, so going live is a single configuration change.

### 9.11 Mini-Events

Scripted and random events keep each run distinct (for example, a sudden brownout that takes the marketplace offline and dims restoration until the player uses a light source). Frequency is tuned and capped per loop so events add variety without overwhelming the daily loop.

### 9.12 Temporal Echoes

Distinct from the Cultural Echoes that guide discovery, a **Temporal Echo** is a memory locked inside an everyday object, released by successfully restoring it — a short glimpse of a past owner, recorded in the Chronos-bound journal (which is why it persists across loops). Echoes are the connective tissue between ordinary restoration and the larger mystery. *(Memory contents are part of the in-development narrative.)*

### 9.13 Gated Caches

The uncle left gated caches — a safe and a locked drawer — opened with codes or clues earned through play and persisting once known. Because money resets each loop, such payoffs are designed to land in a later loop. A known cache can also become an eligible hiding place for a fragment carrier (still an ordinary promoted object, never a loose fragment). *(Specific contents tie into the in-development narrative.)*

### 9.14 Endings & the Perfect Loop

Completing the characters' routes and seating all five fragments breaks the loop and resolves the central mystery — the "Perfect Loop." Completing none of the routes simply repeats the week. Because seated fragments persist, the player never re-gathers them; the Perfect Loop is the loop in which the final fragment is seated. *(The specific endings are part of the in-development narrative.)*

---

## 10. AI Integration & Disclosure

aLima uses AI on two layers: inside the game as live systems the player touches, and in development as disclosed production tools. The team maintains a complete AI-usage log from day one and submits it with every milestone, in line with the jam's Ethical Use & Copyright rules.

**Runtime AI (in-game systems)**

| System | Tooling | Role |
|---|---|---|
| Object scanner | LLM over a curated historical database | Identifies and contextualizes objects against verified records; the player verifies or overrules. |
| Buyer negotiation | LLM with persona + guardrail prompts | Natural-language haggling with distinct buyer motives. |
| Spawn Director | Constraint-weighted placement logic | Hides each fragment in a new location for every player and run. |
| Cultural Echo mixer | Proximity-driven adaptive audio | Mixes regional soundscapes by distance band into a discovery compass. |

All LLM and Portal calls run **server-side**, rate-limited, with cached fallbacks; no keys or provider calls ship in the Godot client.

**Development AI (production tools, fully disclosed)**

| Area | Tooling | Use & safeguard |
|---|---|---|
| Art | Image-generation tools | Concepting and texture passes, hand-finished; style-referenced from public-domain cultural documentation only. |
| Code | AI pair-programming | Systems scaffolding and refactoring; reviewed and owned by the team in a public Git history. |
| Music & audio | AI music generation, human-curated | Original folk-inspired compositions only — never sampling existing recordings of traditional songs. |
| Story & text | LLM drafting, human-edited | Drafts edited for tone and reviewed for cultural accuracy; Kinaray-a lines reviewed by native speakers. |

---

## 11. Technical Overview

- **Engine:** Godot 4.7, typed GDScript. Two connected 3D spaces — a seated shop interior and a walkable scrapyard — with 2D `Control`/`CanvasLayer` interfaces for triage, scanner, dialogue, and the Portal flow. Restoration is a focused 3D view; the journal is hybrid 2D/3D. Godot's audio buses drive the four-band echo mixer.
- **Architecture:** Godot client ↔ a lightweight Node.js/Express backend ↔ the City-Wide Portal API. LLM calls run server-side with rate limiting and cached fallbacks.
- **Mock-first Portal integration:** a local mock service implements the official contract; once portal access is granted, integration is a single endpoint swap.
- **Offline resilience:** the exhibit build ships cached scanner annotations and pre-generated negotiation content, so the booth demo never depends on venue internet.
- **Data-driven:** objects, routes, echoes, and the artifact are defined in JSON and Godot resources, keeping the design artifact-agnostic; per-player history backs the never-twice placement guarantee.
- **Targets & performance:** Windows primary, HTML5 verified separately; full mouse, controller, and touch support; targets of 60 FPS at 1920×1080 (Windows) and 30 FPS at 1280×720 (web).
- **Repository:** public GitHub history begins within the jam window and demonstrates the project being built from scratch.

---

## 12. Art & Audio Direction

**Art.** A warm hybrid presentation: a stylized 3D junk-shop interior and its adjoining open-air scrapyard lot, framed with hand-crafted, painted 2D interfaces and overlays. The palette is golden-hour junk shop — rust, brass, varnished wood, late-afternoon light through dusty louvers. The UI lives inside the fiction: journal paper, masking tape, ballpoint ink. Props are unmistakably Filipino: weighing scales, soft-drink crates, sari-sari signage, *santo* figures, *capiz* panels.

**Audio.** An original folk-inspired score in a Western Visayas idiom — AI-generated, human-curated, and never sampling existing recordings. Kinaray-a and Hiligaynon lines are recorded with native speakers where feasible. The shop and yard themselves are instruments: rain on the roof, the scale's creak, a tricycle passing — and underneath it all, sometimes, a hum that should not be there.

---

## 13. Development Roadmap

| Stage | Focus |
|---|---|
| Core slice | Shop scene, delivery/triage, one complete restoration→open interaction, object data pipeline |
| Jam mechanics | Spawn Director, Cultural Echo mixer, Artifact Found screen, mock Portal |
| Outside world | Walkable scrapyard, foraging, scrap sorting & delivery, scrapyard discovery |
| Content build | Full restoration catalog, economy and dispositions, all character routes, museum, endings |
| Production | Final art/audio/UI, native-speaker review, artifact replica, lore video, exports |

**Submission deadlines:** proposal **June 27, 2026**; final repository + gameplay video **July 11, 2026**; AI Fest exhibit (Iloilo City) **August 3–5, 2026**.

---

## 14. Current Build Status & Scope

This GDD describes the full design; the project is being built from scratch across the jam window. As of the current build:

**Implemented and tested** (Godot 4.7, with automated test coverage): the five-day clock/loop and split-save persistence; weighted delivery and triage; the focused 3D restoration view with selectable 3D tools and the clean→open gate; the constraint-weighted Spawn Director with never-twice placement; the four-band Cultural Echo mixer with resonance meter and captions; the cached AI scanner with player verdict; the Node/Express backend, mock Portal, and the Artifact Found → Portal Unlock → museum-record → fragment-seat flow; the hybrid 2D/3D journal with the five-slot Fragment Case; an AI buyer-negotiation marketplace with offline fallback; settings/pause; and Windows and HTML5 export presets.

**In active development:** the walkable outdoor scrapyard and player movement; foraging and the scrap-sorting delivery loop; relocating discovery into the yard; the full disposition (sell/return/preserve/journal) and evening-upkeep steps; the complete character routes; the full openable-object catalog; the Temporal Echo and mystery-page content; live-service integration alongside the existing fallbacks; final production art, audio, voices, and cultural review; the artifact replica and lore video.

---

## 15. Ethics, Copyright & Cultural Responsibility

- **Full AI disclosure.** A complete list of AI tools used (art, code, story, music) and how each helped highlight regional culture is maintained from day one and submitted with every milestone.
- **Original or properly-licensed assets only.** No third-party IP; assets are original or CC0/credited, referenced from public-domain cultural documentation. Audio is original/folk-inspired and never samples real recordings of traditional songs.
- **No harmful or misleading content.** Scanner facts derive from verified records; folklore is always framed as folklore, never as archaeological fact.
- **Cultural respect.** Artifact selection and Kinaray-a/Hiligaynon usage are validated with local sources and native speakers, with consultation during the official workshops and mentoring.
- **Player data.** Portal synchronization is limited to gameplay-relevant data (discoveries, condition, timestamps) — nothing more.

---

## 16. Team

Students • Region VI – Western Visayas • Iloilo City • West Visayas State University

| Member | Role |
|---|---|
| Francis Gabriel Austria | Lead Developer / Game Design |
| Om Shanti Limpin | Developer / Design / Narrative / Artist / UI |
| Jorge Maverick Acidre | Developer / Design / 3D Modeler / Character Artist |

All members are 18 or older and belong to this team only.

---

## 17. Closing

The title comes from the Kinaray-a word *alima* — "hand." Hidden inside it is *lima* — "five." Five days in every loop. Five fragments of one artifact. Five people the uncle trusted. Hands-on restoration. History handed from one person to the next, from strangers to a shopkeeper, from a junk shop to a city's digital museum.

AI in aLima finds the pattern, names the period, suggests the price. But technology alone cannot restore what has been forgotten. Someone still has to pick the object up, clean it carefully, listen to its story — and place it in another person's hands. That is how history gets a new heartbeat.

---

## Appendix A — Glossary

- **Chronographer** — the uncle's profession: a scholar of the memories held within objects.
- **Chronos Emulsion** — the substance binding the journal; it exists outside time, anchors the five-day loop, and preserves anything seated in the journal's case.
- **Master Artifact** — the in-fiction name for the real Western Visayas heritage object, shattered into five fragments.
- **The Journal's Case** — the empty fitting inside the journal, shaped for the five fragments; filling it reassembles the artifact and breaks the loop.
- **Fragment** — one of the five pieces of the Master Artifact; released by a character's route, then hidden by the Spawn Director inside an ordinary object.
- **Carrier** — the ordinary openable object a fragment is hidden inside for a run; a runtime role, not a special object type.
- **Temporal Echo** — a memory locked inside an everyday object, released by restoring it.
- **Cultural Echo** — the four-band proximity audio that guides the player to a hidden fragment.
- **Perfect Loop** — the loop in which the fifth fragment is seated, completing the case and ending the cycle.
