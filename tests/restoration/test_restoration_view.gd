extends GutTest

## Presentation-boundary tests for the focused 3D restoration view (P4.7).
##
## These cover the view's delegation to RestorationService, surface-stroke and
## clasp behaviour, rotation/reset, pause ownership, and carrier-identity hiding.
## They deliberately avoid asserting on rendered pixels or fixed screen coordinates
## — surface hits are driven through analytic world-space rays and explicit UVs.
## The authored Phase 4 logic suite (test_restoration_service.gd) stays the source
## of truth for the underlying rules and is left untouched.

const SHOP_SCENE := preload("res://scenes/Shop.tscn")
const VIEW_SCENE := preload("res://scenes/restoration/restoration_view.tscn")
const TEST_SAVE := "user://test_restoration_view_save.json"
const TEST_TEMP := "user://test_restoration_view_save.tmp"

# A world-space ray that strikes the medallion (centred at the pivot origin) and
# one that misses it entirely.
const HIT_ORIGIN := Vector3(0.0, 0.0, 3.0)
const HIT_DIR := Vector3(0.0, 0.0, -1.0)
const MISS_ORIGIN := Vector3(0.0, 5.0, 3.0)
const MISS_DIR := Vector3(0.0, 1.0, 0.0)

var _view: RestorationView


func before_each() -> void:
	SaveService.set_save_paths(TEST_SAVE, TEST_TEMP)
	SaveService.delete_save_files()
	GameState.initialize("restoration-view-player")
	GameState.set_debug_seed_override(4242)
	GameState.new_run()
	_grant_starting_tools()
	DayClock.reset()


func after_each() -> void:
	if is_instance_valid(_view):
		_view.close()
		_view.queue_free()
		_view = null
	DayClock.reset()
	SaveService.delete_save_files()
	SaveService.set_save_paths(SaveService.DEFAULT_SAVE_PATH, SaveService.DEFAULT_TEMP_PATH)


func _grant_starting_tools() -> void:
	GameState.save_state.loop.tool_items.append("soft_cloth")
	GameState.save_state.loop.tool_items.append("rust_brush")
	GameState.save_state.persistent.legacy_items.append("soft_cloth")
	GameState.save_state.persistent.techniques_learned.append("pendant_cleaning")


func _add_pendant(
	uid: String,
	is_carrier: bool = false,
	condition: float = 0.0,
	contents: int = ModelEnums.OpenResult.EMPTY
) -> void:
	var inst := ObjectInstance.new()
	inst.template_id = "tarnished_pendant"
	inst.uid = uid
	inst.condition = condition
	inst.state = ModelEnums.ObjState.DIRTY
	inst.is_carrier = is_carrier
	inst.fragment_id = "fragment_01" if is_carrier else ""
	inst.contents = contents
	inst.value = 120
	inst.storage_cost = 1
	GameState.save_state.loop.inventory.append(inst.to_dictionary())


func _make_view() -> RestorationView:
	var view: RestorationView = VIEW_SCENE.instantiate()
	add_child_autofree(view)
	await wait_physics_frames(1)
	return view


func _instance_state(uid: String) -> int:
	return RestorationService.new().find_instance_by_id(uid).state


func _clean_until_clean(view: RestorationView, uid: String) -> void:
	var guard := 0
	while RestorationService.new().find_instance_by_id(uid).state == ModelEnums.ObjState.DIRTY:
		var result := view.attempt_clean_with_ray(HIT_ORIGIN, HIT_DIR)
		assert_not_null(result, "Surface hit must produce a cleaning action")
		guard += 1
		if guard > 20:
			break


func test_switching_artifacts_preserves_exact_cleaned_spots() -> void:
	_add_pendant("p_a")
	_add_pendant("p_b")
	_view = await _make_view()
	_view.open()
	_view.load_instance("p_a")
	_view.select_tool("soft_cloth")

	# One stroke — partial clean (does not reach CLEAN) in a specific spot.
	var result := _view.attempt_clean_with_ray(HIT_ORIGIN, HIT_DIR)
	assert_not_null(result, "a surface hit cleans")
	var coverage_a := _view.get_restoration_object().coverage()
	assert_gt(coverage_a, 0.0, "some surface was cleaned")

	# Switch to another artifact and back.
	_view.load_instance("p_b")
	_view.load_instance("p_a")

	var coverage_back := _view.get_restoration_object().coverage()
	assert_almost_eq(
		coverage_back, coverage_a, 0.001, "exact cleaned spots restored, not rebuilt from condition"
	)


