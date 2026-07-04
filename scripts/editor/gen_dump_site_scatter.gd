@tool
extends SceneTree
## One-shot generator: pulls the individual PROP meshes out of scrapyard.glb
## (heaps, crates, drums, tires, spools...) and bakes scattered copies of them as
## REAL editable MeshInstance3D nodes directly under the ScrapyardAssets node of
## scenes/locations/dump_site/dump_site_map.tscn. Heaps are weighted heavily.
##
## Run headless:
##   godot --headless --path . --script scripts/editor/gen_dump_site_scatter.gd
##
## Structural pieces (walls, floor, house, gate, scale, sign) are skipped. The
## rest of the dump-site map (ground, walls, gate, Alya's house, trees) is left
## untouched — only ScrapyardAssets is repopulated. Re-run any time to reshuffle;
## the layout is seeded, and every prop is a normal node you can nudge in-editor.

const GLB_PATH := "res://assets/3d Assets/Scrapyard/scrapyard.glb"
const MAP_PATH := "res://scenes/locations/dump_site/dump_site_map.tscn"

## Names containing any of these are structural and NOT scattered as loose junk.
const EXCLUDE := [
	"wall", "floor", "ground", "house", "roof", "ceiling", "door", "gate",
	"fence", "scale", "dial", "post", "platform", "sign", "spawn", "anchor",
	"shop", "lean", "window", "chimney", "awning", "counter", "beam", "column",
]
## Heap-like props are placed much more often (the dump site should be buried in them).
const HEAP_KEYWORDS := ["heap", "pile", "mound", "junk", "trash", "debris", "scrap"]

## Dump-site play area (matches dump_site_map walls at ~±40 x, ~±34 z).
const AREA_X := 37.0
const AREA_Z := 31.0
const SCATTER_COUNT := 120
const HEAP_BIAS := 0.7  ## Fraction of scattered props that are heap-like.


func _init() -> void:
	var packed_glb := load(GLB_PATH) as PackedScene
	var packed_map := load(MAP_PATH) as PackedScene
	if packed_glb == null or packed_map == null:
		push_error("gen_dump_site_scatter: cannot load glb or map")
		quit(1)
		return
	var src := packed_glb.instantiate()

	# Split prop meshes into heap-like and other, dedup by mesh.
	var heaps: Array = []
	var others: Array = []
	var seen := {}
	_collect_props(src, heaps, others, seen)
	if heaps.is_empty() and others.is_empty():
		push_error("gen_dump_site_scatter: no prop meshes found")
		quit(1)
		return
	print("gen_dump_site_scatter: %d heap meshes, %d other meshes" % [heaps.size(), others.size()])

	var map := packed_map.instantiate()

	# Fresh ScrapyardAssets holder (drop whatever was there before).
	var old := map.get_node_or_null("ScrapyardAssets")
	if old != null:
		map.remove_child(old)
		old.queue_free()
	var holder := Node3D.new()
	holder.name = "ScrapyardAssets"
	map.add_child(holder)
	holder.owner = map

	var rng := RandomNumberGenerator.new()
	rng.seed = 20260713
	var placed: Array[Vector2] = []
	for i in SCATTER_COUNT:
		var use_heap := (not heaps.is_empty()) and (others.is_empty() or rng.randf() < HEAP_BIAS)
		var pool: Array = heaps if use_heap else others
		var entry: Dictionary = pool[rng.randi() % pool.size()]
		var mi := MeshInstance3D.new()
		mi.mesh = entry["mesh"]
		if entry.get("material") != null:
			mi.material_override = entry["material"]
		mi.name = "%s_%d" % [str(entry["name"]), i]
		var pos := _pick_spot(rng, placed)
		placed.append(Vector2(pos.x, pos.z))
		mi.position = pos
		mi.rotation.y = rng.randf_range(0.0, TAU)
		var s := rng.randf_range(0.8, 1.3)
		mi.scale = Vector3(s, s, s)
		holder.add_child(mi)
		mi.owner = map

	var out := PackedScene.new()
	out.pack(map)
	var err := ResourceSaver.save(out, MAP_PATH)
	if err != OK:
		push_error("gen_dump_site_scatter: save failed (%d)" % err)
		quit(1)
		return
	print("gen_dump_site_scatter: baked %d props into %s" % [SCATTER_COUNT, MAP_PATH])
	quit(0)


## Gathers unique prop meshes into heaps[] / others[] (skipping structural names).
func _collect_props(node: Node, heaps: Array, others: Array, seen: Dictionary) -> void:
	if node is MeshInstance3D:
		var mi := node as MeshInstance3D
		var lname := node.name.to_lower()
		var structural := false
		for kw in EXCLUDE:
			if lname.contains(kw):
				structural = true
				break
		if not structural and mi.mesh != null:
			var key := (
				mi.mesh.resource_path
				if not mi.mesh.resource_path.is_empty()
				else str(mi.mesh.get_instance_id())
			)
			if not seen.has(key):
				seen[key] = true
				var entry := {
					"mesh": mi.mesh,
					"material": mi.get_surface_override_material(0),
					"name": node.name,
				}
				var is_heap := false
				for hk in HEAP_KEYWORDS:
					if lname.contains(hk):
						is_heap = true
						break
				if is_heap:
					heaps.append(entry)
				else:
					others.append(entry)
	for child in node.get_children():
		_collect_props(child, heaps, others, seen)


## A scattered ground spot spaced from other props, leaving a rough central
## corridor open near the gate so the player can walk in.
func _pick_spot(rng: RandomNumberGenerator, placed: Array[Vector2]) -> Vector3:
	for _attempt in 14:
		var x := rng.randf_range(-AREA_X, AREA_X)
		var z := rng.randf_range(-AREA_Z, AREA_Z)
		if absf(x) < 3.5 and z > 6.0:
			continue
		var candidate := Vector2(x, z)
		var too_close := false
		for other in placed:
			if candidate.distance_to(other) < 2.6:
				too_close = true
				break
		if not too_close:
			return Vector3(x, 0.0, z)
	return Vector3(rng.randf_range(-AREA_X, AREA_X), 0.0, rng.randf_range(-AREA_Z, AREA_Z))
