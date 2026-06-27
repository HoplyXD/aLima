class_name ScrapItem
extends Interactable3D
## A rarity-tiered scrap pickup in the walkable scrapyard.
##
## Uses a first-person raycast-E pickup: look at the scrap and press E (or
## gamepad A) to pick it up. This works even when the scrap is sitting on or
## partly inside a heap of trash. The pickup increments the loop-scoped scrap
## pool and despawns the item.
##
## Visual: a random junk-heap mesh from scrap_kit.glb plus a grown inverted-hull
## shell child (cull-front, unshaded, emissive) that draws the rarity-coloured
## glow OUTLINE around the silhouette. The rarity tint lives only on the outline,
## so the same heap mesh serves every tier. Falls back to the placeholder sphere
## if the kit is not imported yet.

signal collected(rarity: String)

const RARITY_COLORS := {
	"white": Color(0.85, 0.85, 0.85),
	"green": Color(0.36, 0.77, 0.42),
	"blue": Color(0.30, 0.55, 1.0),
	"purple": Color(0.69, 0.40, 1.0),
	"gold": Color(1.0, 0.72, 0.17),
}

const SCRAP_KIT_PATH := "res://assets/3d Assets/Scrapyard/scrap_kit.glb"
const OUTLINE_GROW := 0.07
const OUTLINE_EMISSION_ENERGY := 4.5

## Heap meshes are cached across all scrap items so the kit GLB is only
## instantiated once per run.
static var _heap_meshes: Array[Mesh] = []

@export var rarity: String = "white"

var _outline: MeshInstance3D


func _ready() -> void:
	# Raycast-driven activation from the yard player controller; proximity is
	# disabled so overlapping trash heaps don't block the interaction.
	use_proximity = false
	proximity_prompt_text = "Press E to grab scrap"
	prompt_text = "Grab scrap"
	super._ready()
	activated.connect(_on_activated)
	_setup_visual()
	_apply_rarity_visual()


func set_rarity(value: String) -> void:
	rarity = value.to_lower()
	_apply_rarity_visual()


func _on_activated() -> void:
	var pool: Dictionary = GameState.save_state.loop.scrap_pool
	pool[rarity] = int(pool.get(rarity, 0)) + 1
	collected.emit(rarity)
	queue_free()


## Swaps the placeholder sphere for a random heap mesh and builds the outline
## shell. Leaves the placeholder in place if the kit is unavailable.
func _setup_visual() -> void:
	var mesh := get_node_or_null("Mesh") as MeshInstance3D
	if mesh == null:
		return
	var heap := _pick_heap_mesh()
	if heap != null:
		mesh.mesh = heap
		mesh.rotation.y = randf() * TAU
	_outline = MeshInstance3D.new()
	_outline.name = "Outline"
	_outline.mesh = mesh.mesh
	# The shell is a child of the mesh so it inherits the random yaw exactly.
	mesh.add_child(_outline)


func _pick_heap_mesh() -> Mesh:
	if _heap_meshes.is_empty():
		var packed := load(SCRAP_KIT_PATH) as PackedScene
		if packed == null:
			return null
		var inst := packed.instantiate()
		_collect_meshes(inst, _heap_meshes)
		inst.free()
	if _heap_meshes.is_empty():
		return null
	return _heap_meshes[randi() % _heap_meshes.size()]


static func _collect_meshes(node: Node, out: Array[Mesh]) -> void:
	var mi := node as MeshInstance3D
	if mi != null and mi.mesh != null:
		out.append(mi.mesh)
	for child in node.get_children():
		_collect_meshes(child, out)


## Builds the rarity-coloured inverted-hull outline material. Grown along normals
## with front-face culling, it renders as a shell behind the real mesh; the real
## mesh occludes the centre so only the glowing rim shows. Emission energy is high
## so it crosses the WorldEnvironment glow threshold and blooms.
func _apply_rarity_visual() -> void:
	if _outline == null:
		return
	var color: Color = RARITY_COLORS.get(rarity, RARITY_COLORS["white"])
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = OUTLINE_EMISSION_ENERGY
	mat.grow = true
	mat.grow_amount = OUTLINE_GROW
	mat.cull_mode = BaseMaterial3D.CULL_FRONT
	_outline.material_override = mat
