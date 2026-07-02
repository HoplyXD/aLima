class_name ScrapyardHud
extends CanvasLayer
## HUD for the walkable outdoor spaces (scrapyard, mall).
##
## Top-left: phone and journal quick buttons (the overlays open in-place, so
## the player never has to walk back inside just to check the marketplace or
## the book). Top-right: day/clock + quest count. Bottom: the 5-slot carry
## inventory — unsorted scrap bundles into ONE slot (it must go to Ayla before
## it can be restored); restored artifacts fill the remaining slots as 3D
## rotating preview cards.

signal phone_pressed
signal journal_pressed
signal item_inspected(slot_index: int, data: Dictionary)

const INVENTORY_SLOTS: int = 5

## Color swatch for each scrap tier, matching ScrapItem's visuals.
const RARITY_COLORS := {
	"white": Color(0.85, 0.85, 0.85),
	"green": Color(0.36, 0.77, 0.42),
	"blue": Color(0.30, 0.55, 1.0),
	"purple": Color(0.69, 0.40, 1.0),
	"gold": Color(1.0, 0.72, 0.17),
}

const SLOT_EMPTY_COLOR := Color(0.12, 0.12, 0.12, 0.75)
const SLOT_SCRAP_COLOR := Color(0.45, 0.4, 0.32)

const PREVIEW_CARD_SCENE := preload("res://scenes/restoration/preview_3d_card.tscn")

@onready var _day_label: Label = $DayLabel
@onready var _clock_label: Label = $ClockLabel
@onready var _prompt_label: Label = $PromptLabel
@onready var _hotbar: HBoxContainer = $Hotbar

var _quest_label: Label
var _phone_button: Button
var _journal_button: Button
var _slot_data: Array[Dictionary] = []
var _cards: Array[Preview3DCard] = []


func _ready() -> void:
	set_day(1, 5)
	set_time(7, 0)
	set_prompt("")
	_build_top_left_buttons()
	_build_quest_label()
	_build_hotbar()
	set_inventory(0, [])


## Top-left quick actions: phone (marketplace) and journal, usable outdoors.
func _build_top_left_buttons() -> void:
	var row := HBoxContainer.new()
	row.name = "QuickActions"
	row.position = Vector2(24, 24)
	row.add_theme_constant_override("separation", 12)
	add_child(row)
	_phone_button = Button.new()
	_phone_button.text = "Phone"
	_phone_button.custom_minimum_size = Vector2(120, 48)
	_phone_button.focus_mode = Control.FOCUS_ALL
	_phone_button.pressed.connect(func() -> void: phone_pressed.emit())
	row.add_child(_phone_button)
	_journal_button = Button.new()
	_journal_button.text = "Journal"
	_journal_button.custom_minimum_size = Vector2(120, 48)
	_journal_button.focus_mode = Control.FOCUS_ALL
	_journal_button.pressed.connect(func() -> void: journal_pressed.emit())
	row.add_child(_journal_button)


## Quest count under the day/clock readout (top right).
func _build_quest_label() -> void:
	_quest_label = Label.new()
	_quest_label.name = "QuestLabel"
	_quest_label.anchor_left = 1.0
	_quest_label.anchor_right = 1.0
	# Below the tutorial quest panel (top-right, y 64..196) so they never overlap.
	_quest_label.offset_left = -260.0
	_quest_label.offset_right = -24.0
	_quest_label.offset_top = 204.0
	_quest_label.offset_bottom = 236.0
	_quest_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_quest_label.add_theme_font_size_override("font_size", 22)
	add_child(_quest_label)


func set_quest_count(amount: int) -> void:
	if _quest_label != null:
		_quest_label.text = "Quest: %d" % amount


## Shows a prompt at the bottom-center of the screen. Pass an empty string to hide.
func set_prompt(text: String) -> void:
	_prompt_label.text = text
	_prompt_label.visible = not text.is_empty()


func set_day(day: int, total_days: int) -> void:
	_day_label.text = "Day %d of %d" % [day, total_days]


## Day 0 (tutorial) presentation: time does not exist yet, so no clock readout.
func set_day_zero() -> void:
	_day_label.text = "Day 0"
	_clock_label.text = ""


## hour: 24-hour value. minute: 0..59. Shown as H:MM AM/PM.
func set_time(hour: int, minute: int = 0) -> void:
	_clock_label.text = _format_time(hour, minute)


