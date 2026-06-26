class_name ScrapItem
extends Interactable3D
## A rarity-tiered scrap pickup in the walkable scrapyard.
##
## Uses the shared Interactable3D proximity-E path: stand near it and press E
## (or gamepad A) to pick it up. The pickup increments the loop-scoped scrap
## pool and despawns the item. Visuals are simple colored placeholder geometry so
## a future Blender map swap does not depend on these nodes.

signal collected(rarity: String)

const RARITY_COLORS := {
	"white": Color(0.85, 0.85, 0.85),
	"green": Color(0.36, 0.77, 0.42),
	"blue": Color(0.30, 0.55, 1.0),
	"purple": Color(0.69, 0.40, 1.0),
	"gold": Color(1.0, 0.72, 0.17),
}

@export var rarity: String = "white"


func _ready() -> void:
	# Enable the unified proximity-E interaction before Interactable3D wires it.
	use_proximity = true
	proximity_prompt_text = "Press E to grab scrap"
	prompt_text = "Grab scrap"
	super._ready()
	activated.connect(_on_activated)
	_apply_rarity_visual()


func set_rarity(value: String) -> void:
	rarity = value.to_lower()
	_apply_rarity_visual()


func _on_activated() -> void:
	var pool: Dictionary = GameState.save_state.loop.scrap_pool
	pool[rarity] = int(pool.get(rarity, 0)) + 1
	collected.emit(rarity)
	queue_free()


func _apply_rarity_visual() -> void:
	var mesh := get_node_or_null("Mesh") as MeshInstance3D
	if mesh == null:
		return
	var color: Color = RARITY_COLORS.get(rarity, RARITY_COLORS["white"])
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy = 0.3
	mesh.material_override = mat
