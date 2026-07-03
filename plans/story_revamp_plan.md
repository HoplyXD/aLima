# Story Revamp Plan — Alya Quests, Dump Site, Orange Rarity, Day 1 Rewrite

## Overview

This plan rewrites the Day 1 flow, adds a 3-beat Alya quest line, introduces a new **Dump Site** location (2x scrapyard), adds an **Orange (Quest)** rarity, and creates the **Sam** archaeologist character. The salakot quest item becomes a branching point: sell it to a random NPC and break the quest, or give it to Sam to advance the story and earn Fragment B.

---

## 1. Orange Quest Rarity (Foundation)

**Goal**: Quest items show as orange in the UI without adding a new enum value (avoids §4-E glow legend change).

**Implementation**:
- Add `is_quest_item: bool` to `ObjectInstance` and `MasterArtifact`
- Add `quest_color: Color = Color(1.0, 0.55, 0.0)` (orange) to `GlowMapper`
- When `is_quest_item == true`, use orange for name/card/overlay regardless of base rarity
- Quest items cannot be sold to normal buyers (they get a special "This looks important…" refusal)
- Quest items persist across loops (saved in `persistent.legacy_items`)

**Files**:
- `scripts/models/object_instance.gd` — add `is_quest_item`
- `scripts/models/master_artifact.gd` — add `is_quest_item`
- `scripts/core/glow_mapper.gd` — add quest orange path
- `scripts/restoration/artifact_card.gd` — check `is_quest_item` for color
- `scripts/economy/buyer_npc.gd` — refuse quest items

---

## 2. Day 1 Rewrite

**Current flow**: Day 0 tutorial ends → black out → Day 1 morning delivery arrives.

**New flow**:
1. Day 0 ends → journal finale → black out
2. **Day 1 starts**: Player wakes up in shop (inner monologue: "Did I… black out?")
3. Player inner monologue about Tito being missing, the shop being empty
4. Player exits house → Alya is at the scrapyard gate
5. Alya introduces herself, explains she's Yuyu's goddaughter, offers to sort scrap into artifacts
6. **No morning delivery** — player must forage scrap and give it to Alya
7. Alya converts scrap → 2 common artifacts for triage (tutorial-style)
8. Time starts running after the first triage is complete

**Files**:
- `data/tutorial/day1_script.json` — NEW: Day 1 dialogue script
- `scripts/tutorial/tutorial_service.gd` — load day1 script
- `scripts/shop/shop_controller.gd` — day 1 entry point
- `scripts/scrapyard/scrapyard.gd` — Alya at gate, handoff flow

---

## 3. Alya Quest 1 — "Yuyu's Glasses"

**Trigger**: After Day 1 triage, talk to Alya at the scrapyard gate.

**Beat**:
1. Alya tells her backstory: father and Yuyu were best friends. After father died, Yuyu took care of her.
2. She mentions Yuyu lost his glasses in the scrapyard — they were a gift from her father.
3. **Quest objective**: Find Yuyu's glasses in the scrapyard (randomly spawned, quest item).
4. Player finds glasses → gives to Alya → she cleans them (cutscene).
5. **Reward**: Unlocks **Dump Site** location. Alya gives directions: "It's where I used to live with my parents."

**Implementation**:
- Add `QuestService` autoload to track active/completed quests
- Spawn quest item via `SpawnDirector` with `is_quest_item = true`
- Quest item: `yuyu_glasses` template (new artifact, low rarity but orange quest marker)
- Add `QuestHint` UI to scrapyard HUD

**Files**:
- `scripts/core/quest_service.gd` — NEW
- `scripts/delivery/spawn_director.gd` — quest item spawn support
- `scripts/scrapyard/scrapyard.gd` — quest item spawn, Alya dialogue
- `data/artifacts/yuyu_glasses.json` — NEW artifact template

---

## 4. Alya Quest 2 — "The Lost Bag"

**Trigger**: Enter Dump Site for the first time.

**Beat**:
1. Dump Site is 2x scrapyard size, more scrap, more clutter.
2. Alya explains this was her home. Her father gave her a cute bag — she lost it here and became a scavenger to find it.
3. **Quest objective**: Find the cute bag in the Dump Site (randomly spawned, quest item).
4. Player finds bag → Alya begs player to clean it.
5. Player cleans bag → reveals it's a small artifact container with a note from her father.
6. **Reward**: Alya gives 1000 pesos. Bag becomes a permanent inventory item (legacy).

**Implementation**:
- Create `DumpSite` scene (inherits from `Scrapyard` with 2x scale)
- Add `cute_bag` template (quest item, container artifact)
- Add `AlyaDumpSiteNPC` — Alya standing at the Dump Site entrance
- Quest persistence: `persistent.quest_progress["alya_q2"] = "completed"`

**Files**:
- `scenes/locations/dump_site/dump_site.tscn` — NEW (inherits scrapyard layout, 2x scale)
- `scripts/scrapyard/dump_site.gd` — NEW (extends scrapyard.gd)
- `data/artifacts/cute_bag.json` — NEW artifact template

---

## 5. Alya Quest 3 — "The Salakot" (Day 5)

**Trigger**: Day 5, visit Dump Site again.

