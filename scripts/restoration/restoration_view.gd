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
## Drag distance between decal scrub steps. Smaller than the surface threshold so scrubbing
## discrete marks feels responsive; purely an ergonomics knob — it changes how far you drag
## per cleaning step, NOT how many steps (or how much tool wear) a decal costs.
const DECAL_STROKE_PIXEL_THRESHOLD: float = 40.0
## Debug tool ids (data/objects/tools.json) that operate on the DrawableTexture2D paint layer
## instead of cleaning: DRAW stamps grime, ERASE paints the clean surface back. Both use a
## circular, radius-sized brush (the PNG fills the disc for draw; a clean disc for erase).
const DRAW_TOOL_ID: String = "debug_brush"
const ERASE_TOOL_ID: String = "debug_eraser"
## Drag distance between drawn stamps while painting with a debug brush.
const PAINT_BRUSH_THROTTLE: float = 22.0
## Brush radius in paint-layer texels (the disc the PNG fills). The whole radius is textured by the
## brush image, not a pasted rectangle.
const PAINT_RADIUS: int = 48
## texture_blit shader that SUBTRACTS the brush alpha from the paint layer, so the eraser removes
## the drawn overlay (revealing the artifact's own texture) rather than painting a colour over it.
## (shader_type texture_blit / COLOR0 / hint_blit_source0 verified against the local 4.7 compiler.)
const ERASE_BLIT_SHADER := "shader_type texture_blit;\nrender_mode blend_sub;\nuniform sampler2D src : hint_blit_source0;\nvoid blit() {\n\tCOLOR0 = texture(src, UV);\n}\n"

## Artifact zoom — the ARTIFACT moves toward (zoom in) or away from (zoom out) the camera
## along its view axis, so the player can lean a piece in to inspect fine grime or push it
## back for the whole shape. The camera never moves. Presentation only; never touches game
## state. ZOOM_FRONT/BACK are the object's nearest/farthest position.z; the authored rest
## position is the starting point and what reset returns to.
const ZOOM_FRONT: float = 2.45  ## Closest the artifact comes to the camera (camera sits at z≈2.6).
const ZOOM_BACK: float = -1.5  ## Farthest the artifact pulls back (more zoom-out range too).
const ZOOM_NEAR_MARGIN: float = 0.15  ## Gap kept between the artifact's nearest point and the camera.
const ZOOM_WHEEL_STEP: float = 0.25  ## Distance one mouse-wheel notch moves the artifact.
const ZOOM_KEY_SPEED: float = 2.2  ## Distance/second for held keyboard/controller zoom.

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
## True while the current press-drag is a decal scrub (photos / conditions) rather than a
## surface dirt-mask stroke, so motion routes to per-decal cleaning instead of mask painting.
var _decal_stroke: bool = false
## True while the current press-drag is a debug paint brush (draw or erase) on the paint layer.
var _paint_stroke: bool = false
## True while the current press-drag is a REAL tool cleaning the authored condition overlays.
var _overlay_stroke: bool = false
## Circular condition-PNG brushes for the debug draw tool, the erase disc, and the blend_sub blit
## material the eraser uses. Built lazily on first debug-paint use (_ensure_paint_brushes).
var _draw_brushes: Array[Texture2D] = []
var _erase_brush: Texture2D
var _erase_material: ShaderMaterial
var _brushes_ready: bool = false
var _paint_rng := RandomNumberGenerator.new()
var _stroke_pixels: float = 0.0
var _last_pointer: Vector2 = Vector2.ZERO
var _stroke_uvs: PackedVector2Array = PackedVector2Array()
var _instance_uids: Array[String] = []
## Per-instance dirt-mask snapshots so switching artifacts mid-clean and back
## restores the exact spots the player cleaned (condition alone can't rebuild them).
## Decal photos persist their own removed_decals, so only condition-based masks
## are cached. Lives for the view's lifetime (survives close/reopen of the bench).
var _dirt_cache: Dictionary = {}
## Per-instance overlay cleaning progress (uid -> {overlay_name: keep array}), so switching artifacts
## and returning keeps how much of each condition the player has cleaned (the spawn pattern itself
## regenerates deterministically from the instance seed).
var _overlay_cache: Dictionary = {}
## Auto-finish rule (REST): once the surface is ≥95% clean AND has been so for AUTO_FINISH_HOLD_S
## real seconds, the next clean stroke snaps to 100%; ≥98% snaps immediately. This timestamps when
## the CURRENT artifact first crossed 95% in the session (-1 = not yet / fell back below 95%).
const AUTO_FINISH_HOLD_S: float = 30.0
const AUTO_FINISH_NEAR: float = 0.95
const AUTO_FINISH_SNAP: float = 0.98
var _overlay_at95_ms: int = -1
var _scanner_screen: ScannerScreen
var _journal_viewport: BookViewport
var _phone: Phone
var _storage_screen: StorageScreen
## Captured base scale of each bench prop (so hover-grow is relative, not absolute).
var _prop_base_scales: Dictionary = {}
## Resource path of the scene `_object` currently uses, so we only swap when it changes.
var _object_scene_path: String = "res://scenes/restoration/restoration_artifact.tscn"
## Artifact zoom: the authored rest position.z (captured on ready) and the current position.z.
## Clamped to [ZOOM_BACK, ZOOM_FRONT]; reset returns to the rest position.
var _zoom_rest_z: float = 0.0
var _zoom_z: float = 0.0
var _highlight_time: float = 0.0  ## Drives the optional decal-highlight throb.
var _overlay_highlight_time: float = 0.0  ## Drives the 3-second overlay glow pulse.
## Left-edge 2D tool rack (replaces the 3D bench tool props; see CLAUDE.md REST-R9). Built
## in code and added to the HUD on ready.
var _tool_sidebar: ToolSidebar
## The held tool's 3D model, floating at the cursor while a tool is selected (Trash-Goblin
## style). Lives on its own high CanvasLayer + SubViewport (via Preview3DCard) so it always
## draws in front and never clips with the bench artifacts. Presentation only.
var _cursor_tool: Preview3DCard
## The held tool's authored CleanPoint marker (its working tip), aligned to the mouse each frame.
var _cursor_clean_point: Node3D
var _cursor_layer: CanvasLayer
## Cursor-lean state: last pointer position (for velocity) and the current eased lean angle.
var _prev_cursor_pos: Vector2 = Vector2.ZERO
var _cursor_tilt: float = 0.0

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
	_paint_rng.randomize()
	# Circular brushes are built lazily on first debug-paint use (see _ensure_paint_brushes) so
	# the per-pixel brush construction never burdens normal play or the test suite.
	# Remember the artifact's authored distance so zoom is relative to it and reset returns here.
	_zoom_rest_z = _object.position.z
	_zoom_z = _zoom_rest_z
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
	_build_tool_sidebar()
	_build_cursor_tool()
	# Tools now live in the 2D sidebar: hide the 3D bench tray and the old fallback-button
	# row, but keep building them (off-screen) so existing selection plumbing/tests are intact.
	_tool_tray.visible = false
	var tool_row := _tool_container.get_parent()
	if tool_row is CanvasItem:
		(tool_row as CanvasItem).visible = false
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
		if _cursor_tool != null:
			_cursor_tool.visible = false  # its CanvasLayer is independent of this view's visibility
		_set_os_cursor_hidden(false)  # restore the pointer the bench may have hidden
		_release_pause_if_owned()
	closed.emit()


