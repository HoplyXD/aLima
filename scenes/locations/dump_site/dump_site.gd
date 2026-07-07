extends "res://scripts/scrapyard/scrapyard.gd"
class_name DumpSite

## The Dump Site is 2x the scrapyard with a forbidden zone.
## Quest items spawn here for Alya Quest 2 (cute bag) and Quest 3 (salakot).

const DUMP_SITE_SCALE := 2.0
const FORBIDDEN_ZONE_BOUNDS := AABB(Vector3(-20, 0, -30), Vector3(40, 10, 30))

var _forbidden_zone_locked: bool = true
var _forbidden_zone_block: CollisionShape3D
var _intact_fence: Node3D
var _broken_fence: Node3D

func _ready() -> void:
	# Disable auto-generated map collision — the authored Collision shapes in the
	# scene are already scaled 2x and cover the ground, walls, house, and
	# forbidden zone. The scrapyard collision generator assumes MapRoot is unscaled
	# and would place unscaled faces under $Collision, creating a mismatch.
	generate_map_collision = false

	# The new dump_site_map.tscn is already built at full 2x size; no scaling needed.
	# Let the base scrapyard set up player, HUD, dialogue, etc.
	super._ready()

	# Add collision to scrap heaps so the player can't walk through them.
	_generate_heap_collision()

	# Remove journal access — the journal stays in the shop
	if _hud != null:
		if _hud.journal_pressed.is_connected(_open_journal_overlay):
			_hud.journal_pressed.disconnect(_open_journal_overlay)
		var quick_actions := _hud.get_node_or_null("QuickActions")
		if quick_actions != null:
			for child in quick_actions.get_children():
				if child is Button and child.text == "Journal":
					child.visible = false
					break

	# Check if forbidden zone is unlocked (Day 5 quest progress)
	_update_forbidden_zone()

	# Check for Quest 2 trigger on first dump-site visit
	_check_q2_trigger()
	# Check for Quest 3 trigger on Day 5
	_check_q3_trigger()

	# Wire up the fence interactable
	_setup_fence_interactable()

	# Position Alya based on quest state
	_update_ayla_position()


func _update_forbidden_zone() -> void:
	var progress := QuestService.get_progress("alya_quest_line")
	# "q3_salakot" or later means forbidden zone is accessible
	if progress == "q3_salakot" or progress == "completed":
		_forbidden_zone_locked = false
	else:
		_forbidden_zone_locked = true

	# Show the broken fence, hide the intact fence (or vice versa)
	_intact_fence = get_node_or_null("MapRoot/DumpSiteMap/ForbiddenZone/IntactFence")
	_broken_fence = get_node_or_null("MapRoot/DumpSiteMap/ForbiddenZone/BrokenFence")

	if _intact_fence != null:
		_intact_fence.visible = _forbidden_zone_locked
	if _broken_fence != null:
		_broken_fence.visible = not _forbidden_zone_locked

	# Toggle forbidden zone collision barrier
	_forbidden_zone_block = get_node_or_null("Collision/ForbiddenZoneBlock")
	if _forbidden_zone_block != null:
		_forbidden_zone_block.disabled = not _forbidden_zone_locked


func _setup_fence_interactable() -> void:
	var fence: Interactable3D = get_node_or_null("Anchors/FenceInteractable") as Interactable3D
	if fence == null:
		return
	if not fence.activated.is_connected(_on_fence_activated):
		fence.activated.connect(_on_fence_activated)


func _on_fence_activated() -> void:
	if _forbidden_zone_locked:
		# Before Day 5 — player inner monologue
		_show_inner_monologue("I should not trespass this area...")
	else:
		# Day 5+ — transition to forbidden zone
		SpaceManager.go_to_forbidden_zone()


func _show_inner_monologue(text: String) -> void:
	var box: DialogueBox = DIALOGUE_BOX_SCENE.instantiate()
	add_child(box)
	# Free the mouse + freeze the player while the monologue is up (like every other yard dialogue),
	# so the cursor shows during exploration dialogue instead of staying captured for mouse-look.
	_enter_overlay()
	box.start([{"name": "inner", "text": text}])
	box.finished.connect(
		func() -> void:
			_exit_overlay()
			box.queue_free()
	)


func _update_ayla_position() -> void:
	var ayla_anchor: Marker3D = get_node_or_null("Anchors/AylaAnchor") as Marker3D
	if ayla_anchor == null:
		return
	var progress := QuestService.get_progress("alya_quest_line")
	if progress == "q3_salakot" or progress == "completed":
		# On Day 5, Alya is near the broken fence
		ayla_anchor.global_position = Vector3(0, 0, -30)
	else:
		# Default position near the gate
		ayla_anchor.global_position = Vector3(0, 0, 22)


