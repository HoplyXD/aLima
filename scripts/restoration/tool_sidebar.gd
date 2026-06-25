class_name ToolSidebar
extends Control
## Left-edge 2D tool rack for the restoration bench (layout authored in tool_sidebar.tscn).
##
## Replaces the old 3D bench tool props (see CLAUDE.md REST-R9). It instances one editable
## ToolRow (tool_row.tscn) per equipped tool into the authored %List; each row shows the slot
## number + name, a still 3D model, the conditions it cleans (with cleaning power), and a
## durability bar. Clicking a row selects that tool.
##
## Presentation only: it never reads GameState/SaveService. The view hands it the slot layout
## + durability and resolves each tool's conditions via CleaningPower; the tool name comes from
## the data catalog. Both the sidebar and the row are scenes so the design is editable.

signal tool_clicked(tool_id: String)

const ROW_SCENE := preload("res://scenes/restoration/tool_row.tscn")
const MAX_ROWS := 8

var _rows: Dictionary = {}  ## tool_id -> ToolRow
var _order: Array[String] = []
var _selected: String = ""

@onready var _list: VBoxContainer = _resolve_list()


## The container the tool rows are added into. Prefers a node uniquely named "List", but
## falls back to the first VBoxContainer anywhere under this sidebar, so the sidebar's inner
## layout can be freely restructured/renamed in the editor.
func _resolve_list() -> VBoxContainer:
	var named := get_node_or_null("%List")
	if named is VBoxContainer:
		return named
	return _first_vbox(self)


func _first_vbox(node: Node) -> VBoxContainer:
	for child in node.get_children():
		if child is VBoxContainer:
			return child
		var nested := _first_vbox(child)
		if nested != null:
			return nested
	return null


## Rebuilds every row from a fixed-slot layout. `slots` is up to MAX_ROWS entries, each a
## tool_id or "" for an empty slot; the row number is the slot index + 1. `durability` maps
## tool_id -> {current, max}; `conditions_provider` is a Callable(tool_id) -> Array of
## {display_name, color, power} (typically CleaningPower.conditions_for bound to the repo).
func build_slots(slots: Array, durability: Dictionary, conditions_provider: Callable) -> void:
	if _list == null:
		_list = _resolve_list()
	if _list == null:
		push_warning("ToolSidebar: no VBoxContainer found to hold the tool rows.")
		return
	_clear()
	for slot in mini(slots.size(), MAX_ROWS):
		var tool_id := String(slots[slot])
		if tool_id.is_empty():
			continue
		var row: ToolRow = ROW_SCENE.instantiate()
		_list.add_child(row)
		row.configure(
			slot + 1,
			tool_id,
			_tool_display_name(tool_id),
			durability.get(tool_id, {}),
			conditions_provider.call(tool_id)
		)
		row.clicked.connect(_on_row_clicked)
		_rows[tool_id] = row
		_order.append(tool_id)
	_apply_selection()


## Updates the durability bars in place from {tool_id: {current, max}} (no rebuild).
func update_durability(durability: Dictionary) -> void:
	for tool_id in _rows.keys():
		var entry: Dictionary = durability.get(tool_id, {})
		var row: ToolRow = _rows[tool_id]
		row.update_durability(int(entry.get("current", 0)), int(entry.get("max", 0)))


## Highlights the selected row (pass "" to clear). Selection visuals only.
func set_selected(tool_id: String) -> void:
	_selected = tool_id if _rows.has(tool_id) else ""
	_apply_selection()


func selected_tool_id() -> String:
	return _selected


func get_tool_ids() -> Array[String]:
	return _order.duplicate()


func _tool_display_name(tool_id: String) -> String:
	var tool := DataRepository.singleton().get_tool(tool_id)
	return tool.display_name if tool != null else tool_id


func _on_row_clicked(tool_id: String) -> void:
	tool_clicked.emit(tool_id)


func _apply_selection() -> void:
	for tool_id in _rows.keys():
		var row: ToolRow = _rows[tool_id]
		row.set_selected(tool_id == _selected)


func _clear() -> void:
	for child in _list.get_children():
		child.queue_free()
	_rows.clear()
	_order.clear()