## Snapshots the loaded condition-based artifact's exact dirt mask into the in-memory
## cache and persists it onto the instance (survives save/reload).
func _cache_current_dirt() -> void:
	# Cache the outgoing artifact's overlay cleaning progress (works in any mode).
	if (
		not _selected_uid.is_empty()
		and is_instance_valid(_object)
		and _object.has_method("capture_overlay_keep")
	):
		var state: Dictionary = _object.capture_overlay_keep()
		if not state.is_empty():
			_overlay_cache[_selected_uid] = state
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
	_rebuild_tool_sidebar()
	_tool_tray.set_selected(_selected_tool_id)


func _on_storage_closed_from_bench() -> void:
	_rebuild_tool_palette()
	var tools := _service.get_workbench_tools()
	_tool_tray.build_slots(_service.get_workbench_slots(), _service.get_workbench_durability())
	_rebuild_tool_sidebar()
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
# Per-template authored scenes live in ArtifactScenes (shared with the triage screen).
const ArtifactScenes := preload("res://scripts/restoration/artifact_scenes.gd")


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
			var preview_scene: PackedScene = ArtifactScenes.scene_for(template.id, ARTIFACT_OBJECT_SCENE)
			var preview: RestorationObject3D = preview_scene.instantiate()
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
## Swaps the bench object to `template_id`'s authored scene (if mapped) or the default
## placeholder. Reassigns `_object`; the view holds no signals on it, so this is safe.
func _ensure_object_for(template_id: String) -> void:
	var scene: PackedScene = ArtifactScenes.scene_for(template_id, ARTIFACT_OBJECT_SCENE)
	if scene.resource_path == _object_scene_path:
		return
	var world := _object.get_parent()
	var pivot_origin := _object.transform.origin
	world.remove_child(_object)
	_object.queue_free()
	var fresh: RestorationObject3D = scene.instantiate()
	fresh.name = "ObjectPivot"
	world.add_child(fresh)
	# Keep the bench pivot POSITION but preserve the artifact scene's own authored basis
	# (which carries the dev's root scale) instead of overwriting the whole transform — the
	# orientation system folds that scale back in on every rotate/reset.
	fresh.position = pivot_origin
	_object = fresh
	_object_scene_path = scene.resource_path


