class_name RestorationView
extends CanvasLayer
## Focused 3D restoration view (REST-R8): the production Workbench interaction.
##
## The player picks a delivered object, selects an owned tool, rotates the actual
## 3D object, and cleans grime by working the tool across its surface; once CLEAN,
## a separate 3D clasp interaction opens it. This script is a PRESENTATION + INPUT
## layer only. Every gameplay rule — condition/value, tool compatibility, wrong-
## tool damage, the clean->open gate, and open-result resolution — is delegated to
## RestorationService unchanged. The view never re-implements those rules, never
## writes through SaveService, and never branches on carrier identity, so an
## ordinary pendant and a promoted carrier are indistinguishable until opened.
##
## Gestures are translated into deliberate service calls at stable thresholds: a
## cleaning stroke (a press-drag worth of surface work, or one controller press)
## invokes apply_tool() exactly once — never per-frame or per-pixel.

signal closed  ## Emitted after the view is dismissed.
signal journal_requested  ## Player tapped the bench Journal button.
signal phone_requested  ## Player tapped the bench Phone button.
signal storage_requested  ## Player tapped the bench Storage button.

enum Mode { ROTATE, CLEAN }

const MOUSE_ROTATE_SENSITIVITY: float = 0.0065
const KEY_ROTATE_SPEED: float = 2.2
const STROKE_PIXEL_THRESHOLD: float = 64.0  ## Drag distance that commits one stroke.

## Temporary diagnostic logging for the restoration interaction. Flip to false
## (or remove) once the on-screen flow is confirmed working.
const DEBUG_LOG: bool = true
const SCANNER_SCREEN_SCENE := preload("res://scenes/ui/scanner_screen.tscn")

var _service: RestorationService
var _selected_uid: String = ""
var _selected_tool_id: String = ""
var _is_open: bool = false
var _owns_pause: bool = false
var _mode: int = Mode.ROTATE

# Pointer/stroke state.
var _left_down: bool = false
var _right_down: bool = false
var _stroke_active: bool = false
var _stroke_pixels: float = 0.0
var _last_pointer: Vector2 = Vector2.ZERO
var _stroke_uvs: PackedVector2Array = PackedVector2Array()
var _instance_uids: Array[String] = []
## Per-instance dirt-mask snapshots so switching artifacts mid-clean and back
## restores the exact spots the player cleaned (condition alone can't rebuild them).
## Decal photos persist their own removed_decals, so only condition-based masks
## are cached. Lives for the view's lifetime (survives close/reopen of the bench).
var _dirt_cache: Dictionary = {}
var _scanner_screen: ScannerScreen
var _journal_viewport: BookViewport
var _phone: Phone
var _storage_screen: StorageScreen
## Captured base scale of each bench prop (so hover-grow is relative, not absolute).
var _prop_base_scales: Dictionary = {}

@onready var _viewport: SubViewport = $ViewportContainer/SubViewport
@onready var _camera: Camera3D = $ViewportContainer/SubViewport/World/Camera3D
@onready var _object: RestorationObject3D = $ViewportContainer/SubViewport/World/ObjectPivot
@onready var _tool_tray: RestorationToolTray = $ViewportContainer/SubViewport/World/ToolTray
@onready var _phone_prop: Node3D = $ViewportContainer/SubViewport/World/Phone
@onready var _journal_prop: Node3D = $ViewportContainer/SubViewport/World/Journal
@onready var _storage_prop: Node3D = $ViewportContainer/SubViewport/World/StorageBox
@onready var _viewport_container: SubViewportContainer = $ViewportContainer
@onready var _input_catcher: Control = $InputCatcher

@onready var _instance_selector: OptionButton = %InstanceSelector
@onready var _clock_label: Label = %ClockLabel
@onready var _title: Label = %Title
@onready var _state_label: Label = %StateLabel
@onready var _condition_bar: ProgressBar = %ConditionBar
@onready var _condition_label: Label = %ConditionLabel
@onready var _value_label: Label = %ValueLabel
@onready var _damage_label: Label = %DamageLabel
@onready var _surface_bar: ProgressBar = %SurfaceBar
@onready var _tool_container: HBoxContainer = %ToolContainer
@onready var _feedback_label: Label = %FeedbackLabel
@onready var _caption_label: Label = %CaptionLabel
@onready var _clasp_prompt: Label = %ClaspPrompt
@onready var _reset_button: Button = %ResetButton
@onready var _scan_button: Button = %ScanButton
@onready var _close_button: Button = %CloseButton
@onready var _journal_button: Button = %JournalButton
@onready var _phone_button: Button = %PhoneButton
@onready var _storage_button: Button = %StorageButton
@onready var _artifact_cards: HBoxContainer = %ArtifactCards


func _ready() -> void:
	_service = RestorationService.new()
	_scanner_screen = SCANNER_SCREEN_SCENE.instantiate()
	add_child(_scanner_screen)
	_scanner_screen.closed.connect(_on_scanner_closed)
	visible = false
	_ensure_input_actions()
	_viewport_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# The catcher captures all pointer input over the 3D area so it cannot leak
	# through to the Shop HUD buttons sitting behind this view.
	_input_catcher.gui_input.connect(_on_catcher_gui_input)
	_instance_selector.item_selected.connect(_on_instance_selected)
	_reset_button.pressed.connect(reset_view)
	_scan_button.pressed.connect(_on_scan_pressed)
	_close_button.pressed.connect(close)
	_journal_button.pressed.connect(_on_journal_pressed)
	_phone_button.pressed.connect(_on_phone_pressed)
	_storage_button.pressed.connect(_on_storage_pressed)
	# A worn-out tool vanishes from the bench mid-session.
	EventBus.tool_broke.connect(_on_tool_broke)
	# Keep the day/time readout current (the clock is paused at the bench, so this only
	# needs to refresh on open and on the rare hour/day tick).
	DayClock.hour_changed.connect(func(_d: int, _h: int) -> void: _update_clock())
	DayClock.day_changed.connect(func(_d: int) -> void: _update_clock())
	set_process(false)


## Refreshes the top-right Day/time readout from the global clock.
func _update_clock() -> void:
	_clock_label.text = (
		"Day %d · %02d:%02d" % [DayClock.get_day(), DayClock.get_hour(), DayClock.get_minute()]
	)


