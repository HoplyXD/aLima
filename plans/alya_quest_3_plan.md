# Alya Quest 3 + Next Loop Persistence Implementation Plan

## Stage 1: Data & Route Files
1. Add `fragment_b` to `data/artifacts/fragments.json` (or create dynamically)
2. Create `data/routes/sam.json` — Sam's route definition
3. Add Q3 dialogue to `data/routes/routes.json` (scavenger route)
4. Add archeologist house to `data/travel/destinations.json`

## Stage 2: Core Systems
5. Modify `scripts/core/space_manager.gd` — add ARCHEOLOGIST_HOUSE space
6. Modify `scripts/economy/marketplace_service.gd` — quest item buyer priority
7. Modify `scripts/core/route_service.gd` — add Sam to visit priority if needed

## Stage 3: Location & Quest Logic
8. Modify `scripts/scrapyard/dump_site.gd` — Q3 Day 5 trigger, forbidden zone, salakot spawn
9. Modify `scripts/scrapyard/scrapyard.gd` — next-loop welcome dialogue, Q3 helpers
10. Modify `scripts/shop/shop_controller.gd` — Sam priority door visitor

## Stage 4: Archeologist House
11. Create `scripts/archeologist_house/archeologist_house_controller.gd`
12. Create `scenes/locations/archeologist_house/archeologist_house.tscn`

## Stage 5: Verification
13. Check all files compile correctly
14. Verify quest flow logic
