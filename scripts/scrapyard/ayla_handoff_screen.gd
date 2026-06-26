class_name AylaHandoffScreen
extends CanvasLayer
## Minimal hand-off UI for submitting chosen scrap to Ayla (RV2-B).
##
## Opened by interacting with Ayla in the scrapyard. The player can +/- the count
## of each rarity they want to hand over; submitting moves the scrap into the
## pending sort and Ayla knocks ~1 in-game hour later. The clock keeps running.

signal closed

@onready var _panel: Panel = $Panel
@onready var _rows: VBoxContainer = $Panel/Margin/VBox/Rows
@onready var _submit: Button = $Panel/Margin/VBox/Submit
@onready var _close: Button = $Panel/Margin/VBox/Close
@onready var _summary: Label = $Panel/Margin/VBox/Summary

var _selection: Dictionary = {}


func _ready() -> void:
	_submit.pressed.connect(_on_submit)
	_close.pressed.connect(_on_close)
	visible = false


func open() -> void:
	_selection.clear()
	_refresh()
	visible = true
	_submit.grab_focus()


func close() -> void:
	visible = false
	closed.emit()


func _refresh() -> void:
	for child in _rows.get_children():
		child.queue_free()
	var pool: Dictionary = GameState.save_state.loop.scrap_pool
	for rarity_name in ModelEnums.RARITY_NAMES:
		var owned: int = int(pool.get(rarity_name, 0))
		var selected: int = int(_selection.get(rarity_name, 0))
		_rows.add_child(_make_row(rarity_name, owned, selected))
	_update_summary()


func _make_row(rarity_name: String, owned: int, selected: int) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var name_label := Label.new()
	name_label.text = rarity_name.capitalize()
	name_label.custom_minimum_size = Vector2(80, 0)
	row.add_child(name_label)

	var owned_label := Label.new()
	owned_label.text = "Owned: %d" % owned
	owned_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(owned_label)

	var minus := Button.new()
	minus.text = "-"
	minus.disabled = selected <= 0
	minus.pressed.connect(_on_change.bind(rarity_name, -1))
	row.add_child(minus)

	var selected_label := Label.new()
	selected_label.text = str(selected)
	selected_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	selected_label.custom_minimum_size = Vector2(40, 0)
	row.add_child(selected_label)

	var plus := Button.new()
	plus.text = "+"
	plus.disabled = selected >= owned
	plus.pressed.connect(_on_change.bind(rarity_name, 1))
	row.add_child(plus)

	return row


func _on_change(rarity_name: String, delta: int) -> void:
	var current: int = int(_selection.get(rarity_name, 0))
	var owned: int = int(GameState.save_state.loop.scrap_pool.get(rarity_name, 0))
	var next := clampi(current + delta, 0, owned)
	if next > 0:
		_selection[rarity_name] = next
	else:
		_selection.erase(rarity_name)
	_refresh()


func _update_summary() -> void:
	var total := 0
	for count in _selection.values():
		total += int(count)
	_submit.text = "Hand %d scrap to Ayla" % total
	_submit.disabled = total == 0


func _on_submit() -> void:
	if _selection.is_empty():
		return
	if AylaService.submit_scrap(_selection):
		close()
	else:
		_summary.text = "Ayla is already sorting, or today already has a delivery."


func _on_close() -> void:
	close()