func load_instance(uid: String) -> void:
	# Preserve where the player cleaned on the outgoing artifact before switching.
	_cache_current_dirt()
	_selected_uid = uid
	_selected_tool_id = ""
	_reset_zoom()  # each artifact starts at the authored rest distance
	var inst := _service.find_instance_by_id(uid)
	var template: ScrapObjectTemplate = (
		_service.get_repository().get_template(inst.template_id) if inst != null else null
	)
	if inst == null or template == null:
		_show_invalid_state()
		return
	# Swap the bench object to this artifact's own scene (custom model) if one is mapped.
	_ensure_object_for(template.id)
	# Per-instance seed so a shared placed decal scatters/cleans independently per
	# artifact; folding in the loop index re-rolls which random conditions appear each loop.
	var instance_seed := _artifact_seed(uid)
	_overlay_at95_ms = -1  # the auto-finish 95%-hold timer is per-artifact-session
	_object.visible = true
	if _object.has_method("clear_paint"):
		_object.clear_paint()  # drawn debug grime doesn't carry between artifacts
	if not _present_object(_object, inst, template, instance_seed):
		# No condition decals: restore the cleaned spots from this session or the save.
		if _dirt_cache.has(uid):
			_object.restore_dirt_png(_dirt_cache[uid])
		elif not inst.dirt_mask.is_empty():
			_object.restore_dirt_png(inst.dirt_mask)
	# Authored condition overlays (dust/rust/cracking nodes) take priority; artifacts without them
	# fall back to the model-agnostic procedural dust shell.
	if _object.has_method("build_overlays"):
		_object.build_overlays(instance_seed)
		# Restore prior cleaning progress for this artifact (the spawn pattern itself is deterministic
		# from instance_seed, so only the player's cleaning needs caching).
		if _overlay_cache.has(uid) and _object.has_method("apply_overlay_keep"):
			_object.apply_overlay_keep(_overlay_cache[uid])
	if not (_object.has_method("has_overlays") and _object.has_overlays()):
		if _object.has_method("build_dust_overlay"):
			_object.build_dust_overlay(instance_seed)
	_title.text = template.display_name
	_set_mode(Mode.ROTATE)
	_rebuild_tool_palette()
	_tool_tray.build_slots(_service.get_workbench_slots(), _service.get_workbench_durability())
	_rebuild_tool_sidebar()
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


# --- 2D tool sidebar (REST-R9: tools as numbered rows, not 3D bench props) ----


func _build_tool_sidebar() -> void:
	# The sidebar is an authored node under HUD (see restoration_view.tscn) so its placement is
	# editable. Accept either the "LeftSideBar" or legacy "ToolSidebar" unique name.
	for unique_name in ["%LeftSideBar", "%ToolSidebar"]:
		var node := get_node_or_null(unique_name)
		if node is ToolSidebar:
			_tool_sidebar = node
			_tool_sidebar.tool_clicked.connect(toggle_tool)
			return


## Rebuilds the sidebar rows from the current bench loadout, durability, and each tool's
## cleaning conditions. Mirrors the (now hidden) 3D tray so both stay in lockstep.
func _rebuild_tool_sidebar() -> void:
	if _tool_sidebar == null:
		return
	var repo := _service.get_repository()
	var provider := func(tool_id: String) -> Array: return CleaningPower.conditions_for(repo, tool_id)
	_tool_sidebar.build_slots(
		_service.get_workbench_slots(), _service.get_workbench_durability(), provider
	)
	_tool_sidebar.set_selected(_selected_tool_id)


# --- Cursor-following held tool (Trash-Goblin style) -------------------------


const CURSOR_TOOL_SIZE: int = 100
## Velocity-based lean: the held tool tilts toward the direction of horizontal mouse movement
## (more the faster it moves) and eases back to upright when the cursor stops. Flip the sign of
## CURSOR_TILT_SENSITIVITY if the lean direction feels reversed.
const CURSOR_TILT_MAX_DEG: float = 18.0
const CURSOR_TILT_SENSITIVITY: float = 0.00022  ## radians of lean per (pixel/second) of speed
const CURSOR_TILT_RETURN: float = 12.0  ## how fast the lean eases toward its target
## Screen-pixel nudge of the held tool relative to the cursor (negative x = left), to correct
## models whose visible centre sits off the card centre.
const CURSOR_OFFSET: Vector2 = Vector2(-16.0, 0.0)


func _build_cursor_tool() -> void:
	# Its own high CanvasLayer so the held tool always draws in front of the bench + HUD and,
	# rendering in the Preview3DCard's separate 3D world, never clips with the bench artifact.
	_cursor_layer = CanvasLayer.new()
	_cursor_layer.name = "CursorToolLayer"
	_cursor_layer.layer = 128
	add_child(_cursor_layer)

	_cursor_tool = preload("res://scenes/restoration/preview_3d_card.tscn").instantiate()
	_cursor_tool.name = "CursorTool"
	_cursor_tool.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	_cursor_tool.visible = false
	_cursor_layer.add_child(_cursor_tool)
	# Trim the big-card min sizes down to a tight square, hide the name, and make the whole
	# subtree mouse-transparent so clicks fall through to the bench props (phone/journal/box).
	_cursor_tool.custom_minimum_size = Vector2.ZERO
	_cursor_tool.size = Vector2(CURSOR_TOOL_SIZE, CURSOR_TOOL_SIZE)
	var preview_container := _cursor_tool.find_child("PreviewContainer", true, false)
	if preview_container is Control:
		(preview_container as Control).custom_minimum_size = Vector2(CURSOR_TOOL_SIZE, CURSOR_TOOL_SIZE)
	var name_label := _cursor_tool.find_child("NameLabel", true, false)
	if name_label is Control:
		(name_label as Control).visible = false
		(name_label as Control).custom_minimum_size = Vector2.ZERO
	_set_subtree_ignore_mouse(_cursor_tool)
	_cursor_tool.set_spin(false)  # the held tool holds still and orients to the artifact


## Loads the held tool's model into the cursor follower (or hides it when none is held).
func _set_cursor_tool(tool_id: String) -> void:
	if _cursor_tool == null:
		return
	if tool_id.is_empty():
		_cursor_tool.visible = false
		_cursor_clean_point = null
		return
	var model := RestorationTool.build_tool_model(tool_id)
	_cursor_tool.set_preview(model, "", Color.WHITE, RestorationTool.display_fill(tool_id))
	_cursor_tool.set_spin(false)
	# The dev-placed CleanPoint marks the tool's working tip; we line it up with the mouse each frame.
	_cursor_clean_point = model.find_child("CleanPoint", true, false)