## Opens the view, pauses the shop clock, lists restorable objects, and focuses the
## first one. Mirrors the old screen's no-argument integration boundary.
func open() -> void:
	visible = true
	_is_open = true
	# The bench no longer pauses the in-game clock (like the phone) — time keeps moving
	# while you restore. Only dialogue and the pause menu freeze time.
	set_process(true)
	_update_clock()
	_populate_instances()
	_log("open(): %d restorable instance(s): %s" % [_instance_uids.size(), str(_instance_uids)])
	if _instance_uids.is_empty():
		_show_empty_state()
	else:
		# Honour the artifact chosen in Storage, if it is on the bench.
		var target := GameState.save_state.loop.restore_target_uid
		var idx := _instance_uids.find(target)
		if idx < 0:
			idx = 0
		_instance_selector.select(idx)
		load_instance(_instance_uids[idx])
	_grab_initial_focus()


## Closes the view and releases pause ownership exactly once.
func close() -> void:
	if _is_open:
		# Preserve the current artifact's cleaned spots so reopening restores them.
		_cache_current_dirt()
		_is_open = false
		visible = false
		set_process(false)
		_release_pause_if_owned()
	closed.emit()


## Snapshots the loaded condition-based artifact's exact dirt mask into the in-memory
## cache and persists it onto the instance (survives save/reload).
func _cache_current_dirt() -> void:
	if _selected_uid.is_empty() or _object.is_decal_mode():
		return
	var png := _object.snapshot_dirt_png()
	if not png.is_empty():
		_dirt_cache[_selected_uid] = png
		_service.persist_dirt_mask(_selected_uid, png)


func _exit_tree() -> void:
	_release_pause_if_owned()


func _release_pause_if_owned() -> void:
	if _owns_pause:
		DayClock.release_pause(DayClock.PAUSE_RESTORATION)
		_owns_pause = false


func _on_scan_pressed() -> void:
	if _selected_uid.is_empty():
		return
	var inst := _service.find_instance_by_id(_selected_uid)
	if inst == null or inst.state != ModelEnums.ObjState.CLEAN:
		return
	_scanner_screen.open(inst)


## The shared journal viewer (a BookViewport) is handed in by the Shop so the bench
## opens the very same book overlay the shop does — it renders on a layer above this
## view. Set by ShopController.set_journal_viewport().
func set_journal_viewport(viewport: BookViewport) -> void:
	_journal_viewport = viewport


## The shared Phone and Storage screens are handed in by the Shop so the bench
## opens the very same overlays the shop's HUD buttons do.
func set_phone(phone: Phone) -> void:
	_phone = phone


func set_storage_screen(screen: StorageScreen) -> void:
	_storage_screen = screen


## Bench shortcut to the journal: opens the shared book viewer over the bench.
func _on_journal_pressed() -> void:
	journal_requested.emit()
	if _journal_viewport != null:
		_journal_viewport.open()
	else:
		_feedback_label.text = "Journal — viewer not available."


func _on_phone_pressed() -> void:
	phone_requested.emit()
	if _phone != null:
		_phone.open()
	else:
		_feedback_label.text = "Phone — not available."


func _on_storage_pressed() -> void:
	storage_requested.emit()
	if _storage_screen != null:
		# Rebuild the bench tools when Storage closes: the loadout may have changed,
		# so a newly-equipped tool appears and an unequipped one leaves the table.
		if not _storage_screen.closed.is_connected(_on_storage_closed_from_bench):
			_storage_screen.closed.connect(_on_storage_closed_from_bench, CONNECT_ONE_SHOT)
		_storage_screen.open()
	else:
		_feedback_label.text = "Storage — not available."


## A bench tool wore out: rebuild the tray so its prop disappears, and if it was the
## tool in hand, put it down.
func _on_tool_broke(_tool_id: String, _uid: String) -> void:
	if not _selected_tool_id.is_empty() and not _service.is_tool_owned(_selected_tool_id):
		_set_mode(Mode.ROTATE)
	_rebuild_tool_palette()
	_tool_tray.build_slots(_service.get_workbench_slots(), _service.get_workbench_durability())
	_tool_tray.set_selected(_selected_tool_id)


func _on_storage_closed_from_bench() -> void:
	_rebuild_tool_palette()
	var tools := _service.get_workbench_tools()
	_tool_tray.build_slots(_service.get_workbench_slots(), _service.get_workbench_durability())
	# If the tool the player was holding is no longer equipped, put it down.
	var still_equipped := false
	for tool in tools:
		if tool.id == _selected_tool_id:
			still_equipped = true
			break
	if not _selected_tool_id.is_empty() and not still_equipped:
		_set_mode(Mode.ROTATE)


func _on_scanner_closed() -> void:
	# The player may have committed a verdict; refresh the instance display.
	if _selected_uid.is_empty():
		return
	var inst := _service.find_instance_by_id(_selected_uid)
	var template := (
		_service.get_repository().get_template(inst.template_id) if inst != null else null
	)
	if inst != null:
		_refresh(inst, template)


# --- Instance / tool selection ----------------------------------------------


func _populate_instances() -> void:
	_instance_selector.clear()
	_instance_uids.clear()
	for inst in _service.get_restorable_instances():
		var template := _service.get_repository().get_template(inst.template_id)
		var display_name := template.display_name if template != null else inst.template_id
		var state_name := ModelEnums.obj_state_name(inst.state)
		_instance_selector.add_item("%s (%s)" % [display_name, state_name])
		_instance_uids.append(inst.uid)
	_instance_selector.disabled = _instance_uids.is_empty()
	_rebuild_artifact_bar()


# --- Artifact card bar (diegetic replacement for the Object dropdown) ------------

const ARTIFACT_CARD_SCENE := preload("res://scenes/restoration/artifact_card.tscn")
const ARTIFACT_OBJECT_SCENE := preload("res://scenes/restoration/restoration_artifact.tscn")


