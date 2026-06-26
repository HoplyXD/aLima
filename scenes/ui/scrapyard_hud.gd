class_name ScrapyardHud
extends CanvasLayer
## HUD for the walkable scrapyard.
##
## Shows the day/clock (so the player knows when to return for shop visitors) and
## proximity interaction prompts. All other UI is intentionally omitted to keep
## the yard clean and immersive.

@onready var _day_label: Label = $DayLabel
@onready var _clock_label: Label = $ClockLabel
@onready var _prompt_label: Label = $PromptLabel


func _ready() -> void:
	set_day(1, 5)
	set_time(7, 0)
	set_prompt("")


## Shows a prompt at the bottom-center of the screen. Pass an empty string to hide.
func set_prompt(text: String) -> void:
	_prompt_label.text = text
	_prompt_label.visible = not text.is_empty()


func set_day(day: int, total_days: int) -> void:
	_day_label.text = "Day %d of %d" % [day, total_days]


## hour: 24-hour value. minute: 0..59. Shown as H:MM AM/PM.
func set_time(hour: int, minute: int = 0) -> void:
	_clock_label.text = _format_time(hour, minute)


func _format_time(hour: int, minute: int = 0) -> String:
	var suffix := "AM" if hour < 12 else "PM"
	var h := hour % 12
	if h == 0:
		h = 12
	return "%d:%02d %s" % [h, clampi(minute, 0, 59), suffix]
