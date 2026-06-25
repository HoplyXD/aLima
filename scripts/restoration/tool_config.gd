@tool
class_name ToolConfig
extends Node3D
## Per-tool gameplay config authored ON THE TOOL'S SCENE (scenes/restoration/tools/<id>.tscn root),
## the same way artifacts carry their config on their scene. Drives overlay cleaning: which conditions
## this tool removes and how strongly, the brush radius, and the max durability. The tool's MODEL is a
## child of this node (so the scene is still the visual prop the bench instances).
##
## `cleans` maps condition_id -> Power (0..100), where Power is the % of the condition's opacity a
## single stroke removes (50 = remove ~50%). Empty `cleans` means "no overlay cleaning configured" and
## callers fall back to the data-driven CleaningPower (tools.json `cleans` + the journal catalog).

@export var max_durability: int = 12
## Brush radius as a fraction of the overlay's size (per-tool feel).
@export_range(0.01, 0.5) var clean_radius: float = 0.12
## condition_id -> Power (0..100). Multi-select the conditions this tool can clean by adding keys.
@export var cleans: Dictionary = {}

## Cache of loaded configs by tool id, so reading a tool's config never re-instances its scene.
static var _cache: Dictionary = {}


## The authored config for `tool_id` as {max_durability, clean_radius, cleans}. Reads the tool scene's
## ToolConfig root once (then caches). Returns defaults (empty cleans) when the tool has no scene or no
## ToolConfig — callers then fall back to the data-driven cleaning power.
static func for_tool(tool_id: String) -> Dictionary:
	if _cache.has(tool_id):
		return _cache[tool_id]
	var data := {"max_durability": 12, "clean_radius": 0.12, "cleans": {}}
	var path := "res://scenes/restoration/tools/%s.tscn" % tool_id
	if ResourceLoader.exists(path):
		var packed := load(path) as PackedScene
		if packed != null:
			var inst: Node = packed.instantiate()
			# Duck-typed so this never hard-depends on the class while reading the exports.
			if inst.get("cleans") != null:
				data["max_durability"] = inst.get("max_durability")
				data["clean_radius"] = inst.get("clean_radius")
				data["cleans"] = (inst.get("cleans") as Dictionary).duplicate()
			inst.free()
	_cache[tool_id] = data
	return data


## Clears the cache (e.g. after editing tool scenes in a tool run). Test/dev seam.
static func clear_cache() -> void:
	_cache.clear()