## Builds the horizontal, scrollable strip of artifact cards (one square per
## restorable artifact), each rotating-3D-preview or text-only per the settings, with
## its name coloured by rarity. Clicking a card loads that artifact onto the bench.
func _rebuild_artifact_bar() -> void:
	for child in _artifact_cards.get_children():
		child.queue_free()
	var previews_on := SettingsService.previews_enabled()
	for uid in _instance_uids:
		var inst := _service.find_instance_by_id(uid)
		if inst == null:
			continue
		var template := _service.get_repository().get_template(inst.template_id)
		var display := template.display_name if template != null else inst.template_id
		var card: ArtifactCard = ARTIFACT_CARD_SCENE.instantiate()
		_artifact_cards.add_child(card)
		card.configure(uid, display, _rarity_color(_instance_rarity(uid)), previews_on)
		card.selected.connect(_pick_artifact)
		if previews_on and template != null:
			# Embed the real artifact (model + its condition decals) so the rotating
			# preview shows the player exactly what they'll need to restore.
			var preview: RestorationObject3D = ARTIFACT_OBJECT_SCENE.instantiate()
			card.attach_preview(preview)  # in-tree first, so geometry builds in the card's world
			_present_object(preview, inst, template, _artifact_seed(uid))


## Builds an artifact's visible presentation (model + condition decals) onto `obj`.
## Shared by the bench's main object and the rotating previews in the card bar.
## Returns true when condition decals were applied (so callers can skip the dirt-mask
## fallback). `obj` must already be in the tree so its geometry builds in the right
## world.
func _present_object(
	obj: RestorationObject3D, inst: ObjectInstance, template: ScrapObjectTemplate, seed_value: int
) -> bool:
	return _service.present_object(obj, inst, template, seed_value)


## Deterministic per-artifact seed for decal layout + which random conditions appear.
## Folds in the loop index so a relic shows a different mix each loop (and each new save,
## since instance uids differ).
func _artifact_seed(uid: String) -> int:
	return uid.hash() ^ (GameState.loop_index * 104729)


func _pick_artifact(uid: String) -> void:
	var idx := _instance_uids.find(uid)
	if idx >= 0:
		_instance_selector.select(idx)
	load_instance(uid)


func _instance_rarity(uid: String) -> int:
	var inst := _service.find_instance_by_id(uid)
	if inst == null:
		return ModelEnums.Rarity.WHITE
	var template := _service.get_repository().get_template(inst.template_id)
	return template.base_rarity if template != null else ModelEnums.Rarity.WHITE


func _rarity_color(rarity: int) -> Color:
	return GlowMapper.get_instance_glow_color(rarity, false, false)


## Loads a specific instance into the 3D view. Public so the Shop/tests can drive
## selection directly; presentation is rebuilt purely from saved instance state.
func load_instance(uid: String) -> void:
	# Preserve where the player cleaned on the outgoing artifact before switching.
	_cache_current_dirt()
	_selected_uid = uid
	_selected_tool_id = ""
	var inst := _service.find_instance_by_id(uid)
	var template: ScrapObjectTemplate = (
		_service.get_repository().get_template(inst.template_id) if inst != null else null
	)
	if inst == null or template == null:
		_show_invalid_state()
		return
	# Per-instance seed so a shared placed decal scatters/cleans independently per
	# artifact; folding in the loop index re-rolls which random conditions appear each loop.
	var instance_seed := _artifact_seed(uid)
	_object.visible = true
	if not _present_object(_object, inst, template, instance_seed):
		# No condition decals: restore the cleaned spots from this session or the save.
		if _dirt_cache.has(uid):
			_object.restore_dirt_png(_dirt_cache[uid])
		elif not inst.dirt_mask.is_empty():
			_object.restore_dirt_png(inst.dirt_mask)
	_title.text = template.display_name
	_set_mode(Mode.ROTATE)
	_rebuild_tool_palette()
	_tool_tray.build_slots(_service.get_workbench_slots(), _service.get_workbench_durability())
	reset_view()
	_refresh(inst, template)
	_caption_label.text = "Rotate to inspect, then pick up a tool from the bench and work the surface."
	_log(
		(
			"load_instance(%s): template=%s state=%s condition=%.0f tools=%d"
			% [
				uid,
				template.id,
				ModelEnums.obj_state_name(inst.state),
				inst.condition,
				_service.get_available_tools().size()
			]
		)
	)


func _rebuild_tool_palette() -> void:
	for child in _tool_container.get_children():
		child.queue_free()
	var tools := _service.get_workbench_tools()
	if tools.is_empty():
		var none := Label.new()
		none.text = "No tools available."
		_tool_container.add_child(none)
		return
	for tool in tools:
		var button := Button.new()
		button.text = tool.display_name
		button.toggle_mode = true
		button.focus_mode = Control.FOCUS_ALL
		button.button_pressed = tool.id == _selected_tool_id
		var tool_id := tool.id
		button.pressed.connect(func() -> void: toggle_tool(tool_id))
		_tool_container.add_child(button)


## Selects an owned tool to clean with. Public so the Shop/tests can drive it.
func select_tool(tool_id: String) -> void:
	_selected_tool_id = tool_id
	_log("select_tool(%s) -> mode CLEAN" % tool_id)
	# The bench tool prop is the primary selection surface; the HUD buttons are a
	# labelled accessibility/fallback that we keep visually in sync.
	_tool_tray.set_selected(tool_id)
	for child in _tool_container.get_children():
		if child is Button:
			child.button_pressed = (child as Button).text == _tool_display_name(tool_id)
	# Selecting a tool moves the player into cleaning; they can switch back to
	# Rotate (mode toggle / right-drag / rotate keys) to inspect again.
	_set_mode(Mode.CLEAN)
	var inst := _service.find_instance_by_id(_selected_uid)
	if inst != null and inst.state == ModelEnums.ObjState.DIRTY:
		_caption_label.text = (
			"Work the %s across the surface to clean it." % _tool_display_name(tool_id)
		)


func _tool_display_name(tool_id: String) -> String:
	var tool := _service.get_repository().get_tool(tool_id)
	return tool.display_name if tool != null else tool_id


# --- Blemish cleaning (decal-based photos/frames/paper) ----------------------


## Builds a {condition_type: Color} map from the journal surface-condition catalog
## so the hotspots match the colours shown in the Condition Guide.
func _condition_colors(decals: Array) -> Dictionary:
	var colors := {}
	var repo := _service.get_repository()
	for decal in decals:
		var condition := repo.get_surface_condition(decal.type)
		colors[decal.type] = condition.to_color() if condition != null else decal.to_color()
	return colors


