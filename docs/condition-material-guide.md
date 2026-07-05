# Condition ↔ Material Guide

Which surface conditions logically belong on which artifact material, and which tool
treats each one. **This is the authoring reference for placing `ArtifactOverlay` nodes**
(and the rulebook `scripts/editor/gen_condition_overlays.gd` enforces — keep the two in
sync). Two-stage chains are marked `A → B`: cleaning A morphs the mark into B, which
needs its own tool.

## The full condition catalog

| Condition | Tool | Materials it belongs on | Chain |
|---|---|---|---|
| Dust | Soft Brush / Damp Cloth | **everything** | — |
| Grime (`dirt`) | Damp Cloth | **everything** | — |
| Mud | Bar of Soap (mall) | **everything** (buried/flood finds) | **Mud → Grime** |
| Soot | Bar of Soap (mall) | everything (fire/kitchen pieces) | — |
| Salt Crust | Damp Cloth | everything (coastal finds — very aLima) | — |
| Wax | Wax Scraper (mall) | everything (candle-lit households) | — |
| Tape Residue | Solvent | everything (old "repairs") | — |
| Grease | Bar of Soap (mall) | **metals + wood** (machines, kitchens) | **Grease → Tarnish** |
| Mold | Mold Remover (online) | **organics**: wood, fabric, paper, leather, bamboo, rattan | **Mold → Water Stain** |
| Moss | Mold Remover (online) | wood, stone, ceramic, clay, bamboo, rattan (left outdoors) | — |
| Old Paint | Solvent | wood, metals, ceramic (painted-over pieces) | — |
| Dark Varnish | Solvent | **wood only** (aged shellac) | — |
| Wood Rot | Consolidant | **wood only** | — |
| Woodworm | Consolidant | **wood only** | — |
| Cracking | Consolidant | wood, ceramic, glaze, frames (authored by hand — never randomised) | — |
| Water Stain | Stain Lifter | paper, photos, fabric, light wood | — |
| Fading | Photo Restoration Kit | photos/paper only | — |
| Rust | Wire Brush | **iron / tin / steel only** — brass, bronze, silver, gold DO NOT rust | — |
| Tarnish | Polishing Cloth | silver, brass, bronze, copper | — |
| Black Tarnish | Polishing Cloth | silver (heavy sulfide), brass | **Black Tarnish → Tarnish** |
| Verdigris | Metal Polish Paste (mall) | bronze, copper, brass (the green patina) | — |

## Cheat-sheet by material

**WOOD (and bamboo/rattan)** — your biggest set:
dust, grime, mud, soot, salt crust, wax, tape residue, **grease**, **mold**, **moss**,
**old paint**, **dark varnish**, **wood rot**, **woodworm**, cracking. That's 15 —
wood takes almost everything *except* the metal corrosion family.

**GOLD** — gold never corrodes (that's why the Oton mask survived 600 years!):
only the generic soils — dust, grime, mud, soot, salt crust, wax, grease, tape residue.
A gold piece under crud that polishes back to perfect = great "reveal" moment.

**SILVER** — dust, grime, generic soils + **tarnish**, **black tarnish → tarnish**
(the signature silver chain: near-black sulfide buffs down to ordinary tarnish, then off).

**BRASS** — generic soils + tarnish, black tarnish, verdigris (brass is a copper alloy).

**BRONZE / COPPER** — generic soils + tarnish, **verdigris** (the classic green patina).

**IRON / TIN / STEEL** — generic soils + **rust** (the ONLY rusting metals), old paint.

**CERAMIC / CLAY / STONE** — generic soils + moss, old paint, cracking (authored).
No corrosion, no rot.

**FABRIC / PAPER / PHOTOS** — dust, grime, mold, water stain, fading, tape residue.
(Photo pieces run the blemish/photo-kit flow, not overlays.)

## Rules the generator enforces

1. **Material fit** — a condition only lands on artifacts whose template `materials`
   (objects.json) or known scene material matches the table above.
2. **White-tier safety** — rust/tarnish/black-tarnish/verdigris never land on WHITE
   (common) artifacts, so early pieces stay cleanable with starter tools.
3. **Hand-authored wins** — a condition already on the scene (your overlays, any
   `condition_id` you set) is never duplicated or touched; re-running only replaces
   the generator's own blocks.

## Placeholder art status

New condition PNGs currently reuse existing art (`Black Tarnish.png` ← Tarnish,
`Wood Rot.png` ← Cracking, `Woodworm.png` ← Grime, `Moss.png` ← Mold,
`Old Paint.png` ← Tape Residue, `Dark Varnish.png` ← Water Stain, plus the earlier
Mud/Soot/Grease/Mold/Wax/Verdigris/Salt Crust set). Replace in
`assets/artifact_conditions/` keeping the exact file names — the file name IS the
condition type.
