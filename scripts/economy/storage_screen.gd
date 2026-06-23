class_name StorageScreen
extends CanvasLayer
## Storage: an HSR-style master/detail inventory across three tabs.
##
##   * Artifacts — restorable inventory as a grid of boxes; the left panel shows the
##     selected item's condition, name, and description, with a Restore button
##     (Sell once it has been restored).
##   * Tools     — owned tools as draggable chips; the left panel shows durability
##     and which surface conditions the tool treats. Drag chips onto the five
##     workbench slots to equip; dropping on an occupied slot replaces just that
##     tool, and the hovered slot highlights to show where the drop will land. Drag
##     a chip back out to unequip.
##   * Key Items — quest artifacts (restorable like ordinary ones) and the five
##     fragments with their lifecycle state.
##
## Presentation only. Loadout/restore-target rules live in ToolService; selling and
## inventory/fragment state are read from GameState. The UI is built in code so the
## scene file stays trivial. Public methods (open/close/refresh/select_artifact/
## toggle_tool/owns_pause) are the stable seams the GUT tests drive.

signal closed
## Emitted when the player presses Restore on an artifact, so the shop can open the
## workbench on the chosen target.
signal restore_requested(uid: String)

const DETAIL_WIDTH: float = 360.0
const BOX_MIN: Vector2 = Vector2(164, 196)
const SLOT_MIN: Vector2 = Vector2(164, 196)
const DRAG_KIND: String = "storage_tool"

## Rotating 3D preview card + the artifact model, shared with the restoration bench.
const PREVIEW_CARD_SCENE := preload("res://scenes/restoration/preview_3d_card.tscn")
const ARTIFACT_OBJECT_SCENE := preload("res://scenes/restoration/restoration_artifact.tscn")
const PREVIEW_SCALE: float = 0.46

var _owns_pause: bool = false
var _tools: ToolService
var _restoration: RestorationService
var _selected_artifact_uid: String = ""  ## Shared by the Artifacts + Key Items detail.
var _selected_tool_uid: String = ""

@onready var _tabs: TabContainer = %Tabs
@onready var _status_label: Label = %StatusLabel
@onready var _close_button: Button = %CloseButton


func _ready() -> void:
	visible = false
	_tools = ToolService.new()
	_restoration = RestorationService.new()
	_close_button.pressed.connect(close)


func open() -> void:
	if not visible:
		visible = true
		if not _owns_pause:
			DayClock.request_pause(DayClock.PAUSE_STORAGE)
			_owns_pause = true
	refresh()
	_close_button.grab_focus()


func close() -> void:
	if visible:
		visible = false
		_release_pause_if_owned()
	closed.emit()


func _exit_tree() -> void:
	_release_pause_if_owned()


func _release_pause_if_owned() -> void:
	if _owns_pause and DayClock.has_pause_owner(DayClock.PAUSE_STORAGE):
		DayClock.release_pause(DayClock.PAUSE_STORAGE)
	_owns_pause = false


func _input(event: InputEvent) -> void:
	# Backspace closes Storage; Esc is reserved for the pause menu.
	if visible and event.is_action_pressed("back"):
		close()
		get_viewport().set_input_as_handled()


func owns_pause() -> bool:
	return _owns_pause


# --- Player actions (also test seams) ----------------------------------------


## Chooses which artifact to restore next at the bench.
func select_artifact(uid: String) -> void:
	_tools.set_restore_target(uid)
	SaveService.save_game()
	refresh()


## Restore button: choose the target, close storage, then ask the shop to open the
## bench. Closing first lets the shop's close handler settle before the bench opens.
func request_restore(uid: String) -> void:
	select_artifact(uid)
	close()
	restore_requested.emit(uid)