## Builds a {condition_type: Texture2D} map from the placeholder condition art
## (assets/artifact_conditions/<Display Name>.png), so each condition decal shows its
## proper image instead of a generic placeholder.
func _condition_textures(decals: Array) -> Dictionary:
	var textures := {}
	var repo := _service.get_repository()
	for decal in decals:
		if textures.has(decal.type):
			continue
		var condition := repo.get_surface_condition(decal.type)
		if condition == null:
			continue
		var path := "res://assets/artifact_conditions/%s.png" % condition.display_name
		if ResourceLoader.exists(path):
			textures[decal.type] = load(path)
	return textures


## Cleans one blemish by id with the selected tool (delegates the rule to the
## service). Removes the hotspot on success and surfaces join/scan prompts when the
## photo becomes fully clean. Returns the service result, or null when no tool is
## selected.
func clean_blemish(blemish_id: String) -> RestorationService.DecalResult:
	if _selected_tool_id.is_empty():
		_caption_label.text = "Pick up a tool from the bench first."
		return null
	var result := _service.clean_decal(_selected_uid, blemish_id, _selected_tool_id)
	if not result.ok:
		_feedback_label.text = result.feedback
		return result
	# A grime puff plays on every stroke (right tool or wrong); a successful clean adds
	# the sparkle via remove_blemish.
	_object.blemish_working_burst(blemish_id)
	if result.removed:
		_object.remove_blemish(blemish_id)
	_feedback_label.text = result.feedback
	if not result.compatible:
		_caption_label.text = "Wrong tool — %s" % result.feedback
	elif result.reached_clean:
		_caption_label.text = _clean_photo_caption()
	else:
		_caption_label.text = "Treated one mark. %d left." % result.remaining_decals
	var inst := _service.find_instance_by_id(_selected_uid)
	var template := (
		_service.get_repository().get_template(inst.template_id) if inst != null else null
	)
	if inst != null:
		_refresh(inst, template)
	return result


# --- Author-placed condition decals (event artifacts) ------------------------


## Works a tool against an author-placed condition. A grime puff plays on EVERY use.
## The right tool (one with cleaning power for this condition) fades the decal a step
## per stroke and, once fully scrubbed away, triggers the success sparkle; a powerless
## (wrong) tool only puffs and is rejected. Returns true only when the condition is
## fully cleaned this stroke.
func clean_authored_condition(condition_id: String) -> bool:
	if _selected_tool_id.is_empty():
		_caption_label.text = "Pick up a tool from the bench first."
		return false
	# A tool always kicks up a puff where it's worked, right tool or wrong.
	_object.authored_working_burst(condition_id)
	var label := _object.authored_type_id(condition_id).replace("_", " ")
	var strength := CleaningPower.power(
		_service.get_repository(), _selected_tool_id, _object.authored_type_id(condition_id)
	)
	if strength <= 0:
		var required := _object.authored_required_tool(condition_id)
		var needs := _tool_display_name(required) if not required.is_empty() else "the right tool"
		_feedback_label.text = "Wrong tool — the %s needs %s." % [label, needs]
		_caption_label.text = "Wrong tool — the %s needs %s." % [label, needs]
		return false
	var cleaned := _object.apply_authored_clean(condition_id, strength)
	# Record the gameplay effect (wear the tool, raise condition/value, reach CLEAN) — this
	# is what makes the author-placed decals real conditions, not just a visual.
	var total := _object.authored_active_count()
	var done := total - _object.uncleaned_authored_ids().size()
	var res := _service.register_authored_clean(_selected_uid, _selected_tool_id, total, done, cleaned)
	if cleaned:
		_feedback_label.text = "The %s lifts away — spotless!" % label
		_caption_label.text = (
			"The surface is clean. Open the clasp to see inside."
			if res.reached_clean
			else "Cleaned the %s." % label
		)
	else:
		_feedback_label.text = "Working off the %s..." % label
		_caption_label.text = "Keep scrubbing the %s." % label
	var inst := _service.find_instance_by_id(_selected_uid)
	if inst != null:
		_refresh(inst, _service.get_repository().get_template(inst.template_id))
	return cleaned


## Ray-tests the author-placed condition decals and cleans the one hit. Returns true
## when one was targeted, so a miss falls through to the normal clean/rotate gesture.
func _try_authored_condition_at_pointer(pos: Vector2) -> bool:
	if not _object.has_authored_conditions():
		return false
	var origin := _camera.project_ray_origin(_to_viewport(pos))
	var dir := _camera.project_ray_normal(_to_viewport(pos))
	var hit := _object.ray_test_authored(origin, dir)
	if not hit.get("hit", false):
		return false
	clean_authored_condition(hit["condition_id"])
	return true


## Test seam mirroring attempt_clean_with_ray(): cleans the authored decal a ray hits.
func attempt_clean_authored_with_ray(origin: Vector3, direction: Vector3) -> bool:
	var hit := _object.ray_test_authored(origin, direction)
	if not hit.get("hit", false):
		return false
	return clean_authored_condition(hit["condition_id"])


## Ray-tests the photo's blemishes and cleans the one hit. Returns true when a
## blemish was targeted (so aiming at bare photo is a no-op). Test seam mirroring
## attempt_clean_with_ray().
func attempt_clean_blemish_with_ray(origin: Vector3, direction: Vector3) -> bool:
	var hit := _object.ray_test_blemish(origin, direction)
	if not hit.get("hit", false):
		return false
	clean_blemish(hit["blemish_id"])
	return true


## Performs the join step (e.g. taping torn photo halves) with the selected tool.
## The service enforces the clean-gate and the correct join tool. Returns the
## service result.
func try_join() -> RestorationService.JoinResult:
	var result := _service.join_object(_selected_uid, _selected_tool_id)
	if result.ok and result.joined:
		_feedback_label.text = "The pieces hold together again."
		_caption_label.text = "Rejoined — the photograph is whole."
	else:
		_feedback_label.text = result.error
		_caption_label.text = result.error
	var inst := _service.find_instance_by_id(_selected_uid)
	var template := (
		_service.get_repository().get_template(inst.template_id) if inst != null else null
	)
	if inst != null:
		_refresh(inst, template)
	return result


func _clean_photo_caption() -> String:
	var inst := _service.find_instance_by_id(_selected_uid)
	var template := (
		_service.get_repository().get_template(inst.template_id) if inst != null else null
	)
	if template != null and template.requires_join and inst != null and not inst.is_joined:
		return "Every mark is gone. Pick up the Archival Tape and join the pieces."
	return "The photograph is clean. Scan and judge it."


# --- Cleaning (delegates every rule to RestorationService) -------------------


