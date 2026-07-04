# Condition ↔ Material reference

Which surface **conditions** (the overlay textures in `assets/artifact_conditions/`) belong on which
**material**. Use this when authoring an artifact's overlays: group overlays by the material region they
sit on (e.g. the bell's brass body vs its wood handle), and only add conditions that make physical sense
for that material. Dust + Grime are universal; the rest are material-specific.

## Conditions and where they belong

| Condition (texture) | Belongs on | Notes / clean tool |
|---|---|---|
| **Dust** (`Dust.png`, `Dust(2).png`) | **Everything** | Universal settled dust. Soft cloth / soft brush. |
| **Grime** (`Grime.png`) | **Everything** | Greasy/sticky built-up dirt. Damp cloth. |
| **Tarnish** (`Tarnish.png`) | **Non-ferrous metal** — brass, bronze, copper, **silver**, pewter | Oxidation darkening. Polishing cloth. NOT iron/steel (those rust). |
| **Rust** (`Rust.png`) | **Ferrous metal** — iron, steel, **tin** | Only metals that actually rust. Wire/rust brush. NOT brass/silver. |
| **Cracking** (`Cracking.png`) | **Brittle** — ceramic, porcelain, clay, **wood**, stone, glass, bone/ivory | Age cracks/crazing. Consolidant. NOT metal (metal dents). *(Currently disabled until the damage system — only spawns in damaged areas later.)* |
| **Water Stain** (`Water Stain.png`) | **Porous/absorbent** — wood, paper, ceramic, fabric, stone, shell | Ring/tide marks. Stain lifter. |
| **Fading** (`Fading.png`) | **Light-sensitive** — paper, photo, fabric, painted/printed surfaces | Sun/age fade. Photo kit. |
| **Tape Residue** (`Tape Residue.png`) | **Smooth** — paper, glass, ceramic, metal | Old adhesive/sticker gunk. Solvent. |

## Material → conditions (quick lookup for authoring)

| Material | Conditions to put on it |
|---|---|
| **Brass / bronze / copper / silver** (jewelry, bells, lamps) | Tarnish, Dust, Grime, (Tape Residue) |
| **Iron / steel / tin** | Rust, Dust, Grime, (Tape Residue) |
| **Ceramic / porcelain / clay** | Cracking, Water Stain, Dust, Grime |
| **Wood** | Cracking, Water Stain, Dust, Grime |
| **Glass** | Dust, Grime, Water Stain, Tape Residue |
| **Paper / photo / parchment** | Fading, Water Stain, Tape Residue, Dust |
| **Shell / capiz / bone / ivory** | Water Stain, Dust, Grime |
| **Stone** | Cracking, Water Stain, Dust, Grime |
| **Fabric / textile** | Water Stain, Dust, Grime, Fading |

> Multi-material artifacts (e.g. a brass bell with a wood handle) get **one overlay group per material
> region**, each on its own part-mesh, with that region's conditions. See
> `scenes/restoration/artifacts/Basic Artifacts/brass_hand_bell.tscn` for the worked example.