func test_cleaned_spots_persist_through_save_and_reload() -> void:
	_add_pendant("p_a")
	_view = await _make_view()
	_view.open()
	_view.load_instance("p_a")
	_view.select_tool("soft_cloth")
	_view.attempt_clean_with_ray(HIT_ORIGIN, HIT_DIR)
	var coverage_a := _view.get_restoration_object().coverage()
	assert_gt(coverage_a, 0.0, "some surface was cleaned")
	_view.close()  # persists the mask onto the instance and saves

	# Reload from disk into a brand-new view (no in-memory cache to fall back on).
	var loaded := SaveService.load_game()
	assert_true(loaded.ok, "save reloads")
	var view2: RestorationView = VIEW_SCENE.instantiate()
	add_child_autofree(view2)
	await wait_physics_frames(1)
	view2.open()
	view2.load_instance("p_a")

	var coverage_reloaded := view2.get_restoration_object().coverage()
	view2.close()
	assert_almost_eq(
		coverage_reloaded, coverage_a, 0.001, "cleaned spots survive save/reload"
	)


# --- Workbench integration / pause ownership --------------------------------


func test_workbench_opens_focused_3d_restoration_scene() -> void:
	var shop: Node3D = SHOP_SCENE.instantiate()
	add_child_autofree(shop)
	await wait_physics_frames(1)
	DayClock.running = false
	DayClock.reset()
	DayClock.running = true
	DayClock.start_day(1)

	var hud: ShopHud = shop.get_node("HUD")
	hud.workbench_pressed.emit()
	await wait_physics_frames(1)

	var view: RestorationView = shop.get_node("RestorationView")
	assert_true(view.visible, "Workbench opens the restoration view")
	assert_not_null(
		view.get_node_or_null("ViewportContainer/SubViewport"), "View is a focused 3D scene"
	)
	assert_not_null(view.get_restoration_object(), "View has a manipulable 3D object")
	assert_false(DayClock.is_paused(), "the bench no longer pauses the clock — time keeps moving")
	DayClock.reset()


func test_open_and_close_do_not_pause_the_clock() -> void:
	_view = await _make_view()
	_view.open()
	assert_false(_view.owns_pause(), "the bench no longer owns a clock pause")
	assert_false(DayClock.is_paused(), "time keeps running at the bench")

	# A dialogue pause from elsewhere is untouched by the bench opening/closing.
	DayClock.request_pause(DayClock.PAUSE_DIALOGUE)
	_view.close()
	assert_true(DayClock.is_paused(), "the bench never resumes a dialogue-held clock")
	DayClock.release_pause(DayClock.PAUSE_DIALOGUE)
	assert_false(DayClock.is_paused())


func test_close_and_exit_do_not_double_release_pause() -> void:
	_view = await _make_view()
	_view.open()
	_view.close()
	assert_eq(DayClock.pause_owner_count(), 0)
	# A second close (and the eventual tree exit) must be harmless no-ops.
	_view.close()
	assert_eq(DayClock.pause_owner_count(), 0, "Repeated close does not re-release")
	assert_false(_view.owns_pause())


# --- Instance loading --------------------------------------------------------


func test_open_loads_selected_inventory_instance() -> void:
	_add_pendant("pendant_load")
	_view = await _make_view()
	_view.open()
	assert_eq(_view.get_selected_uid(), "pendant_load", "First restorable instance is loaded")
	var title: Label = _view.get_node("HUD/TopBar/Margin/Bar/Title")
	assert_eq(title.text, "Tarnished Pendant", "Loads the instance's template name")


# --- Rotation ----------------------------------------------------------------


func test_rotation_changes_pivot_without_mutating_state() -> void:
	_add_pendant("pendant_rot")
	_view = await _make_view()
	_view.open()
	var obj := _view.get_restoration_object()
	var before_basis := obj.get_orientation_basis()
	var before := RestorationService.new().find_instance_by_id("pendant_rot")

	_view.rotate_view(0.6, 0.25)
	var after_basis := obj.get_orientation_basis()
	var after := RestorationService.new().find_instance_by_id("pendant_rot")

	assert_false(before_basis.is_equal_approx(after_basis), "Rotation changes the pivot")
	assert_eq(after.condition, before.condition, "Rotation must not change condition")
	assert_eq(after.value, before.value, "Rotation must not change value")
	assert_eq(after.state, before.state, "Rotation must not change state")


