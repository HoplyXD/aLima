class_name MallToolShop
extends CanvasLayer
## The mall's physical tool shop. Sells the MALL catalog (a different set from the
## phone's online store): buying here is in person — money out, tool owned instantly,
## no shipment. Presentation only; the purchase itself runs through
## MarketplaceService.buy_in_person(). Built in code so no scene file is needed.

signal closed
## A tool was bought in person (already granted). The mall shows it in the carry hotbar.
signal tool_bought(tool_id: String)

const PAUSE_OWNER := "mall_tool_shop"

var _root: Control
var _rows: VBoxContainer
var _money_label: Label
var _status_label: Label


func _ready() -> void:
	layer = 40
	visible = false
	_build()


func open() -> void:
	visible = true
	DayClock.request_pause(PAUSE_OWNER)
	refresh()


func close() -> void:
	visible = false
	DayClock.release_pause(PAUSE_OWNER)
	closed.emit()


func _exit_tree() -> void:
	DayClock.release_pause(PAUSE_OWNER)


func _input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()


func refresh() -> void:
	if _rows == null:
		return
	for child in _rows.get_children():
		child.queue_free()
	_money_label.text = "₱%d" % GameState.save_state.loop.money
	var catalog: Array[ToolDefinition] = MarketplaceService.get_mall_catalog()
	if catalog.is_empty():
		var note := Label.new()
		note.text = "Shelves are empty today."
		_rows.add_child(note)
		return
	for def in catalog:
		_rows.add_child(_make_row(def))


func _make_row(def: ToolDefinition) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var name_label := Label.new()
	name_label.text = def.display_name
	name_label.custom_minimum_size = Vector2(220, 0)
	name_label.add_theme_font_size_override("font_size", 20)
	row.add_child(name_label)
	var cleans_label := Label.new()
	cleans_label.text = _cleans_text(def)
	cleans_label.custom_minimum_size = Vector2(260, 0)
	cleans_label.add_theme_color_override("font_color", Color(0.7, 0.74, 0.8))
	row.add_child(cleans_label)
	var buy := Button.new()
	buy.text = "Buy · ₱%d" % def.cost
	buy.custom_minimum_size = Vector2(140, 44)
	buy.focus_mode = Control.FOCUS_ALL
	buy.disabled = GameState.save_state.loop.money < def.cost
	buy.pressed.connect(_on_buy_pressed.bind(def.id))
	row.add_child(buy)
	return row


## "Cleans: Mud, Soot, Grease" from the tool's data (falls back to the catalog lookup).
func _cleans_text(def: ToolDefinition) -> String:
	var names: Array[String] = []
	var repo := DataRepository.singleton()
	for entry in CleaningPower.conditions_for(repo, def.id):
		names.append(str((entry as Dictionary).get("display_name", "")))
	if names.is_empty():
		return ""
	return "Cleans: %s" % ", ".join(names)


func _on_buy_pressed(tool_id: String) -> void:
	var res: Dictionary = MarketplaceService.buy_in_person(tool_id)
	if res.get("ok", false):
		_status_label.text = "Bought! It's in your bag."
		tool_bought.emit(tool_id)
	else:
		_status_label.text = str(res.get("error", "Something went wrong."))
	refresh()


func _build() -> void:
	_root = PanelContainer.new()
	_root.set_anchors_preset(Control.PRESET_CENTER)
	_root.custom_minimum_size = Vector2(760, 520)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.09, 0.10, 0.13, 0.96)
	style.corner_radius_top_left = 12
	style.corner_radius_top_right = 12
	style.corner_radius_bottom_right = 12
	style.corner_radius_bottom_left = 12
	_root.add_theme_stylebox_override("panel", style)
	add_child(_root)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_top", 18)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_bottom", 18)
	_root.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	margin.add_child(vbox)

	var header := HBoxContainer.new()
	vbox.add_child(header)
	var title := Label.new()
	title.text = "Mall Tool Shop"
	title.add_theme_font_size_override("font_size", 28)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	_money_label = Label.new()
	_money_label.add_theme_font_size_override("font_size", 22)
	_money_label.add_theme_color_override("font_color", Color(0.95, 0.85, 0.45))
	header.add_child(_money_label)

	var hint := Label.new()
	hint.text = "In-person stock — different from the online store. Yours the moment you pay."
	hint.add_theme_color_override("font_color", Color(0.65, 0.68, 0.75))
	vbox.add_child(hint)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(0, 320)
	vbox.add_child(scroll)
	_rows = VBoxContainer.new()
	_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_rows.add_theme_constant_override("separation", 10)
	scroll.add_child(_rows)

	_status_label = Label.new()
	_status_label.add_theme_color_override("font_color", Color(0.5, 0.85, 0.55))
	vbox.add_child(_status_label)

	var close_button := Button.new()
	close_button.text = "Leave the shop (Esc)"
	close_button.custom_minimum_size = Vector2(220, 48)
	close_button.focus_mode = Control.FOCUS_ALL
	close_button.pressed.connect(close)
	vbox.add_child(close_button)
