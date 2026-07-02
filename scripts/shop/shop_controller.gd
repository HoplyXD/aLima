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
const RESTORATION_ARTIFACT_SCENE := preload("res://scenes/restoration/restoration_artifact.tscn")
const ShopArtifactScenes := preload("res://scripts/restoration/artifact_scenes.gd")

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
## True while Alya is waiting at the door with the morning delivery (answer the door).
var _alya_waiting := false
## True while Alya's morning-delivery dialogue is up; triage opens when it ends.
var _alya_delivering := false

## Whether the waiting Ayla knock is the daily free drop or a scrap-sort return.
enum AylaSource { NONE, DAILY, SCRAP }
var _ayla_source: AylaSource = AylaSource.NONE

## Alya (the morning-delivery courier) portrait, shown when she knocks.
const ALYA_PORTRAIT := preload("res://assets/Characters/Scavenger.png")
## Yuyu (the uncle), standing in the shop through Day 0 until he vanishes (TUT).
const YUYU_PORTRAIT := preload("res://assets/Characters/Uncle.png")

@onready var _hud: ShopHud = $HUD
@onready var _visitor: Sprite3D = $Visitor
@onready var _visitor2: Sprite3D = $Visitor2  ## Alya (scavenger) waiting at the door.
## Day 0 placeholder Yuyu sprite (created at runtime while the tutorial runs).
var _yuyu_sprite: Sprite3D
## Restored-artifact 3D inspection overlay (created on first card click).
var _artifact_viewer: ArtifactViewer
@onready var _triage_screen: TriageController = $TriageScreen
@onready var _book_viewport: BookViewport = $BookViewport
@onready var _restoration_view: RestorationView = _create_restoration_view()
@onready var _phone: Phone = _create_phone()
@onready var _storage_screen: StorageScreen = _create_storage_screen()
## Auntie's scripted photograph showcase (Phase 10). Opens after her door dialogue
## when a beat is due; completing it records the beat and (on the final beat)
## releases her fragment through RouteService -> FragmentService.
@onready var _showcase: ShowcaseScreen = _create_showcase()
## DEBUG-only slice/placement demo overlay (F9). Excluded from normal progression.
@onready var _demo_menu: DemoMenu = _create_demo_menu()
## End-of-day evening summary/upkeep/plan screen (Phase 14, §4-N). Opened at the
## 20:00 close via EventBus.evening_started; committing it advances the day.
@onready var _evening_screen: EveningScreen = _create_evening_screen()

# Diegetic 3D shop interactables. Each one fires the same controller handler as
# its HUD fallback button, so the physical prop and the accessibility button are
# interchangeable.
@onready var _door_interactable: Interactable3D = $Interactables/DoorInteractable
@onready var _workbench_interactable: Interactable3D = $Interactables/WorkbenchInteractable
@onready var _journal_interactable: Interactable3D = $Interactables/JournalInteractable
@onready var _phone_interactable: Interactable3D = $Interactables/PhoneInteractable
@onready var _delivery_interactable: Interactable3D = $Interactables/DeliveryInteractable

## Set true ONLY on the title-screen's backdrop instance (see Antique Shop.tscn
## embedded in title_screen.tscn). The same shop scene serves as both the live game
## and the menu backdrop; in backdrop mode it presents the room only — no clock,
## delivery, HUD, or interactable wiring runs, so the live autoload state is never
## touched behind the menu. Defaults false, so the gameplay scene and tests run live.
@export var backdrop_mode: bool = false


