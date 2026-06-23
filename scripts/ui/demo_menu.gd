class_name DemoMenu
extends CanvasLayer
## Slice reset / placement-demo menu (Phase 10, P10.6). A clearly-labelled DEBUG
## overlay, separated from normal progression: it is reachable only via the
## `demo_menu` input action (registered at runtime, debug builds only) and never
## through any in-fiction action.
##
## It can: pick a debug seed; clear only the demo save (with an explicit confirm);
## run three seeded Spawn Director placements for the route fragment to prove the
## "same fragment, different location" variation; and release the route fragment via
## the debug override so discovery can be demonstrated without a five-day playthrough.
## It edits no production data files — every run mutates only runtime state.

const DEMO_PLAYER_ID: String = "demo-player"
const DEMO_FRAGMENT_ID: String = "fragment_01"

var _owns_pause: bool = false
var _clear_armed: bool = false

var _seed_field: LineEdit
var _status: RichTextLabel
var _clear_button: Button


func _ready() -> void:
	layer = 90
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()


func open() -> void:
	visible = true
	_clear_armed = false
	if not _owns_pause:
		DayClock.request_pause(DayClock.PAUSE_DEMO)
		_owns_pause = true
	_set_status("Debug menu. These controls never appear in normal play.")
	_clear_button.text = "Clear Demo Save"


func close() -> void:
	if visible:
		visible = false
		_release_pause_if_owned()


func _exit_tree() -> void:
	_release_pause_if_owned()


func toggle() -> void:
	if visible:
		close()
	else:
		open()


# --- Debug actions (also the test seams) --------------------------------------


func current_seed() -> int:
	return int(_seed_field.text) if _seed_field.text.is_valid_int() else 0


## Applies the chosen debug seed to the run context (takes effect on the next run).
func apply_seed() -> void:
	var seed := current_seed()
	GameState.set_debug_seed_override(seed)
	_set_status("Debug seed override set to %d (applies on the next run/loop)." % seed)


## Releases the route's fragment through the debug override, then asks the Spawn
## Director to place it so the carrier appears in an upcoming delivery. This proves
## the release path without playing the route. Returns the placement plan, if any.
func release_route_fragment() -> Dictionary:
	if not FragmentService.release_fragment(DEMO_FRAGMENT_ID, "demo override"):
		if FragmentService.is_released(DEMO_FRAGMENT_ID):
			_set_status("%s is already RELEASED." % DEMO_FRAGMENT_ID)
		else:
			_set_status("Could not release %s." % DEMO_FRAGMENT_ID)
		return {}
	var plan := _plan_placement()
	_set_status(
		(
			"Released %s via debug override; Spawn Director placed it -> %s"
			% [DEMO_FRAGMENT_ID, _describe_plan(plan)]
		)
	)
	return plan


## Runs three seeded Spawn Director placements for the same fragment/player and
## returns their audit logs, proving the "same fragment, different location" beat.
## Operates entirely in runtime state (no production data is written).
func run_placement_demo() -> Array[Dictionary]:
	var base := current_seed()
	var seeds: Array[int] = [base, base + 101, base + 202]
	var director := SpawnDirector.new(DataRepository.singleton(), GameState)
	var logs := director.run_three_seed_demo(DEMO_PLAYER_ID, DEMO_FRAGMENT_ID, seeds)
	var lines: Array[String] = ["[b]Three seeded placements of %s:[/b]" % DEMO_FRAGMENT_ID]
	for log in logs:
		(
			lines
			. append(
				(
					"  seed %d -> %s @ %s (day %d)%s"
					% [
						int(log.get("run_seed", 0)),
						str(log.get("selected_carrier_template", "?")),
						str(log.get("selected_container", "?")),
						int(log.get("selected_day", 0)),
						"  [soft-reset]" if log.get("soft_reset", false) else "",
					]
				)
			)
		)
	_set_status("\n".join(lines))
	return logs


## Clears the demo save. The first press arms the action; the second confirms it, so
## a save is never wiped on a single accidental click.
func request_clear_save() -> void:
	if not _clear_armed:
		_clear_armed = true
		_clear_button.text = "Confirm Clear (deletes save)"
		_set_status("Press again to confirm clearing the demo save.")
		return
	_clear_armed = false
	_clear_button.text = "Clear Demo Save"
	SaveService.delete_save_files()
	_set_status("Demo save cleared. Restart the slice to begin a fresh seeded run.")


func _plan_placement() -> Dictionary:
	var director := SpawnDirector.new(DataRepository.singleton(), GameState)
	director.plan_loop_placements()
	return GameState.save_state.loop.current_carrier_placements.get(DEMO_FRAGMENT_ID, {})


func _describe_plan(plan: Dictionary) -> String:
	if plan.is_empty():
		return "(no placement; check seed/state)"
	return (
		"%s @ %s (day %d)"
		% [
			str(plan.get("carrier_template_id", "?")),
			str(plan.get("container_id", "?")),
			int(plan.get("day", 0)),
		]
	)


func _set_status(text: String) -> void:
	if _status != null:
		_status.text = text


func _release_pause_if_owned() -> void:
	if _owns_pause:
		if DayClock.has_pause_owner(DayClock.PAUSE_DEMO):
			DayClock.release_pause(DayClock.PAUSE_DEMO)
		_owns_pause = false


func _build_ui() -> void:
	var backdrop := ColorRect.new()
	backdrop.color = Color(0.05, 0.02, 0.02, 0.82)
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(backdrop)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(560, 460)
	center.add_child(panel)

	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_%s" % side, 24)
	panel.add_child(margin)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	margin.add_child(col)

	var title := Label.new()
	title.text = "DEBUG — Slice / Placement Demo"
	title.add_theme_font_size_override("font_size", 26)
	col.add_child(title)

	var warn := Label.new()
	warn.text = "Not reachable in normal play. Excluded from release builds."
	warn.modulate = Color(1, 0.8, 0.4)
	col.add_child(warn)

	var seed_row := HBoxContainer.new()
	seed_row.add_theme_constant_override("separation", 8)
	col.add_child(seed_row)
	var seed_label := Label.new()
	seed_label.text = "Debug seed:"
	seed_row.add_child(seed_label)
	_seed_field = LineEdit.new()
	_seed_field.text = "12345"
	_seed_field.custom_minimum_size = Vector2(160, 0)
	seed_row.add_child(_seed_field)
	var apply_button := Button.new()
	apply_button.text = "Apply Seed"
	apply_button.pressed.connect(apply_seed)
	seed_row.add_child(apply_button)

	var demo_button := Button.new()
	demo_button.text = "Show 3 Placement Variations"
	demo_button.pressed.connect(run_placement_demo)
	col.add_child(demo_button)

	var release_button := Button.new()
	release_button.text = "Release Auntie's Fragment (debug)"
	release_button.pressed.connect(release_route_fragment)
	col.add_child(release_button)

	_clear_button = Button.new()
	_clear_button.text = "Clear Demo Save"
	_clear_button.pressed.connect(request_clear_save)
	col.add_child(_clear_button)

	_status = RichTextLabel.new()
	_status.bbcode_enabled = true
	_status.fit_content = true
	_status.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_status.custom_minimum_size = Vector2(0, 140)
	col.add_child(_status)

	var close_button := Button.new()
	close_button.text = "Close"
	close_button.pressed.connect(close)
	col.add_child(close_button)
