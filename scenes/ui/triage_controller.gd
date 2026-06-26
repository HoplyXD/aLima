class_name TriageController
extends CanvasLayer
## Diegetic 3D triage interaction (Phase 3 presentation rework).
##
## Alya's delivered batch is presented as physical 3D models on a table. The player
## grabs each object and drops it into the Keep box (left) or Recycle bin (right).
## Every decision still flows through TriageState.set_decision() and confirming calls
## TriageService.apply_triage() exactly as the old 2D row screen did.
##
## The public surface (signal closed, open(delivery, storage_cap), close(), visible)
## is unchanged so scripts/shop/shop_controller.gd needs no edits.
##
## Accessibility parity (§4P) is preserved through a toggleable "List View" fallback
## that restores the old keyboard/controller-friendly button rows.

signal closed  ## Emitted after triage is confirmed and applied.

const ARTIFACT_OBJECT_SCENE := preload("res://scenes/restoration/restoration_artifact.tscn")
const ArtifactScenes := preload("res://scripts/restoration/artifact_scenes.gd")
const PREVIEW_CARD_SCENE := preload("res://scenes/restoration/preview_3d_card.tscn")

const KEEP_ZONE_NAME := "KeepZone"
const RECYCLE_ZONE_NAME := "RecycleZone"
const ITEM_GROUP := "triage_item"
const ZONE_GROUP := "triage_zone"

const ITEM_COLLISION_LAYER: int = 1 << 6  ## Layer 7 for triage items only.
const ZONE_COLLISION_LAYER: int = 1 << 7  ## Layer 8 for bin trigger zones.
const RAY_LENGTH: float = 100.0
const TABLE_Y: float = 0.0
const DRAG_HEIGHT: float = 0.35
const PILE_RADIUS: float = 0.7
const GRAB_LERP_SPEED: float = 18.0
const RETURN_LERP_SPEED: float = 8.0
const GLOW_EMISSION_ENERGY: float = 1.6

const HELD_SCALE: float = 1.2
const ZONE_HOVER_RADIUS: float = 1.5
const ZONE_MAGNET_RADIUS: float = 1.0
const ZONE_MAGNET_STRENGTH: float = 0.65
const ZONE_RING_BASE_ENERGY: float = 0.25
const ZONE_RING_HOVER_ENERGY: float = 2.5

enum InputMode { MODE_3D, MODE_LIST }

var _state: TriageState
var _service: TriageService
var _restoration: RestorationService
var _rows: Dictionary = {}  ## uid -> Control row (list-view fallback).

## 3D interaction state.
var _held_body: RigidBody3D = null
var _held_uid: String = ""
var _held_offset: Vector3 = Vector3.ZERO
var _held_target: Vector3 = Vector3.ZERO
var _returning_body: RigidBody3D = null
var _return_target: Vector3 = Vector3.ZERO
var _input_mode: int = InputMode.MODE_3D
var _force_fallback: bool = false
var _bodies: Dictionary = {}  ## uid -> RigidBody3D.
var _pending_release: bool = false

var _keep_zone_pos: Vector3 = Vector3.ZERO
var _recycle_zone_pos: Vector3 = Vector3.ZERO
var _keep_ring: MeshInstance3D = null
var _recycle_ring: MeshInstance3D = null

@onready var _viewport_container: SubViewportContainer = $ViewportContainer
@onready var _viewport: SubViewport = $ViewportContainer/SubViewport
@onready var _camera: Camera3D = $ViewportContainer/SubViewport/World/Camera3D
@onready var _keep_zone: Area3D = $ViewportContainer/SubViewport/World/KeepBin/KeepZone
@onready var _recycle_zone: Area3D = $ViewportContainer/SubViewport/World/RecycleBin/RecycleZone
@onready var _pile_spawn: Marker3D = $ViewportContainer/SubViewport/World/PileSpawn

@onready var _hud_layer: CanvasLayer = $HudLayer
@onready var _hud_storage_label: Label = $HudLayer/StorageLabel
@onready var _hud_validation_label: Label = $HudLayer/ValidationLabel
@onready var _hud_confirm_button: Button = $HudLayer/ConfirmButton
@onready var _hud_fallback_button: Button = $HudLayer/FallbackButton