## Spawn 2x the scrap with wider bounds suited to the dump site.
func _spawn_scrap_items() -> void:
	var scrap_cfg := DataRepository.singleton().get_scrap_config()
	var rng := GameState.make_rng("dump_site_scatter_day_%d" % DayClock.get_day())

	# Double the base count for the larger dump site
	var desired_count := scrap_cfg.base_scatter_count * 2
	var bonus_key := str(DayClock.get_day())
	desired_count += int(scrap_cfg.per_day_scatter_bonus.get(bonus_key, 0))
	desired_count += rng.randi_range(0, 1)

	var loop := GameState.save_state.loop
	if loop.dump_site_scrap_remaining < 0:
		loop.dump_site_scrap_remaining = desired_count

	var count := maxi(loop.dump_site_scrap_remaining, 0)
	if count <= 0:
		return

	var rarity_names := ModelEnums.RARITY_NAMES
	var weights: Array[float] = []
	for rarity_name in rarity_names:
		weights.append(float(scrap_cfg.yard_scatter_rarity_weights.get(rarity_name, 0.0)))
	# Day 0 (TUT): the taught forage only scatters common scrap.
	if TutorialService.is_tutorial_active():
		for i in weights.size():
			weights[i] = 1.0 if i == ModelEnums.Rarity.WHITE else 0.0

	# Wider bounds for the dump site (2x the scrapyard footprint)
	var bounds := {
		"center_x": 0.0,
		"center_z": -14.0,
		"size_x": 80.0,
		"size_z": 68.0,
	}

	var space := get_world_3d().direct_space_state
	var placed: Array[Vector3] = []
	for i in count:
		var rarity := _pick_rarity(rng, rarity_names, weights)
		var pos := _find_scrap_spawn_position(rng, bounds, space, placed)
		placed.append(pos)
		var item: ScrapItem = SCRAP_ITEM_SCENE.instantiate()
		item.set_rarity(rarity)
		item.position = pos
		item.collected.connect(_on_scrap_collected)
		_scrap_items_root.add_child(item)


func _on_scrap_collected(_rarity: String) -> void:
	GameState.save_state.loop.dump_site_scrap_remaining = maxi(
		GameState.save_state.loop.dump_site_scrap_remaining - 1, 0
	)
	_refresh_hud_hotbar()


## Override Ayla dialogue to use dump-site-specific keys when available.
func _ayla_lines(dialogue_key: String, fallback: String) -> Array:
	var dump_site_key := dialogue_key
	if dialogue_key == "yard_sort_ready":
		dump_site_key = "dump_site_sort_ready"
	elif dialogue_key == "yard_sorting":
		dump_site_key = "dump_site_sorting"
	elif dialogue_key == "yard_empty":
		dump_site_key = "dump_site_empty"

	var route := DataRepository.singleton().get_route("scavenger")
	if route != null:
		var lines: Array = route.dialogue_for(dump_site_key)
		if not lines.is_empty():
			return lines
	return [fallback]


## Quest 3 trigger: Day 5, forbidden zone fence is broken, salakot spawns.
func _check_q3_trigger() -> void:
	var progress := QuestService.get_progress("alya_quest_line")
	if progress == "q2_completed" and DayClock.get_day() == 5:
		_dialogue_box.start(_ayla_lines("q3_start", "Ayla: The fence wasn't broken yesterday... Something's wrong."))
		_pending_dialogue_action = "q3_start"
		_enter_overlay()


## Quest 2 trigger: first time entering the dump site after completing Q1.
func _check_q2_trigger() -> void:
	var progress := QuestService.get_progress("alya_quest_line")
	if progress == "q1_completed":
		_dialogue_box.start(_ayla_lines("q2_start", "Ayla: This was my home..."))
		_pending_dialogue_action = "q2_start"
		_enter_overlay()


## Override handoff to handle Quest 2 (cute bag) and Quest 3 (salakot) before scrap logic.
func _open_handoff() -> void:
	var quest_progress := QuestService.get_progress("alya_quest_line")

	# Quest 3: Player found salakot
	if quest_progress == "q3_salakot" and _has_quest_item_in_inventory("salakot"):
		_dialogue_box.start(_ayla_lines("q3_salakot_found", "Ayla: You found it! Take it back to the shop — someone important will come looking for it."))
		_pending_dialogue_action = "q3_salakot_found"
		_enter_overlay()
		return

	# Quest 2: Player found cute bag (dirty)
	if quest_progress == "q2_bag" and _has_quest_item_in_inventory("cute_bag"):
		var bag_inst := _find_quest_item_in_inventory("cute_bag")
		if bag_inst != null:
			if bag_inst.state == ModelEnums.ObjState.DIRTY:
				_dialogue_box.start(_ayla_lines("q2_bag_found", "Ayla: You found it! Please clean it for me... I want to see what's inside."))
				_pending_dialogue_action = "q2_bag_found"
				_enter_overlay()
				return
			elif bag_inst.state == ModelEnums.ObjState.OPEN:
				_dialogue_box.start(_ayla_lines("q2_bag_opened", "Ayla: It's a note from Papa... and this small artifact he left for me."))
				_pending_dialogue_action = "q2_bag_opened"
				_enter_overlay()
				return

	super._open_handoff()


