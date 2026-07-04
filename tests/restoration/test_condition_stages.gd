extends GutTest
## Revamp A: new conditions/tools + two-stage condition chains.
##
## Data: mud -> dirt (soap then damp cloth), grease -> tarnish, mold -> water_stain.
## Engine: fully cleaning a chained condition MORPHS the authored decal into the
## revealed condition (new tool/tint/texture) instead of removing it; only the final
## link cleans away. Shops: the phone lists online tools, the mall list is separate.

const MUD_TEXTURE := "res://assets/artifact_conditions/Mud.png"


func before_each() -> void:
	DataRepository.singleton().load_from_filesystem()


# --- Data ----------------------------------------------------------------------


func test_new_conditions_load_and_validate() -> void:
	var repo := DataRepository.singleton()
	assert_true(repo.is_loaded(), "catalog with new conditions/tools validates")
	for condition_id in ["mud", "soot", "grease", "mold", "wax", "verdigris", "salt_crust"]:
		assert_not_null(repo.get_surface_condition(condition_id), condition_id + " exists")
	for tool_id in ["soap_bar", "mold_remover", "wax_scraper", "metal_polish"]:
		assert_not_null(repo.get_tool(tool_id), tool_id + " exists")


func test_reveal_chain_links_are_authored() -> void:
	var repo := DataRepository.singleton()
	assert_eq(repo.get_surface_condition("mud").reveals_condition, "dirt")
	assert_eq(repo.get_surface_condition("grease").reveals_condition, "tarnish")
	assert_eq(repo.get_surface_condition("mold").reveals_condition, "water_stain")
	assert_eq(repo.get_surface_condition("soot").reveals_condition, "")


func test_soap_cleans_mud_but_not_damp_cloth() -> void:
	var repo := DataRepository.singleton()
	assert_gt(CleaningPower.power(repo, "soap_bar", "mud"), 0, "soap cleans mud")
	assert_eq(CleaningPower.power(repo, "damp_cloth", "mud"), 0, "damp cloth cannot clean mud")
	assert_gt(CleaningPower.power(repo, "damp_cloth", "dirt"), 0, "damp cloth cleans grime")


func test_surface_condition_round_trips_reveals() -> void:
	var c := (
		SurfaceCondition
		. from_dictionary(
			{
				"id": "mud",
				"display_name": "Mud",
				"category": "surface_soil",
				"color": "#7A5C3E",
				"cleaning_tool": "soap_bar",
				"reveals_condition": "dirt",
			}
		)
	)
	assert_eq(SurfaceCondition.from_dictionary(c.to_dictionary()).reveals_condition, "dirt")


func test_condition_cannot_reveal_itself() -> void:
	var c := (
		SurfaceCondition
		. from_dictionary(
			{
				"id": "loop",
				"display_name": "Loop",
				"category": "surface_soil",
				"color": "#000000",
				"cleaning_tool": "soap_bar",
				"reveals_condition": "loop",
			}
		)
	)
	assert_false(c.validate().is_valid(), "self-reveal is a validation error")


# --- Engine: the authored decal morphs through its chain ------------------------


func _mud_object() -> RestorationObject3D:
	var obj := RestorationObject3D.new()
	add_child_autofree(obj)
	var decal := ArtifactConditionDecal.new()
	decal.name = "ConditionMud"
	decal.texture = load(MUD_TEXTURE)
	decal.position = Vector3(0, 0, 0.5)
	obj.add_child(decal)
	obj.register_authored_conditions(DataRepository.singleton())
	return obj