@onready var _fallback_panel: Panel = $HudLayer/FallbackPanel
@onready var _fallback_storage_label: Label = $HudLayer/FallbackPanel/Panel/Margin/VBox/StorageLabel
@onready var _fallback_validation_label: Label = (
	$HudLayer/FallbackPanel/Panel/Margin/VBox/ValidationLabel as Label
)
@onready var _fallback_items_container: VBoxContainer = (
	$HudLayer/FallbackPanel/Panel/Margin/VBox/Scroll/Items as VBoxContainer
)
@onready var _fallback_confirm_button: Button = (
	$HudLayer/FallbackPanel/Panel/Margin/VBox/ConfirmButton as Button
)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_hud_confirm_button.pressed.connect(_on_confirm)
	_fallback_confirm_button.pressed.connect(_on_confirm)
	_hud_fallback_button.pressed.connect(_toggle_fallback_mode)
	if _viewport != null and _viewport.world_3d == null:
		_viewport.world_3d = World3D.new()
	visible = false
	_hud_layer.visible = false
	_set_input_mode(InputMode.MODE_3D)
	_cache_zone_visuals()


func _cache_zone_visuals() -> void:
	_keep_ring = _find_zone_ring(_keep_zone)
	_recycle_ring = _find_zone_ring(_recycle_zone)
	if _keep_zone != null:
		_keep_zone_pos = _keep_zone.global_position
	if _recycle_zone != null:
		_recycle_zone_pos = _recycle_zone.global_position
	_set_ring_energy(_keep_ring, ZONE_RING_BASE_ENERGY)
	_set_ring_energy(_recycle_ring, ZONE_RING_BASE_ENERGY)


func _find_zone_ring(zone: Area3D) -> MeshInstance3D:
	if zone == null:
		return null
	var parent := zone.get_parent()
	if parent == null:
		return null
	return parent.get_node_or_null("Ring") as MeshInstance3D


func _set_ring_energy(ring: MeshInstance3D, energy: float) -> void:
	if ring == null:
		return
	var mat := ring.material_override as StandardMaterial3D
	if mat == null:
		return
	mat.emission_energy_multiplier = energy


func _update_zone_highlights() -> void:
	var keep_dist := _held_target.distance_to(_keep_zone_pos)
	var recycle_dist := _held_target.distance_to(_recycle_zone_pos)
	if minf(keep_dist, recycle_dist) > ZONE_HOVER_RADIUS:
		_set_ring_energy(_keep_ring, ZONE_RING_BASE_ENERGY)
		_set_ring_energy(_recycle_ring, ZONE_RING_BASE_ENERGY)
		return
	if keep_dist < recycle_dist:
		_set_ring_energy(_keep_ring, ZONE_RING_HOVER_ENERGY)
		_set_ring_energy(_recycle_ring, ZONE_RING_BASE_ENERGY)
	else:
		_set_ring_energy(_keep_ring, ZONE_RING_BASE_ENERGY)
		_set_ring_energy(_recycle_ring, ZONE_RING_HOVER_ENERGY)


func _process(delta: float) -> void:
	if not visible:
		return
	if _held_body != null and is_instance_valid(_held_body):
		var target := _held_target + _held_offset
		_held_body.global_position = _held_body.global_position.lerp(
			target, clampf(GRAB_LERP_SPEED * delta, 0.0, 1.0)
		)
		_update_zone_highlights()
	elif _returning_body != null and is_instance_valid(_returning_body):
		_returning_body.global_position = _returning_body.global_position.lerp(
			_return_target, clampf(RETURN_LERP_SPEED * delta, 0.0, 1.0)
		)
		if _returning_body.global_position.distance_to(_return_target) < 0.05:
			_returning_body = null


func _input(event: InputEvent) -> void:
	if not visible or _input_mode != InputMode.MODE_3D:
		return
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_LEFT:
			if mouse_event.pressed:
				_try_pick(mouse_event.position)
			else:
				_release_held()
	elif event is InputEventScreenTouch:
		var touch_event := event as InputEventScreenTouch
		if touch_event.pressed:
			_try_pick(touch_event.position)
		else:
			_release_held()
	elif event is InputEventMouseMotion and _held_body != null:
		_update_held_target(event.position)
	elif event is InputEventScreenDrag and _held_body != null:
		_update_held_target(event.position)


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("back"):
		get_viewport().set_input_as_handled()
		if _state != null and _state.can_complete():
			_on_confirm()
		else:
			_show_validation("Decide every item (keep or recycle) before leaving.")


