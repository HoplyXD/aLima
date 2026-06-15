extends Node3D

## Production Shop controller, attached to the Shop scene root. It is the live
## driver and presentation surface for the core clock/loop: each frame it advances
## the DayClock autoload and reflects its state into the HUD, answers the HUD's
## intent signals, and drives the door -> visitor -> dialogue flow (freezing shop
## time via pause ownership). The clock/loop simulation lives in the DayClock and
## LoopController autoloads, not here. Real delivery/restoration systems replace
## the count placeholders in later phases (see docs/phase-task.md).

## Real seconds per in-game hour. GDD cadence is 1 real minute = 1 in-game hour.
## Lower this in the inspector (e.g. 0.1) to watch the clock move faster while
## testing; the value is forwarded to the DayClock on ready.
@export var seconds_per_hour: float = 60.0

# --- Placeholder count state until the delivery/restoration systems exist ---
var _unrestored := {
	ShopHud.Rarity.WHITE: 3,
	ShopHud.Rarity.GREEN: 2,
	ShopHud.Rarity.BLUE: 1,
	ShopHud.Rarity.PURPLE: 0,
	ShopHud.Rarity.GOLD: 0,
}
var _restored := {
	ShopHud.Rarity.WHITE: 0,
	ShopHud.Rarity.GREEN: 1,
	ShopHud.Rarity.BLUE: 0,
	ShopHud.Rarity.PURPLE: 0,
	ShopHud.Rarity.GOLD: 0,
}
var _quest_artifacts := 1

@onready var _hud: ShopHud = $HUD
@onready var _visitor: Sprite3D = $Visitor


func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

	_hud.door_pressed.connect(_on_door_pressed)
	_hud.workbench_pressed.connect(_on_workbench_pressed)
	_hud.journal_pressed.connect(_on_journal_pressed)
	_hud.phone_pressed.connect(_on_phone_pressed)
	_hud.dialogue_finished.connect(_on_dialogue_finished)

	_visitor.visible = false

	DayClock.seconds_per_hour = seconds_per_hour
	LoopController.begin_session()

	_refresh_ui()
	print("[Shop] ready — HUD visible, buttons connected. Click them in the running game.")


func _process(delta: float) -> void:
	# `running` is the auto-driver gate; tick() itself still no-ops while paused or
	# closed. Tests set running=false to drive the clock deterministically.
	if DayClock.running:
		DayClock.tick(delta)
	_update_clock_display()


func _exit_tree() -> void:
	# Stop the autoload clock so its state does not bleed into later scenes/tests.
	DayClock.reset()


## True while the day clock is actively ticking (paused during dialogue). Exposed
## as a read-only seam for tests; not a gameplay system.
func is_day_running() -> bool:
	return DayClock.is_running()


func _refresh_ui() -> void:
	_hud.set_unrestored(_unrestored)
	_hud.set_restored(_restored)
	_hud.set_quest_count(_quest_artifacts)
	_update_clock_display()


func _update_clock_display() -> void:
	_hud.set_day(DayClock.get_day(), DayClock.TOTAL_DAYS)
	_hud.set_time(DayClock.get_hour(), DayClock.get_minute())


# --- HUD intent ---------------------------------------------------------


func _on_door_pressed() -> void:
	# Demo visitor — the Elderly Auntie's Day 1 beat from aLima.twee. Phase 10
	# moves authored prose to data/routes/.
	var lines: Array = [
		{
			"name": "Elderly Auntie",
			"text": "A frail knock. She clutches a [i]cracked photo frame[/i].",
		},
		{
			"name": "You",
			"text": "Let me see it. I can free the photo without tearing the emulsion.",
		},
		"[b]Elderly Auntie Quest 1 available.[/b]",
	]
	_open_dialogue(lines, true)


func _on_workbench_pressed() -> void:
	var line := "You step over to the work desk. [i]Restoration mini-games land here soon.[/i]"
	_open_dialogue([line], false)


func _on_journal_pressed() -> void:
	var line := "You flip open the journal. [i]Entries and the fragment case land here soon.[/i]"
	_open_dialogue([line], false)


func _on_phone_pressed() -> void:
	var line := "You check your phone. [i]The marketplace to sell restored pieces lands here soon.[/i]"
	_open_dialogue([line], false)


## Opens the dialogue box, optionally showing the visitor sprite, and freezes the
## shop (clock + action buttons) until the conversation ends. The clock pause uses
## the DayClock pause-ownership API so it composes with other full-screen systems.
func _open_dialogue(lines: Array, show_visitor: bool) -> void:
	DayClock.request_pause(DayClock.PAUSE_DIALOGUE)
	_hud.set_actions_visible(false)
	_visitor.visible = show_visitor
	_hud.start_dialogue(lines)


func _on_dialogue_finished() -> void:
	_visitor.visible = false
	_hud.set_actions_visible(true)
	DayClock.release_pause(DayClock.PAUSE_DIALOGUE)