## Commits one deliberate cleaning stroke worth of work over the given surface UVs.
## Returns the service ToolResult, or null when nothing actionable happened (no
## tool, not DIRTY, or the stroke never touched the surface — i.e. empty space).
func commit_stroke(worked_uvs: PackedVector2Array) -> RestorationService.ToolResult:
	if not _is_open or worked_uvs.is_empty():
		_log("commit_stroke skipped: no surface worked (missed the object)")
		return null
	if _selected_uid.is_empty() or _selected_tool_id.is_empty():
		_log("commit_stroke skipped: no tool selected")
		return null
	var inst := _service.find_instance_by_id(_selected_uid)
	if inst == null or inst.state != ModelEnums.ObjState.DIRTY:
		var state_name := "missing" if inst == null else ModelEnums.obj_state_name(inst.state)
		_log("commit_stroke skipped: instance not DIRTY (state=%s)" % state_name)
		return null
	var result := _service.apply_tool(_selected_uid, _selected_tool_id)
	if result.ok and result.compatible:
		for uv in worked_uvs:
			_object.clean_brush_at_uv(uv)
		if result.reached_clean:
			_object.set_fully_clean()
	_log(
		(
			"commit_stroke: tool=%s compatible=%s condition=%.0f->%.0f reached_clean=%s coverage=%.2f"
			% [
				_selected_tool_id,
				str(result.compatible),
				result.condition_before,
				result.condition_after,
				str(result.reached_clean),
				_object.coverage()
			]
		)
	)
	_apply_action_feedback(result)
	return result


## Convenience for a single-point stroke (controller/keyboard cleaning and tests).
func clean_stroke_at_uv(uv: Vector2) -> RestorationService.ToolResult:
	return commit_stroke(PackedVector2Array([uv]))


## Ray-tests the surface and, on a hit, performs one stroke there. Returns null on
## a miss so cleaning empty space is a genuine no-op.
func attempt_clean_with_ray(origin: Vector3, direction: Vector3) -> RestorationService.ToolResult:
	var hit := _object.ray_test_surface(origin, direction)
	if not hit.get("hit", false):
		return null
	return clean_stroke_at_uv(hit["uv"])


# --- Clasp opening (delegates the gate + resolution to the service) ----------


## Attempts the 3D clasp open. The service enforces the clean->open gate, so a
## DIRTY object is rejected here exactly as everywhere else, and opening is
## single-use. Content is shown from the resolved result without re-resolving it.
func try_open_clasp() -> RestorationService.OpenAttemptResult:
	if not _is_open or _selected_uid.is_empty():
		var blocked := RestorationService.OpenAttemptResult.new()
		blocked.error = "No object selected."
		return blocked
	var result := _service.open_clasp(_selected_uid)
	if result.ok:
		_object.set_clasp_open(true)
		_feedback_label.text = "The clasp opens."
		_caption_label.text = "The clasp opens — inside is %s" % _friendly_result(result.result)
	else:
		_feedback_label.text = result.error
		_caption_label.text = result.error
	var inst := _service.find_instance_by_id(_selected_uid)
	var template := (
		_service.get_repository().get_template(inst.template_id) if inst != null else null
	)
	if inst != null:
		_refresh(inst, template)
	return result


func _friendly_result(open_result: int) -> String:
	match open_result:
		ModelEnums.OpenResult.FRAGMENT:
			return "a fragment."
		ModelEnums.OpenResult.TEMPORAL_ECHO:
			return "a faint echo."
		_:
			return "nothing of note."


# --- Feedback / meters -------------------------------------------------------


func _apply_action_feedback(result: RestorationService.ToolResult) -> void:
	if result == null:
		return
	_feedback_label.text = result.feedback
	if not result.compatible:
		_caption_label.text = "Wrong tool — %s Condition and value dropped." % result.feedback
	elif result.reached_clean:
		_caption_label.text = "The surface is clean. Open the clasp to see inside."
	else:
		_caption_label.text = "Cleaned a section. Keep working the grime."
	var inst := _service.find_instance_by_id(_selected_uid)
	var template := (
		_service.get_repository().get_template(inst.template_id) if inst != null else null
	)
	if inst != null:
		_refresh(inst, template)


func _refresh(inst: ObjectInstance, template: ScrapObjectTemplate) -> void:
	# Keep the bench durability bars current after any action that may have worn a tool.
	_tool_tray.update_durability(_service.get_workbench_durability())
	var threshold := template.clean_completion_threshold if template != null else 100
	_state_label.text = "State: %s" % ModelEnums.obj_state_name(inst.state).capitalize()
	_condition_bar.max_value = threshold
	_condition_bar.value = inst.condition
	_condition_label.text = "Condition %d / %d" % [int(inst.condition), threshold]
	_value_label.text = "Value: P%d" % inst.value
	_damage_label.text = "Recorded damage: %d" % inst.recorded_damage

	if _object.is_photo_mode():
		_refresh_photo(inst, template)
		return

	if _object.has_authored_conditions():
		var total := _object.authored_active_count()
		var cleaned := total - _object.uncleaned_authored_ids().size()
		_surface_bar.value = (float(cleaned) / float(total) * 100.0) if total > 0 else 0.0
	elif _object.is_condition_mode():
		var total := _service.effective_decals(inst, template).size()
		var cleaned := total - _remaining_blemishes(inst, template)
		_surface_bar.value = (float(cleaned) / float(total) * 100.0) if total > 0 else 0.0
	else:
		_surface_bar.value = _object.coverage() * 100.0
	var is_clean := inst.state == ModelEnums.ObjState.CLEAN
	var is_open := inst.state == ModelEnums.ObjState.OPEN
	_object.set_clasp_revealed(is_clean)
	if is_open:
		_object.set_clasp_open(true)
	_clasp_prompt.visible = is_clean
	_scan_button.visible = is_clean
	if is_clean:
		_clasp_prompt.text = "Pendant is clean — scan and judge, or click the clasp to open."
	elif is_open:
		_clasp_prompt.visible = false


