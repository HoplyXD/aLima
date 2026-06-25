class_name RestorationToolTray
extends Node3D
## Presentation-only 3D tool props for the focused restoration view (REST-R8).
##
## The cleaning tools are physical things on the workbench: one selectable
## RestorationTool prop per owned tool, laid out along the front of the bench, each
## with a 2D info panel below it (durability bar + the conditions it can clean).
## Selecting a prop is how the player chooses a tool (the 2D HUD buttons are a
## labelled accessibility/fallback path). The selected prop lifts and highlights.
##
## Carries NO game rules: it never reads is_carrier/contents, never touches
## RestorationService/GameState/SaveService, and never decides whether a tool is
## correct. It is built data-driven from the owned ToolDefinitions the view hands it
## (plus durability values), reading only the data catalog for the condition images.

const TOOL_SCENE := preload("res://scenes/restoration/restoration_tool.tscn")

## Resting layout (object space, on the bench top in front of the object).
const BENCH_Y: float = -0.7
const FRONT_Z: float = 0.55
const SLOT_COUNT: int = 8  ## The tool sidebar has eight fixed slots (number keys 1-8).
const SLOT_SPACING: float = 0.62  ## Spacing between the five fixed slot centres.

## Selection pose: the chosen tool lifts off the bench and leans toward the object.
const SELECT_LIFT: float = 0.12
const SELECT_FORWARD: float = 0.08
const SELECT_TILT_DEG: float = -22.0

## Analytic pick radius around each prop (matches the simple development geometry).
const PICK_RADIUS: float = 0.26
const PICK_CENTER_OFFSET: Vector3 = Vector3(0.0, 0.06, 0.0)

var _order: Array[String] = []
var _props: Dictionary = {}  ## tool_id -> RestorationTool
var _rest_pos: Dictionary = {}  ## tool_id -> Vector3
var _selected: String = ""


## Rebuilds the props, packing the given tools into slots 0..n-1 (left to right).
## `durability` maps tool_id -> {current, max} for each bench tool's wear bar.
func build_tools(tools: Array[ToolDefinition], durability: Dictionary = {}) -> void:
	var slots: Array = []
	for tool in tools:
		slots.append(tool.id)
	build_slots(slots, durability)


## Rebuilds the props from a fixed-slot layout: `slots` is up to SLOT_COUNT entries,
## one per bench slot, holding a tool_id or "" for an empty slot. A tool stays pinned
## to its slot index, so a single tool placed in slot 4 renders at the far right with
## the other slots empty. Clears prior props first.
func build_slots(slots: Array, durability: Dictionary = {}) -> void:
	_clear()
	var repo := DataRepository.singleton()
	for slot in mini(slots.size(), SLOT_COUNT):
		var tool_id := String(slots[slot])
		if tool_id.is_empty():
			continue
		var rest := Vector3(_slot_x(slot), BENCH_Y, FRONT_Z)
		var prop: RestorationTool = TOOL_SCENE.instantiate()
		prop.name = "ToolProp_%s" % tool_id
		prop.position = rest
		add_child(prop)
		prop.configure(
			tool_id, durability.get(tool_id, {}), CleaningPower.conditions_for(repo, tool_id)
		)
		_props[tool_id] = prop
		_rest_pos[tool_id] = rest
		_order.append(tool_id)
	if not _props.has(_selected):
		_selected = ""
	_apply_poses()


## World-space x of a fixed bench slot (slot 0 leftmost, SLOT_COUNT-1 rightmost).
func _slot_x(slot: int) -> float:
	return (float(slot) - float(SLOT_COUNT - 1) / 2.0) * SLOT_SPACING


## Pointer-hover feedback: grows the hovered prop (pass "" to clear).
func set_hovered(tool_id: String) -> void:
	for id in _props.keys():
		(_props[id] as RestorationTool).set_hovered(id == tool_id and not tool_id.is_empty())


## Updates the durability bars in place (no rebuild) from {tool_id: {current, max}}.
func update_durability(durability: Dictionary) -> void:
	for tool_id in _props.keys():
		var prop: RestorationTool = _props[tool_id]
		var entry: Dictionary = durability.get(tool_id, {})
		prop.update_durability(int(entry.get("current", 0)), int(entry.get("max", 0)))


## Highlights/poses the selected prop and rests the rest. Pass "" to deselect all.
func set_selected(tool_id: String) -> void:
	_selected = tool_id if _props.has(tool_id) else ""
	_apply_poses()


## Analytic ray->prop test. Returns the hit tool_id, or "" on a miss.
func ray_pick(origin: Vector3, direction: Vector3) -> String:
	var best_id := ""
	var best_t := INF
	for id in _order:
		var prop: Node3D = _props[id]
		var center: Vector3 = prop.global_position + PICK_CENTER_OFFSET
		var hit := _ray_sphere(origin, direction, center, PICK_RADIUS)
		if hit.get("hit", false) and float(hit["t"]) < best_t:
			best_t = float(hit["t"])
			best_id = id
	return best_id


func get_tool_ids() -> Array[String]:
	return _order.duplicate()


func get_prop(tool_id: String) -> Node3D:
	return _props.get(tool_id)


func is_selected(tool_id: String) -> bool:
	return _selected == tool_id and not tool_id.is_empty()


func selected_tool_id() -> String:
	return _selected


# --- Poses / highlight -------------------------------------------------------


func _apply_poses() -> void:
	for id in _props.keys():
		var prop: RestorationTool = _props[id]
		var rest: Vector3 = _rest_pos[id]
		if id == _selected:
			prop.position = rest + Vector3(0.0, SELECT_LIFT, SELECT_FORWARD)
			prop.rotation = Vector3(deg_to_rad(SELECT_TILT_DEG), 0.0, 0.0)
		else:
			prop.position = rest
			prop.rotation = Vector3.ZERO
		prop.set_selected(id == _selected)


func _clear() -> void:
	for child in get_children():
		child.queue_free()
	_order.clear()
	_props.clear()
	_rest_pos.clear()


func _ray_sphere(origin: Vector3, direction: Vector3, center: Vector3, radius: float) -> Dictionary:
	var dir := direction.normalized()
	var oc := origin - center
	var b := oc.dot(dir)
	var c := oc.dot(oc) - radius * radius
	var disc := b * b - c
	if disc < 0.0:
		return {"hit": false}
	var sqrt_disc := sqrt(disc)
	var t := -b - sqrt_disc
	if t < 0.0:
		t = -b + sqrt_disc
		if t < 0.0:
			return {"hit": false}
	return {"hit": true, "t": t}
