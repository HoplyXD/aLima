extends RefCounted
## Folder-driven artifact catalog. Scans scenes/restoration/artifacts/** for artifact scenes and
## reads each one's designer-set config (rarity, value range, quest assignment) off its
## RestorationObject3D root, so dropping a new scene into the folder adds it to the game with no code
## edit ("follow the folders"). Cached after the first scan; call refresh() to rescan.
##
## The data template (objects.json, keyed by template id) still supplies gameplay params (clean tool,
## openable, storage). The SCENE supplies presentation + rarity/value/quest overrides. An override is
## INHERIT/0 by default, so existing artifacts keep their authored data values until a designer sets
## the field on the scene.

const ROOT_DIR := "res://scenes/restoration/artifacts"
## Quest NPC enum index -> route/npc id (matches data/routes/routes.json and RestorationObject3D.QuestNpc).
const NPC_IDS: Array[String] = ["auntie", "artisan", "scavenger", "archeologist", "buyer"]
## Legacy scenes whose file name differs from their data template id.
const _FILENAME_ALIAS := {"gold_locket": "dusty_locket", "gold_pendant": "tarnished_pendant"}

static var _entries: Dictionary = {}  ## template_id -> entry dict
static var _scanned: bool = false


static func _ensure_scanned() -> void:
	if _scanned:
		return
	_scanned = true
	_entries.clear()
	_scan_dir(ROOT_DIR)
	_apply_overrides_to_repo()


## Makes the FOLDER the source of truth for spawning: for every discovered scene, either apply its
## rarity/value overrides onto the matching data template, OR — if no template exists — synthesize a
## minimal one and register it, so a brand-new artifact scene spawns with NO objects.json edit. Every
## system (delivery weighting, rarity glow, storage/top-bar colours) then reads one consistent record.
static func _apply_overrides_to_repo() -> void:
	var repo := DataRepository.singleton()
	if repo == null:
		return
	for tid in _entries.keys():
		var entry: Dictionary = _entries[tid]
		var template := repo.get_template(tid)
		if template == null:
			# Scene-only artifact (e.g. vase / wood_pipe / lamp): generate a spawnable template.
			repo.scrap_object_templates[tid] = _synthesize_template(tid, entry)
			continue
		var rarity := int(entry.get("rarity", -1))
		if rarity >= 0:
			template.base_rarity = rarity
		var vmin := int(entry.get("value_min", 0))
		var vmax := int(entry.get("value_max", 0))
		if vmin > 0 or vmax > 0:
			template.base_value_range = Vector2(vmin, maxi(vmin, vmax))


## Builds a minimal, spawnable data template from a scene's config + sensible defaults. The artifact is
## a non-openable, surface-clean piece (its scene overlays ARE its conditions), deliverable unless it's
## a quest item. Rarity/value come from the scene (default white, 20–80 when unset).
static func _synthesize_template(tid: String, entry: Dictionary) -> ScrapObjectTemplate:
	var rarity := int(entry.get("rarity", -1))
	if rarity < 0:
		rarity = ModelEnums.Rarity.WHITE
	var vmin := int(entry.get("value_min", 0))
	var vmax := int(entry.get("value_max", 0))
	if vmax <= 0:
		vmin = 20
		vmax = 80
	return ScrapObjectTemplate.from_dictionary(
		{
			"id": tid,
			"display_name": tid.capitalize(),  # "wood_pipe" -> "Wood Pipe"
			"category": "artifact",
			"base_rarity": ModelEnums.rarity_name(rarity),
			"weight_range": [50.0, 250.0],
			"materials": [],
			"tags": [],
			"is_openable": false,
			"openable_type": "",
			"required_clean_tool": "",
			"clean_minigame": "",
			"clean_completion_threshold": 100,
			"clean_progress_per_action": 25,
			"clean_value_bonus": 10,
			"wrong_tool_condition_damage": 10,
			"wrong_tool_value_damage": 8,
			"wrong_tool_feedback": "The wrong tool risks damaging the surface.",
			"base_value_range": [vmin, maxi(vmin, vmax)],
			"storage_cost": 1,
			"can_hold_temporal_echo": false,
			"deliverable": not bool(entry.get("is_quest", false)),
		}
	)


## Ensures the folder has been scanned and synthesized templates are registered in the repo. Call
## this BEFORE iterating the repo's templates so scene-only artifacts are included.
static func ensure_ready() -> void:
	_ensure_scanned()


## Forces a fresh scan (e.g. after adding a scene at runtime / in a tool).
static func refresh() -> void:
	_scanned = false
	_ensure_scanned()