## Override dialogue finish to handle Quest 2 and Quest 3 progression.
func _on_dialogue_finished() -> void:
	match _pending_dialogue_action:
		"q2_start":
			QuestService.advance_quest("alya_quest_line", "q2_bag")
			_spawn_quest_item("cute_bag", _get_dump_site_bounds())
			_pending_dialogue_action = ""
			_exit_overlay()
		"q2_bag_found":
			_pending_dialogue_action = ""
			_exit_overlay()
		"q2_bag_opened":
			_remove_quest_item_from_inventory("cute_bag")
			QuestService.advance_quest("alya_quest_line", "q2_completed")
			GameState.save_state.loop.money += 1000
			if not GameState.save_state.persistent.legacy_items.has("cute_bag"):
				GameState.save_state.persistent.legacy_items.append("cute_bag")
			_pending_dialogue_action = ""
			_exit_overlay()
		"q3_start":
			QuestService.advance_quest("alya_quest_line", "q3_salakot")
			QuestService.unlock_location("forbidden_zone")
			# Open forbidden zone and spawn salakot
			_update_forbidden_zone()
			_pending_dialogue_action = ""
			_exit_overlay()
		"q3_salakot_found":
			QuestService.advance_quest("alya_quest_line", "q3_salakot_returned")
			_pending_dialogue_action = ""
			_exit_overlay()
		_:
			super._on_dialogue_finished()
	_refresh_hud_hotbar()


func _spawn_salakot_in_forbidden_zone() -> void:
	var bounds := _get_forbidden_zone_bounds()
	_spawn_quest_item("salakot", bounds)


func _get_forbidden_zone_bounds() -> Dictionary:
	return {
		"center_x": 0.0,
		"center_z": -15.0,
		"size_x": 30.0,
		"size_z": 20.0,
	}


## Override quest item respawn for dump-site bounds.
func _spawn_pending_quest_items() -> void:
	var progress := QuestService.get_progress("alya_quest_line")
	if progress == "q2_bag" and not _has_quest_item_in_inventory("cute_bag"):
		_spawn_quest_item("cute_bag", _get_dump_site_bounds())
	# Salakot is now in the Forbidden Zone (separate location) — don't spawn it here



func _get_dump_site_bounds() -> Dictionary:
	return {
		"center_x": 0.0,
		"center_z": -14.0,
		"size_x": 80.0,
		"size_z": 68.0,
	}


## Adds box collision to every scrap heap mesh under MapRoot so the player can't walk through them.
## Heaps are MeshInstance3D nodes whose names start with "Heap_" or "ScrapHeap_".
func _generate_heap_collision() -> void:
	var map_root := get_node_or_null("MapRoot/DumpSiteMap")
	if map_root == null:
		return
	for child in _find_heap_meshes(map_root):
		var mesh := child as MeshInstance3D
		if mesh.mesh == null:
			continue
		var aabb := mesh.mesh.get_aabb()
		var body := StaticBody3D.new()
		body.name = "%s_Collision" % mesh.name
		body.collision_layer = 1
		body.collision_mask = 0
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		# The box is a CHILD of the mesh, so the mesh's scale (and every parent scale) already applies
		# via the transform — size/position must be the mesh-LOCAL AABB, not multiplied by mesh.scale
		# (which double-scaled the box: filling empty space, or missing the heap entirely).
		box.size = aabb.size
		shape.shape = box
		shape.position = aabb.position + aabb.size * 0.5  # AABB centre, in mesh-local space
		body.add_child(shape)
		mesh.add_child(body)
		body.owner = mesh
		shape.owner = mesh


## Recursively finds all MeshInstance3D nodes whose names start with Heap_ or ScrapHeap_.
func _find_heap_meshes(root: Node) -> Array[MeshInstance3D]:
	var result: Array[MeshInstance3D] = []
	for child in root.get_children():
		if child is MeshInstance3D:
			var name := str(child.name)
			if name.begins_with("Heap_") or name.begins_with("ScrapHeap_"):
				result.append(child)
		if child.get_child_count() > 0:
			result.append_array(_find_heap_meshes(child))
	return result