## Refresh for decal-based photos/frames: blemish-progress bar plus join/scan
## prompts (no clasp).
func _refresh_photo(inst: ObjectInstance, template: ScrapObjectTemplate) -> void:
	var total := _service.effective_decals(inst, template).size()
	var cleaned := total - _remaining_blemishes(inst, template)
	_surface_bar.value = (float(cleaned) / float(total) * 100.0) if total > 0 else 0.0

	var is_clean := inst.state == ModelEnums.ObjState.CLEAN
	_scan_button.visible = is_clean
	var needs_join := template != null and template.requires_join and not inst.is_joined
	_clasp_prompt.visible = is_clean
	if is_clean and needs_join:
		_clasp_prompt.text = "Clean — pick up the Archival Tape and join the pieces."
	elif is_clean:
		_clasp_prompt.text = "The photograph is clean — scan and judge it."
	else:
		_clasp_prompt.visible = false


func _remaining_blemishes(inst: ObjectInstance, template: ScrapObjectTemplate) -> int:
	var remaining := 0
	for decal in _service.effective_decals(inst, template):
		if not inst.removed_decals.has(decal.id):
			remaining += 1
	return remaining


func _show_empty_state() -> void:
	_selected_uid = ""
	_title.text = "Nothing to restore"
	_object.visible = false
	_caption_label.text = "No delivered objects are ready for the bench."
	_state_label.text = ""
	_condition_label.text = ""
	_value_label.text = ""
	_damage_label.text = ""
	_clasp_prompt.visible = false
	# The bench tools (and their durability/condition panels) still show even with no
	# artifact on the bench, so the player can inspect their kit.
	_rebuild_tool_palette()
	_tool_tray.build_slots(_service.get_workbench_slots(), _service.get_workbench_durability())


func _show_invalid_state() -> void:
	_object.visible = false
	_title.text = "Object unavailable"
	_caption_label.text = "That object can no longer be restored."
	_clasp_prompt.visible = false


# --- Mode --------------------------------------------------------------------


func _toggle_mode() -> void:
	_set_mode(Mode.ROTATE if _mode == Mode.CLEAN else Mode.CLEAN)


func _set_mode(mode: int) -> void:
	_mode = mode
	# Rotate is for inspecting, not cleaning — put the held tool down so it is no
	# longer "in hand" until the player picks one up again.
	if _mode == Mode.ROTATE:
		_deselect_tool()


## Clears the held tool and returns the tray prop + fallback buttons to rest.
func _deselect_tool() -> void:
	_selected_tool_id = ""
	_tool_tray.set_selected("")
	for child in _tool_container.get_children():
		if child is Button:
			(child as Button).button_pressed = false


func get_mode() -> int:
	return _mode


func get_selected_uid() -> String:
	return _selected_uid


func get_selected_tool_id() -> String:
	return _selected_tool_id


func get_restoration_object() -> RestorationObject3D:
	return _object


func get_tool_tray() -> RestorationToolTray:
	return _tool_tray


func owns_pause() -> bool:
	return _owns_pause


func _log(msg: String) -> void:
	if DEBUG_LOG:
		print("[Restoration] ", msg)


# --- View controls -----------------------------------------------------------


func reset_view() -> void:
	_object.reset_orientation()


## Orbits the displayed object. Presentation only — never mutates game state.
func rotate_view(delta_yaw: float, delta_pitch: float) -> void:
	_object.rotate_view(delta_yaw, delta_pitch)


# --- Input -------------------------------------------------------------------


func _process(delta: float) -> void:
	if not _is_open:
		return
	# Time keeps moving at the bench now, so keep the Day/time readout live.
	_update_clock()
	var rx := (
		Input.get_action_strength("restoration_rotate_right")
		- Input.get_action_strength("restoration_rotate_left")
	)
	var ry := (
		Input.get_action_strength("restoration_rotate_down")
		- Input.get_action_strength("restoration_rotate_up")
	)
	if rx != 0.0 or ry != 0.0:
		_object.rotate_view(-rx * KEY_ROTATE_SPEED * delta, -ry * KEY_ROTATE_SPEED * delta)


func _unhandled_input(event: InputEvent) -> void:
	# Keyboard/controller actions only; pointer input is handled by the InputCatcher
	# so it cannot fall through to Controls on other CanvasLayers (the Shop HUD).
	if not _is_open:
		return
	if _handle_action_event(event):
		get_viewport().set_input_as_handled()


## Mouse and (emulated) touch handling for the 3D area. Positions are in catcher-
## local space, which equals screen space because the catcher fills the screen.
func _on_catcher_gui_input(event: InputEvent) -> void:
	if not _is_open:
		return
	if event is InputEventMouseButton:
		_handle_mouse_button(event as InputEventMouseButton)
		_input_catcher.accept_event()
	elif event is InputEventMouseMotion:
		_handle_mouse_motion(event as InputEventMouseMotion)
		_input_catcher.accept_event()


func _handle_action_event(event: InputEvent) -> bool:
	# action -> zero-arg handler. Keeps a single dispatch point (and stays under the
	# lint return-count cap) as more keyboard/controller actions are added.
	var handlers := {
		"restoration_clean": _controller_clean,
		"restoration_open": _open_or_join,
		"restoration_reset_view": reset_view,
		"restoration_toggle_mode": _toggle_mode,
		"restoration_cycle_tool": func() -> void: cycle_tool(1),
		"back": close,  # Esc closes the bench; Space is the pause menu.
	}
	for action in handlers:
		if event.is_action_pressed(action):
			(handlers[action] as Callable).call()
			return true
	return false


func _handle_mouse_button(event: InputEventMouseButton) -> void:
	var pos := event.position
	if event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			var hit := _ray_at_pointer(pos)
			_log(
				(
					"left press @%s mode=%s surface_hit=%s tool=%s"
					% [
						str(pos),
						"CLEAN" if _mode == Mode.CLEAN else "ROTATE",
						str(hit.get("hit", false)),
						_selected_tool_id
					]
				)
			)
			if not _pointer_over_viewport(pos):
				return
			if _try_clasp_at_pointer(pos):
				return
			# Picking up a bench tool prop selects it (off to the side of the object,
			# so it never competes with a cleaning stroke or a rotate drag).
			if _try_tool_pick_at_pointer(pos):
				return
			# The diegetic phone / journal / storage props open their overlays (the old
			# HUD buttons are now hidden accessibility fallbacks).
			if _try_bench_object_at_pointer(pos):
				return
			# Author-placed condition decals (event artifacts) clean on a direct click
			# with the right tool, before a surface stroke begins.
			if _mode == Mode.CLEAN and _try_authored_condition_at_pointer(pos):
				return
			_last_pointer = pos
			_left_down = true
			if _object.is_decal_mode():
				# Decal-based artifacts (photos or random conditions) clean by clicking
				# discrete marks, not by stroking a dirt mask.
				if _mode == Mode.CLEAN and _try_photo_action_at_pointer(pos):
					_left_down = false
				return
			if _mode == Mode.CLEAN:
				_begin_stroke(pos)
		else:
			if _stroke_active:
				_end_stroke()
			_left_down = false
	elif event.button_index == MOUSE_BUTTON_RIGHT:
		# Right-drag always rotates (a mouse convenience); touch/controller use the
		# mode toggle and rotate actions instead, so no gesture is right-click-only.
		if event.pressed and _pointer_over_viewport(pos):
			_right_down = true
			_last_pointer = pos
		else:
			_right_down = false