## Opens the triage interface for the given delivery. Requests clock pause.
func open(delivery: Array[ObjectInstance], storage_cap: int) -> void:
	_state = TriageState.new(delivery, storage_cap)
	_service = TriageService.new(GameState)
	_restoration = RestorationService.new()
	visible = true
	_hud_layer.visible = true
	DayClock.request_pause(DayClock.PAUSE_TRIAGE)
	_clear_world()
	_clear_rows()
	_update_input_mode_from_settings()
	_build_rows()
	_spawn_items()
	_update_ui()
	if _input_mode == InputMode.MODE_LIST and _rows.size() > 0:
		var first_row: Control = _rows.values()[0]
		first_row.grab_focus()
	elif _input_mode == InputMode.MODE_3D:
		_hud_confirm_button.grab_focus()


## Closes the interface and releases pause ownership.
func close() -> void:
	if visible:
		visible = false
		_hud_layer.visible = false
		DayClock.release_pause(DayClock.PAUSE_TRIAGE)
	_clear_world()
	_clear_rows()
	closed.emit()


func _exit_tree() -> void:
	if visible:
		DayClock.release_pause(DayClock.PAUSE_TRIAGE)


func _set_input_mode(mode: int) -> void:
	_input_mode = mode
	_viewport_container.visible = mode == InputMode.MODE_3D
	_fallback_panel.visible = mode == InputMode.MODE_LIST
	_hud_fallback_button.text = (
		"Switch to List View" if mode == InputMode.MODE_3D else "Switch to 3D View"
	)


func _update_input_mode_from_settings() -> void:
	if _force_fallback or not SettingsService.previews_enabled():
		_set_input_mode(InputMode.MODE_LIST)
	else:
		_set_input_mode(InputMode.MODE_3D)


func _toggle_fallback_mode() -> void:
	_force_fallback = not _force_fallback
	_update_input_mode_from_settings()
	_update_ui()
	if _input_mode == InputMode.MODE_LIST and _rows.size() > 0:
		var first_row: Control = _rows.values()[0]
		first_row.grab_focus()


# --- 3D world -----------------------------------------------------------------


func _clear_world() -> void:
	for uid in _bodies.keys():
		var body: RigidBody3D = _bodies[uid]
		if is_instance_valid(body):
			body.queue_free()
	_bodies.clear()
	_held_body = null
	_held_uid = ""
	_returning_body = null


func _spawn_items() -> void:
	if _viewport == null or _pile_spawn == null:
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = _delivery_seed()
	var index := 0
	for inst in _state.instances:
		var body := _create_item_body(inst, rng, index)
		_viewport.add_child(body)
		_bodies[inst.uid] = body
		index += 1


func _delivery_seed() -> int:
	var base := GameState.run_context.run_seed
	var day: int = GameState.save_state.loop.current_day
	var loop_index: int = GameState.loop_index
	return hash("triage_%d_%d_%d" % [base, loop_index, day])


func _create_item_body(inst: ObjectInstance, rng: RandomNumberGenerator, index: int) -> RigidBody3D:
	var body := RigidBody3D.new()
	body.name = "TriageItem_%s" % inst.uid
	body.add_to_group(ITEM_GROUP)
	body.collision_layer = ITEM_COLLISION_LAYER
	body.collision_mask = ITEM_COLLISION_LAYER
	body.freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
	body.gravity_scale = 1.5
	body.mass = 2.0
	body.linear_damp = 2.5
	body.angular_damp = 4.0

	var phys := PhysicsMaterial.new()
	phys.bounce = 0.05
	phys.friction = 0.9
	body.physics_material_override = phys
	body.set_meta("uid", inst.uid)

	var pivot := Node3D.new()
	pivot.name = "ModelPivot"
	body.add_child(pivot)

	var template := DataRepository.singleton().get_template(inst.template_id)
	var obj: RestorationObject3D = (
		ArtifactScenes
		. scene_for(inst.template_id if template != null else "", ARTIFACT_OBJECT_SCENE)
		. instantiate()
	)
	obj.name = "ArtifactModel"
	pivot.add_child(obj)

	if template != null:
		_restoration.present_object(obj, inst, template, inst.uid.hash())
		var color := GlowMapper.get_instance_glow_color(
			template.base_rarity, inst.is_carrier, false
		)
		_apply_rarity_glow(pivot, color)

	var shape := CollisionShape3D.new()
	shape.shape = SphereShape3D.new()
	shape.shape.radius = 0.45
	body.add_child(shape)

	var angle := rng.randf() * TAU
	var radius := sqrt(rng.randf()) * PILE_RADIUS
	var spawn_pos := (
		_pile_spawn.global_position
		+ Vector3(cos(angle) * radius, 0.25 + index * 0.12, sin(angle) * radius)
	)
	body.position = spawn_pos
	body.rotation = Vector3(0.0, rng.randf() * TAU, 0.0)

	return body