func _ready() -> void:
	if backdrop_mode:
		_enter_backdrop_mode()
		return

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
	_hud.unrestored_card_selected.connect(_on_unrestored_card_selected)
	_hud.restored_card_selected.connect(_on_restored_card_selected)

	_connect_interactables()

	_visitor.visible = false
	_visitor2.visible = false

	DayClock.seconds_per_hour = seconds_per_hour
	LoopController.begin_session()

	_triage_screen.closed.connect(_on_triage_closed)
	_restoration_view.closed.connect(_on_restoration_closed)
	_phone.closed.connect(_on_phone_closed)
	_storage_screen.closed.connect(_on_storage_closed)
	_storage_screen.restore_requested.connect(_on_storage_restore_requested)
	_showcase.closed.connect(_on_showcase_closed)
	_register_demo_menu_action()
	# The restoration bench opens the same shared journal / marketplace / storage overlays.
	_restoration_view.set_journal_viewport(_book_viewport)
	_restoration_view.set_phone(_phone)
	_restoration_view.set_storage_screen(_storage_screen)
	_book_viewport.closed.connect(_on_journal_closed)

	AylaService.sort_ready.connect(_on_ayla_sort_ready)
	EventBus.day_changed.connect(_on_day_changed)
	# The evening runs interactively while the shop is the active scene; leaving the
	# shop (to the yard/title) drops back to auto-advance so the clock never soft-locks
	# waiting for an evening screen that isn't on screen.
	EveningService.interactive = true
	EventBus.evening_started.connect(_on_evening_started)
	_evening_screen.closed.connect(_on_evening_closed)
	_refresh_ayla_knock()

	# Day 0 (TUT): the tutorial glue presents Yuyu's dialogue and hint arrows on
	# top of the normal shop, and Yuyu himself stands in the room per step data.
	# Created only while the tutorial is active; outside it the hand-placed node
	# stays hidden (he vanished with Day 0).
	if TutorialService.is_tutorial_active():
		_create_tutorial_glue()
		_create_yuyu_sprite()
	else:
		var yuyu_node := get_node_or_null("YuyuNpc") as Sprite3D
		if yuyu_node != null:
			yuyu_node.visible = false

	_refresh_ui()
	print("[Shop] ready — HUD visible, buttons connected. Click them in the running game.")


## Presents the room as the static title-screen backdrop: hide all gameplay UI,
## stop the clock driver, and frame the room with the dedicated menu camera. The
## @onready overlay children still instantiate (hidden) but stay inert.
func _enter_backdrop_mode() -> void:
	set_process(false)
	_hud.visible = false
	_visitor.visible = false
	_visitor2.visible = false
	var menu_cam := get_node_or_null("Title Screen cam")
	if menu_cam is Camera3D:
		(menu_cam as Camera3D).make_current()


func _process(delta: float) -> void:
	# `running` is the auto-driver gate; tick() itself still no-ops while paused or
	# closed. Tests set running=false to drive the clock deterministically.
	if DayClock.running:
		DayClock.tick(delta)
	_update_clock_display()


func _exit_tree() -> void:
	# The backdrop never started the clock or any gameplay, so it must not reset
	# shared autoload state when the menu is torn down to enter the game.
	if backdrop_mode:
		return
	# Leaving the shop scene returns the evening to non-interactive auto-advance.
	EveningService.interactive = false
	# The clock is intentionally not reset here: the scrapyard keeps the same
	# running session, and SpaceManager resets it only on return-to-title.
	# Autosave on the way out so the exact day/hour/minute survives stepping into the
	# yard or quitting the game (serialize_state snapshots the live clock).
	if DayClock.running:
		SaveService.save_game()
	if _triage_screen != null:
		_triage_screen.close()


## True while the day clock is actively ticking (paused during dialogue). Exposed
## as a read-only seam for tests; not a gameplay system.
func is_day_running() -> bool:
	return DayClock.is_running()


func _refresh_ui() -> void:
	_hud.set_artifact_cards(
		_artifact_card_entries(false),
		_artifact_card_entries(true),
		SettingsService.previews_enabled(),
		_attach_card_preview
	)
	_hud.set_quest_count(_count_seated_fragments())
	_update_clock_display()


## Card entries ({uid, display_name, color}) for one strip of the top bar.
func _artifact_card_entries(restored_only: bool) -> Array:
	var out: Array = []
	var repo := DataRepository.singleton()
	for raw in GameState.save_state.loop.inventory:
		if not (raw is Dictionary):
			continue
		var inst := ObjectInstance.from_dictionary(raw)
		var template := repo.get_template(inst.template_id)
		if template == null:
			continue
		var is_restored := (
			inst.state == ModelEnums.ObjState.CLEAN or inst.state == ModelEnums.ObjState.OPEN
		)
		if is_restored != restored_only:
			continue
		out.append(
			{
				"uid": inst.uid,
				"display_name": template.display_name,
				"color": _rarity_color(template.base_rarity),
			}
		)
	return out


func _rarity_color(rarity: int) -> Color:
	var index := clampi(rarity, 0, ShopHud.RARITY.size() - 1)
	return Color.from_string(str(ShopHud.RARITY[index]["color"]), Color.WHITE)


## Embeds the rotating 3D preview (model + live conditions) into a top-bar card,
## mirroring the bench's artifact bar presentation.
func _attach_card_preview(uid: String, card: ArtifactCard) -> void:
	var service := RestorationService.new()
	var inst := service.find_instance_by_id(uid)
	if inst == null:
		return
	var template := service.get_repository().get_template(inst.template_id)
	if template == null:
		return
	var scene: PackedScene = ShopArtifactScenes.scene_for(
		template.id, RESTORATION_ARTIFACT_SCENE
	)
	var preview: RestorationObject3D = scene.instantiate()
	card.attach_preview(preview)  # in-tree first, so geometry builds in the card's world
	service.present_object(preview, inst, template, uid.hash())