func _handle_mouse_motion(event: InputEventMouseMotion) -> void:
	var pos := event.position
	if _left_down and _mode == Mode.CLEAN and _stroke_active:
		_accumulate_stroke(pos)
	elif _right_down or (_left_down and _mode == Mode.ROTATE):
		_object.rotate_view(
			-event.relative.x * MOUSE_ROTATE_SENSITIVITY,
			-event.relative.y * MOUSE_ROTATE_SENSITIVITY
		)
	else:
		_update_hover(pos)


## Highlights the tool or bench object under the idle pointer (shop-style hover).
func _update_hover(pos: Vector2) -> void:
	if not _pointer_over_viewport(pos):
		_tool_tray.set_hovered("")
		_set_bench_hover("")
		return
	var origin := _camera.project_ray_origin(_to_viewport(pos))
	var dir := _camera.project_ray_normal(_to_viewport(pos))
	var tool_id := _tool_tray.ray_pick(origin, dir)
	if not tool_id.is_empty():
		_tool_tray.set_hovered(tool_id)
		_set_bench_hover("")
		return
	_tool_tray.set_hovered("")
	_set_bench_hover(_bench_object_pick(origin, dir))


## Grows the hovered bench prop (phone/journal/storage) by 10% of its OWN base scale,
## clearing the others. (The props have different base scales — e.g. the phone model is
## tiny — so we must scale relative to each, not to an absolute 1.0.)
func _set_bench_hover(id: String) -> void:
	if _prop_base_scales.is_empty():
		_prop_base_scales = {
			"phone": _phone_prop.scale,
			"journal": _journal_prop.scale,
			"storage": _storage_prop.scale,
		}
	_phone_prop.scale = _prop_base_scales["phone"] * (1.1 if id == "phone" else 1.0)
	_journal_prop.scale = _prop_base_scales["journal"] * (1.1 if id == "journal" else 1.0)
	_storage_prop.scale = _prop_base_scales["storage"] * (1.1 if id == "storage" else 1.0)


func _controller_clean() -> void:
	if _selected_tool_id.is_empty():
		_caption_label.text = "Select a tool first."
		return
	if _object.is_decal_mode():
		var blemish_id := _object.auto_target_blemish_id()
		if blemish_id.is_empty():
			_open_or_join()
		else:
			clean_blemish(blemish_id)
		return
	var inst := _service.find_instance_by_id(_selected_uid)
	if inst == null or inst.state != ModelEnums.ObjState.DIRTY:
		return
	clean_stroke_at_uv(_object.auto_target_dirty_uv())


## Keyboard/controller "open" action: opens the clasp on an openable object, or
## performs the join on a decal-based photo that needs reassembly.
func _open_or_join() -> void:
	if _object.is_photo_mode():
		var inst := _service.find_instance_by_id(_selected_uid)
		var template := (
			_service.get_repository().get_template(inst.template_id) if inst != null else null
		)
		if template != null and template.requires_join:
			try_join()
		return
	try_open_clasp()


func _begin_stroke(pos: Vector2) -> void:
	_stroke_active = true
	_stroke_pixels = 0.0
	_stroke_uvs.clear()
	_last_pointer = pos
	_add_stroke_sample(pos)


func _accumulate_stroke(pos: Vector2) -> void:
	_stroke_pixels += pos.distance_to(_last_pointer)
	_last_pointer = pos
	_add_stroke_sample(pos)
	if _stroke_pixels >= STROKE_PIXEL_THRESHOLD:
		if not _stroke_uvs.is_empty():
			commit_stroke(_stroke_uvs)
		_stroke_uvs.clear()
		_stroke_pixels = 0.0


func _end_stroke() -> void:
	if _stroke_active and not _stroke_uvs.is_empty():
		commit_stroke(_stroke_uvs)
	_stroke_active = false
	_stroke_uvs.clear()
	_stroke_pixels = 0.0


func _add_stroke_sample(pos: Vector2) -> void:
	var hit := _ray_at_pointer(pos)
	if hit.get("hit", false):
		_stroke_uvs.append(hit["uv"])


func _try_clasp_at_pointer(pos: Vector2) -> bool:
	var origin := _camera.project_ray_origin(_to_viewport(pos))
	var dir := _camera.project_ray_normal(_to_viewport(pos))
	if _object.ray_test_clasp(origin, dir).get("hit", false):
		try_open_clasp()
		return true
	return false


## In photo mode, a click either joins the cleaned halves (when the photo is clean
## and needs joining) or cleans the blemish under the pointer. Returns true when it
## acted, so a click on bare photo falls through to a rotate drag.
func _try_photo_action_at_pointer(pos: Vector2) -> bool:
	var inst := _service.find_instance_by_id(_selected_uid)
	var template := (
		_service.get_repository().get_template(inst.template_id) if inst != null else null
	)
	if (
		inst != null
		and template != null
		and template.requires_join
		and not inst.is_joined
		and inst.state == ModelEnums.ObjState.CLEAN
	):
		try_join()
		return true
	var origin := _camera.project_ray_origin(_to_viewport(pos))
	var dir := _camera.project_ray_normal(_to_viewport(pos))
	return attempt_clean_blemish_with_ray(origin, dir)


func _try_tool_pick_at_pointer(pos: Vector2) -> bool:
	var origin := _camera.project_ray_origin(_to_viewport(pos))
	var dir := _camera.project_ray_normal(_to_viewport(pos))
	var tool_id := _tool_tray.ray_pick(origin, dir)
	if tool_id.is_empty():
		return false
	toggle_tool(tool_id)  # clicking the held tool again puts it down (back to Rotate)
	return true


