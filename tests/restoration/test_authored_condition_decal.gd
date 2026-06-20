extends GutTest
## Author-placed condition decals: a dev drops an ArtifactConditionDecal into the
## artifact scene, its type comes from the albedo file name (Rust.png -> rust), and
## it cleans in-game only with the tool that condition needs — emitting particles.
## The restoration_artifact scene ships one example (ConditionRust) on the medallion.

const VIEW_SCENE := preload("res://scenes/restoration/restoration_view.tscn")
const TEST_SAVE := "user://test_authored_view_save.json"
const TEST_TEMP := "user://test_authored_view_save.tmp"

var _view: RestorationView


func before_each() -> void:
	SaveService.set_save_paths(TEST_SAVE, TEST_TEMP)
	SaveService.delete_save_files()
	DataRepository.singleton().load_from_filesystem()
	GameState.initialize("authored-view-player")
	GameState.set_debug_seed_override(4242)
	GameState.new_run()
	for tool_id in ["rust_brush", "soft_brush", "damp_cloth"]:
		GameState.save_state.loop.tool_items.append(tool_id)
	DayClock.reset()


func after_each() -> void:
	if is_instance_valid(_view):
		_view.close()
		_view.queue_free()
		_view = null
	DayClock.reset()
	SaveService.delete_save_files()
	SaveService.set_save_paths(SaveService.DEFAULT_SAVE_PATH, SaveService.DEFAULT_TEMP_PATH)


func _add_object(uid: String, template_id: String) -> void:
	var inst := ObjectInstance.new()
	inst.template_id = template_id
	inst.uid = uid
	inst.condition = 0.0
	inst.state = ModelEnums.ObjState.DIRTY
	inst.storage_cost = 1
	GameState.save_state.loop.inventory.append(inst.to_dictionary())


func _make_view() -> RestorationView:
	var view: RestorationView = VIEW_SCENE.instantiate()
	add_child_autofree(view)
	await wait_physics_frames(1)
	return view


func _open_with_object() -> RestorationObject3D:
	_add_object("obj_1", "tarnished_pendant")
	_view = await _make_view()
	_view.open()
	_view.load_instance("obj_1")
	return _view.get_restoration_object()


# --- The node ----------------------------------------------------------------


func test_condition_slug_derives_type_from_albedo_filename() -> void:
	var decal := ArtifactConditionDecal.new()
	add_child_autofree(decal)
	decal.texture_albedo = load("res://assets/artifact_conditions/Water Stain.png")
	assert_eq(decal.condition_slug(), "water_stain")
	decal.texture_albedo = load("res://assets/artifact_conditions/Rust.png")
	assert_eq(decal.condition_slug(), "rust")


# --- Registration on the artifact --------------------------------------------


func test_artifact_registers_its_authored_rust_decal() -> void:
	var obj := await _open_with_object()
	assert_true(obj.has_authored_conditions(), "scene ships an authored decal")
	var ids := obj.uncleaned_authored_ids()
	assert_eq(ids.size(), 1)
	# Rust.png -> rust -> the journal says rust is treated by the wire/rust brush.
	assert_eq(obj.authored_required_tool(ids[0]), "rust_brush")


# --- Cleaning ----------------------------------------------------------------


func _aim_at(obj: RestorationObject3D, condition_id: String) -> Dictionary:
	var center := obj.get_authored_global_center(condition_id)
	return {"origin": center + Vector3(0.0, 0.0, 3.0), "dir": Vector3(0.0, 0.0, -1.0)}


func test_wrong_tool_does_not_clean_authored_decal() -> void:
	var obj := await _open_with_object()
	var condition_id := obj.uncleaned_authored_ids()[0]
	_view.select_tool("soft_brush")  # wrong for rust
	var aim := _aim_at(obj, condition_id)

	var cleaned := _view.attempt_clean_authored_with_ray(aim["origin"], aim["dir"])

	assert_false(cleaned, "wrong tool is rejected")
	assert_eq(obj.uncleaned_authored_ids().size(), 1, "decal stays")


func test_correct_tool_cleans_authored_decal_and_emits_particles() -> void:
	var obj := await _open_with_object()
	var condition_id := obj.uncleaned_authored_ids()[0]
	var decal := obj.get_node(condition_id) as ArtifactConditionDecal
	_view.select_tool("rust_brush")
	var aim := _aim_at(obj, condition_id)

	var cleaned := _view.attempt_clean_authored_with_ray(aim["origin"], aim["dir"])

	assert_true(cleaned, "correct tool cleans it")
	assert_true(decal.is_cleaned())
	assert_eq(obj.uncleaned_authored_ids().size(), 0)
	var particles := decal.get_node("CleanParticles") as GPUParticles3D
	assert_true(particles.emitting, "cleaning spawns the particle burst")
