# Route & Dialogue Compendium — aLima

**Canonical character-route structure and dialogue reference (v2).** Supersedes the v1 Google-Doc
draft ("Loop Memory & Decision Branching Reference"). Authority order is unchanged: `CLAUDE.md` §4
invariants → `README.md` GDD → `docs/PRD.md` requirements → `docs/phase-task.md`. Where this doc and
an invariant disagree, the invariant wins.

> **Dialect status.** Every Hiligaynon / Kinaray-a line carried over from the v1 draft is a *working
> draft* pending a native-speaker pass (GDD §15 / `ASSET-R4`). Treat all dialect text as
> placeholder-quality until reviewed.

---

## 1. What changed in v2 (and why)

The v1 draft predates the **inside/outside spatial reform** (seated shop interior + walkable
scrapyard) and the **scrap-foraging delivery loop**. Four structural changes follow from that, plus
one invariant fix the v1 draft violated:

1. **Ayla is now the permanent scrapyard delivery NPC**, not a gated afternoon visitor. She works the
   yard every open day, sorts the scrap the player forages into each day's delivery, and her story
   advances through that daily contact. *Reason:* she literally has to be present for the new core
   loop; a scavenger belongs in the yard.
2. **The Lave ↔ Ayla mutual exclusion is removed.** Lave is still **unlocked by helping the Auntie**
   (he's her grandson), but he no longer "replaces" or refuses to share a slot with Ayla. Both
   fragment-holders can be pursued in one loop. *Reason:* the exclusion is impossible once Ayla is the
   daily delivery backbone, and the v1 draft itself admitted it was contrived.
3. **The Cultural Echo hunt moves outside.** The four-band proximity hunt belongs to the **scrapyard**,
   tied to a released carrier hidden there. *Temporal* Echoes (the photo memory, the santo-altar flash)
   stay **inside** at the bench. The v1 draft threaded Cultural Echo bands through interior scenes; that
   ambient flavor moves to the yard.
4. **Inside/outside cast map.** Outside (scrapyard): **Ayla**. Inside (shop): **Shine, Lave, Sam,
   Maverick**. This mirrors the new spatial design.
5. **Invariant fix — Mr. Maverick can never hand over a fragment.** The v1 LOOP-2 scene had him
   produce the fifth fragment from his coat and set it down ("This is yours now"). That breaks
   `CLAUDE.md` §4-B/§4-C and `ROUTE-R5`: *no character hands over a fragment.* His qualifying trade
   **releases** the fifth fragment; the Spawn Director hides it inside an ordinary carrier in the
   scrapyard, and the player tracks it by sound, cleans, opens, and seats it like every other.

**What did NOT change:** the emotional core of every scene. Shine's restored photograph + Temporal
Echo, Lave's "dulom"/patina lesson, Sam's "show the break, don't erase it" jar, the Maverick ledger
and the spiral mark, and the entire Yuyu finale all carry over essentially as written in v1, pending
the native-speaker pass. Only Ayla's framing and Maverick's climax are rewritten below.

---

## 2. Route structure (v2)

| Route | ID | Where | Schedule / availability | Gate | Holds | Reward |
|---|---|---|---|---|---|---|
| Elderly Auntie (Nang Shine) | `auntie` | Inside (shop) | 12:00–14:00 on Days 1, 3, 5 | — | frag | Safe code · drawer clue |
| Local Artisan (Nong Lave) | `artisan` | Inside (shop) | 13:00–14:00 on Days 2, 4, 5 | **Auntie helped** (her grandson; no longer excludes Ayla) | frag | delicate (legacy) tool · fragile-object access |
| Trash Scavenger (Ayla) | `scavenger` | **Outside (scrapyard)** | present every open day; her completion is the lunchbox beat | **Sam's excavation tool** (to dig the lunchbox); the Sam *lead* itself comes free from daily contact | frag | fragment released |
| Archeologist (Sam) | `archeologist` | Inside (shop) | 08:00–11:00 Days 3, 5; 15:00–17:00 Day 1 once Ayla's lead is known (persists) | **Ayla's lead** (from daily contact, persists) | frag | excavation tools (also unearth Ayla's lunchbox) · sturdy-object access |
| Mysterious Buyer (Mr. Maverick) | `buyer` | Inside (shopfront) | 17:00–18:00 daily; +07:00–09:00 Day 5 | deal Days 1–4 ≥ once; **finale capstone — after the other four fragments are seated** | releases 5th frag | guaranteed special carrier in the yard · encoded ledger · investigation evidence |
| Uncle's Legacy (Yuyu) | `yuyu` | Inside (finale) | — | all 5 seated | — (finale) | Master Artifact whole · Perfect Loop |

**Fragment lifecycle is unchanged:** `LOCKED → RELEASED → SEATED`. Completing a route *releases* its
fragment into the scrap stream; the Spawn Director hides its carrier in the scrapyard; the player
finds, cleans, opens, and seats it. No character hands a fragment over directly.

**One ending per loop.** A loop has room to **complete only one fragment-holder's route** — the
scheduled characters' windows conflict, and Ayla's completion has its own multi-step gate (below). You
*can* still **find and seat** an already-released fragment out in the yard the same loop (the hunt
doesn't conflict with a route), so a typical loop = finish one new character + seat one older fragment.
Re-running an already-finished route in a later loop replays the scenes but yields **no new fragment**.

**Route dependency chain (the intended order across loops):**

- **Sam** is gated by **Ayla's lead**, which the player gets *free* from daily contact at the yard (not
  from completing Ayla). So Sam is reachable early.
- **Ayla's completion** is gated by **Sam's excavation tool**: with it the player digs her father's
  **lunchbox** out of the yard, cleans it (initials reveal), and chooses **"Show Ayla the lunchbox"** to
  finish her route. So the order is **Sam loop → Ayla loop**.
- **Lave** is gated by **helping Auntie** (his grandmother).
- **Maverick** is the **finale capstone**: his daily trades are background; once the other four
  fragments are seated, his qualifying Day-5 trade **releases the fifth**, found in the yard that same
  Day 5 to break the loop. He is not one of the per-loop route slots.

So a full playthrough is roughly **~5 loops**: Auntie, Lave, Sam, and Ayla one per loop (in a valid
dependency order), seating each fragment as you go, then the Buyer's finale loop for the fifth.

---

## 3. Ayla — reframed for the scrapyard (rewrite)

Ayla's two v1 scenes (the dismissed-then-vindicated lunchbox arc) are preserved in spirit but
**re-homed to the yard and the daily hand-off**, and split into two registers so daily contact never
flattens her arc:

- **Routine register (every open day, light):** quick banter at the hand-off as she takes the scrap
  the player foraged. She always insists today's haul has "tesoro" in it. This is functional and
  varied, not a cutscene.
- **Milestone register (gated, heavy) — a cross-route chain:** the **lead to Sam** is a *free* early
  gift of daily contact (she tells the player to go see the archeologist who digs professionally).
  Completing **Sam** grants the **excavation tools**, which let the player **dig her late father's
  dented lunchbox** out of a spot in the yard. Cleaning it reveals his initials and a date; then a
  **"Show Ayla the lunchbox"** option appears at the yard. Showing it drops her bravado, ties her
  father to "the Manong with a notebook" (Yuyu), and **releases her fragment**. So her ending cannot
  land until Sam's is done in an earlier loop (one-ending-per-loop ordering).

The v1 lunchbox dialogue (LOOP 1 dismissive / LOOP 2 vindicated) is reusable almost verbatim — relocate
the setting to the yard hand-off / the bench, and let the **excavated** lunchbox (not a chance forage)
surface it. The dig spot can be a fixed authored location or a Spawn-Director-style yard spot; the gate
is owning Sam's excavation tool.

---

## 4. Mr. Maverick — climax fix (rewrite)

Replace the v1 LOOP-2 hand-over with a **release**. Keep the ledger, the spiral mark, and the trust
beat; change only the delivery of the fragment itself. Maverick is the **finale capstone**, not a
per-loop route slot: his daily trades are light background across loops, and his fragment release only
matters once the other four fragments are seated — it is the final loop's climax.

- Across Days 1–4 the player makes at least one honest trade (ideally a spiral-marked piece).
- On his qualifying **Day 5** encounter, Maverick opens his encoded ledger, reveals Yuyu kept him on a
  short list of trusted dealers, and tells the player Yuyu asked him to "look into something" the week
  he vanished — an investigation he never finished.
- Instead of producing the fragment, he tells the player the fifth piece "surfaced in the yard
  yesterday with the rest of a lot I couldn't place" — **releasing** it. The spiral-marked trinket the
  player traded him and the fifth fragment "have been speaking to each other," and now the yard is
  calling. *(Poetic hook preserved; it just points the player outside.)*
- The player then **hears the Cultural Echo in the scrapyard, tracks the carrier, cleans, opens, and
  seats** the fifth fragment — identical to every other discovery, satisfying `§4-B/§4-C` and
  `ROUTE-R5`.

Suggested final line (draft, pending dialect review): *"I'm not the type to hand a man his own
history, anak. Go find it — it's out there waiting for you, same as it waited for me."*

---

## 5. Scenes carried over from v1 (placement notes only)

These keep their v1 prose (pending native-speaker review); only their *placement* is noted here:

- **Nang Shine (Auntie)** — inside, restoration corner, Days 1/3/5. The faded-photo Temporal Echo
  stays at the bench. Unchanged otherwise. Completing her route unlocks Lave.
- **Nong Lave (Artisan)** — inside, Days 2/4/5, unlocked by the Auntie. The santo "dulom"/patina
  lesson and his tool-roll gift carry over. Remove the v1 Branch Note language about refusing to share
  the slot with Ayla.
- **Sam (Archeologist)** — inside, mornings Days 3/5, early on Day 1 once Ayla's lead is known. The
  cracked-jar "show the break" lesson and the Yuyu tie carry over.
- **Yuyu (finale)** — inside, all five seated. The Neutral outcome and the Perfect-Loop return scene
  carry over intact (it already complies with the invariants).

---

## 6. Open writing tasks

- [ ] Native-speaker review pass on all Hiligaynon / Kinaray-a lines (`ASSET-R4`).
- [ ] Author Ayla's routine-register banter pool (varied daily hand-off lines).
- [ ] Re-set Ayla's lunchbox beat to "foraged from the yard."
- [ ] Rewrite the Maverick Day-5 climax to *release* (per §4 above) and remove the hand-over.
- [ ] Relocate Cultural Echo band cues out of interior scenes into the scrapyard hunt.
- [ ] 3 authored progression beats each for Auntie, Artisan, Scavenger, Archeologist, Buyer
      (`CONTENT-R7`).