func test_reset_view_restores_authored_orientation() -> void:
	_add_pendant("pendant_reset")
	_view = await _make_view()
	_view.open()
	var obj := _view.get_restoration_object()
	_view.rotate_view(1.0, 0.4)
	_view.reset_view()
	assert_true(
		obj.get_orientation_basis().is_equal_approx(obj.get_authored_basis()),
		"Reset returns to the authored orientation"
	)


# --- Surface cleaning --------------------------------------------------------


func test_cleaning_empty_space_does_nothing() -> void:
	_add_pendant("pendant_miss")
	_view = await _make_view()
	_view.open()
	_view.select_tool("soft_cloth")
	var before := RestorationService.new().find_instance_by_id("pendant_miss").condition

	var result := _view.attempt_clean_with_ray(MISS_ORIGIN, MISS_DIR)
	assert_null(result, "A ray that misses the object performs no cleaning")
	var after := RestorationService.new().find_instance_by_id("pendant_miss").condition
	assert_eq(after, before, "Empty-space cleaning leaves condition unchanged")


func test_surface_hit_produces_deliberate_cleaning_action() -> void:
	_add_pendant("pendant_hit")
	_view = await _make_view()
	_view.open()
	_view.select_tool("soft_cloth")
	var before := RestorationService.new().find_instance_by_id("pendant_hit").condition

	var result := _view.attempt_clean_with_ray(HIT_ORIGIN, HIT_DIR)
	assert_not_null(result, "A surface hit produces a cleaning action")
	assert_true(result.ok)
	assert_true(result.compatible)
	var after := RestorationService.new().find_instance_by_id("pendant_hit").condition
	assert_gt(after, before, "Correct-tool surface stroke raises condition via the service")
	assert_gt(_view.get_restoration_object().coverage(), 0.0, "Worked area visibly clears")


func test_correct_tool_strokes_reach_clean() -> void:
	_add_pendant("pendant_clean")
	_view = await _make_view()
	_view.open()
	_view.select_tool("soft_cloth")
	_clean_until_clean(_view, "pendant_clean")
	assert_eq(
		_instance_state("pendant_clean"),
		ModelEnums.ObjState.CLEAN,
		"Repeated correct-tool strokes reach CLEAN through the service"
	)


func test_wrong_tool_strokes_preserve_damage_consequences() -> void:
	_add_pendant("pendant_wrong", false, 60.0)
	_view = await _make_view()
	_view.open()
	_view.select_tool("rust_brush")
	var before := RestorationService.new().find_instance_by_id("pendant_wrong")

	var result := _view.attempt_clean_with_ray(HIT_ORIGIN, HIT_DIR)
	assert_not_null(result)
	assert_false(result.compatible, "Wrong tool is incompatible")
	var after := RestorationService.new().find_instance_by_id("pendant_wrong")
	assert_gt(after.recorded_damage, before.recorded_damage, "Wrong tool records damage")
	assert_lt(after.condition, before.condition, "Wrong tool lowers condition")


func test_visual_coverage_cannot_bypass_condition_gate() -> void:
	_add_pendant("pendant_bypass")
	_view = await _make_view()
	_view.open()
	_view.select_tool("soft_cloth")
	# Force the visual mask fully clean directly; the service never saw a stroke.
	_view.get_restoration_object().set_fully_clean()
	assert_almost_eq(_view.get_restoration_object().coverage(), 1.0, 0.001)
	assert_eq(
		_instance_state("pendant_bypass"),
		ModelEnums.ObjState.DIRTY,
		"Visual cleanliness alone never reaches CLEAN; only the service does"
	)


# --- Clasp -------------------------------------------------------------------


func test_cleaning_does_not_auto_open_clasp() -> void:
	_add_pendant("pendant_noauto")
	_view = await _make_view()
	_view.open()
	_view.select_tool("soft_cloth")
	_clean_until_clean(_view, "pendant_noauto")
	assert_eq(_instance_state("pendant_noauto"), ModelEnums.ObjState.CLEAN)
	assert_true(
		_view.get_restoration_object().is_clasp_interactive(),
		"Clasp becomes available at CLEAN but does not open itself"
	)