func _apply_rarity_glow(root: Node3D, color: Color) -> void:
	var outlined := false
	for child in root.get_children(true):
		if child is MeshInstance3D:
			var mesh := child as MeshInstance3D
			var mat: Material = null
			if mesh.material_override != null:
				mat = mesh.material_override
			elif mesh.mesh != null and mesh.mesh.get_surface_count() > 0:
				mat = mesh.mesh.surface_get_material(0)
			if mat is StandardMaterial3D:
				var outline := (mat as StandardMaterial3D).duplicate() as StandardMaterial3D
				outline.albedo_color = color
				outline.emission_enabled = true
				outline.emission = color
				outline.emission_energy_multiplier = GLOW_EMISSION_ENERGY
				outline.grow_enabled = true
				outline.grow_amount = 0.035
				outline.cull_mode = BaseMaterial3D.CULL_FRONT
				mesh.material_override = outline
				outlined = true
	if outlined:
		return
	# Fallback: authored model has no StandardMaterial3D surface, so add a visible aura sphere.
	var aura := MeshInstance3D.new()
	aura.name = "RarityAura"
	var sphere := SphereMesh.new()
	sphere.radius = 0.55
	sphere.height = 1.1
	aura.mesh = sphere
	var aura_mat := StandardMaterial3D.new()
	aura_mat.albedo_color = color
	aura_mat.albedo_color.a = 0.25
	aura_mat.emission_enabled = true
	aura_mat.emission = color
	aura_mat.emission_energy_multiplier = GLOW_EMISSION_ENERGY
	aura_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	aura_mat.cull_mode = BaseMaterial3D.CULL_FRONT
	aura.material_override = aura_mat
	root.add_child(aura)


func _try_pick(screen_pos: Vector2) -> void:
	var result := _raycast_item(screen_pos)
	if result.is_empty():
		return
	var body := result["collider"] as RigidBody3D
	if body == null or not body.is_in_group(ITEM_GROUP):
		return
	_held_body = body
	_held_uid = body.get_meta("uid", "")
	_held_body.freeze = true
	_held_body.linear_velocity = Vector3.ZERO
	_held_body.angular_velocity = Vector3.ZERO
	var hit_point: Vector3 = result["position"]
	_held_offset = _held_body.global_position - hit_point
	if not body.has_meta("original_scale"):
		body.set_meta("original_scale", body.scale)
	body.scale = body.get_meta("original_scale") * HELD_SCALE
	_update_held_target(screen_pos)
	get_viewport().set_input_as_handled()


func _update_held_target(screen_pos: Vector2) -> void:
	var plane_hit := _raycast_plane(screen_pos, TABLE_Y + DRAG_HEIGHT)
	if plane_hit != Vector3.ZERO:
		_held_target = _apply_zone_magnet(plane_hit)


func _apply_zone_magnet(point: Vector3) -> Vector3:
	var keep_dist := point.distance_to(_keep_zone_pos)
	var recycle_dist := point.distance_to(_recycle_zone_pos)
	if keep_dist < ZONE_MAGNET_RADIUS:
		var t := 1.0 - clampf(keep_dist / ZONE_MAGNET_RADIUS, 0.0, 1.0)
		return point.lerp(_keep_zone_pos + Vector3.UP * DRAG_HEIGHT, t * ZONE_MAGNET_STRENGTH)
	if recycle_dist < ZONE_MAGNET_RADIUS:
		var t := 1.0 - clampf(recycle_dist / ZONE_MAGNET_RADIUS, 0.0, 1.0)
		return point.lerp(_recycle_zone_pos + Vector3.UP * DRAG_HEIGHT, t * ZONE_MAGNET_STRENGTH)
	return point


func _release_held() -> void:
	if _held_body == null or not is_instance_valid(_held_body):
		_held_body = null
		_held_uid = ""
		return
	_held_body.freeze = false
	_held_body.linear_velocity = Vector3.ZERO
	_held_body.angular_velocity = Vector3.ZERO
	if _held_body.has_meta("original_scale"):
		_held_body.scale = _held_body.get_meta("original_scale")
	_pending_release = true
	_resolve_drop_after_physics.call_deferred()
	_held_body = null
	_held_uid = ""
	_set_ring_energy(_keep_ring, ZONE_RING_BASE_ENERGY)
	_set_ring_energy(_recycle_ring, ZONE_RING_BASE_ENERGY)