## Quick-sells a restored artifact at its assessed value. A placeholder for the
## Phase-14 buyer negotiation: it simply credits money and removes the instance.
func sell_artifact(uid: String) -> void:
	var found := _find_inventory(uid)
	if found.is_empty():
		return
	var inst: ObjectInstance = found["inst"]
	var template: ScrapObjectTemplate = found["template"]
	if not _is_restored(inst):
		return
	var price := _sale_price(inst, template)
	GameState.save_state.loop.money += price
	_remove_inventory(uid)
	if _selected_artifact_uid == uid:
		_selected_artifact_uid = ""
	SaveService.save_game()
	_status_label.text = "Sold %s for %s." % [template.display_name, _peso(price)]
	refresh()


## Loads/unloads an owned tool from the bench (max 5). Accessibility fallback for
## the drag-and-drop loadout.
func toggle_tool(uid: String) -> void:
	if GameState.save_state.loop.workbench_tools.has(uid):
		_tools.remove_from_workbench(uid)
	else:
		if not _tools.add_to_workbench(uid):
			_status_label.text = "The bench is full (%d tools)." % ToolService.MAX_WORKBENCH_TOOLS
			return
	SaveService.save_game()
	refresh()


# --- Rendering ---------------------------------------------------------------


func refresh() -> void:
	_clear(_tab("Artifacts"))
	_clear(_tab("Tools"))
	_clear(_tab("Key Items"))
	_build_artifacts_tab()
	_build_tools_tab()
	_build_key_items_tab()
	var loaded: int = _tools.equipped_count()
	var target := _tools.get_restore_target()
	var target_name := _instance_display_name(target) if not target.is_empty() else "nothing"
	if _status_label.text == "":
		_status_label.text = (
			"Bench: %d / %d tools · Restoring: %s · %s"
			% [
				loaded,
				ToolService.MAX_WORKBENCH_TOOLS,
				target_name,
				_peso(GameState.save_state.loop.money)
			]
		)


# --- Artifacts tab -----------------------------------------------------------


func _build_artifacts_tab() -> void:
	var panes := _make_master_detail(_tab("Artifacts"))
	var grid := _make_grid(3)
	(panes["content"] as VBoxContainer).add_child(grid)
	var detail_host: VBoxContainer = panes["detail"]
	var repo := DataRepository.singleton()
	var target := _tools.get_restore_target()
	var any := false
	for raw in GameState.save_state.loop.inventory:
		if not (raw is Dictionary):
			continue
		var inst := ObjectInstance.from_dictionary(raw)
		var template := repo.get_template(inst.template_id)
		if template == null or not template.deliverable:
			continue  # quest-given items live under Key Items.
		any = true
		_add_artifact_card(grid, inst, template, target == inst.uid)
	if not any:
		grid.add_child(_make_note("No restorable artifacts in storage yet."))
	_render_artifact_detail(detail_host, _selected_artifact_uid)


## Adds a rotating 3D preview card for one artifact (model + its condition decals, so
## the player can see what needs restoring). Clicking shows its detail.
func _add_artifact_card(
	grid: GridContainer, inst: ObjectInstance, template: ScrapObjectTemplate, is_target: bool
) -> void:
	var card: Preview3DCard = PREVIEW_CARD_SCENE.instantiate()
	grid.add_child(card)  # in the tree first, so the preview builds in the card's world
	var obj: RestorationObject3D = ARTIFACT_OBJECT_SCENE.instantiate()
	var name_text := template.display_name + ("  ◆" if is_target else "")
	card.set_preview(obj, name_text, _rarity_color(template.base_rarity), PREVIEW_SCALE)
	_restoration.present_object(obj, inst, template, inst.uid.hash())
	var uid := inst.uid
	card.clicked.connect(func() -> void: _show_artifact(uid))


func _show_artifact(uid: String) -> void:
	_selected_artifact_uid = uid
	_status_label.text = ""
	refresh()