func test_dirty_clasp_interaction_is_rejected() -> void:
	_add_pendant("pendant_dirtyclasp")
	_view = await _make_view()
	_view.open()
	var result := _view.try_open_clasp()
	assert_false(result.ok, "A dirty pendant rejects the clasp interaction")
	assert_eq(_instance_state("pendant_dirtyclasp"), ModelEnums.ObjState.DIRTY)


func test_clean_pendant_clasp_opens_once() -> void:
	_add_pendant("pendant_open", true, 0.0, ModelEnums.OpenResult.FRAGMENT)
	_view = await _make_view()
	_view.open()
	_view.select_tool("soft_cloth")
	_clean_until_clean(_view, "pendant_open")

	var first := _view.try_open_clasp()
	assert_true(first.ok, "A clean pendant can be opened via the clasp")
	assert_eq(first.result, ModelEnums.OpenResult.FRAGMENT)
	assert_eq(_instance_state("pendant_open"), ModelEnums.ObjState.OPEN)

	var second := _view.try_open_clasp()
	assert_false(second.ok, "Opening is single-use")


# --- Carrier identity hiding -------------------------------------------------


func test_ordinary_and_carrier_share_presentation_path_and_hide_identity() -> void:
	_add_pendant("ord_pendant", false)
	_add_pendant("car_pendant", true, 0.0, ModelEnums.OpenResult.FRAGMENT)
	_view = await _make_view()
	_view.open()

	_view.load_instance("ord_pendant")
	var ord_sig := _presentation_signature(_view)
	_view.load_instance("car_pendant")
	var car_sig := _presentation_signature(_view)

	assert_eq(car_sig, ord_sig, "Carrier and ordinary pendant present identically before opening")
	assert_false(_hud_text_reveals_carrier(_view), "No HUD text reveals carrier identity")


# --- Tool loadout / mode --------------------------------------------------------


func test_switching_to_rotate_puts_the_held_tool_down() -> void:
	_add_pendant("p_a")
	_view = await _make_view()
	_view.open()
	_view.load_instance("p_a")
	_view.select_tool("soft_cloth")
	assert_eq(_view.get_selected_tool_id(), "soft_cloth", "a tool is held in clean mode")

	_view._toggle_mode()  # CLEAN -> ROTATE
	assert_eq(_view.get_mode(), RestorationView.Mode.ROTATE)
	assert_eq(_view.get_selected_tool_id(), "", "rotate puts the held tool down")


func test_unequipping_in_storage_drops_the_tool_from_the_bench() -> void:
	var tools := ToolService.new(GameState, DataRepository.singleton())
	var inst := tools.grant_tool("rust_brush")  # auto-equipped into the loadout
	_add_pendant("p_a")
	_view = await _make_view()
	_view.open()
	_view.load_instance("p_a")
	_view.select_tool("rust_brush")
	assert_true(_view.get_tool_tray().get_tool_ids().has("rust_brush"), "tool is on the table")

	# Unequip it in Storage, then simulate Storage closing back to the bench.
	tools.remove_from_workbench(inst.uid)
	_view._on_storage_closed_from_bench()

	assert_eq(_view.get_selected_tool_id(), "", "the held, now-unequipped tool is put down")
	assert_false(
		_view.get_tool_tray().get_tool_ids().has("rust_brush"), "and it leaves the table"
	)


func _presentation_signature(view: RestorationView) -> Dictionary:
	var obj := view.get_restoration_object()
	var title: Label = view.get_node("HUD/TopBar/Margin/Bar/Title")
	return {
		"title": title.text,
		"coverage": obj.coverage(),
		"clasp_interactive": obj.is_clasp_interactive(),
	}


func _hud_text_reveals_carrier(view: RestorationView) -> bool:
	var paths := [
		"HUD/TopBar/Margin/Bar/Title",
		"HUD/LeftMeters/Margin/VBox/StateLabel",
		"HUD/LeftMeters/Margin/VBox/ConditionLabel",
		"HUD/LeftMeters/Margin/VBox/ClaspPrompt",
		"HUD/BottomPanel/Margin/VBox/CaptionLabel",
		"HUD/BottomPanel/Margin/VBox/FeedbackLabel",
	]
	for path in paths:
		var label: Label = view.get_node(path)
		var text := label.text.to_lower()
		if text.find("carrier") >= 0 or text.find("fragment") >= 0:
			return true
	return false
