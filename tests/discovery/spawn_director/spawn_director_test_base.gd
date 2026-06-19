extends GutTest
## Shared setup and helpers for the Phase 5 Spawn Director test suites.

const TEST_SAVE := "user://test_phase5_save.json"
const TEST_TEMP := "user://test_phase5_save.tmp"

var _repo: DataRepository


func before_each() -> void:
	SaveService.set_save_paths(TEST_SAVE, TEST_TEMP)
	SaveService.delete_save_files()
	# Reload the repository from disk so every test starts from pristine authored
	# data, isolating the suite from cross-test singleton pollution.
	_repo = DataRepository.singleton()
	_repo.load_from_filesystem()
	# Control the starting kit for winnability tests: the production kit now ships
	# every cleaning tool, but these tests must verify that an un-obtainable required
	# tool excludes a carrier candidate. Pin a minimal kit and restore it on teardown.
	_repo.starting_kit["tool_ids"] = ["soft_cloth"] as Array
	GameState.initialize("phase5-test-player")
	GameState.set_debug_seed_override(4242)
	GameState.new_run()
	_grant_starting_kit()


func after_each() -> void:
	# Restore the authored starting kit so the override never leaks into other suites.
	_repo.load_from_filesystem()
	SaveService.delete_save_files()
	SaveService.set_save_paths(SaveService.DEFAULT_SAVE_PATH, SaveService.DEFAULT_TEMP_PATH)


func _grant_starting_kit() -> void:
	for technique_id in _repo.starting_kit.get("technique_ids", []):
		if not GameState.save_state.persistent.techniques_learned.has(technique_id):
			GameState.save_state.persistent.techniques_learned.append(technique_id)
	for tool_id in _repo.starting_kit.get("tool_ids", []):
		var tool := _repo.get_tool(tool_id)
		if tool == null:
			continue
		if tool.is_legacy:
			if not GameState.save_state.persistent.legacy_items.has(tool_id):
				GameState.save_state.persistent.legacy_items.append(tool_id)
		if not GameState.save_state.loop.tool_items.has(tool_id):
			GameState.save_state.loop.tool_items.append(tool_id)


func _make_director() -> SpawnDirector:
	return SpawnDirector.new(_repo, GameState)


func _make_generator() -> DeliveryGenerator:
	return DeliveryGenerator.new(_repo, GameState)


func _plan(fragment_id: String = "fragment_01") -> Dictionary:
	return _make_director().plan_fragment_placement(fragment_id)


func _pair_for(plan: Dictionary) -> String:
	return "%s|%s" % [plan["carrier_template_id"], plan["container_id"]]


func _tool_is_available(tool_id: String) -> bool:
	if _repo.starting_kit.get("tool_ids", []).has(tool_id):
		return true
	if GameState.save_state.persistent.legacy_items.has(tool_id):
		return true
	return GameState.save_state.loop.tool_items.has(tool_id)


func _eligible_candidates(director: SpawnDirector) -> Array[PlacementCandidate]:
	var out: Array[PlacementCandidate] = []
	for c in director.enumerate_candidates("fragment_01"):
		if c.is_eligible():
			out.append(c)
	return out
