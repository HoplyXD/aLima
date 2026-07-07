class_name FragmentFind
extends Interactable3D

## The hidden-fragment hunt payoff: a half-buried glint at the planned hiding
## spot. Picking it up IS the discovery — the owning scene reports it and the
## existing Found -> Portal -> seat chain takes over (team decision 2026-07-07;
## the pickup path has no carrier nesting or clean->open step).
##
## Presentation honors DISC-R10: the glint's flicker only becomes visible once
## Cultural Echo proximity reaches the reveal threshold, so audio leads and the
## glow confirms. `always_reveal` is for the seated shop, which has no
## proximity hunt.

signal found(fragment_id: String)

const OUTLINE_GROW := 0.07
const OUTLINE_EMISSION_ENERGY := 5.0
const FLICKER_COLOR := Color("#ffd75e")
const REVEAL_AT := 0.60

## Reveal the flicker regardless of echo proximity (seated shop spots).
var always_reveal: bool = false

var fragment_id: String = ""
var _outline: MeshInstance3D
var _outline_material: StandardMaterial3D
var _flicker_time: float = 0.0


func _ready() -> void:
	use_proximity = false
	prompt_text = "Dig out the buried piece"
	proximity_prompt_text = "Press E to dig out the buried piece"
	super._ready()
	activated.connect(_on_activated)
	_setup_visual()


func set_fragment_id(id: String) -> void:
	fragment_id = id


func _process(delta: float) -> void:
	if _outline == null:
		return
	var revealed := always_reveal or _echo_proximity() >= REVEAL_AT
	_outline.visible = revealed
	if not revealed:
		return
	# Irregular shimmer so the reveal reads as the "flickering" glow state.
	_flicker_time += delta
	var pulse := 0.55 + 0.45 * sin(_flicker_time * 9.0) * sin(_flicker_time * 2.3)
	_outline_material.emission_energy_multiplier = OUTLINE_EMISSION_ENERGY * maxf(pulse, 0.15)


func _echo_proximity() -> float:
	var state: Dictionary = EchoController.get_state()
	if not state.get("valid", false):
		return 0.0
	if state.get("fragment_id", "") != fragment_id:
		return 0.0
	return float(state.get("proximity", 0.0))


func _on_activated() -> void:
	if fragment_id.is_empty():
		return
	found.emit(fragment_id)
	queue_free()


func _setup_visual() -> void:
	var mesh := get_node_or_null("Mesh") as MeshInstance3D
	if mesh == null:
		return
	_outline = MeshInstance3D.new()
	_outline.name = "Outline"
	_outline.mesh = mesh.mesh
	_outline.visible = false
	mesh.add_child(_outline)
	_outline_material = StandardMaterial3D.new()
	_outline_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_outline_material.albedo_color = FLICKER_COLOR
	_outline_material.emission_enabled = true
	_outline_material.emission = FLICKER_COLOR
	_outline_material.emission_energy_multiplier = OUTLINE_EMISSION_ENERGY
	_outline_material.grow = true
	_outline_material.grow_amount = OUTLINE_GROW
	_outline_material.cull_mode = BaseMaterial3D.CULL_FRONT
	_outline.material_override = _outline_material