static func _scan_dir(path: String) -> void:
	var dir := DirAccess.open(path)
	if dir == null:
		return
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		var full := "%s/%s" % [path, entry]
		if dir.current_is_dir():
			if not entry.begins_with("."):
				_scan_dir(full)
		elif entry.ends_with(".tscn"):
			_read_scene(full)
		entry = dir.get_next()
	dir.list_dir_end()


## Loads a scene and reads its artifact config WITHOUT adding it to the tree (so _ready/_build never
## runs — only the inspector-set property values are read), then frees the throwaway instance.
static func _read_scene(scene_path: String) -> void:
	var packed := load(scene_path) as PackedScene
	if packed == null:
		return
	var root := packed.instantiate()
	if not (root is RestorationObject3D):
		root.free()
		return
	var obj := root as RestorationObject3D
	var stem := scene_path.get_file().get_basename()
	var tid: String = obj.artifact_template_id
	if tid.is_empty():
		tid = _FILENAME_ALIAS.get(stem, stem)
	var npc_idx := clampi(int(obj.quest_npc), 0, NPC_IDS.size() - 1)
	_entries[tid] = {
		"scene": packed,
		"rarity": int(obj.artifact_rarity),  # -1 == INHERIT (use the data template's rarity)
		"value_min": obj.base_value_min,
		"value_max": obj.base_value_max,
		"is_quest": obj.is_quest_item,
		"npc": NPC_IDS[npc_idx],
		"quest_number": obj.quest_number,
		"scanner": _read_scanner_data(root),
	}
	root.free()


## Captures the artifact's designer-authored scanner payload from an ArtifactScannerData child, or
## an empty dict when none is present / authored.
static func _read_scanner_data(root: Node) -> Dictionary:
	for child in root.get_children():
		if child is ArtifactScannerData:
			return (child as ArtifactScannerData).to_response_dict()
	return {}


## The authored scene for `template_id`, or null when none is mapped.
static func scene_for(template_id: String, fallback: PackedScene = null) -> PackedScene:
	_ensure_scanned()
	var e: Dictionary = _entries.get(template_id, {})
	return e.get("scene", fallback)


static func has_scene(template_id: String) -> bool:
	_ensure_scanned()
	return _entries.has(template_id)


## Rarity override for `template_id` as a ModelEnums.Rarity, or -1 when the scene inherits the
## data template's rarity.
static func rarity_override(template_id: String) -> int:
	_ensure_scanned()
	return int(_entries.get(template_id, {}).get("rarity", -1))


## Value range override {min, max} for `template_id`, or an empty Vector2i (0,0) to inherit.
static func value_range_override(template_id: String) -> Vector2i:
	_ensure_scanned()
	var e: Dictionary = _entries.get(template_id, {})
	return Vector2i(int(e.get("value_min", 0)), int(e.get("value_max", 0)))


static func is_quest_item(template_id: String) -> bool:
	_ensure_scanned()
	return bool(_entries.get(template_id, {}).get("is_quest", false))


## The designer-authored scanner-response payload for `template_id` from its scene's ArtifactScannerData
## node, or an empty dict when none is authored (callers then fall back to the JSON scanner cache).
static func scanner_response_for(template_id: String) -> Dictionary:
	_ensure_scanned()
	return (_entries.get(template_id, {}).get("scanner", {}) as Dictionary).duplicate(true)


## Template ids of artifacts the random delivery may spawn (everything with a scene that is NOT a
## quest item). Callers still apply their own data filters (e.g. template.deliverable).
static func spawnable_template_ids() -> Array[String]:
	_ensure_scanned()
	var out: Array[String] = []
	for tid in _entries.keys():
		if not bool(_entries[tid].get("is_quest", false)):
			out.append(tid)
	return out


## Template ids assigned to (npc_id, quest_number). Two artifacts on the same step pool together.
static func quest_artifacts(npc_id: String, quest_number: int) -> Array[String]:
	_ensure_scanned()
	var out: Array[String] = []
	for tid in _entries.keys():
		var e: Dictionary = _entries[tid]
		if e.get("is_quest", false) and e.get("npc", "") == npc_id and int(e.get("quest_number", 0)) == quest_number:
			out.append(tid)
	out.sort()  # deterministic order before any seeded pick
	return out


## One artifact template id for the (npc_id, quest_number) step, chosen via `rng` when several share
## the step. Empty string when none is assigned.
static func random_quest_artifact(npc_id: String, quest_number: int, rng: RandomNumberGenerator) -> String:
	var pool := quest_artifacts(npc_id, quest_number)
	if pool.is_empty():
		return ""
	if pool.size() == 1 or rng == null:
		return pool[0]
	return pool[rng.randi_range(0, pool.size() - 1)]
