# Story Revamp v2 — Node Quest UI + Route/Fragment Canon

User request (2026-07-03, delegated overnight). Canon saved in memory `storyline-revamp-v2-canon`.

## Requirements (verbatim intent)
1. **Node-based Quest UI** — rebuild the quest UI so "everything is a node" (reusable scene tree,
   per-quest entry nodes), replacing the thin `set_quest_count` Label counter.
2. **Route schedules / gating**
   - Auntie visits days **1, 3, 5**. *(already in routes.json)*
   - Artisan visits days **2, 4, 5** only if **auntie quest 1** finished. *(routes.json gates on
     `auntie`; tighten to auntie's first beat.)*
   - Alya quest available days **2, 4, 5**, no door conflict with artisan (Alya is a yard NPC).
   - Maverick (buyer) shows up at **end of day 5** only, offering the **last fragment for ~50000
     pesos** (hard to afford; rewards good bantering + consistent clean restorations).
   - Sam storyline: **DEFERRED** (keep current Alya→salakot→Sam→fragment_04 as-is).
3. **Fragment sourcing**
   - Auntie → **fragment_01 in the safe** (find after opening the safe).
   - Artisan → **fragment_02** after his last quest.
   - Maverick → **fragment_05** at day-5 end for ~50000 pesos.
   - Alya/Sam → fragment_04 (existing flow).

## Status

### DONE this pass (built + tested + green)
- [x] **Node Quest UI**: `scenes/ui/quest_tracker.tscn` + `quest_entry.tscn` + scripts
      (`scripts/ui/quest_tracker.gd`, `quest_entry.gd`), driven by QuestService + EventBus quest
      signals; wired into shop + scrapyard/dump HUDs; hides when no active quests. Tests in
      `tests/ui/test_quest_tracker.gd`.
- [x] `QuestService.current_objective(quest_id)` helper (beat summary for current progress, else
      description) — the data-driven text the tracker shows.
- [x] Confirmed the existing data already matches the schedule intent: auntie `[1,3,5]`, artisan
      `[2,4,5]` gated on `auntie`, scavenger/alya `[2,4,5]`. Alya's questline runs as yard/dump NPC
      interactions (`alya_quest_line`), NOT the shop-door route, so it does not consume the door
      slot artisan needs — the "no conflict" requirement is already satisfied.

### DEFERRED (needs your design steer — would break working systems if guessed overnight)
- **Maverick day-5-end 50k last offer**: the current `buyer` route (routes.json) already delivers
  fragment_05, but via a *spiral-mark trust* flow — he visits days 1–4 dropping hints, then a
  `return` visit hands the fragment after you sell him the marked piece. Switching him to
  **day-5-only** and a **50000-peso paid purchase + banter gate** is a real economy redesign: it
  needs the negotiation/haggle depth, a money-sink balance pass, and a new day-5-end hand-off flow,
  and a half-change would break fragment_05 acquisition. Left intact pending your call.
- **Auntie fragment in the safe**: the mechanism already exists (`safe_code_known` +
  `safe` placement container in `spawn_director.gd`), so once auntie's route releases fragment_01
  and the safe code is known, the Spawn Director can seat the carrier in the safe. What's missing is
  the *auntie quest chain* that grants the safe code + releases fragment_01 — authored content.
- **Artisan cleaning-quest content**: the multi-beat "clean his arts" chain + fragment_02 hand-off
  (authored beats/dialogue + restoration tie-in).
- **Tighten artisan gate to auntie *quest 1* specifically** (currently route-level `auntie`
  prerequisite) — needs the auntie quest defined first.
- **Full narrative dialogue rewrite**; **Sam storyline expansion** (user-deferred);
  **fragment_03 (scavenger) vs fragment_04 (archeologist)** ownership split.

## Notes / decisions
- Quest UI is generic + data-driven (reads QuestService active quests + beat summaries) so new
  quests need no UI code.
- Maverick's fragment/price are recorded as data canon; the *mechanic* to earn+spend 50k and the
  day-5 hand-off flow are deferred as above.
