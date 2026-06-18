class_name ShopHud
extends CanvasLayer

## Presentation-only HUD for the production Shop. It owns no game state: it shows
## whatever the ShopController tells it to and reports player intent through typed
## signals. The controller (scripts/shop/shop_controller.gd) listens to these
## signals and pushes updates back via the public set_* methods. Dialogue display
## is delegated to the reusable DialogueBox; deciding what to say and any
## clock/visitor side effects stay in the controller.

signal door_pressed  ## Player wants to answer the door / accept a visitor.
signal workbench_pressed  ## Player wants to go to the work desk.
signal journal_pressed  ## Player wants to view the journal.
signal phone_pressed  ## Player wants to view the phone (marketplace).
signal storage_pressed  ## Player wants to open Storage (bench loadout / restore target).
signal morning_delivery_pressed  ## Player wants to start the morning delivery triage.
signal dialogue_finished  ## Re-emitted when the dialogue box closes its queue.

enum Rarity { WHITE, GREEN, BLUE, PURPLE, GOLD }

## Display info per rarity, indexed by the Rarity enum order.
const RARITY := [
	{"name": "W", "color": "cfd2d6"},
	{"name": "G", "color": "5bc46a"},
	{"name": "B", "color": "4c8cff"},
	{"name": "P", "color": "b066ff"},
	{"name": "Gd", "color": "e6b422"},
]

@onready var _door_button: Button = $DoorButton
@onready var _workbench_button: Button = $WorkbenchButton
@onready var _journal_button: Button = $JournalButton
@onready var _phone_button: Button = $PhoneButton
@onready var _morning_button: Button = $MorningDeliveryButton
@onready var _dialogue: DialogueBox = $DialogueBox

var _storage_button: Button

@onready var _unrestored_counts: RichTextLabel = %UnrestoredCounts
@onready var _restored_counts: RichTextLabel = %RestoredCounts
@onready var _quest_count: Label = %QuestCount
@onready var _day_label: Label = %DayLabel
@onready var _clock_label: Label = %ClockLabel
@onready var _prompt_label: Label = $PromptLabel


func _ready() -> void:
	_door_button.pressed.connect(func() -> void: door_pressed.emit())
	_workbench_button.pressed.connect(func() -> void: workbench_pressed.emit())
	_journal_button.pressed.connect(func() -> void: journal_pressed.emit())
	_phone_button.pressed.connect(func() -> void: phone_pressed.emit())
	_morning_button.pressed.connect(func() -> void: morning_delivery_pressed.emit())
	_dialogue.finished.connect(func() -> void: dialogue_finished.emit())
	_build_storage_button()


## The Storage button is created in code (the rest of the HUD is authored in
## Shop.tscn). It sits on the right, just below the Phone button.
func _build_storage_button() -> void:
	_storage_button = Button.new()
	_storage_button.name = "StorageButton"
	_storage_button.text = "Storage"
	_storage_button.anchor_left = 1.0
	_storage_button.anchor_right = 1.0
	_storage_button.anchor_top = 0.5
	_storage_button.anchor_bottom = 0.5
	_storage_button.offset_left = -188.0
	_storage_button.offset_right = -28.0
	_storage_button.offset_top = 60.0
	_storage_button.offset_bottom = 160.0
	_storage_button.grow_horizontal = 0
	_storage_button.grow_vertical = 2
	_storage_button.focus_mode = Control.FOCUS_ALL
	_storage_button.add_theme_font_size_override("font_size", 18)
	_storage_button.pressed.connect(func() -> void: storage_pressed.emit())
	add_child(_storage_button)


## counts: Dictionary keyed by Rarity enum -> int.
func set_unrestored(counts: Dictionary) -> void:
	_unrestored_counts.text = _format_counts(counts)


## counts: Dictionary keyed by Rarity enum -> int (restored, ready to sell).
func set_restored(counts: Dictionary) -> void:
	_restored_counts.text = _format_counts(counts)


func set_quest_count(amount: int) -> void:
	_quest_count.text = str(amount)


## Shows the diegetic hover prompt for a focused shop interactable (empty clears).
func set_prompt(text: String) -> void:
	_prompt_label.text = text


func set_day(day: int, total_days: int) -> void:
	_day_label.text = "Day %d of %d" % [day, total_days]


## hour: 24-hour value (the shop runs 7..20). minute: 0..59.
## Shown as H:MM AM/PM.
func set_time(hour: int, minute: int = 0) -> void:
	_clock_label.text = _format_time(hour, minute)


## Show or hide the four action buttons (e.g. hidden while a dialogue plays).
func set_actions_visible(value: bool) -> void:
	_door_button.visible = value
	_workbench_button.visible = value
	_journal_button.visible = value
	_phone_button.visible = value
	_morning_button.visible = value
	if _storage_button != null:
		_storage_button.visible = value


## Reflects the journal book being presented (centered for reading). While open,
## the shop's other action buttons are hidden so they don't overlap or block clicks
## on the book; the Journal button stays as the way to put it away.
func set_journal_open(open: bool) -> void:
	_door_button.visible = not open
	_workbench_button.visible = not open
	_morning_button.visible = not open
	if _storage_button != null:
		_storage_button.visible = not open
	_journal_button.text = "Close Journal" if open else "Journal"


## Render a queue of dialogue lines. The controller chooses the content and any
## side effects; this only displays.
func start_dialogue(lines: Array) -> void:
	_dialogue.start(lines)


func _format_counts(counts: Dictionary) -> String:
	var parts: PackedStringArray = []
	for i in RARITY.size():
		var info: Dictionary = RARITY[i]
		var amount: int = int(counts.get(i, 0))
		parts.append("[color=#%s]%s %d[/color]" % [info.color, info.name, amount])
	return "   ".join(parts)


func _format_time(hour: int, minute: int = 0) -> String:
	var suffix := "AM" if hour < 12 else "PM"
	var h := hour % 12
	if h == 0:
		h = 12
	return "%d:%02d %s" % [h, clampi(minute, 0, 59), suffix]