func _render_artifact_detail(host: VBoxContainer, uid: String) -> void:
	if uid.is_empty():
		host.add_child(_make_note("Select an artifact to see its details."))
		return
	var found := _find_inventory(uid)
	if found.is_empty():
		host.add_child(_make_note("Select an artifact to see its details."))
		return
	var inst: ObjectInstance = found["inst"]
	var template: ScrapObjectTemplate = found["template"]

	host.add_child(_make_title(template.display_name))
	var meta := (
		"%s · %s"
		% [
			template.category.capitalize(),
			ModelEnums.rarity_name(template.base_rarity).capitalize(),
		]
	)
	host.add_child(_make_sub(meta))
	host.add_child(_make_condition_bar(inst.condition))
	host.add_child(_make_kv("State", _state_word(inst)))
	host.add_child(_make_body(_artifact_description(template)))

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	host.add_child(spacer)

	var action := Button.new()
	action.focus_mode = Control.FOCUS_ALL
	if _is_restored(inst):
		action.text = "Sell for %s" % _peso(_sale_price(inst, template))
		action.pressed.connect(func() -> void: sell_artifact(uid))
	else:
		var is_target := _tools.get_restore_target() == uid
		action.text = "Restoring…" if is_target else "Restore"
		action.pressed.connect(func() -> void: request_restore(uid))
	host.add_child(action)


# --- Tools tab ---------------------------------------------------------------


func _build_tools_tab() -> void:
	var panes := _make_master_detail(_tab("Tools"))
	var detail_host: VBoxContainer = panes["detail"]
	var right: VBoxContainer = panes["content"]

	var loaded: int = _tools.equipped_count()
	var bench_label := "Workbench  —  %d / %d equipped" % [loaded, ToolService.MAX_WORKBENCH_TOOLS]
	right.add_child(_make_sub(bench_label))
	right.add_child(_make_equip_area())
	right.add_child(_make_sub("Owned tools  —  drag onto the bench to equip"))
	right.add_child(_make_owned_area())

	_render_tool_detail(detail_host, _selected_tool_uid)


## The five workbench slots. Each slot is its own drop target that highlights on
## hover and equips/replaces the tool dropped onto it; the surrounding zone is a
## fallback that equips into the first free slot when a drop lands between slots.
func _make_equip_area() -> Control:
	var zone := ToolDropZone.new()
	zone.on_drop = _on_equip_drop
	_style_zone(zone, Color(0.16, 0.18, 0.22, 0.6))
	var grid := GridContainer.new()
	grid.columns = 5
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	zone.add_child(grid)

	var equipped: Array = GameState.save_state.loop.workbench_tools
	for i in range(ToolService.MAX_WORKBENCH_TOOLS):
		var slot := ToolSlot.new()
		slot.slot_index = i
		slot.on_drop_to_slot = _on_slot_drop
		slot.setup(SLOT_MIN, Color(0.08, 0.09, 0.10, 0.5), Color(0.20, 0.34, 0.22, 0.95))
		var inst: ToolInstance = null
		if i < equipped.size():
			inst = _find_owned(ModelUtils.as_string(equipped[i]))
		if inst != null:
			slot.occupant_uid = inst.uid
			slot.add_child(_make_tool_chip(inst, true))
		else:
			slot.add_child(_make_slot_placeholder())
		grid.add_child(slot)
	return zone


## Owned tools that are not currently on the bench, wrapped in a drop zone that
## unequips a tool dragged out of the workbench.
func _make_owned_area() -> Control:
	var zone := ToolDropZone.new()
	zone.on_drop = _on_unequip_drop
	_style_zone(zone, Color(0.10, 0.11, 0.13, 0.6))
	# A VBox so an empty-state note spans the full width instead of being squeezed
	# into one narrow grid cell (which wraps the text one letter per line).
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	zone.add_child(vbox)
	var grid := _make_grid(5)
	vbox.add_child(grid)

	var owned := _tools.get_owned_tools()
	var shown := 0
	for inst in owned:
		if GameState.save_state.loop.workbench_tools.has(inst.uid):
			continue  # shown in the equip area instead.
		shown += 1
		grid.add_child(_make_tool_chip(inst, false))
	if shown == 0:
		var msg := (
			"No tools owned yet. Buy some from the phone Marketplace."
			if owned.is_empty()
			else "All owned tools are on the bench."
		)
		vbox.add_child(_make_note(msg))
	return zone