func test_cleaning_mud_reveals_grime_then_cleans() -> void:
	var obj := _mud_object()
	assert_eq(obj.authored_type_id("ConditionMud"), "mud")
	assert_eq(obj.authored_required_tool("ConditionMud"), "soap_bar")
	# Scrub the mud fully off: the decal must MORPH into grime, not clean away.
	var morphed := false
	for i in 20:
		morphed = not obj.apply_authored_clean("ConditionMud", 60)
		if obj.authored_type_id("ConditionMud") == "dirt":
			break
	assert_eq(obj.authored_type_id("ConditionMud"), "dirt", "mud reveals the grime underneath")
	assert_eq(obj.authored_required_tool("ConditionMud"), "damp_cloth", "grime needs its own tool")
	assert_true(morphed, "the reveal stroke does NOT report cleaned")
	assert_false(obj.uncleaned_authored_ids().is_empty(), "still dirty after the reveal")
	# Now clean the revealed grime — the FINAL link removes the condition for real.
	var cleaned := false
	for i in 20:
		cleaned = obj.apply_authored_clean("ConditionMud", 60)
		if cleaned:
			break
	assert_true(cleaned, "the final chain link cleans away")
	assert_true(obj.uncleaned_authored_ids().is_empty(), "no conditions left")


func test_single_stage_condition_still_cleans_normally() -> void:
	var obj := RestorationObject3D.new()
	add_child_autofree(obj)
	var decal := ArtifactConditionDecal.new()
	decal.name = "ConditionRust"
	decal.texture = load("res://assets/artifact_conditions/Rust.png")
	decal.position = Vector3(0, 0, 0.5)
	obj.add_child(decal)
	obj.register_authored_conditions(DataRepository.singleton())
	var cleaned := false
	for i in 20:
		cleaned = obj.apply_authored_clean("ConditionRust", 60)
		if cleaned:
			break
	assert_true(cleaned, "rust (no chain) cleans away exactly as before")


# --- Shops: online vs mall catalogs ---------------------------------------------


func test_phone_catalog_excludes_mall_tools() -> void:
	var ids: Array[String] = []
	for def in MarketplaceService.get_catalog():
		ids.append(def.id)
	assert_has(ids, "mold_remover", "online shop still lists online tools")
	assert_does_not_have(ids, "soap_bar", "mall-only tools are not in the phone shop")


func test_mall_catalog_lists_only_mall_tools() -> void:
	var ids: Array[String] = []
	for def in MarketplaceService.get_mall_catalog():
		ids.append(def.id)
	assert_has(ids, "soap_bar")
	assert_has(ids, "wax_scraper")
	assert_has(ids, "metal_polish")
	assert_does_not_have(ids, "mold_remover", "online tools are not sold at the mall")


func test_online_buy_rejects_mall_tools() -> void:
	GameState.initialize("stage-test-player")
	GameState.save_state.loop.money = 10000
	var res: Dictionary = MarketplaceService.buy("soap_bar")
	assert_false(res.get("ok", true), "phone buy refuses a mall-only tool")


func test_buy_in_person_grants_immediately() -> void:
	GameState.initialize("stage-test-player")
	GameState.save_state.loop.money = 10000
	var res: Dictionary = MarketplaceService.buy_in_person("soap_bar")
	assert_true(res.get("ok", false), str(res))
	var tools := ToolService.new(GameState, DataRepository.singleton())
	var owned_ids: Array[String] = []
	for inst in tools.get_owned_tools():
		owned_ids.append(inst.tool_id)
	assert_has(owned_ids, "soap_bar", "the tool is owned the moment it is bought")
	assert_eq(GameState.save_state.loop.tool_shipments.size(), 0, "no shipment queued")


# --- Overlay path (the LIVE condition system; decals are the hidden legacy layer) ---


func test_overlay_condition_id_follows_transform() -> void:
	var overlay := ArtifactOverlay.new()
	add_child_autofree(overlay)
	overlay.condition_texture = load(MUD_TEXTURE)
	assert_eq(overlay.get_condition_id(), "mud", "texture file name derives the condition")
	overlay.transform_to_condition("dirt", load("res://assets/artifact_conditions/Grime.png"))
	assert_eq(overlay.get_condition_id(), "dirt", "the reveal swaps the overlay's condition")
