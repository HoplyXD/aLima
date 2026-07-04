# Dump Site Location

The Dump Site is where Alya used to live with her parents before it became a junkyard. It is a larger, more cluttered version of the scrapyard.

## Files

- `dump_site.tscn` — Main scene file
- `dump_site_map.tscn` — 3D environment (instances and scales the ScrapyardMap 2x)
- `dump_site.gd` — Controller script (extends `scrapyard.gd`)

## Key Features

- **2x scale** on all axes compared to the scrapyard
- **2x scrap spawn count** with wider scatter bounds
- **No triage table** — Alya handles triage directly
- **No journal** — journal stays in the shop; the HUD journal button is hidden
- **Tricycle access** — can ride to/from the Dump Site once unlocked via TravelService
- **Forbidden zone** — a fenced-off section with a "No Trespassing" sign, locked until Day 5 (Alya Quest 3)
- **Alya at the entrance** — different dialogue from the scrapyard Alya

## Scene Structure

- `MapRoot` — contains the scaled-up DumpSiteMap instance
- `Collision` — StaticBody3D with 2x scaled walls + ForbiddenZoneBlock collision
- `Anchors` — gameplay points:
  - `PlayerSpawn` at the entrance gate
  - `DoorReturn` to return to the shop
  - `Tricycle` for travel
  - `StorageCrate` for outdoor storage
  - `AylaAnchor` at the entrance (different from scrapyard position)
  - `DeliveryBay` for hand-offs
  - `DestinationPanel` for tricycle travel
- `DirectionalLight3D` + `WorldEnvironment` — same sky/lighting as scrapyard
- `ScrapyardHud` — shared HUD (journal button hidden)

## Forbidden Zone

The forbidden zone is defined by `AABB(Vector3(-20, 0, -30), Vector3(40, 10, 30))`.

- **Visuals**: `IntactFence` (visible when locked) vs `BrokenFence` (visible when unlocked on Day 5)
- **Collision**: `ForbiddenZoneBlock` is disabled when the zone is unlocked
- **Unlock condition**: `QuestService.get_progress("alya_quest_line") == "q3_salakot"` or `"completed"`

## Integration

### SpaceManager
`Space.DUMP_SITE` was added to the `Space` enum with scene path `res://scenes/locations/dump_site/dump_site.tscn`.

### Travel Destinations
A `"dump_site"` destination was added to `data/travel/destinations.json` with `space: "DUMP_SITE"`.

### Save State
`LoopState.dump_site_scrap_remaining` was added to persist dump-site scrap count across visits.

## Quest Integration

Quest items spawn here for:
- Alya Quest 2: cute bag
- Alya Quest 3: salakot

The dialogue system maps yard-specific keys to dump-site-specific keys:
- `yard_sort_ready` → `dump_site_sort_ready`
- `yard_sorting` → `dump_site_sorting`
- `yard_empty` → `dump_site_empty`

Add these keys to the scavenger dialogue route for custom dump-site Ayla lines.
