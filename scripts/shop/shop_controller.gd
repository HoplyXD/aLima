extends Node3D

## Production Shop controller, attached to the Shop scene root. It is the live
## driver and presentation surface for the core clock/loop: each frame it advances
## the DayClock autoload and reflects its state into the HUD, answers the HUD's
## intent signals, and drives the door -> visitor -> dialogue flow (freezing shop
## time via pause ownership). The clock/loop simulation lives in the DayClock and
## LoopController autoloads, not here. Real delivery/restoration systems replace
## the count placeholders in later phases (see docs/phase-task.md).

const RESTORATION_VIEW_SCENE := preload("res://scenes/restoration/restoration_view.tscn")
const PHONE_SCENE := preload("res://scenes/ui/phone.tscn")
const STORAGE_SCREEN_SCENE := preload("res://scenes/ui/storage_screen.tscn")

## Real seconds per in-game hour. GDD cadence is 1 real minute = 1 in-game hour.
## Lower this in the inspector (e.g. 0.1) to watch the clock move faster while
## testing; the value is forwarded to the DayClock on ready.
@export var seconds_per_hour: float = 60.0

# --- Placeholder count state until the delivery/restoration systems exist --
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

## Route id of the character currently at the door, or "" for a non-visitor line.
## Marked "met" when their dialogue closes so the next visit plays the return set.
var _active_visitor_route_id := ""

@onready var _hud: ShopHud = $HUD
@onready var _visitor: Sprite3D = $Visitor
@onready var _triage_screen: TriageController = $TriageScreen
@onready var _book_viewport: BookViewport = $BookViewport
@onready var _restoration_view: RestorationView = _create_restoration_view()
@onready var _phone: Phone = _create_phone()
@onready var _storage_screen: StorageScreen = _create_storage_screen()

# Diegetic 3D shop interactables. Each one fires the same controller handler as
# its HUD fallback button, so the physical prop and the accessibility button are
# interchangeable.
@onready var _door_interactable: Interactable3D = $Interactables/DoorInteractable
@onready var _workbench_interactable: Interactable3D = $Interactables/WorkbenchInteractable
@onready var _journal_interactable: Interactable3D = $Interactables/JournalInteractable
@onready var _phone_interactable: Interactable3D = $Interactables/PhoneInteractable
@onready var _delivery_interactable: Interactable3D = $Interactables/DeliveryInteractable


func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	# Required for the diegetic Interactable3D props to receive mouse clicks/hover.
	get_viewport().physics_object_picking = true

	_hud.door_pressed.connect(_on_door_pressed)
	_hud.workbench_pressed.connect(_on_workbench_pressed)
	_hud.journal_pressed.connect(_on_journal_pressed)
	_hud.phone_pressed.connect(_on_phone_pressed)
	_hud.storage_pressed.connect(_on_storage_pressed)
	_hud.morning_delivery_pressed.connect(_on_morning_delivery_pressed)
	_hud.dialogue_finished.connect(_on_dialogue_finished)

	_connect_interactables()

	_visitor.visible = false

	DayClock.seconds_per_hour = seconds_per_hour
	LoopController.begin_session()

	_triage_screen.closed.connect(_on_triage_closed)
	_restoration_view.closed.connect(_on_restoration_closed)
	_phone.closed.connect(_on_phone_closed)
	_storage_screen.closed.connect(_on_storage_closed)
	_storage_screen.restore_requested.connect(_on_storage_restore_requested)
	# The restoration bench opens the same shared journal / marketplace / storage overlays.
	_restoration_view.set_journal_viewport(_book_viewport)
	_restoration_view.set_phone(_phone)
	_restoration_view.set_storage_screen(_storage_screen)
	_book_viewport.closed.connect(_on_journal_closed)

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
	if _triage_screen != null:
		_triage_screen.close()


## True while the day clock is actively ticking (paused during dialogue). Exposed
## as a read-only seam for tests; not a gameplay system.
func is_day_running() -> bool:
	return DayClock.is_running()