func _resolve_drop_after_physics() -> void:
	_pending_release = false
	if _state == null:
		return
	for uid in _bodies.keys():
		var body: RigidBody3D = _bodies[uid]
		if not is_instance_valid(body):
			continue
		var zone_id := _zone_at_body(body)
		var decision := _resolve_drop(uid, zone_id)
		if decision == TriageState.Decision.KEEP and not _state.within_capacity():
			_set_decision(uid, TriageState.Decision.UNDECIDED)
			_return_to_pile(body)
		else:
			_set_decision(uid, decision)
			if decision == TriageState.Decision.KEEP:
				_snap_to_zone(body, _keep_zone_pos)
			elif decision == TriageState.Decision.RECYCLE:
				_snap_to_zone(body, _recycle_zone_pos)
			else:
				_return_to_pile(body)
	_update_ui()


## Returns the zone name at the body position, or "" if none.
func _zone_at_body(body: RigidBody3D) -> String:
	for zone in _keep_zone.get_overlapping_bodies():
		if zone == body:
			return KEEP_ZONE_NAME
	for zone in _recycle_zone.get_overlapping_bodies():
		if zone == body:
			return RECYCLE_ZONE_NAME
	return ""


## Maps a drop zone id to a TriageState.Decision. Exposed for headless testing.
func _resolve_drop(_uid: String, zone_id: String) -> int:
	match zone_id:
		KEEP_ZONE_NAME:
			return TriageState.Decision.KEEP
		RECYCLE_ZONE_NAME:
			return TriageState.Decision.RECYCLE
		_:
			return TriageState.Decision.UNDECIDED


func _return_to_pile(body: RigidBody3D) -> void:
	if not is_instance_valid(body):
		return
	body.freeze = true
	if body.has_meta("original_scale"):
		body.scale = body.get_meta("original_scale")
	_returning_body = body
	_return_target = (
		_pile_spawn.global_position + Vector3(randf() - 0.5, 0.5, randf() - 0.5) * PILE_RADIUS
	)


func _snap_to_zone(body: RigidBody3D, zone_pos: Vector3) -> void:
	if not is_instance_valid(body):
		return
	body.freeze = true
	body.global_position = zone_pos + Vector3.UP * 0.35
	body.rotation = Vector3.ZERO


func _raycast_item(screen_pos: Vector2) -> Dictionary:
	if _viewport == null or _viewport.world_3d == null:
		return {}
	var space_state := _viewport.world_3d.direct_space_state
	var ray := _screen_ray(screen_pos)
	var query := PhysicsRayQueryParameters3D.new()
	query.from = ray["origin"]
	query.to = ray["origin"] + ray["direction"] * RAY_LENGTH
	query.collision_mask = ITEM_COLLISION_LAYER
	query.collide_with_areas = false
	return space_state.intersect_ray(query)


func _raycast_plane(screen_pos: Vector2, plane_y: float) -> Vector3:
	var ray := _screen_ray(screen_pos)
	var origin: Vector3 = ray["origin"]
	var direction: Vector3 = ray["direction"]
	if abs(direction.y) < 0.001:
		return Vector3.ZERO
	var t := (plane_y - origin.y) / direction.y
	if t < 0.0:
		return Vector3.ZERO
	return origin + direction * t


func _screen_ray(screen_pos: Vector2) -> Dictionary:
	var viewport_pos := screen_pos - _viewport_container.get_global_rect().position
	return {
		"origin": _camera.project_ray_origin(viewport_pos),
		"direction": _camera.project_ray_normal(viewport_pos),
	}


# --- Decision logic (shared by 3D and list view) -----------------------------


func _set_decision(uid: String, decision: int) -> void:
	if _state == null:
		return
	_state.set_decision(uid, decision)
	_update_row(uid)
	_update_ui()


func _on_confirm() -> void:
	if _state == null or _service == null:
		return
	if not _state.can_complete():
		if not _state.all_decided():
			_show_validation("Decide every item before confirming.")
		elif not _state.within_capacity():
			_show_validation("Over capacity. Recycle more items.")
		return
	if _service.apply_triage(_state):
		close()


# --- List-view fallback (keyboard/controller/touch parity) -------------------


