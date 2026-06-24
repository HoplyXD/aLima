extends GutTest

## Integration tests for the visible 3D tool props in the restoration view (P4.8):
## picking a bench prop selects the tool, the picked tool drives cleaning through
## RestorationService, the labelled HUD fallback button still selects a tool, and
## the controller/keyboard cycle action advances through owned tools. Kept in a
## dedicated file (alongside test_restoration_view.gd) so each presentation-boundary
## suite stays focused. Selection is driven through analytic world-space rays.

const VIEW_SCENE := preload("res://scenes/restoration/restoration_view.tscn")
const TEST_SAVE := "user://test_restoration_tool_props_save.json"
const TEST_TEMP := "user://test_restoration_tool_props_save.tmp"

const HIT_ORIGIN := Vector3(0.0, 0.0, 3.0)
const HIT_DIR := Vector3(0.0, 0.0, -1.0)

var _view: RestorationView


func before_each() -> void:
	SaveService.set_save_paths(TEST_SAVE, TEST_TEMP)
	SaveService.delete_save_files()
	GameState.initialize("restoration-toolprops-player")
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


func _add_pendant(uid: String) -> void:
	var inst := ObjectInstance.new()
	inst.template_id = "tarnished_pendant"
	inst.uid = uid
	inst.condition = 0.0
	inst.state = ModelEnums.ObjState.DIRTY
	inst.value = 120
	inst.storage_cost = 1
	GameState.save_state.loop.inventory.append(inst.to_dictionary())


func _make_view() -> RestorationView:
	var view: RestorationView = VIEW_SCENE.instantiate()
	add_child_autofree(view)
	await wait_physics_frames(1)
	return view


## A world ray that strikes a built tool prop straight down the camera axis.
func _ray_to_prop(view: RestorationView, tool_id: String) -> Dictionary:
	var prop := view.get_tool_tray().get_prop(tool_id)
	var center: Vector3 = prop.global_position + RestorationToolTray.PICK_CENTER_OFFSET
	return {"origin": Vector3(center.x, center.y, center.z + 3.0), "dir": Vector3(0.0, 0.0, -1.0)}


func _has_mesh_instance(node: Node) -> bool:
	if node is MeshInstance3D:
		return true
	for child in node.get_children():
		if _has_mesh_instance(child):
			return true
	return false


## A tool WITH an authored per-tool scene (scenes/restoration/tools/<id>.tscn) builds the
## real model; one WITHOUT a scene falls back to the procedural placeholder. Both render a
## mesh, so the bench and Storage previews always show something for every tool.
func test_build_tool_model_uses_authored_scene_or_falls_back() -> void:
	var modeled := RestorationTool.build_tool_model("rust_brush")
	add_child_autofree(modeled)
	assert_eq(modeled.name, &"rust_brush", "the authored per-tool scene root is used")
	assert_true(_has_mesh_instance(modeled), "the authored model has visible geometry")

	var fallback := RestorationTool.build_tool_model("nonexistent_tool")  # no per-tool scene
	add_child_autofree(fallback)
	assert_true(_has_mesh_instance(fallback), "a tool without a scene still gets placeholder geometry")


func test_tool_tray_builds_props_for_owned_tools() -> void:
	_add_pendant("pendant_props")
	_view = await _make_view()
	_view.open()
	assert_eq(
		_view.get_tool_tray().get_tool_ids(),
		["soft_cloth", "rust_brush"],
		"The bench shows a 3D prop for each owned tool"
	)


func test_picking_a_tool_prop_selects_that_tool() -> void:
	_add_pendant("pendant_pickprop")
	_view = await _make_view()
	_view.open()
	var ray := _ray_to_prop(_view, "soft_cloth")

	var picked := _view.attempt_select_tool_with_ray(ray["origin"], ray["dir"])
	assert_eq(picked, "soft_cloth", "Aiming at the cloth prop selects the cloth")
	assert_eq(_view.get_selected_tool_id(), "soft_cloth", "View tracks the prop selection")
	assert_true(_view.get_tool_tray().is_selected("soft_cloth"), "The prop is shown as selected")


func test_picked_tool_prop_drives_cleaning_through_the_service() -> void:
	_add_pendant("pendant_propclean")
	_view = await _make_view()
	_view.open()
	var ray := _ray_to_prop(_view, "soft_cloth")
	_view.attempt_select_tool_with_ray(ray["origin"], ray["dir"])
	var before := RestorationService.new().find_instance_by_id("pendant_propclean").condition

	var result := _view.attempt_clean_with_ray(HIT_ORIGIN, HIT_DIR)
	assert_not_null(result, "A surface hit after picking the prop cleans")
	assert_true(result.compatible, "The picked cloth is the compatible tool")
	var after := RestorationService.new().find_instance_by_id("pendant_propclean").condition
	assert_gt(after, before, "Cleaning with the picked prop raises condition via the service")


func test_fallback_tool_button_still_selects_a_tool() -> void:
	_add_pendant("pendant_fallback")
	_view = await _make_view()
	_view.open()
	var container: HBoxContainer = _view.get_node(
		"HUD/BottomPanel/Margin/VBox/ToolRow/ToolContainer"
	)
	var pressed_any := false
	for child in container.get_children():
		if child is Button and (child as Button).text == "Soft Cleaning Cloth":
			(child as Button).pressed.emit()
			pressed_any = true
	assert_true(pressed_any, "The accessibility/fallback tool button exists")
	assert_eq(
		_view.get_selected_tool_id(), "soft_cloth", "The fallback button selects the tool too"
	)
	assert_true(
		_view.get_tool_tray().is_selected("soft_cloth"), "Prop reflects the fallback choice"
	)


func test_cycle_tool_advances_through_owned_tools() -> void:
	_add_pendant("pendant_cycle")
	_view = await _make_view()
	_view.open()
	_view.cycle_tool(1)
	assert_eq(_view.get_selected_tool_id(), "soft_cloth", "First cycle selects the first tool")
	_view.cycle_tool(1)
	assert_eq(_view.get_selected_tool_id(), "rust_brush", "Next cycle advances to the next tool")
	_view.cycle_tool(1)
	assert_eq(_view.get_selected_tool_id(), "soft_cloth", "Cycling wraps around")
