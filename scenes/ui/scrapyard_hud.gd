class_name ScrapyardHud
extends CanvasLayer
## HUD for the walkable scrapyard.
##
## Shows the day/clock, proximity interaction prompts, and a 5-slot hotbar of
## carried scrap by rarity tier. All other UI is intentionally omitted to keep
## the yard clean and immersive.

## Color swatch for each scrap tier, matching ScrapItem's visuals.
const RARITY_COLORS := {
	"white": Color(0.85, 0.85, 0.85),
	"green": Color(0.36, 0.77, 0.42),
	"blue": Color(0.30, 0.55, 1.0),
	"purple": Color(0.69, 0.40, 1.0),
	"gold": Color(1.0, 0.72, 0.17),
}

@onready var _day_label: Label = $DayLabel
@onready var _clock_label: Label = $ClockLabel
@onready var _prompt_label: Label = $PromptLabel
@onready var _hotbar: HBoxContainer = $Hotbar


func _ready() -> void:
	set_day(1, 5)
	set_time(7, 0)
	set_prompt("")
	_build_hotbar()
	set_hotbar({})


## Shows a prompt at the bottom-center of the screen. Pass an empty string to hide.
func set_prompt(text: String) -> void:
	_prompt_label.text = text
	_prompt_label.visible = not text.is_empty()


func set_day(day: int, total_days: int) -> void:
	_day_label.text = "Day %d of %d" % [day, total_days]


## hour: 24-hour value. minute: 0..59. Shown as H:MM AM/PM.
func set_time(hour: int, minute: int = 0) -> void:
	_clock_label.text = _format_time(hour, minute)


## Refreshes the 5-slot hotbar from a rarity_name -> count dictionary.
func set_hotbar(scrap_pool: Dictionary) -> void:
	for i in ModelEnums.RARITY_NAMES.size():
		var rarity_name: String = ModelEnums.RARITY_NAMES[i]
		var slot: Panel = _hotbar.get_child(i)
		var label: Label = slot.get_child(0)
		label.text = "%d" % int(scrap_pool.get(rarity_name, 0))


func _build_hotbar() -> void:
	for child in _hotbar.get_children():
		child.queue_free()
	for rarity_name in ModelEnums.RARITY_NAMES:
		var slot := Panel.new()
		slot.custom_minimum_size = Vector2(56, 56)
		slot.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		var color: Color = RARITY_COLORS.get(rarity_name, RARITY_COLORS["white"])
		var style := StyleBoxFlat.new()
		style.bg_color = color
		style.border_width_bottom = 4
		style.border_color = color.darkened(0.4)
		slot.add_theme_stylebox_override("panel", style)

		var label := Label.new()
		label.text = "0"
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.anchor_left = 0.0
		label.anchor_top = 0.0
		label.anchor_right = 1.0
		label.anchor_bottom = 1.0
		label.add_theme_font_size_override("font_size", 24)
		label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 1.0))
		label.add_theme_color_override("font_outline_color", Color(0.1, 0.1, 0.1, 1.0))
		label.add_theme_constant_override("outline_size", 3)
		slot.add_child(label)
		_hotbar.add_child(slot)


func _format_time(hour: int, minute: int = 0) -> String:
	var suffix := "AM" if hour < 12 else "PM"
	var h := hour % 12
	if h == 0:
		h = 12
	return "%d:%02d %s" % [h, clampi(minute, 0, 59), suffix]