## Ray-tests the diegetic bench objects (phone, journal, storage box) and opens the
## matching overlay. These are the 3D replacements for the old HUD buttons.
func _try_bench_object_at_pointer(pos: Vector2) -> bool:
	var origin := _camera.project_ray_origin(_to_viewport(pos))
	var dir := _camera.project_ray_normal(_to_viewport(pos))
	match _bench_object_pick(origin, dir):
		"phone":
			_on_phone_pressed()
		"journal":
			_on_journal_pressed()
		"storage":
			_on_storage_pressed()
		_:
			return false
	return true


## Nearest bench object hit by the ray ("phone"/"journal"/"storage"), or "".
func _bench_object_pick(origin: Vector3, direction: Vector3) -> String:
	var candidates := [
		{"id": "phone", "node": _phone_prop, "radius": 0.32},
		{"id": "journal", "node": _journal_prop, "radius": 0.32},
		{"id": "storage", "node": _storage_prop, "radius": 0.42},
	]
	var best := ""
	var best_t := INF
	for entry in candidates:
		var node: Node3D = entry["node"]
		var hit := _ray_sphere(origin, direction, node.global_position, float(entry["radius"]))
		if hit.get("hit", false) and float(hit["t"]) < best_t:
			best_t = float(hit["t"])
			best = String(entry["id"])
	return best


func _ray_sphere(origin: Vector3, direction: Vector3, center: Vector3, radius: float) -> Dictionary:
	var dir := direction.normalized()
	var oc := origin - center
	var b := oc.dot(dir)
	var c := oc.dot(oc) - radius * radius
	var disc := b * b - c
	if disc < 0.0:
		return {"hit": false}
	var t := -b - sqrt(disc)
	if t < 0.0:
		t = -b + sqrt(disc)
		if t < 0.0:
			return {"hit": false}
	return {"hit": true, "t": t}


## Ray-tests the bench tool props and selects the hit tool. Returns the selected
## tool id, or "" on a miss (so aiming at empty space is a no-op). Test seam that
## mirrors attempt_clean_with_ray().
func attempt_select_tool_with_ray(origin: Vector3, direction: Vector3) -> String:
	var tool_id := _tool_tray.ray_pick(origin, direction)
	if not tool_id.is_empty():
		toggle_tool(tool_id)
	return tool_id


## Picks up a tool, or — if it's the one already in hand — puts it down and returns to
## Rotate. This is how the player switches between cleaning and inspecting now that the
## explicit mode button is gone.
func toggle_tool(tool_id: String) -> void:
	if tool_id == _selected_tool_id:
		_set_mode(Mode.ROTATE)
	else:
		select_tool(tool_id)


## Cycles selection to the next owned tool prop. Gives controller/keyboard players
## a diegetic-equivalent path to picking up a tool without precision aiming.
func cycle_tool(step: int = 1) -> void:
	var ids := _tool_tray.get_tool_ids()
	if ids.is_empty():
		return
	var current := ids.find(_selected_tool_id)
	var next := 0 if current < 0 else posmod(current + step, ids.size())
	select_tool(ids[next])


func _ray_at_pointer(pos: Vector2) -> Dictionary:
	var vp := _to_viewport(pos)
	var origin := _camera.project_ray_origin(vp)
	var dir := _camera.project_ray_normal(vp)
	return _object.ray_test_surface(origin, dir)


func _pointer_over_viewport(pos: Vector2) -> bool:
	return _viewport_container.get_global_rect().has_point(pos)


func _to_viewport(pos: Vector2) -> Vector2:
	return pos - _viewport_container.get_global_rect().position


func _grab_initial_focus() -> void:
	if not _instance_selector.disabled:
		_instance_selector.grab_focus()
	else:
		_close_button.grab_focus()


func _on_instance_selected(index: int) -> void:
	if index >= 0 and index < _instance_uids.size():
		load_instance(_instance_uids[index])


# --- Input map ---------------------------------------------------------------


## Registers restoration Input Map actions at runtime (idempotent) so the view
## works with keyboard and controller without requiring hand-edited project.godot
## InputEvent serialization. A full remap UI is a later input/accessibility phase.
func _ensure_input_actions() -> void:
	_add_action("restoration_rotate_left", [_key(KEY_A)], [_joy_axis(JOY_AXIS_LEFT_X, -1.0)])
	_add_action("restoration_rotate_right", [_key(KEY_D)], [_joy_axis(JOY_AXIS_LEFT_X, 1.0)])
	_add_action("restoration_rotate_up", [_key(KEY_W)], [_joy_axis(JOY_AXIS_LEFT_Y, -1.0)])
	_add_action("restoration_rotate_down", [_key(KEY_S)], [_joy_axis(JOY_AXIS_LEFT_Y, 1.0)])
	# Cleaning is mouse/controller only now; Space is the global pause key.
	_add_action("restoration_clean", [], [_joy_button(JOY_BUTTON_A)])
	_add_action("restoration_open", [_key(KEY_E)], [_joy_button(JOY_BUTTON_X)])
	_add_action("restoration_reset_view", [_key(KEY_R)], [_joy_button(JOY_BUTTON_Y)])
	_add_action("restoration_toggle_mode", [_key(KEY_TAB)], [_joy_button(JOY_BUTTON_LEFT_SHOULDER)])
	_add_action("restoration_cycle_tool", [_key(KEY_Q)], [_joy_button(JOY_BUTTON_RIGHT_SHOULDER)])
	# Esc closes the bench; Space is the pause menu (both registered by PauseMenu).
	_add_action("back", [_key(KEY_ESCAPE)], [])


func _add_action(action: String, keys: Array, pads: Array) -> void:
	if InputMap.has_action(action):
		return
	InputMap.add_action(action)
	for ev in keys:
		InputMap.action_add_event(action, ev)
	for ev in pads:
		InputMap.action_add_event(action, ev)


func _key(keycode: Key) -> InputEventKey:
	var ev := InputEventKey.new()
	ev.physical_keycode = keycode
	return ev


func _joy_button(button: JoyButton) -> InputEventJoypadButton:
	var ev := InputEventJoypadButton.new()
	ev.button_index = button
	return ev


func _joy_axis(axis: JoyAxis, value: float) -> InputEventJoypadMotion:
	var ev := InputEventJoypadMotion.new()
	ev.axis = axis
	ev.axis_value = value
	return ev
