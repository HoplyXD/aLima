# Game Revamp — Conditions/Tools, Storage Shelf, Mall Shop, Time-of-Day Sun

User request 2026-07-04. Status of each ask:

## A. More conditions + tools + two-stage chains — DONE
- 7 new surface conditions in `data/journal/surface_conditions.json`:
  mud, soot, grease, mold, wax, verdigris, salt_crust.
- New data field `reveals_condition` (SurfaceCondition model + repo cross-validation):
  fully cleaning the condition MORPHS it into the revealed one instead of removing it.
  Chains authored now: **mud → dirt** (soap, then damp cloth — the user's example),
  **grease → tarnish**, **mold → water_stain**.
- 4 new tools in `data/objects/tools.json`: soap_bar (mall), mold_remover (online),
  wax_scraper (mall), metal_polish (mall). New `shop: online|mall` field on tools.
- Engine — BOTH condition systems support the chain:
  * **Overlays (the LIVE system)**: `ArtifactOverlay.transform_to_condition()` — on full
    clean, `clean_overlays_with_tool` morphs the overlay into the revealed condition
    (new texture + tool) and re-dirties the SPAWN pattern, so the revealed layer sits
    exactly where the outer one was. View caption announces the reveal.
  * Decals (hidden legacy layer, still the logic for some event artifacts):
    `ArtifactConditionDecal.transform_to()` + `apply_authored_clean()` morph path.
- **Placeholder PNGs** (copies, teammate replaces): Mud, Soot, Grease, Mold, Wax,
  Verdigris, "Salt Crust" in `assets/artifact_conditions/`. File name = condition type.
- Tests: `tests/restoration/test_condition_stages.gd` (11 green).

## B. Sun follows time + Day 0 scripted phases — DONE
- New `scripts/core/sun_controller.gd` (SunController.attach): hour → sun arc
  (elevation/yaw/color/energy). Attached in code to Shop + Mall lights.
- Scrapyard/DumpSite keep their richer smooth sun+sky driver (`_update_sun`), now
  Day 0-aware via the shared `SunController.DAY0_PHASES` table.
- Day 0 phases: sunrise (intro→restore_artifact), noon (scan→deliver_to_buyer),
  sunset (return_to_shop→journal_finale).
- Already true before this pass: on the Day 0 return the shop is empty (steps have
  npcs: []) and the journal prop only appears at journal_finale (task #18 gate).
- Tests: `tests/core/test_sun_controller.gd`.

## C. Storage artifacts shelf — DONE
- Artifacts tab is now an 8-column shelf (`ARTIFACT_GRID_COLUMNS`) padded to whole
  rows with visible empty boxes (min 16 slots).
- `ArtifactSlot` (Button, tool-chip-style drag): drag any artifact box onto another
  box (or an empty box) to reorder; `_reorder_artifact` rewrites loop.inventory so
  the restoration view's artifact bar follows the same order. Quest items keep
  their inventory positions.
- Tests appended to `tests/economy/test_storage_screen.gd`.

## D. Mall tool shop + carry hotbar — DONE
- `MarketplaceService.get_mall_catalog()` / `buy_in_person()` (instant grant, no
  shipment); phone `get_catalog()` now lists ONLY online tools and `buy()` refuses
  mall-only stock.
- New `scripts/mall/mall_tool_shop.gd` (MallToolShop screen, built in code) + a
  ToolShopDoor proximity interactable spawned by mall_controller beside the
  storefront (TOOL_SHOP_DOOR position const — nudge in code if it feels off).
- Tools bought in person appear in the mall's 5-slot carry hotbar for the trip home.

## Notes / follow-ups for the team
- Teammate: replace the placeholder condition PNGs listed above (same file names).
- New conditions only appear on artifacts where a dev PLACES their decals (the
  randomiser picks among authored decals), so no soft-locks — but remember common
  (white) artifacts should stay cleanable with starter tools (rust/tarnish commons
  are already banned from the delivery pool; consider the same for new hard chains).
- Salt crust intentionally uses the starter damp_cloth (variety without a new tool).
- The tool sidebar + journal Condition Guide pick the new data up automatically.