## Each frame: centre the held-tool model on the cursor while the pointer is inside the
## artifact area (not over the top/bottom bars or side panels), and orient it toward the
## artifact (clamped so it never flips upside down). It stops following — and hides — the
## moment the pointer leaves that area.
func _update_cursor_tool(delta: float) -> void:
	if _cursor_tool == null:
		return
	var pos := get_viewport().get_mouse_position()
	var show := (
		not _selected_tool_id.is_empty()
		and _pointer_in_artifact_area(pos)
		and not _cursor_blocked_by_overlay()
	)
	if show != _cursor_tool.visible:
		_cursor_tool.visible = show
		# The tool's CleanPoint tip now sits at the cursor, so hide the OS pointer while it shows.
		_set_os_cursor_hidden(show)
	if not show:
		_prev_cursor_pos = pos  # avoid a velocity spike when it reappears
		return
	# The held tool zooms with the artifact: scale the cursor card by the same distance ratio
	# the artifact gains/loses when the player zooms it in or out.
	var mult := _cursor_zoom_multiplier()
	_cursor_tool.scale = Vector2(mult, mult)
	# Line the tool's authored CleanPoint (its working tip) up with the mouse, so the cleaning — which
	# happens at the mouse — visually comes from the tip. Falls back to the card centre if none.
	var marker_local := Vector2(CURSOR_TOOL_SIZE, CURSOR_TOOL_SIZE) * 0.5
	if _cursor_clean_point != null and is_instance_valid(_cursor_clean_point):
		marker_local = _cursor_tool.project_to_card(_cursor_clean_point.global_position)
	_cursor_tool.position = pos - marker_local * mult
	# Lean toward the direction of horizontal motion (scaled by speed), easing back to upright
	# when the cursor stops.
	var velocity_x := (pos.x - _prev_cursor_pos.x) / maxf(delta, 0.0001)
	var limit := deg_to_rad(CURSOR_TILT_MAX_DEG)
	var target := clampf(-velocity_x * CURSOR_TILT_SENSITIVITY, -limit, limit)
	_cursor_tilt = lerpf(_cursor_tilt, target, clampf(CURSOR_TILT_RETURN * delta, 0.0, 1.0))
	_cursor_tool.set_facing_angle(_cursor_tilt)
	_prev_cursor_pos = pos


## How much bigger/smaller the held tool should render than its rest size, tracking the
## artifact's zoom: closer artifact (zoomed in) -> larger tool, and vice versa.
func _cursor_zoom_multiplier() -> float:
	if not is_instance_valid(_camera):
		return 1.0
	var cam_z := _camera.position.z
	var dist_now := maxf(cam_z - _zoom_z, 0.1)
	var dist_rest := maxf(cam_z - _zoom_rest_z, 0.1)
	return clampf(dist_rest / dist_now, 0.6, 2.4)


func _set_os_cursor_hidden(hidden: bool) -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN if hidden else Input.MOUSE_MODE_VISIBLE)


## True when a full-screen overlay opened from the bench (scanner, phone, storage, journal)
## is up — the held tool must not float over it (its CanvasLayer sits above everything).
func _cursor_blocked_by_overlay() -> bool:
	if _scanner_screen != null and _scanner_screen.visible:
		return true
	if _phone != null and _phone.visible:
		return true
	if _storage_screen != null and _storage_screen.visible:
		return true
	if _journal_viewport != null and _journal_viewport.is_open():
		return true
	return false


