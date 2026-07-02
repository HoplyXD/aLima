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
## Player clicked an unrestored artifact card: open the bench on that artifact.
signal unrestored_card_selected(uid: String)
## Player clicked a restored artifact card: open the 3D viewer on it.
signal restored_card_selected(uid: String)

enum Rarity { WHITE, GREEN, BLUE, PURPLE, GOLD }

## Display info per rarity, indexed by the Rarity enum order.
const RARITY := [
	{"name": "W", "color": "cfd2d6"},
	{"name": "G", "color": "5bc46a"},
	{"name": "B", "color": "4c8cff"},
	{"name": "P", "color": "b066ff"},
	{"name": "Gd", "color": "e6b422"},
]

## The diegetic 3D shop props are the primary controls now, so the 2D fallback
## buttons stay hidden. Flip to true to expose them as an accessibility fallback.
const FALLBACK_BUTTONS_VISIBLE := false

@onready var _door_button: Button = $DoorButton
@onready var _workbench_button: Button = $WorkbenchButton
@onready var _journal_button: Button = $JournalButton
@onready var _phone_button: Button = $PhoneButton
@onready var _morning_button: Button = $MorningDeliveryButton
@onready var _dialogue: DialogueBox = $DialogueBox

var _storage_button: Button

# Null-tolerant: the menu/loading backdrop scenes reuse this script with an
# older HUD tree that has no card strips (they never call set_artifact_cards).
@onready var _unrestored_cards: HBoxContainer = get_node_or_null("%UnrestoredCards")
@onready var _restored_cards: HBoxContainer = get_node_or_null("%RestoredCards")
@onready var _quest_count: Label = get_node_or_null("%QuestCount")
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
	_storage_button.visible = FALLBACK_BUTTONS_VISIBLE
	add_child(_storage_button)


const ARTIFACT_CARD_SCENE := preload("res://scenes/restoration/artifact_card.tscn")


## Rebuilds the two artifact card strips (like the bench's artifact bar).
## `unrestored`/`restored` entries: {uid, display_name, color: Color}. The
## controller follows up per card via `preview_provider.call(uid, card)` to
## embed the rotating 3D preview (presentation stays state-free here).
func set_artifact_cards(
	unrestored: Array, restored: Array, previews_on: bool, preview_provider: Callable
) -> void:
	_fill_card_strip(_unrestored_cards, unrestored, previews_on, preview_provider, true)
	_fill_card_strip(_restored_cards, restored, previews_on, preview_provider, false)


func _fill_card_strip(
	strip: HBoxContainer,
	entries: Array,
	previews_on: bool,
	preview_provider: Callable,
	is_unrestored: bool
) -> void:
	if strip == null:
		return
	for child in strip.get_children():
		child.queue_free()
	for raw in entries:
		var entry: Dictionary = raw
		var uid := str(entry.get("uid"))
		var card: ArtifactCard = ARTIFACT_CARD_SCENE.instantiate()
		strip.add_child(card)
		card.configure(
			uid,
			str(entry.get("display_name", uid)),
			entry.get("color", Color.WHITE),
			previews_on
		)
		if is_unrestored:
			card.selected.connect(func(id: String) -> void: unrestored_card_selected.emit(id))
		else:
			card.selected.connect(func(id: String) -> void: restored_card_selected.emit(id))
		if previews_on and preview_provider.is_valid():
			preview_provider.call(uid, card)


func set_quest_count(amount: int) -> void:
	if _quest_count != null:
		_quest_count.text = "Quest: %d" % amount


## Shows the diegetic hover prompt for a focused shop interactable (empty clears).
func set_prompt(text: String) -> void:
	_prompt_label.text = text


func set_day(day: int, total_days: int) -> void:
	_day_label.text = "Day %d of %d" % [day, total_days]


## Day 0 (tutorial) presentation: time does not exist yet, so no clock readout.
func set_day_zero() -> void:
	_day_label.text = "Day 0"
	_clock_label.text = ""


## hour: 24-hour value (the shop runs 7..20). minute: 0..59.
## Shown as H:MM AM/PM.
func set_time(hour: int, minute: int = 0) -> void:
	_clock_label.text = _format_time(hour, minute)


## Show or hide the four action buttons (e.g. hidden while a dialogue plays).
func set_actions_visible(value: bool) -> void:
	var v := value and FALLBACK_BUTTONS_VISIBLE
	_door_button.visible = v
	_workbench_button.visible = v
	_journal_button.visible = v
	_phone_button.visible = v
	_morning_button.visible = v
	if _storage_button != null:
		_storage_button.visible = v


## Reflects the journal book being presented (centered for reading). While open,
## the shop's other action buttons are hidden so they don't overlap or block clicks
## on the book; the Journal button stays as the way to put it away.
func set_journal_open(open: bool) -> void:
	var v := (not open) and FALLBACK_BUTTONS_VISIBLE
	_door_button.visible = v
	_workbench_button.visible = v
	_morning_button.visible = v
	_journal_button.visible = v
	if _storage_button != null:
		_storage_button.visible = v
	_journal_button.text = "Close Journal" if open else "Journal"


## Render a queue of dialogue lines. The controller chooses the content and any
## side effects; this only displays.
func start_dialogue(lines: Array) -> void:
	_dialogue.start(lines)


func _format_time(hour: int, minute: int = 0) -> String:
	var suffix := "AM" if hour < 12 else "PM"
	var h := hour % 12
	if h == 0:
		h = 12
	return "%d:%02d %s" % [h, clampi(minute, 0, 59), suffix]