func _refresh_ui() -> void:
	var unrestored := _count_inventory_by_glow(false)
	var restored := _count_inventory_by_glow(true)
	_hud.set_unrestored(unrestored)
	_hud.set_restored(restored)
	_hud.set_quest_count(_count_seated_fragments())
	_update_clock_display()


func _update_clock_display() -> void:
	_hud.set_day(DayClock.get_day(), DayClock.TOTAL_DAYS)
	_hud.set_time(DayClock.get_hour(), DayClock.get_minute())


# --- HUD intent ---------------------------------------------------------


func _on_door_pressed() -> void:
	# Authored dialogue + portraits live in data/routes/routes.json. The door shows
	# whichever character RouteService schedules for the current in-game day/hour,
	# branching their lines on whether the player has met them before.
	var route := RouteService.resolve_visitor(DayClock.get_day(), DayClock.get_hour())
	if route == null:
		_open_dialogue(["No one is at the door right now."], false)
		return
	var key := RouteService.dialogue_key(route, DayClock.get_day())
	var lines := route.dialogue_for(key)
	if lines.is_empty():
		lines = ["%s steps in, but has nothing to say today." % route.display_name]
	if not route.portrait.is_empty():
		var tex: Texture2D = load(route.portrait)
		if tex != null:
			_visitor.texture = tex
	_active_visitor_route_id = route.id
	_open_dialogue(lines, true)


func _on_workbench_pressed() -> void:
	_set_interactables_enabled(false)
	_restoration_view.open()


func _on_journal_pressed() -> void:
	# The journal is the book rendered in its own viewport overlay. Opening it covers
	# the shop; it closes via Esc, the Close button, or clicking off the book.
	_set_interactables_enabled(false)
	_book_viewport.open()
	_hud.set_journal_open(true)


func _on_journal_closed() -> void:
	_set_interactables_enabled(true)
	_hud.set_journal_open(false)


func _on_phone_pressed() -> void:
	# The phone opens to its home screen of apps (Marketplace now; selling comes
	# with the Phase-14 buyer negotiation). It covers the shop and pauses time.
	_set_interactables_enabled(false)
	_phone.open()


func _on_phone_closed() -> void:
	_set_interactables_enabled(true)
	_refresh_ui()


func _on_storage_pressed() -> void:
	# Storage prepares the bench: choose the artifact to restore and which tools
	# (max 10) to load. It covers the shop and pauses time via PAUSE_STORAGE.
	_set_interactables_enabled(false)
	_storage_screen.open()


func _on_storage_closed() -> void:
	_set_interactables_enabled(true)
	_refresh_ui()


## Storage's Restore button already set the restore target and closed; open the
## bench directly on that artifact.
func _on_storage_restore_requested(_uid: String) -> void:
	_on_workbench_pressed()


## Opens the dialogue box, optionally showing the visitor sprite, and freezes the
## shop (clock + action buttons) until the conversation ends. The clock pause uses
## the DayClock pause-ownership API so it composes with other full-screen systems.
func _open_dialogue(lines: Array, show_visitor: bool) -> void:
	DayClock.request_pause(DayClock.PAUSE_DIALOGUE)
	_hud.set_actions_visible(false)
	_set_interactables_enabled(false)
	_visitor.visible = show_visitor
	_hud.start_dialogue(lines)


func _generate_and_show_triage() -> void:
	_set_interactables_enabled(false)
	var repo := DataRepository.singleton()

	# Plan carrier placements once per loop if missing.
	if GameState.save_state.loop.current_carrier_placements.is_empty():
		var director := SpawnDirector.new(repo, GameState)
		director.plan_loop_placements()

	var generator := DeliveryGenerator.new(repo, GameState)
	var delivery := generator.generate_day_delivery(GameState.save_state.loop.current_day)
	GameState.save_state.loop.last_delivery_day = GameState.save_state.loop.current_day
	var cfg := repo.get_delivery_config()
	_triage_screen.open(delivery, cfg.storage_cap)


