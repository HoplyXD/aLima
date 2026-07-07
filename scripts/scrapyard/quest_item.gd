class_name QuestItem
extends Interactable3D

## A quest item pickup in the walkable spaces.
##
## Uses the same first-person raycast-E pickup as ScrapItem, but adds an
## ObjectInstance to the loop inventory instead of scrap. Displays an orange
## quest glow outline.

signal collected(template_id: String)

const OUTLINE_GROW := 0.07
const OUTLINE_EMISSION_ENERGY := 4.5
const QUEST_COLOR := Color("#ff7f00")

var template_id: String = ""


func _ready() -> void:
	use_proximity = false
	proximity_prompt_text = "Press E to pick up"
	prompt_text = "Pick up quest item"
	super._ready()
	activated.connect(_on_activated)
	_setup_visual()


func set_template_id(id: String) -> void:
	template_id = id
	var template := DataRepository.singleton().get_template(template_id)
	if template != null:
		prompt_text = "Pick up %s" % template.display_name
		proximity_prompt_text = "Press E to pick up %s" % template.display_name


func _on_activated() -> void:
	var template := DataRepository.singleton().get_template(template_id)
	if template == null:
		return
	var instance := ObjectInstance.new()
	instance.template_id = template_id
	instance.uid = _make_uid()
	instance.condition = 0.0
	instance.state = ModelEnums.ObjState.DIRTY
	instance.is_quest_item = true
	instance.storage_cost = template.storage_cost
	instance.value = int(template.base_value_range.x)
	instance.true_value = int(template.base_value_range.x)
	GameState.save_state.loop.inventory.append(instance.to_dictionary())
	collected.emit(template_id)
	queue_free()


func _make_uid() -> String:
	return "quest_%s_%d_%d_%d" % [template_id, GameState.loop_index, Time.get_unix_time_from_system(), randi()]


func _setup_visual() -> void:
	var mesh := get_node_or_null("Mesh") as MeshInstance3D
	if mesh == null:
		return
	var outline := MeshInstance3D.new()
	outline.name = "Outline"
	outline.mesh = mesh.mesh
	outline.scale = Vector3.ONE * 1.08
	mesh.add_child(outline)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = QUEST_COLOR
	mat.emission_enabled = true
	mat.emission = QUEST_COLOR
	mat.emission_energy_multiplier = OUTLINE_EMISSION_ENERGY
	mat.grow = true
	mat.grow_amount = OUTLINE_GROW
	mat.cull_mode = BaseMaterial3D.CULL_FRONT
	outline.material_override = mat