func _update_clock_display() -> void:
	# Day 0 (tutorial) is clockless: show the day tag only (TUT).
	if TutorialService.is_tutorial_active():
		_hud.set_day_zero()
		_refresh_yuyu_presence()
		return
	_hud.set_day(DayClock.get_day(), DayClock.TOTAL_DAYS)
	_hud.set_time(DayClock.get_hour(), DayClock.get_minute())


## Yuyu stands in the shop on the steps whose data lists him (npcs: ["yuyu"]);
## he is gone by the finale — the empty shop IS the story beat (TUT).
func _refresh_yuyu_presence() -> void:
	if _yuyu_sprite == null:
		return
	var step := TutorialService.current_step()
	_yuyu_sprite.visible = (
		TutorialService.is_tutorial_active()
		and ModelUtils.as_string(step.get("space")) == "SHOP"
		and ModelUtils.as_string_array(step.get("npcs")).has("yuyu")
	)


## Resolves the hand-placed Yuyu node (Shop.tscn/YuyuNpc — move him in the
## editor); falls back to a runtime duplicate beside the visitor spot when the
## scene lacks one. Presentation only; step data decides when he is visible.
func _create_yuyu_sprite() -> void:
	_yuyu_sprite = get_node_or_null("YuyuNpc") as Sprite3D
	if _yuyu_sprite != null:
		_yuyu_sprite.visible = false
		return
	if _visitor == null:
		return
	_yuyu_sprite = _visitor.duplicate() as Sprite3D
	_yuyu_sprite.name = "YuyuNpc"
	_yuyu_sprite.texture = YUYU_PORTRAIT
	_yuyu_sprite.visible = false
	add_child(_yuyu_sprite)
	_yuyu_sprite.transform = _visitor.transform
	_yuyu_sprite.translate(Vector3(1.4, 0.0, 0.0))


# --- HUD intent ---------------------------------------------------------


func _on_door_pressed() -> void:
	# Alya's morning delivery takes priority: if she's waiting, answering the door
	# greets her and hands the delivery to triage when her line ends.
	if _alya_waiting:
		_alya_waiting = false
		_visitor2.visible = false
		_alya_delivering = true
		_visitor.texture = ALYA_PORTRAIT
		var lines: Array = []
		if _ayla_source == AylaSource.DAILY:
			lines = [
				"Alya: Morning! Dragged in today's haul for you.",
				"Let's sort through what's worth keeping.",
			]
		else:
			lines = [
				"Alya: Here's what I sorted from your scrap.",
				"Let's see what's worth keeping.",
			]
		_open_dialogue(lines, true)
		return
	# Day 0 (TUT): no scheduled route visitors exist yet — the door always steps
	# out to the yard while the tutorial is running.
	if TutorialService.is_tutorial_active():
		SpaceManager.go_to_yard()
		return
	# Authored dialogue + portraits live in data/routes/routes.json. The door shows
	# whichever character RouteService schedules for the current in-game day/hour,
	# branching their lines on whether the player has met them before.
	var route := RouteService.resolve_visitor(DayClock.get_day(), DayClock.get_hour())
	if route == null:
		# No visitor waiting: step outside into the walkable scrapyard.
		SpaceManager.go_to_yard()
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
	EventBus.restoration_opened.emit(GameState.save_state.loop.restore_target_uid)


## Top-bar card click on an UNRESTORED artifact: load exactly that piece onto
## the bench and open restoration on it.
func _on_unrestored_card_selected(uid: String) -> void:
	GameState.save_state.loop.restore_target_uid = uid
	_on_workbench_pressed()


## Top-bar card click on a RESTORED artifact: open the spin/zoom 3D viewer
## (viewing only — clicking outside the model exits).
func _on_restored_card_selected(uid: String) -> void:
	if _artifact_viewer == null:
		_artifact_viewer = ArtifactViewer.new()
		add_child(_artifact_viewer)
		_artifact_viewer.closed.connect(func() -> void: _set_interactables_enabled(true))
	_set_interactables_enabled(false)
	_artifact_viewer.open(uid)


func _on_journal_pressed() -> void:
	# Day 0 ending (TUT): on the finale step, touching the journal triggers the
	# blackout into Day 1 instead of opening the book.
	if TutorialService.run_finale():
		return
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
	# (max 5) to load. It covers the shop and pauses time via PAUSE_STORAGE.
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