func _on_morning_delivery_pressed() -> void:
	if GameState.save_state.loop.current_day == GameState.save_state.loop.last_delivery_day:
		_open_dialogue(["The morning delivery has already arrived."], false)
		return
	_generate_and_show_triage()


func _on_triage_closed() -> void:
	_set_interactables_enabled(true)
	_refresh_ui()


func _on_restoration_closed() -> void:
	_set_interactables_enabled(true)
	_refresh_ui()


func _create_restoration_view() -> RestorationView:
	var view: RestorationView = RESTORATION_VIEW_SCENE.instantiate()
	add_child(view)
	return view


func _create_phone() -> Phone:
	var phone: Phone = PHONE_SCENE.instantiate()
	add_child(phone)
	return phone


func _create_storage_screen() -> StorageScreen:
	var screen: StorageScreen = STORAGE_SCREEN_SCENE.instantiate()
	add_child(screen)
	return screen


# --- Diegetic interactables ---------------------------------------------------


func _connect_interactables() -> void:
	# Each physical prop reuses the existing HUD-button handler unchanged.
	_door_interactable.activated.connect(_on_door_pressed)
	_workbench_interactable.activated.connect(_on_workbench_pressed)
	_journal_interactable.activated.connect(_on_journal_pressed)
	_phone_interactable.activated.connect(_on_phone_pressed)
	_delivery_interactable.activated.connect(_on_morning_delivery_pressed)
	for entry in _interactables():
		entry.hover_changed.connect(_on_interactable_hover.bind(entry))


func _interactables() -> Array[Interactable3D]:
	return [
		_door_interactable,
		_workbench_interactable,
		_journal_interactable,
		_phone_interactable,
		_delivery_interactable,
	]


func _on_interactable_hover(hovering: bool, source: Interactable3D) -> void:
	_hud.set_prompt(source.prompt_text if hovering else "")


## Switches every shop prop on/off together. Called whenever a full-screen overlay
## opens or closes so a click can't fall through to the shop behind it.
func _set_interactables_enabled(value: bool) -> void:
	for entry in _interactables():
		entry.set_enabled(value)
	if not value:
		_hud.set_prompt("")


func _count_inventory_by_glow(restored_only: bool) -> Dictionary:
	var counts := {}
	for i in ShopHud.Rarity.size():
		counts[i] = 0
	for raw in GameState.save_state.loop.inventory:
		if raw is Dictionary:
			var inst := ObjectInstance.from_dictionary(raw)
			var template: ScrapObjectTemplate = DataRepository.singleton().get_template(
				inst.template_id
			)
			if template == null:
				continue
			var is_restored := (
				inst.state == ModelEnums.ObjState.CLEAN or inst.state == ModelEnums.ObjState.OPEN
			)
			if is_restored == restored_only:
				var rarity: int = template.base_rarity
				if rarity >= 0 and rarity < ShopHud.Rarity.size():
					counts[rarity] = counts.get(rarity, 0) + 1
	return counts


func _count_seated_fragments() -> int:
	var count := 0
	for fragment_id in GameState.save_state.persistent.fragments.keys():
		var fragment: Fragment = GameState.save_state.persistent.fragments[fragment_id]
		if fragment.state == ModelEnums.FragmentState.SEATED:
			count += 1
	return count


func _on_dialogue_finished() -> void:
	_visitor.visible = false
	# Finishing a visitor's conversation records that the player has met them, so
	# the next visit (this loop or a later one — the flag is persistent) branches to
	# their return dialogue.
	if not _active_visitor_route_id.is_empty():
		RouteService.mark_met(_active_visitor_route_id)
		_active_visitor_route_id = ""
	_hud.set_actions_visible(true)
	# Restoring all actions can re-show buttons that sit under an open journal;
	# re-apply the journal layout so it stays consistent.
	if _book_viewport.is_open():
		_hud.set_journal_open(true)
	else:
		_set_interactables_enabled(true)
	DayClock.release_pause(DayClock.PAUSE_DIALOGUE)