**Beat**:
1. New area in Dump Site: fence is broken ("No Trespassing" sign).
2. Alya: "The fence wasn't broken yesterday…"
3. **Quest objective**: Enter forbidden area, find the **Salakot** (quest item, traditional Filipino hat artifact).
4. Player finds salakot → cleans it → it's a rare/master-class artifact.
5. **First buyer of the day** is always **Sam** (archaeologist).
6. Sam: "That salakot… I recognize it. Yuyu was wearing it when we investigated the master artifact."
7. Sam asks player to meet at her place (Archeologist House).

**At Sam's Place**:
1. Alya shows up: "I remember you! You were with Tito Yuyu before he disappeared!"
2. Sam explains: Yuyu and her investigated the master artifact. They were ambushed in the Dump Site. Yuyu put a piece of the master artifact inside a bag before entering the forbidden zone.
3. Alya remembers: "The bag…!" She shows Fragment B.
4. Sam tells Alya to give it to the player.
5. **Reward**: Player receives **Fragment B** (seated in journal).

**Branching**:
- If player sells salakot to a non-Sam buyer → quest fails, Sam never appears, Fragment B unobtainable this loop
- Next loop: Dump Site and Sam's Place are accessible from Day 1 (persistent unlock)

**Implementation**:
- Add `Sam` character route with priority scheduling (always first on Day 5 if salakot is held)
- Add `ArcheologistHouse` scene (simple interior, Sam standing behind a desk)
- Add `salakot` template (quest item, high value but quest-locked)
- Add `Fragment B` to the fragment system
- Buyer NPC: check if quest item → refuse with special dialogue

**Files**:
- `data/routes/sam.json` — NEW character route
- `scenes/locations/archeologist_house/archeologist_house.tscn` — NEW
- `scripts/economy/buyer_npc.gd` — quest buyer priority logic
- `data/artifacts/salakot.json` — NEW artifact template
- `data/artifacts/fragment_b.json` — NEW fragment template

---

## 6. Next Loop Persistence

**Goal**: After completing Alya Quest 3, the next loop starts with:
- Dump Site accessible from Day 1
- Sam's Place accessible from Day 1
- Sam's quest available from Day 1 (can skip straight to her if desired)
- Alya remembers the player (different intro dialogue)

**Implementation**:
- Add `persistent.unlocked_locations: Array[String]` — list of location IDs
- Add `persistent.completed_quests: Array[String]` — list of completed quest IDs
- SpaceManager checks `unlocked_locations` before transitioning
- Alya dialogue key: "intro_returning" vs "intro_first"

**Files**:
- `scripts/models/save_state.gd` — add `unlocked_locations`, `completed_quests`
- `scripts/core/space_manager.gd` — check unlocked locations
- `scripts/scrapyard/scrapyard.gd` — Alya returning player dialogue

---

## 7. Dump Site Location (2x Scrapyard)

**Layout**: Inherits from scrapyard but:
- 2x scale on all dimensions
- 2x scrap spawn count
- No triage table (Alya handles triage at the gate)
- No journal (journal stays in shop)
- Tricycle can travel to/from Dump Site (unlocked after Quest 1)
- Forbidden zone area (fenced, locked until Day 5 Quest 3)

**Files**:
- `scenes/locations/dump_site/dump_site.tscn` — NEW
- `scripts/scrapyard/dump_site.gd` — NEW (extends scrapyard.gd)
- `scenes/locations/dump_site/dump_site_map.tscn` — NEW (or reuse ScrapyardMap.tscn scaled)

---

## 8. Order of Implementation

1. **Orange quest rarity** — Foundation for all quest items
2. **QuestService** — Track active/completed quests
3. **SaveState extensions** — `unlocked_locations`, `completed_quests`, `quest_progress`
4. **Day 1 rewrite** — New script, no morning delivery
5. **Alya Quest 1** — Yuyu's glasses, unlock Dump Site
6. **Dump Site location** — 2x scrapyard scene
7. **Alya Quest 2** — Cute bag, 1000 pesos
8. **Alya Quest 3** — Day 5 salakot, Sam, Fragment B
9. **Sam/Archeologist House** — New character, new location
10. **Next loop persistence** — Carry unlocks across loops

---

## 9. New Files Summary

### Scenes
- `scenes/locations/dump_site/dump_site.tscn`
- `scenes/locations/dump_site/dump_site_map.tscn`
- `scenes/locations/archeologist_house/archeologist_house.tscn`
- `scenes/locations/archeologist_house/sam_npc.tscn`

### Scripts
- `scripts/core/quest_service.gd`
- `scripts/scrapyard/dump_site.gd`
- `scripts/archeologist_house/archeologist_house_controller.gd`
- `scripts/economy/quest_buyer.gd` (Sam's special buyer logic)

### Data
- `data/artifacts/yuyu_glasses.json`
- `data/artifacts/cute_bag.json`
- `data/artifacts/salakot.json`
- `data/artifacts/fragment_b.json`
- `data/routes/sam.json`
- `data/tutorial/day1_script.json`
- `data/quests/alya_quest_line.json`

### Tests
- `tests/quest/test_quest_service.gd`
- `tests/dump_site/test_dump_site.gd`