func _make_tool_chip(inst: ToolInstance, equipped: bool) -> ToolChip:
	var def := DataRepository.singleton().get_tool(inst.tool_id)
	var chip := ToolChip.new()
	chip.tool_uid = inst.uid
	chip.from_equipped = equipped
	chip.custom_minimum_size = SLOT_MIN
	chip.clip_text = true
	var wear := "∞" if inst.is_infinite() else "%d/%d" % [inst.durability, inst.max_durability]
	var nm := def.display_name if def != null else inst.tool_id
	chip.text = "%s\n%s" % [nm, wear]  # fallback shown when previews are off
	if not inst.is_usable():
		chip.add_theme_color_override("font_color", Color(0.7, 0.4, 0.4))
	# A rotating 3D preview of the tool fills the chip (built in ToolChip._ready, once
	# it is in the tree). Drag/click still go to the chip.
	chip.preview_tool_id = inst.tool_id
	chip.preview_label = "%s\n%s" % [nm, wear]
	chip.preview_color = Color(0.7, 0.4, 0.4) if not inst.is_usable() else Color(0.92, 0.9, 0.84)
	chip.on_drag_out = _on_chip_dragged_out
	var uid := inst.uid
	chip.pressed.connect(func() -> void: _show_tool(uid))
	return chip