func _generate_and_show_triage(is_free_daily: bool = false) -> void:
	_set_interactables_enabled(false)
	# Pop the loading screen up FIRST and let it paint, so the (one-time) catalog scan + delivery
	# generation below freezes behind the loading overlay instead of on Alya's face.
	_triage_screen.begin_loading()
	await get_tree().process_frame
	var repo := DataRepository.singleton()

	# Plan carrier placements once per loop if missing.
	if GameState.save_state.loop.current_carrier_placements.is_empty():
		var director := SpawnDirector.new(repo, GameState)
		director.plan_loop_placements()

	# Consume the earned scrap sort unless this is the separate daily free drop.
	if not is_free_daily:
		AylaService.consume_sort()

	# Trigger/apply morning mini-events (Rush Delivery, Mystery Box, Community Request,
	# Suspicious Antique) before generating the batch so their modifiers and injected
	# instances are included. Scrap bias is layered on top of the event-adjusted weights
	# and only touches rarity weights, so event batch-size/storage effects remain intact.
	# Day 0 (TUT) never rolls events: their injected extras bypass the tutorial's
	# rarity/condition constraints (that's where the odd uncommon artifact came from).
	var tutorial_active := TutorialService.is_tutorial_active()
	if not tutorial_active:
		EventDirector.roll_morning_event(GameState.save_state.loop.current_day)
	var event_cfg := EventDirector.modify_delivery_config(repo.get_delivery_config())
	# The daily free drop uses the event-adjusted base config; only scrap-sort
	# returns get the scrap-bias layer applied.
	var biased_cfg := event_cfg
	if not is_free_daily:
		biased_cfg = AylaService.get_biased_delivery_config(event_cfg)
	# Day 0 (TUT): the taught batch is EXACTLY TWO random common artifacts carrying
	# both whitelisted conditions. Yuyu tells you to keep one and recycle the other.
	if tutorial_active:
		biased_cfg.rarity_weights = {ModelEnums.rarity_name(ModelEnums.Rarity.WHITE): 1.0}
		biased_cfg.batch_min = 2
		biased_cfg.batch_max = 2
	var extras: Array[ObjectInstance] = []
	if not tutorial_active:
		extras = EventDirector.get_injected_delivery_extras(GameState.save_state.loop.current_day)

	var generator := DeliveryGenerator.new(repo, GameState)
	var delivery := generator.generate_day_delivery(
		GameState.save_state.loop.current_day, biased_cfg, extras
	)
	_triage_screen.open(delivery, biased_cfg.storage_cap, is_free_daily)


func _on_morning_delivery_pressed() -> void:
	# Hidden accessibility fallback. If Ayla is already waiting at the door, answer it;
	# otherwise generate the daily free drop if still due, or a ready scrap sort.
	if _alya_waiting:
		_on_door_pressed()
		return
	if AylaService.is_sort_ready():
		_generate_and_show_triage(false)
		return
	if GameState.save_state.loop.last_delivery_day != GameState.save_state.loop.current_day:
		_generate_and_show_triage(true)
		return
	_open_dialogue(["No deliveries are waiting right now."], false)


## Called when the in-game day advances. Ayla may show up with the free morning drop.
func _on_day_changed(_day: int) -> void:
	_refresh_ayla_knock()


## Re-arm the door knock for a finished scrap sort (called by signal) or a new day.
## Sort returns take priority over the daily free drop; the other is queued after
## the current knock is answered.
func _refresh_ayla_knock() -> void:
	if _alya_waiting or _alya_delivering or _triage_screen.visible:
		return
	if AylaService.is_sort_ready():
		_ayla_source = AylaSource.SCRAP
		_alya_waiting = true
		_visitor2.texture = ALYA_PORTRAIT
		_visitor2.visible = true
		return
	# Day 0 (TUT): only the taught forage -> hand-off -> sort flow may knock; the
	# daily free drop starts with the normal days.
	if TutorialService.is_tutorial_active():
		return
	if GameState.save_state.loop.last_delivery_day != GameState.save_state.loop.current_day:
		_ayla_source = AylaSource.DAILY
		_alya_waiting = true
		_visitor2.texture = ALYA_PORTRAIT
		_visitor2.visible = true


## Wrapper for the AylaService sort_ready signal.
func _on_ayla_sort_ready(_day: int, _hour: int) -> void:
	_refresh_ayla_knock()