## Recursively makes a subtree mouse-transparent so it never intercepts pointer input.
func _set_subtree_ignore_mouse(node: Node) -> void:
	if node is Control:
		(node as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in node.get_children():
		_set_subtree_ignore_mouse(child)


## True when `pos` is over the central 3D artifact area: inside the viewport but NOT over the
## top bar, bottom panel, condition meters, artifact strip, or the tool sidebar.
func _pointer_in_artifact_area(pos: Vector2) -> bool:
	if not _pointer_over_viewport(pos):
		return false
	for path in ["HUD/TopBar", "HUD/BottomPanel", "HUD/RightSideBar", "HUD/ArtifactBar"]:
		var node := get_node_or_null(path)
		if node is Control and (node as Control).visible:
			if (node as Control).get_global_rect().has_point(pos):
				return false
	if _tool_sidebar != null and _tool_sidebar.visible:
		if _tool_sidebar.get_global_rect().has_point(pos):
			return false
	return true


## Selects an owned tool to clean with. Public so the Shop/tests can drive it.
func select_tool(tool_id: String) -> void:
	_selected_tool_id = tool_id
	_log("select_tool(%s) -> mode CLEAN" % tool_id)
	# The sidebar is the primary selection surface; the (hidden) 3D tray + HUD buttons
	# stay in sync as accessibility/fallback. The held tool also floats at the cursor.
	_tool_tray.set_selected(tool_id)
	_tool_sidebar.set_selected(tool_id)
	_set_cursor_tool(tool_id)
	for child in _tool_container.get_children():
		if child is Button:
			child.button_pressed = (child as Button).text == _tool_display_name(tool_id)
	# Selecting a tool moves the player into cleaning; they can switch back to
	# Rotate (mode toggle / right-drag / rotate keys) to inspect again.
	_set_mode(Mode.CLEAN)
	if tool_id == DRAW_TOOL_ID:
		_caption_label.text = "Debug draw brush — drag across the surface to draw grime."
		return
	if tool_id == ERASE_TOOL_ID:
		_caption_label.text = "Debug eraser — drag across the surface to wipe it clean."
		return
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
	var res := _service.register_authored_clean(
		_selected_uid, _selected_tool_id, total, done, cleaned
	)
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


## Shows/hides the separate "Surface cleaned" caption + bar (hidden for overlay artifacts, whose clean
## % lives in the Condition meter instead).
func _set_surface_meter_visible(show: bool) -> void:
	_surface_bar.visible = show
	var caption := get_node_or_null("HUD/RightSideBar/Margin/VBox/SurfaceCaption")
	if caption is CanvasItem:
		(caption as CanvasItem).visible = show


func _refresh(inst: ObjectInstance, template: ScrapObjectTemplate) -> void:
	# Keep the bench durability bars current after any action that may have worn a tool.
	_tool_tray.update_durability(_service.get_workbench_durability())
	if _tool_sidebar != null:
		_tool_sidebar.update_durability(_service.get_workbench_durability())
	var threshold := template.clean_completion_threshold if template != null else 100
	_state_label.text = "State: %s" % ModelEnums.obj_state_name(inst.state).capitalize()
	var is_overlay := _object.has_method("has_overlays") and _object.has_overlays()
	if is_overlay:
		# The Condition meter IS the live clean % for overlay artifacts; the separate Surface bar
		# is hidden (one bar, no redundant 0/100).
		var pct: float = _object.overlay_clean_percent() * 100.0
		_condition_bar.max_value = 100
		_condition_bar.value = pct
		_condition_label.text = "Condition %d%%" % int(round(pct))
	else:
		_condition_bar.max_value = threshold
		_condition_bar.value = inst.condition
		_condition_label.text = "Condition %d / %d" % [int(inst.condition), threshold]
	_set_surface_meter_visible(not is_overlay)
	# Show the coverage-based market value (true value minus live condition penalties) so the
	# player watches the price climb as they clean. Pre-revamp instances fall back to inst.value.
	var shown_value := (
		ValueModel.current_value(inst, template, _service.get_repository())
		if inst.true_value > 0
		else inst.value
	)
	_value_label.text = "Value: P%d" % shown_value

	if _object.is_photo_mode():
		_refresh_photo(inst, template)
		return

	if is_overlay:
		pass  # the Condition meter above already shows the clean %
	elif _object.has_authored_conditions():
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
	_clasp_prompt.visible = false
	# The bench tools (and their durability/condition panels) still show even with no
	# artifact on the bench, so the player can inspect their kit.
	_rebuild_tool_palette()
	_tool_tray.build_slots(_service.get_workbench_slots(), _service.get_workbench_durability())
	_rebuild_tool_sidebar()


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
	if _tool_sidebar != null:
		_tool_sidebar.set_selected("")
	_set_cursor_tool("")
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
	_reset_zoom()


## Orbits the displayed object. Presentation only — never mutates game state.
func rotate_view(delta_yaw: float, delta_pitch: float) -> void:
	_object.rotate_view(delta_yaw, delta_pitch)


## Moves the artifact toward the camera (amount > 0 = zoom in) or away (amount < 0). The near limit is
## DYNAMIC: a big artifact stops sooner so its nearest point never pushes through the camera. The camera
## never moves — only the artifact.
func zoom_by(amount: float) -> void:
	_zoom_z = clampf(_zoom_z + amount, ZOOM_BACK, _zoom_front_limit())
	_object.position.z = _zoom_z


## Nearest zoom position.z that keeps the artifact's front face clear of the camera. = camera.z minus a
## small near-plane margin minus the artifact's bounding radius (so its closest point can't reach the
## camera at any rotation). Capped at ZOOM_FRONT so small artifacts still have a sane closest distance.
func _zoom_front_limit() -> float:
	if not is_instance_valid(_camera) or not is_instance_valid(_object):
		return ZOOM_FRONT
	var radius := 0.0
	if _object.has_method("view_bounding_radius"):
		radius = _object.view_bounding_radius()
	return minf(ZOOM_FRONT, _camera.position.z - ZOOM_NEAR_MARGIN - radius)


## Current artifact zoom position.z (test/integration seam).
func zoom_offset() -> float:
	return _zoom_z


## Returns the artifact to its authored rest position (on reset and artifact swap), but never closer than
## the dynamic near limit — so a big artifact doesn't start out clipping into the camera.
func _reset_zoom() -> void:
	_zoom_z = minf(_zoom_rest_z, _zoom_front_limit())
	if is_instance_valid(_object):
		_object.position.z = _zoom_z


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
	# Keyboard/controller zoom (held): in pulls the camera closer, out pushes it back.
	var zoom := (
		Input.get_action_strength("restoration_zoom_in")
		- Input.get_action_strength("restoration_zoom_out")
	)
	if zoom != 0.0:
		zoom_by(zoom * ZOOM_KEY_SPEED * delta)
	_update_decal_highlight(delta)
	_update_overlay_highlight(delta)
	_update_cursor_tool(delta)


## Optional learning aid (settings, default off): throbs the conditions the selected tool
## can clean. When the setting is off or no tool is held, conditions are left calm.
func _update_decal_highlight(delta: float) -> void:
	if not is_instance_valid(_object) or not _object.has_method("highlight_for_tool"):
		return
	if not SettingsService.decal_highlight_enabled() or _selected_tool_id.is_empty():
		_object.highlight_for_tool("", 0.0)
		return
	_highlight_time += delta
	var pulse := 0.5 + 0.5 * sin(_highlight_time * 5.0)
	_object.highlight_for_tool(_selected_tool_id, pulse)


## Pulses the artifact's condition overlays the held tool can clean — a brief glow every ~3 seconds
## so the player can spot, say, dust on a silver artifact (same colour) when a dust tool is equipped.
func _update_overlay_highlight(delta: float) -> void:
	if not is_instance_valid(_object) or not _object.has_method("highlight_overlays"):
		return
	if _selected_tool_id.is_empty() or _is_paint_tool(_selected_tool_id):
		_object.highlight_overlays({}, 0.0)
		return
	_overlay_highlight_time += delta
	# A sharp glow that peaks once every 3 seconds, near-dark in between.
	var phase := fposmod(_overlay_highlight_time, 3.0) / 3.0
	var pulse := pow(maxf(0.0, sin(phase * PI)), 3.0)
	_object.highlight_overlays(_tool_clean_params(_selected_tool_id)["cleans"], pulse)


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
	# Number keys 1-5 select the tool sitting in that bench slot.
	for slot in RestorationToolTray.SLOT_COUNT:
		if event.is_action_pressed("restoration_tool_slot_%d" % (slot + 1)):
			_select_tool_slot(slot)
			return true
	return false


## Selects the bench tool in slot `slot` (0-based), bound to number keys 1-5. A no-op for
## an empty or unowned slot, so a stray keypress can't clear the current tool.
func _select_tool_slot(slot: int) -> void:
	var slots := _service.get_workbench_slots()
	if slot < 0 or slot >= slots.size():
		return
	var tool_id := String(slots[slot])
	if tool_id.is_empty() or not _service.is_tool_owned(tool_id):
		return
	select_tool(tool_id)


func _handle_mouse_button(event: InputEventMouseButton) -> void:
	var pos := event.position
	# Mouse wheel zooms the artifact in/out. Fires as a pressed button event.
	if event.button_index == MOUSE_BUTTON_WHEEL_UP:
		if event.pressed:
			zoom_by(ZOOM_WHEEL_STEP)  # wheel up → artifact comes closer
		return
	if event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
		if event.pressed:
			zoom_by(-ZOOM_WHEEL_STEP)  # wheel down → artifact pulls back
		return
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
			_last_pointer = pos
			_left_down = true
			if _mode != Mode.CLEAN:
				return
			# The debug brushes PAINT the surface paint layer (draw grime / erase) instead of cleaning.
			if _is_paint_tool(_selected_tool_id):
				_begin_paint_stroke(pos)
			# Artifacts with authored condition overlays: a REAL tool cleans the overlay layers it can.
			elif _object.has_method("has_overlays") and _object.has_overlays():
				_begin_overlay_stroke(pos)
			# Decal-based artifacts (photos, random conditions, author-placed event
			# conditions) now clean by DRAGGING the tool across the grime (Trash-Goblin
			# style) rather than single clicks; a pure dirt-mask object keeps its surface
			# stroke (also drag-based). Either way a quick click still cleans one step.
			elif _object.is_decal_mode() or _object.has_authored_conditions():
				_begin_decal_stroke(pos)
			else:
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
		if _paint_stroke:
			_accumulate_paint_stroke(pos)
		elif _overlay_stroke:
			_accumulate_overlay_stroke(pos)
		elif _decal_stroke:
			_accumulate_decal_stroke(pos)
		else:
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
	# The 3D tray is hidden (tools live in the sidebar); don't hover/pick its bench props.
	var tool_id := _tool_tray.ray_pick(origin, dir) if _tool_tray.visible else ""
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
	_decal_stroke = false
	_paint_stroke = false
	_overlay_stroke = false
	_stroke_active = true
	_stroke_pixels = 0.0
	_stroke_uvs.clear()
	_last_pointer = pos
	_add_stroke_sample(pos)


# --- Debug draw brush (texture drawing via the DrawableTexture2D paint layer) -------------


## Begins a press-drag that DRAWS grime onto the surface with the debug brush. Dragging stamps
## a random condition PNG at a random size along the path, so the drawn grime varies in size and
## shape — the texture-drawing test. Painting targets the surface UV, so it works on the
## dirt-mask medallion (artifacts without an authored model covering it).
func _begin_paint_stroke(pos: Vector2) -> void:
	_paint_stroke = true
	_decal_stroke = false
	_overlay_stroke = false
	_stroke_active = true
	_stroke_pixels = 0.0
	_last_pointer = pos
	_paint_at_pointer(pos)


# --- Real tools cleaning the authored condition overlays ----------------------


## Begins a press-drag where the selected REAL tool cleans the artifact's condition overlays. The tool
## removes only the conditions its config lists (each at its Power), at its clean_radius.
func _begin_overlay_stroke(pos: Vector2) -> void:
	_overlay_stroke = true
	_paint_stroke = false
	_decal_stroke = false
	_stroke_active = true
	_stroke_pixels = 0.0
	_last_pointer = pos
	_clean_overlay_with_tool(pos)


func _accumulate_overlay_stroke(pos: Vector2) -> void:
	_stroke_pixels += pos.distance_to(_last_pointer)
	_last_pointer = pos
	if _stroke_pixels >= PAINT_BRUSH_THROTTLE:
		_stroke_pixels = 0.0
		_clean_overlay_with_tool(pos)


## One step of overlay cleaning with the selected tool: cleans the outermost layer under the pointer
## the tool can fix, then routes durability + condition/value through register_authored_clean (reused
## from the authored-decal path) so the clean->open gate, tool wear, and value all work unchanged.
func _clean_overlay_with_tool(pos: Vector2) -> void:
	if _selected_tool_id.is_empty():
		_caption_label.text = "Pick up a tool from the bench first."
		return
	var params := _tool_clean_params(_selected_tool_id)
	var origin := _camera.project_ray_origin(_to_viewport(pos))
	var dir := _camera.project_ray_normal(_to_viewport(pos))
	var result := _object.clean_overlays_with_tool(origin, dir, params["cleans"], params["radius"])
	if result.get("cleaned", false):
		# Dust puffs off the artifact at the spot the tool meets it (a 3D burst on the model itself).
		var hit_pt: Variant = result.get("point", null)
		if hit_pt != null and _object.has_method("clean_burst_at_world"):
			_object.clean_burst_at_world(hit_pt)
		var inst := _service.find_instance_by_id(_selected_uid)
		var pct: float = _object.overlay_clean_percent()
		# Track how long the piece has been ≥95% clean this session (-1 once it drops back below).
		if pct >= AUTO_FINISH_NEAR:
			if _overlay_at95_ms < 0:
				_overlay_at95_ms = Time.get_ticks_msec()
		else:
			_overlay_at95_ms = -1
		var held_95_s := (
			float(Time.get_ticks_msec() - _overlay_at95_ms) / 1000.0 if _overlay_at95_ms >= 0 else 0.0
		)
		# Auto-finish: snap to 100% immediately at ≥98%, or once the piece has held ≥95% for
		# AUTO_FINISH_HOLD_S (this next stroke completes it) — so the player isn't chasing specks,
		# but completion is no longer instant the moment the surface looks nearly done.
		var should_finish := (
			pct >= AUTO_FINISH_SNAP
			or (pct >= AUTO_FINISH_NEAR and held_95_s >= AUTO_FINISH_HOLD_S)
		)
		if inst != null and inst.state == ModelEnums.ObjState.DIRTY and should_finish:
			_object.force_clean_overlays(["crack"])
			var fc: Dictionary = _object.overlay_counts()
			_service.register_authored_clean(
				_selected_uid, _selected_tool_id, int(fc.get("total", 0)), int(fc.get("total", 0)), true
			)
			_feedback_label.text = "Spotless!"
		else:
			var counts: Dictionary = _object.overlay_counts()
			_service.register_authored_clean(
				_selected_uid,
				_selected_tool_id,
				int(counts.get("total", 0)),
				int(counts.get("cleaned", 0)),
				bool(result.get("fully_cleaned", false))
			)
			_feedback_label.text = "Working off the %s..." % String(result.get("condition_id", "")).replace("_", " ")
		var inst2 := _service.find_instance_by_id(_selected_uid)
		if inst2 != null:
			_refresh(inst2, _service.get_repository().get_template(inst2.template_id))
	elif result.get("wrong_tool", false):
		_feedback_label.text = "Wrong tool for that layer — try another."


## The selected tool's cleaning params {cleans, radius}: the scene-authored ToolConfig if it lists
## conditions, otherwise the data-driven cleaning power (tools.json + journal catalog).
func _tool_clean_params(tool_id: String) -> Dictionary:
	var cfg := ToolConfig.for_tool(tool_id)
	var cleans: Dictionary = cfg.get("cleans", {})
	var radius: float = float(cfg.get("clean_radius", 0.12))
	if cleans.is_empty():
		cleans = {}
		for entry in CleaningPower.conditions_for(_service.get_repository(), tool_id):
			cleans[String(entry.get("id", ""))] = int(entry.get("power", 0))
	return {"cleans": cleans, "radius": radius}


func _accumulate_paint_stroke(pos: Vector2) -> void:
	_stroke_pixels += pos.distance_to(_last_pointer)
	_last_pointer = pos
	if _stroke_pixels >= PAINT_BRUSH_THROTTLE:
		_stroke_pixels = 0.0
		_paint_at_pointer(pos)


## True for the debug DRAW brush, which paints grime onto the paint layer instead of cleaning.
## The debug ERASER is no longer a paint tool: it routes through the real cleaning paths as a
## universal cleaner (CleaningPower.is_universal_cleaner) so it removes ANY condition for real.
func _is_paint_tool(tool_id: String) -> bool:
	return tool_id == DRAW_TOOL_ID


## Builds the circular brushes + erase material the first time a debug paint tool is used (lazy).
func _ensure_paint_brushes() -> void:
	if _brushes_ready:
		return
	_brushes_ready = true
	_draw_brushes = ConditionBrushes.load_circular()
	_erase_brush = ConditionBrushes.make_erase_disc()
	var shader := Shader.new()
	shader.code = ERASE_BLIT_SHADER
	_erase_material = ShaderMaterial.new()
	_erase_material.shader = shader


## Stamps the current paint brush onto the surface under the pointer as a radius-sized circle:
## a random condition disc when drawing, the clean disc when erasing. No-op on a ray miss or when
## the object has no runtime paint layer (e.g. a photo or an authored model hiding the medallion).
func _paint_at_pointer(pos: Vector2) -> void:
	# The eraser cleans grime where the tool meets the surface: authored overlays (smooth, per-texel)
	# first, then the procedural dust shell fallback.
	if _selected_tool_id == ERASE_TOOL_ID:
		var ray_origin := _camera.project_ray_origin(_to_viewport(pos))
		var ray_dir := _camera.project_ray_normal(_to_viewport(pos))
		if _object.has_method("has_overlays") and _object.has_overlays():
			_object.clean_overlays_ray(ray_origin, ray_dir)
			return
		if _object.has_method("has_dust_overlay") and _object.has_dust_overlay():
			_object.erase_dust_ray(ray_origin, ray_dir)
			return
	if not _object.has_method("paint_at_uv"):
		return
	_ensure_paint_brushes()
	# Draw ADDS grime (random condition disc, default blend_mix); erase SUBTRACTS the overlay
	# (erase disc + blend_sub material) so the artifact's own texture shows through.
	var brush: Texture2D = _erase_brush
	var material: Material = _erase_material
	if _selected_tool_id == DRAW_TOOL_ID:
		if _draw_brushes.is_empty():
			return
		brush = _draw_brushes[_paint_rng.randi_range(0, _draw_brushes.size() - 1)]
		material = null
	if brush == null:
		return
	var hit := _ray_at_pointer(pos)
	if not hit.get("hit", false):
		return
	_object.paint_at_uv(hit["uv"], brush, PAINT_RADIUS, material)


## Begins a press-drag "scrub" over a decal-based artifact (photos, random conditions, or
## author-placed event conditions). Dragging the tool applies repeated cleaning steps at a
## steady cadence so grime wears away as you work across it — the Trash-Goblin feel — instead
## of one click per mark. A clean photo awaiting reassembly joins on the press instead.
func _begin_decal_stroke(pos: Vector2) -> void:
	if _photo_join_at_pointer():
		return
	_decal_stroke = true
	_paint_stroke = false
	_overlay_stroke = false
	_stroke_active = true
	_stroke_pixels = 0.0
	_stroke_uvs.clear()
	_last_pointer = pos
	# A single click still cleans one step (accessibility + parity with the old tap).
	_clean_decal_under_pointer(pos)


## One drag-step of decal scrubbing: every DECAL_STROKE_PIXEL_THRESHOLD pixels of travel,
## clean whatever decal sits under the pointer once. A miss (empty space / already-clean
## mark) cleans nothing and wears nothing, so only contact with grime costs durability.
func _accumulate_decal_stroke(pos: Vector2) -> void:
	_stroke_pixels += pos.distance_to(_last_pointer)
	_last_pointer = pos
	if _stroke_pixels >= DECAL_STROKE_PIXEL_THRESHOLD:
		_stroke_pixels = 0.0
		_clean_decal_under_pointer(pos)


## Cleans the author-placed condition or photo/random blemish under the pointer (authored
## first, then blemish). Returns true when a decal was targeted. Reuses the existing per-decal
## clean paths, so all service rules, wear, and tests are unchanged — only the input is a drag.
func _clean_decal_under_pointer(pos: Vector2) -> bool:
	if _try_authored_condition_at_pointer(pos):
		return true
	var origin := _camera.project_ray_origin(_to_viewport(pos))
	var dir := _camera.project_ray_normal(_to_viewport(pos))
	return attempt_clean_blemish_with_ray(origin, dir)


## True (and performs the join) when the loaded artifact is a clean photo awaiting
## reassembly — a join is a deliberate click, not a scrub, so it never starts a stroke.
func _photo_join_at_pointer() -> bool:
	if not _object.is_photo_mode():
		return false
	var inst := _service.find_instance_by_id(_selected_uid)
	var template := (
		_service.get_repository().get_template(inst.template_id) if inst != null else null
	)
	return (
		inst != null
		and template != null
		and template.requires_join
		and not inst.is_joined
		and inst.state == ModelEnums.ObjState.CLEAN
		and try_join().joined
	)


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
	_decal_stroke = false
	_paint_stroke = false
	_overlay_stroke = false
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


func _try_tool_pick_at_pointer(pos: Vector2) -> bool:
	# Tools are selected from the 2D sidebar now; the 3D tray is hidden. Its props still sit on
	# the bench, so picking them would steal clicks meant for cleaning the artifact.
	if not _tool_tray.visible:
		return false
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
	# Zoom the artifact in/out: +/- (and numpad) on keyboard, the triggers on a controller.
	_add_action(
		"restoration_zoom_in",
		[_key(KEY_EQUAL), _key(KEY_KP_ADD)],
		[_joy_axis(JOY_AXIS_TRIGGER_RIGHT, 1.0)]
	)
	_add_action(
		"restoration_zoom_out",
		[_key(KEY_MINUS), _key(KEY_KP_SUBTRACT)],
		[_joy_axis(JOY_AXIS_TRIGGER_LEFT, 1.0)]
	)
	# Number keys 1-5 select bench tool slots 1-5 (KEY_1..KEY_5 are consecutive keycodes).
	for slot in RestorationToolTray.SLOT_COUNT:
		_add_action("restoration_tool_slot_%d" % (slot + 1), [_key((KEY_1 + slot) as Key)], [])
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