## Recursively makes a control subtree transparent to the mouse, so an embedded
## preview never steals clicks/drag from its host chip.
static func ignore_mouse_recursive(node: Node) -> void:
	if node is Control:
		(node as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in node.get_children():
		ignore_mouse_recursive(child)


## An equipped chip dropped outside the workbench unequips.
func _on_chip_dragged_out(uid: String) -> void:
	if GameState.save_state.loop.workbench_tools.has(uid):
		_tools.remove_from_workbench(uid)
		SaveService.save_game()
		_status_label.text = ""  # let the bench summary recompute.
		refresh()


## The "empty slot" interior label shown inside an unoccupied ToolSlot.
func _make_slot_placeholder() -> Control:
	var label := Label.new()
	label.text = "—"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", Color(0.4, 0.4, 0.45))
	return label


func _show_tool(uid: String) -> void:
	_selected_tool_uid = uid
	_status_label.text = ""
	refresh()


func _render_tool_detail(host: VBoxContainer, uid: String) -> void:
	var inst := _find_owned(uid)
	if uid.is_empty() or inst == null:
		host.add_child(_make_note("Select a tool to see what it treats."))
		return
	var def := DataRepository.singleton().get_tool(inst.tool_id)
	host.add_child(_make_title(def.display_name if def != null else inst.tool_id))
	if def != null and def.is_legacy:
		host.add_child(_make_sub("Legacy tool · persists across loops"))
	var wear := "Never wears out"
	if not inst.is_infinite():
		wear = "%d / %d uses left" % [inst.durability, inst.max_durability]
	host.add_child(_make_kv("Durability", wear))

	host.add_child(_make_sub("Treats these conditions:"))
	var treated := _conditions_treated_by(inst.tool_id)
	if treated.is_empty():
		host.add_child(_make_note("No catalogued conditions — a finishing or specialty tool."))
	else:
		for condition in treated:
			host.add_child(_make_kv(condition.display_name, condition.category_label()))

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	host.add_child(spacer)

	var equipped: bool = GameState.save_state.loop.workbench_tools.has(uid)
	var action := Button.new()
	action.focus_mode = Control.FOCUS_ALL
	action.text = "Unequip" if equipped else "Equip"
	action.pressed.connect(func() -> void: toggle_tool(uid))
	host.add_child(action)


func _on_equip_drop(data: Dictionary) -> void:
	var uid := ModelUtils.as_string(data.get("uid"))
	if uid.is_empty() or GameState.save_state.loop.workbench_tools.has(uid):
		return
	if not _tools.add_to_workbench(uid):
		_status_label.text = "The bench is full (%d tools)." % ToolService.MAX_WORKBENCH_TOOLS
		refresh()
		return
	SaveService.save_game()
	_status_label.text = ""  # let the bench summary recompute.
	refresh()


## Drop onto a specific workbench slot: equip into an empty slot, or replace/swap
## the tool already sitting there. Only that one slot changes. A drop onto an
## occupied slot of a full bench replaces that slot's tool rather than failing.
func _on_slot_drop(slot_index: int, data: Dictionary) -> void:
	var uid := ModelUtils.as_string(data.get("uid"))
	if uid.is_empty():
		return
	if not _tools.equip_to_slot(uid, slot_index):
		return  # only fails for a tool the player doesn't own (can't happen via the UI).
	SaveService.save_game()
	_status_label.text = ""  # let the bench summary recompute.
	refresh()


func _on_unequip_drop(data: Dictionary) -> void:
	if not bool(data.get("from_equipped", false)):
		return  # dropping an already-owned chip back onto the shelf is a no-op.
	var uid := ModelUtils.as_string(data.get("uid"))
	_tools.remove_from_workbench(uid)
	SaveService.save_game()
	_status_label.text = ""  # let the bench summary recompute.
	refresh()


# --- Key Items tab -----------------------------------------------------------


func _build_key_items_tab() -> void:
	var panes := _make_master_detail(_tab("Key Items"))
	var grid := _make_grid(3)
	(panes["content"] as VBoxContainer).add_child(grid)
	var detail_host: VBoxContainer = panes["detail"]
	var repo := DataRepository.singleton()

	for raw in GameState.save_state.loop.inventory:
		if not (raw is Dictionary):
			continue
		var inst := ObjectInstance.from_dictionary(raw)
		var template := repo.get_template(inst.template_id)
		if template == null or template.deliverable:
			continue
		_add_artifact_card(grid, inst, template, _tools.get_restore_target() == inst.uid)

	var fragments: Dictionary = GameState.save_state.persistent.fragments
	for fragment_id in fragments.keys():
		grid.add_child(_make_fragment_box(fragments[fragment_id]))

	if grid.get_child_count() == 0:
		grid.add_child(_make_note("No key items in hand yet."))

	# Key Items reuses the artifact detail for quest objects (selection is shared).
	_render_artifact_detail(detail_host, _selected_artifact_uid)


func _make_fragment_box(fragment: Fragment) -> Button:
	var box := Button.new()
	box.custom_minimum_size = BOX_MIN
	box.clip_text = true
	box.disabled = true
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var state := ModelEnums.fragment_state_name(fragment.state).capitalize()
	box.text = "Fragment %d\n%s" % [fragment.case_slot_index + 1, state]
	box.add_theme_color_override("font_color", Color(0.85, 0.78, 0.5))
	return box


# --- Shared layout helpers ---------------------------------------------------


## Builds the master/detail layout into `tab`: a scrolling boxes/content area on
## the left and a fixed-width detail panel on the right (HSR places detail on the
## right). Returns {detail, content} — `content` is the left VBox to fill.
func _make_master_detail(tab: HBoxContainer) -> Dictionary:
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var content := VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 8)
	scroll.add_child(content)
	tab.add_child(scroll)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(DETAIL_WIDTH, 0)
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_style_zone(panel, Color(0.10, 0.11, 0.13, 0.85))
	var detail_margin := MarginContainer.new()
	for side in ["left", "top", "right", "bottom"]:
		detail_margin.add_theme_constant_override("margin_%s" % side, 16)
	panel.add_child(detail_margin)
	var detail := VBoxContainer.new()
	detail.add_theme_constant_override("separation", 8)
	detail_margin.add_child(detail)
	tab.add_child(panel)

	return {"detail": detail, "content": content}