func _on_triage_closed() -> void:
	_set_interactables_enabled(true)
	_refresh_ui()
	_refresh_ayla_knock()


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


func _create_showcase() -> ShowcaseScreen:
	var screen := ShowcaseScreen.new()
	add_child(screen)
	return screen


func _create_demo_menu() -> DemoMenu:
	var menu := DemoMenu.new()
	add_child(menu)
	return menu


func _create_evening_screen() -> EveningScreen:
	var screen := EveningScreen.new()
	add_child(screen)
	return screen


func _create_tutorial_glue() -> TutorialGlue:
	var glue := TutorialGlue.new()
	glue.setup(
		"SHOP",
		{
			"door": _door_interactable,
			"workbench": _workbench_interactable,
			"journal": _journal_interactable,
			"phone": _phone_interactable,
			"storage": _delivery_interactable,
		}
	)
	add_child(glue)
	return glue


# --- Evening (Phase 14, §4-N) -------------------------------------------------


## Opens the evening screen when the day closes (EVE-R1). Committing it advances the
## day through EveningService -> LoopController.
func _on_evening_started(day: int) -> void:
	_hud.set_actions_visible(false)
	_set_interactables_enabled(false)
	_evening_screen.open(day)


func _on_evening_closed() -> void:
	_hud.set_actions_visible(true)
	_set_interactables_enabled(true)
	_refresh_ui()


# --- Diegetic interactables ---------------------------------------------------


func _connect_interactables() -> void:
	# Each physical prop reuses the existing HUD-button handler. The workbench opens the
	# restoration bench; the morning-delivery box is now Storage (pick an artifact +
	# Restore there to enter the bench with it loaded); Alya's delivery comes via the
	# door each morning.
	_door_interactable.activated.connect(_on_door_pressed)
	_workbench_interactable.activated.connect(_on_workbench_pressed)
	_journal_interactable.activated.connect(_on_journal_pressed)
	_phone_interactable.activated.connect(_on_phone_pressed)
	_delivery_interactable.activated.connect(_on_storage_pressed)
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
	# their return dialogue. It also answers the scheduled visit so it is not later
	# consumed as missed.
	var finished_route_id := _active_visitor_route_id
	if not finished_route_id.is_empty():
		RouteService.mark_met(finished_route_id)
		RouteService.notify_visit_answered(finished_route_id, DayClock.get_day())
		_active_visitor_route_id = ""
	_hud.set_actions_visible(true)
	# Restoring all actions can re-show buttons that sit under an open journal;
	# re-apply the journal layout so it stays consistent.
	if _book_viewport.is_open():
		_hud.set_journal_open(true)
	else:
		_set_interactables_enabled(true)
	DayClock.release_pause(DayClock.PAUSE_DIALOGUE)
	# Alya's knock is over — now hand the delivery to triage.
	if _alya_delivering:
		_alya_delivering = false
		var was_daily := _ayla_source == AylaSource.DAILY
		_ayla_source = AylaSource.NONE
		_generate_and_show_triage(was_daily)
		return
	# After a route's door conversation, open its scripted showcase if a beat is due.
	if not finished_route_id.is_empty():
		_maybe_open_showcase(finished_route_id)


## Opens the route's scripted showcase when a beat is authored and ready for the
## current day (RouteService.due_beat handles the ordinal gating). The showcase, not
## the dialogue, records the beat and triggers any fragment release.
func _maybe_open_showcase(route_id: String) -> void:
	var beat := RouteService.due_beat(route_id, DayClock.get_day())
	if beat.is_empty():
		return
	var route := DataRepository.singleton().get_route(route_id)
	if route == null:
		return
	_hud.set_actions_visible(false)
	_set_interactables_enabled(false)
	_showcase.open(route, beat)


func _on_showcase_closed() -> void:
	_hud.set_actions_visible(true)
	_set_interactables_enabled(true)
	_refresh_ui()


# --- Debug demo menu (Phase 10, P10.6) ----------------------------------------


func _register_demo_menu_action() -> void:
	# F9 opens the DEBUG slice/placement demo menu in debug builds only.
	if not OS.is_debug_build():
		return
	if not InputMap.has_action("demo_menu"):
		InputMap.add_action("demo_menu")
		var ev := InputEventKey.new()
		ev.physical_keycode = KEY_F9
		InputMap.action_add_event("demo_menu", ev)


func _unhandled_input(event: InputEvent) -> void:
	if not OS.is_debug_build():
		return
	if InputMap.has_action("demo_menu") and event.is_action_pressed("demo_menu"):
		_demo_menu.toggle()
		get_viewport().set_input_as_handled()