## Refreshes the 5-slot carry inventory. The whole unsorted scrap pool bundles
## into ONE slot (it still needs Ayla's sorting before restoration); `restored`
## entries fill the remaining slots as 3D rotating preview cards.
func set_inventory(scrap_total: int, restored_data: Array[Dictionary]) -> void:
	var slot_index := 0
	# Clear all slots first
	for i in INVENTORY_SLOTS:
		_clear_slot(i)
		_slot_data[i] = {}

	if scrap_total > 0:
		# A little scrap heap (matches the round yard pickups, not a plain cube).
		var scrap_mesh := Node3D.new()
		var mat := StandardMaterial3D.new()
		mat.albedo_color = SLOT_SCRAP_COLOR
		var offsets := [Vector3.ZERO, Vector3(0.28, -0.06, 0.1), Vector3(-0.22, -0.1, -0.12)]
		var radii := [0.22, 0.16, 0.13]
		for i in offsets.size():
			var lump := MeshInstance3D.new()
			var ball := SphereMesh.new()
			ball.radius = radii[i]
			ball.height = radii[i] * 1.6
			lump.mesh = ball
			lump.material_override = mat
			lump.position = offsets[i]
			scrap_mesh.add_child(lump)
		_set_slot(slot_index, "Scrap x%d" % scrap_total, SLOT_SCRAP_COLOR, scrap_mesh)
		_slot_data[slot_index] = {
			"preview": scrap_mesh,
			"display_name": "Scrap x%d" % scrap_total,
			"color": SLOT_SCRAP_COLOR,
			"description": "Unsorted scrap from the yard.",
			"is_scrap": true,
		}
		slot_index += 1

	for raw in restored_data:
		if slot_index >= INVENTORY_SLOTS:
			# Free unused previews to prevent leaks
			var preview: Node3D = raw.get("preview") as Node3D
			if preview != null and is_instance_valid(preview):
				preview.queue_free()
			continue
		var entry: Dictionary = raw
		_set_slot(
			slot_index,
			str(entry.get("display_name", "?")),
			entry.get("color", RARITY_COLORS["white"]),
			entry.get("preview") as Node3D
		)
		_slot_data[slot_index] = entry.duplicate()
		slot_index += 1

	while slot_index < INVENTORY_SLOTS:
		_clear_slot(slot_index)
		slot_index += 1


func _set_slot(index: int, display_name: String, color: Color, preview: Node3D) -> void:
	if index < 0 or index >= _cards.size():
		return
	var card: Preview3DCard = _cards[index]
	if preview == null:
		preview = Node3D.new()
	card.set_spin(true)
	card.set_preview(preview, display_name, color, 0.9)
	# Restore the card's panel style (dark background with rounded corners)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.12, 0.85)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_right = 8
	style.corner_radius_bottom_left = 8
	style.content_margin_left = 6.0
	style.content_margin_top = 6.0
	style.content_margin_right = 6.0
	style.content_margin_bottom = 6.0
	card.add_theme_stylebox_override("panel", style)


func _clear_slot(index: int) -> void:
	if index < 0 or index >= _cards.size():
		return
	var card: Preview3DCard = _cards[index]
	card.set_spin(false)
	card.set_preview(Node3D.new(), "", Color.WHITE, 0.0)
	# Dark empty slot look
	var style := StyleBoxFlat.new()
	style.bg_color = SLOT_EMPTY_COLOR
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_right = 8
	style.corner_radius_bottom_left = 8
	style.content_margin_left = 6.0
	style.content_margin_top = 6.0
	style.content_margin_right = 6.0
	style.content_margin_bottom = 6.0
	card.add_theme_stylebox_override("panel", style)


func _build_hotbar() -> void:
	for child in _hotbar.get_children():
		child.queue_free()
	_cards.clear()
	_slot_data.clear()

	# Resize hotbar to accommodate 5 Preview3DCards
	_hotbar.custom_minimum_size = Vector2(860, 210)
	_hotbar.offset_left = -430
	_hotbar.offset_right = 430
	_hotbar.offset_top = -230
	_hotbar.offset_bottom = -20

	for i in INVENTORY_SLOTS:
		var card: Preview3DCard = PREVIEW_CARD_SCENE.instantiate()
		_hotbar.add_child(card)
		_cards.append(card)
		_slot_data.append({})
		var slot_index := i
		card.clicked.connect(func() -> void: item_inspected.emit(slot_index, _slot_data[slot_index]))


func _format_time(hour: int, minute: int = 0) -> String:
	var suffix := "AM" if hour < 12 else "PM"
	var h := hour % 12
	if h == 0:
		h = 12
	return "%d:%02d %s" % [h, clampi(minute, 0, 59), suffix]
