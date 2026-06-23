class_name TriageController
extends CanvasLayer
## Full-screen 2D triage interface.
##
## Shows every delivered object with its apparent glow, assigned anchor, and
## storage cost. Requires an explicit keep or recycle decision for each item and
## enforces the storage cap by cost. Supports mouse-first input and basic
## keyboard/controller focus navigation.

signal closed  ## Emitted after triage is confirmed and applied.

## Rotating 3D artifact preview, shared with the bench/storage.
const PREVIEW_CARD_SCENE := preload("res://scenes/restoration/preview_3d_card.tscn")
const ARTIFACT_OBJECT_SCENE := preload("res://scenes/restoration/restoration_artifact.tscn")
const ArtifactScenes := preload("res://scripts/restoration/artifact_scenes.gd")

var _state: TriageState
var _service: TriageService
var _restoration: RestorationService
var _rows: Dictionary = {}  ## uid -> Control row.

@onready var _panel: Panel = $Panel
@onready var _title: Label = $Panel/Margin/VBox/Title
@onready var _storage_label: Label = $Panel/Margin/VBox/StorageLabel
@onready var _validation_label: Label = $Panel/Margin/VBox/ValidationLabel
@onready var _items_container: VBoxContainer = $Panel/Margin/VBox/Scroll/Items
@onready var _confirm_button: Button = $Panel/Margin/VBox/ConfirmButton


func _ready() -> void:
	_confirm_button.pressed.connect(_on_confirm)
	visible = false


## Alya's delivery must be triaged before leaving: Esc/Backspace confirms once every
## item is decided, and otherwise just nudges the player to decide (there is no exit).
func _unhandled_input(event: InputEvent) -> void:
	if not visible or not event.is_action_pressed("back"):
		return
	get_viewport().set_input_as_handled()
	if _state != null and _state.can_complete():
		_on_confirm()
	else:
		_validation_label.text = "Decide every item (keep or recycle) before leaving."


## Opens the triage interface for the given delivery. Requests clock pause.
func open(delivery: Array[ObjectInstance], storage_cap: int) -> void:
	_state = TriageState.new(delivery, storage_cap)
	_service = TriageService.new(GameState)
	visible = true
	DayClock.request_pause(DayClock.PAUSE_TRIAGE)
	_build_rows()
	_update_ui()
	if _rows.size() > 0:
		var first_row: Control = _rows.values()[0]
		first_row.grab_focus()


## Closes the interface and releases pause ownership.
func close() -> void:
	if visible:
		visible = false
		DayClock.release_pause(DayClock.PAUSE_TRIAGE)
	closed.emit()


func _exit_tree() -> void:
	# Avoid warning if pause was never requested (e.g. scene freed before open()).
	if visible:
		DayClock.release_pause(DayClock.PAUSE_TRIAGE)


func _build_rows() -> void:
	for child in _items_container.get_children():
		child.queue_free()
	_rows.clear()
	if _restoration == null:
		_restoration = RestorationService.new()

	for inst in _state.instances:
		var row := _make_row(inst)
		_items_container.add_child(row)
		_rows[inst.uid] = row
		_fill_row_preview(row, inst)


## Builds the row's rotating artifact preview (model + condition decals) once the row
## is in the tree, so the player sees what each delivered piece actually looks like.
func _fill_row_preview(row: Control, inst: ObjectInstance) -> void:
	if not row.has_meta("preview_card"):
		return
	var template := DataRepository.singleton().get_template(inst.template_id)
	if template == null:
		return
	var card: Preview3DCard = row.get_meta("preview_card")
	var obj: RestorationObject3D = ArtifactScenes.scene_for(template.id, ARTIFACT_OBJECT_SCENE).instantiate()
	var color := GlowMapper.get_instance_glow_color(template.base_rarity, false, false)
	card.set_preview(obj, template.display_name, color, 0.46)
	_restoration.present_object(obj, inst, template, inst.uid.hash())


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

	# A rotating 3D preview of the delivered artifact (filled in after the row is in the
	# tree). Falls back to the flat glow swatch when previews are off.
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
	# Carrier status is intentionally not exposed in unrestricted UI; the carrier
	# displays its ordinary template glow until the Echo phase authorizes flicker.
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


func _set_decision(uid: String, decision: int) -> void:
	if _state == null:
		return
	_state.set_decision(uid, decision)
	_update_row(uid)
	_update_ui()


func _update_row(uid: String) -> void:
	var row: Control = _rows.get(uid)
	if row == null:
		return
	var keep: Button = row.get_meta("keep_button")
	var recycle: Button = row.get_meta("recycle_button")
	var decision: int = _state.decisions.get(uid, TriageState.Decision.UNDECIDED)
	keep.button_pressed = decision == TriageState.Decision.KEEP
	recycle.button_pressed = decision == TriageState.Decision.RECYCLE


func _update_ui() -> void:
	if _state == null:
		return
	var used := _state.used_storage()
	var cap := _state.storage_cap
	_storage_label.text = "Storage: %d / %d used, %d available" % [used, cap, cap - used]

	var validation := ""
	if not _state.all_decided():
		validation = "Decide every item before confirming."
	elif not _state.within_capacity():
		validation = "Over capacity. Recycle more items."
	_validation_label.text = validation
	_confirm_button.disabled = not _state.can_complete()


func _on_confirm() -> void:
	if _state == null or _service == null:
		return
	if _service.apply_triage(_state):
		close()