func _make_grid(columns: int) -> GridContainer:
	var grid := GridContainer.new()
	grid.columns = columns
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	return grid


func _make_condition_bar(condition: float) -> Control:
	var box := VBoxContainer.new()
	box.add_child(_make_kv("Condition", "%d / 100" % int(round(condition))))
	var bar := ProgressBar.new()
	bar.min_value = 0
	bar.max_value = 100
	bar.value = condition
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(0, 14)
	box.add_child(bar)
	return box


# --- Small widgets -----------------------------------------------------------


func _make_title(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", 24)
	label.add_theme_color_override("font_color", Color(0.95, 0.92, 0.8))
	return label


func _make_sub(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 15)
	label.add_theme_color_override("font_color", Color(0.7, 0.72, 0.78))
	return label


func _make_body(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", Color(0.82, 0.82, 0.85))
	return label


func _make_kv(key: String, value: String) -> Control:
	var row := HBoxContainer.new()
	var k := Label.new()
	k.text = key
	k.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	k.add_theme_font_size_override("font_size", 14)
	k.add_theme_color_override("font_color", Color(0.65, 0.67, 0.72))
	row.add_child(k)
	var v := Label.new()
	v.text = value
	v.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	v.add_theme_font_size_override("font_size", 14)
	v.add_theme_color_override("font_color", Color(0.9, 0.9, 0.92))
	row.add_child(v)
	return row


func _make_note(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.75))
	return label


func _style_zone(node: Control, color: Color) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.set_corner_radius_all(6)
	sb.set_content_margin_all(8)
	node.add_theme_stylebox_override("panel", sb)


func _clear(container: Node) -> void:
	for child in container.get_children():
		child.queue_free()


# --- Data helpers ------------------------------------------------------------


func _tab(tab_name: String) -> HBoxContainer:
	return _tabs.get_node(tab_name) as HBoxContainer


func _find_inventory(uid: String) -> Dictionary:
	var repo := DataRepository.singleton()
	for raw in GameState.save_state.loop.inventory:
		if raw is Dictionary and raw.get("uid") == uid:
			var inst := ObjectInstance.from_dictionary(raw)
			var template := repo.get_template(inst.template_id)
			if template == null:
				return {}
			return {"inst": inst, "template": template}
	return {}


func _remove_inventory(uid: String) -> void:
	var kept: Array = []
	for raw in GameState.save_state.loop.inventory:
		if not (raw is Dictionary and raw.get("uid") == uid):
			kept.append(raw)
	GameState.save_state.loop.inventory = kept


func _find_owned(uid: String) -> ToolInstance:
	for inst in _tools.get_owned_tools():
		if inst.uid == uid:
			return inst
	return null


## Surface conditions whose cleaning tool is this one, ordered by category.
func _conditions_treated_by(tool_id: String) -> Array:
	var out: Array = []
	for condition in DataRepository.singleton().get_surface_conditions_sorted():
		if (condition as SurfaceCondition).cleaning_tool == tool_id:
			out.append(condition)
	out.sort_custom(
		func(a: SurfaceCondition, b: SurfaceCondition) -> bool:
			return (
				SurfaceCondition.CATEGORY_ORDER.find(a.category)
				< SurfaceCondition.CATEGORY_ORDER.find(b.category)
			)
	)
	return out


func _artifact_description(template: ScrapObjectTemplate) -> String:
	if not template.description.is_empty():
		return template.description
	var materials := "unknown materials"
	if not template.materials.is_empty():
		materials = ", ".join(template.materials)
	return (
		"A %s piece of %s. %s"
		% [
			template.category,
			materials,
			(
				"It can be opened."
				if template.is_openable
				else "An ordinary find awaiting restoration."
			),
		]
	)


func _is_restored(inst: ObjectInstance) -> bool:
	return inst.state == ModelEnums.ObjState.CLEAN or inst.state == ModelEnums.ObjState.OPEN


func _sale_price(inst: ObjectInstance, template: ScrapObjectTemplate) -> int:
	if inst.value > 0:
		return inst.value
	return int(round((template.base_value_range.x + template.base_value_range.y) / 2.0))


func _state_word(inst: ObjectInstance) -> String:
	return ModelEnums.obj_state_name(inst.state).capitalize()


func _rarity_color(rarity: int) -> Color:
	match rarity:
		ModelEnums.Rarity.GREEN:
			return Color(0.55, 0.85, 0.55)
		ModelEnums.Rarity.BLUE:
			return Color(0.5, 0.7, 0.95)
		ModelEnums.Rarity.PURPLE:
			return Color(0.78, 0.6, 0.9)
		ModelEnums.Rarity.GOLD:
			return Color(0.95, 0.82, 0.45)
		_:
			return Color(0.9, 0.9, 0.9)


func _instance_display_name(uid: String) -> String:
	var found := _find_inventory(uid)
	if found.is_empty():
		return uid
	return (found["template"] as ScrapObjectTemplate).display_name


func _peso(amount: int) -> String:
	return "₱%d" % amount


# --- Drag-and-drop chips and zones -------------------------------------------


## A draggable tool tile. Subclasses Button so a plain click still selects it for
## the detail panel while a click-drag starts a loadout drag.
class ToolChip:
	extends Button
	var tool_uid: String = ""
	var from_equipped: bool = false
	## Called with the uid when an equipped chip is dropped anywhere that is not the
	## workbench (i.e. dragged "out"), so it unequips.
	var on_drag_out: Callable
	## True only on the chip the player is actually dragging. NOTIFICATION_DRAG_END is
	## broadcast to every chip in the tree, so without this flag every equipped chip
	## would unequip itself on one failed drop — the "unequips everything" bug.
	var _is_dragging: bool = false
	## Rotating 3D tool preview (built in _ready when in the tree). Empty = no preview.
	var preview_tool_id: String = ""
	var preview_label: String = ""
	var preview_color: Color = Color.WHITE

	func _ready() -> void:
		if preview_tool_id.is_empty() or not SettingsService.previews_enabled():
			return
		var card: Preview3DCard = StorageScreen.PREVIEW_CARD_SCENE.instantiate()
		add_child(card)  # in the tree now, so the preview viewport renders
		card.set_anchors_preset(Control.PRESET_FULL_RECT)
		# Tools are small meshes, so they need a bigger scale than artifacts to fill the
		# card and read clearly.
		card.set_preview(
			RestorationTool.build_geometry(preview_tool_id), preview_label, preview_color, 1.6
		)
		StorageScreen.ignore_mouse_recursive(card)
		text = ""  # the card shows the name now

	func _get_drag_data(_at_position: Vector2) -> Variant:
		_is_dragging = true
		# Drag the whole 3D box: a copy of the card follows the cursor (centred on it).
		if not preview_tool_id.is_empty() and SettingsService.previews_enabled():
			var holder := Control.new()
			var card: Preview3DCard = StorageScreen.PREVIEW_CARD_SCENE.instantiate()
			card.position = -0.5 * StorageScreen.SLOT_MIN  # centre the box on the cursor
			holder.add_child(card)
			set_drag_preview(holder)  # in the tree now → the card's viewport renders
			card.set_preview(
				RestorationTool.build_geometry(preview_tool_id), preview_label, preview_color, 1.6
			)
		else:
			var preview := Label.new()
			preview.text = preview_label if not preview_label.is_empty() else text
			preview.add_theme_color_override("font_color", Color(1, 1, 1))
			set_drag_preview(preview)
		return {"kind": StorageScreen.DRAG_KIND, "uid": tool_uid, "from_equipped": from_equipped}

	func _notification(what: int) -> void:
		# While a drag is in progress, every chip ignores the mouse so the Button's own
		# hover highlight can't fight the slot's swap highlight — only the slot the tool
		# is hovering lights up. Restored when the drag ends.
		if what == NOTIFICATION_DRAG_BEGIN:
			mouse_filter = Control.MOUSE_FILTER_IGNORE
			return
		# Only the chip being dragged reacts on drag-end. An equipped chip dropped
		# without a zone accepting it (empty space or the owned shelf) unequips itself —
		# "drag it out of the bench". A successful equip/replace/swap does nothing.
		if what != NOTIFICATION_DRAG_END:
			return
		mouse_filter = Control.MOUSE_FILTER_STOP
		if not _is_dragging:
			return
		_is_dragging = false
		if not from_equipped or not is_instance_valid(self):
			return
		if get_viewport().gui_is_drag_successful():
			return
		if on_drag_out.is_valid():
			on_drag_out.call(tool_uid)


## A panel that accepts tool chips and forwards the drop to `on_drop`.
class ToolDropZone:
	extends PanelContainer
	var on_drop: Callable

	func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
		return data is Dictionary and data.get("kind") == StorageScreen.DRAG_KIND

	func _drop_data(_at_position: Vector2, data: Variant) -> void:
		if on_drop.is_valid():
			on_drop.call(data)


## A single workbench slot (holds one tool chip or an empty placeholder). It is its
## own drop target so the player can aim at one slot, and it lights up while a tool
## is hovered over it so the drop target is obvious. `_active` tracks the one slot
## currently lit so moving between slots can't leave several glowing at once.
class ToolSlot:
	extends PanelContainer
	static var _active: ToolSlot = null

	var slot_index: int = -1
	var occupant_uid: String = ""  ## "" when the slot is empty.
	## Called with (slot_index, data) when a tool chip is dropped onto this slot.
	var on_drop_to_slot: Callable

	var _base_style: StyleBoxFlat
	var _highlight_style: StyleBoxFlat
	var _lit: bool = false

	func setup(min_size: Vector2, base: Color, highlight: Color) -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP
		custom_minimum_size = min_size
		_base_style = _flat(base, Color(0, 0, 0, 0))
		_highlight_style = _flat(highlight, Color(0.55, 0.9, 0.55, 0.95))
		add_theme_stylebox_override("panel", _base_style)

	func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
		var ok: bool = data is Dictionary and data.get("kind") == StorageScreen.DRAG_KIND
		if ok:
			_set_lit(true)
		return ok

	func _drop_data(_at_position: Vector2, data: Variant) -> void:
		_set_lit(false)
		if on_drop_to_slot.is_valid():
			on_drop_to_slot.call(slot_index, data)

	func _notification(what: int) -> void:
		# Clear the highlight when the pointer leaves the slot or the drag ends, so a
		# slot never stays lit after the tool moves elsewhere or the drag is dropped.
		if what == NOTIFICATION_MOUSE_EXIT or what == NOTIFICATION_DRAG_END:
			_set_lit(false)

	func _set_lit(on: bool) -> void:
		if on == _lit or _base_style == null:
			return
		if on:
			if _active != null and _active != self and is_instance_valid(_active):
				_active._set_lit(false)
			_active = self
			add_theme_stylebox_override("panel", _highlight_style)
		else:
			if _active == self:
				_active = null
			add_theme_stylebox_override("panel", _base_style)
		_lit = on

	static func _flat(bg: Color, border: Color) -> StyleBoxFlat:
		var sb := StyleBoxFlat.new()
		sb.bg_color = bg
		sb.set_corner_radius_all(6)
		sb.set_content_margin_all(4)
		if border.a > 0.0:
			sb.set_border_width_all(2)
			sb.border_color = border
		return sb
