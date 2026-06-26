# Scrapyard Scene — Blender → Godot GLB Swap Guide

This scene is the walkable outdoor scrapyard introduced in Phase RV2-A. It is
intentionally built as a **shell** so that a final Blender-made map can drop in
with minimal friction.

## Scene Structure

`scenes/scrapyard/Scrapyard.tscn` is organised into three independent layers:

1. **MapRoot** — swappable visual geometry only. While `map_scene` is empty the
   placeholder ground, fence, scrap heaps, and delivery-bay shell live here.
   When a final `.glb` is assigned, the placeholder children are removed and the
   imported scene is instanced under this node.
2. **Collision** — Godot-side StaticBody3D floor + perimeter walls. This is kept
   separate from MapRoot so an art swap never removes gameplay collision.
3. **Anchors** — permanent Marker3D / Area3D nodes that MUST survive any art
   swap:
   - `PlayerSpawn` — where the player appears on yard entry.
   - `DoorReturn` — `Interactable3D` that returns to the shop.
   - `AylaAnchor` — Ayla's persistent scrapyard position (used in RV2-B).
   - `DeliveryBay` — drop-off point for sorted deliveries (used in RV2-B).
   - `Bounds` — placeholder yard-bounds marker for future zoning.

## One-Step Swap

1. Export the final map from Blender as **glTF 2.0 binary (`.glb`)**.
2. Copy the `.glb` into the project (e.g. `assets/3d Assets/Scrapyard/`).
   Godot imports it automatically; `import/blender/enabled=false` in
   `project.godot` means `.blend` files are NOT imported, so the pipeline is
   strictly Blender → export GLB → Godot imports GLB.
3. Select the root `Scrapyard` node in the editor.
4. Drag the imported `.glb` scene into the `Map Scene` export slot
   (`@export var map_scene: PackedScene`).
5. Run the game. `_ready()` in `scripts/scrapyard/scrapyard.gd` frees the
   placeholder MapRoot children and instances the imported map in their place.
   Anchors and Collision remain untouched.

If the imported map contains its own collision, either:

- remove the Godot `Collision` node and rely on `-col` / `-colonly` / `-convcol`
  meshes in the GLB (see suffix convention below), or
- keep the Godot collision and do not include collision meshes in the GLB.

Do not do both — duplicated collision walls will catch the player.

## Blender Export Conventions

Use these settings so the imported map aligns with the existing anchors and
player controller:

- **Format:** glTF 2.0 (`.glb`).
- **Scale:** 1 Blender unit = 1 Godot meter.
- **Up axis:** +Y up.
- **Transforms:** Apply all transforms before export.
- **Origin:** Place the scene origin at the shop-door threshold where the player
  steps out. The `PlayerSpawn` marker is at `(0, 0.9, 10)` in Godot space, so the
  map should be authored so that walking forward from the door reaches the yard.
- **Collision suffixes:** Godot recognises these mesh-name suffixes on imported
  GLB meshes and auto-generates collision shapes:
  - `-col` — static trimesh collision.
  - `-colonly` — collision only, no visible mesh.
  - `-convcol` — simplified convex collision.

If you use these suffixes, remove the placeholder `Collision` node from the
scene. If you prefer authoring collision in Godot, leave the suffixes off the
GLB meshes and keep the `Collision` node.

## Performance Notes

- The placeholder geometry is intentionally cheap primitive meshes so the shell
  holds the Mobile renderer + web target (PLAT-R4).
- The final map should stay compact and zoned; the yard is loaded only while the
  player is outside.
- Keep the final draw-call count and material count low for the 1280x720 web
  reference target.

## Out of Scope for RV2-A

Foraging, scrap pickup, Ayla delivery logic, Cultural Echoes in the yard, and
Ayla-delivery hand-offs are intentionally NOT implemented in this phase. They
are tracked in Phase RV2-B and later.