func _build_rows() -> void:
	for child in _fallback_items_container.get_children():
		child.queue_free()
	_rows.clear()

	for inst in _state.instances:
		var row := _make_row(inst)
		_fallback_items_container.add_child(row)
		_rows[inst.uid] = row
		_fill_row_preview(row, inst)


func _clear_rows() -> void:
	for child in _fallback_items_container.get_children():
		child.queue_free()
	_rows.clear()


func _make_row(inst: ObjectInstance) -> Control:
	var template: ScrapObjectTemplate = DataRepository.singleton().get_template(inst.template_id)
	var display_name := inst.template_id if template == null else template.display_name
	var container: PlacementContainer = DataRepository.singleton().get_container(
		inst.assigned_anchor_id
	)
	var container_name := inst.assigned_anchor_id if container == null else container.display_name
	var glow_color := GlowMapper.get_instance_glow_color(
		template.base_rarity if template != null else ModelEnums.Rarity.WHITE,
		inst.is_carrier,
		false
	)
	var glow_name := GlowMapper.get_display_name(
		GlowMapper.resolve_glow_state(
			template.base_rarity if template != null else ModelEnums.Rarity.WHITE,
			inst.is_carrier,
			false
		)
	)

	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	if SettingsService.previews_enabled():
		var card: Preview3DCard = PREVIEW_CARD_SCENE.instantiate()
		card.custom_minimum_size = Vector2(96, 108)
		card.tooltip_text = glow_name
		row.add_child(card)
		row.set_meta("preview_card", card)
	else:
		var icon := ColorRect.new()
		icon.custom_minimum_size = Vector2(40, 40)
		icon.color = glow_color
		icon.tooltip_text = glow_name
		row.add_child(icon)

	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var name_label := Label.new()
	name_label.text = display_name
	name_label.add_theme_font_size_override("font_size", 18)
	info.add_child(name_label)

	var detail := Label.new()
	detail.text = "%s | %s | cost %d" % [glow_name, container_name, inst.storage_cost]
	detail.add_theme_font_size_override("font_size", 14)
	info.add_child(detail)

	row.add_child(info)

	var keep := Button.new()
	keep.text = "Keep"
	keep.toggle_mode = true
	keep.pressed.connect(func() -> void: _set_decision(inst.uid, TriageState.Decision.KEEP))
	row.add_child(keep)

	var recycle := Button.new()
	recycle.text = "Recycle"
	recycle.toggle_mode = true
	recycle.pressed.connect(func() -> void: _set_decision(inst.uid, TriageState.Decision.RECYCLE))
	row.add_child(recycle)

	row.set_meta("keep_button", keep)
	row.set_meta("recycle_button", recycle)
	return row


func _fill_row_preview(row: Control, inst: ObjectInstance) -> void:
	if not row.has_meta("preview_card"):
		return
	var template := DataRepository.singleton().get_template(inst.template_id)
	if template == null:
		return
	var card: Preview3DCard = row.get_meta("preview_card")
	var obj: RestorationObject3D = (
		ArtifactScenes.scene_for(template.id, ARTIFACT_OBJECT_SCENE).instantiate()
	)
	var color := GlowMapper.get_instance_glow_color(template.base_rarity, false, false)
	card.set_preview(obj, template.display_name, color, 0.46)
	_restoration.present_object(obj, inst, template, inst.uid.hash())


func _update_row(uid: String) -> void:
	var row: Control = _rows.get(uid)
	if row == null:
		return
	var keep: Button = row.get_meta("keep_button")
	var recycle: Button = row.get_meta("recycle_button")
	var decision: int = _state.decisions.get(uid, TriageState.Decision.UNDECIDED)
	keep.button_pressed = decision == TriageState.Decision.KEEP
	recycle.button_pressed = decision == TriageState.Decision.RECYCLE


# --- HUD updates --------------------------------------------------------------


func _update_ui() -> void:
	if _state == null:
		return
	var used := _state.used_storage()
	var cap := _state.storage_cap
	var storage_text := "Storage: %d / %d used, %d available" % [used, cap, cap - used]
	_hud_storage_label.text = storage_text
	_fallback_storage_label.text = storage_text

	var validation := ""
	if not _state.all_decided():
		validation = "Decide every item before confirming."
	elif not _state.within_capacity():
		validation = "Over capacity. Recycle more items."
	_show_validation(validation)

	var can_complete := _state.can_complete()
	_hud_confirm_button.disabled = not can_complete
	_fallback_confirm_button.disabled = not can_complete


func _show_validation(text: String) -> void:
	_hud_validation_label.text = text
	_fallback_validation_label.text = text
