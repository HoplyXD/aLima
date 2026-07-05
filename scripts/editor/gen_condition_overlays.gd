@tool
extends SceneTree
## One-shot generator: gives EVERY artifact scene a full set of condition OVERLAY nodes
## (ArtifactOverlay — the live condition system), so the per-artifact randomiser has the
## whole catalog to roll from and artists can tune each overlay in the editor.
##
## Run headless:
##   godot --headless --path . --script scripts/editor/gen_condition_overlays.gd
##
## §4-R safe BY CONSTRUCTION: scenes are edited as TEXT — the only changes are a bumped
## load_steps, appended [ext_resource] lines, and appended overlay [node] blocks at the
## end of the file. Every existing byte (including every hand-placed
## ArtifactConditionDecal) is left exactly as authored. Idempotent: overlays whose
## condition the scene already carries are skipped, so re-running changes nothing.
##
## Scope: Basic + Historical artifacts. Event Quest artifacts are SKIPPED on purpose —
## they are curated for scripted quest lessons (Day 0 whitelist, Alya beats, photo mode).
## Rust/tarnish/verdigris are skipped on WHITE (rarity 0) artifacts so commons stay
## cleanable with early tools (same spirit as the rust/tarnish common delivery ban).

const OVERLAY_SCRIPT_PATH := "res://scripts/restoration/artifact_overlay.gd"
const OVERLAY_SCRIPT_UID := "uid://ctnrs25rfmqld"
const TEX_DIR := "res://assets/artifact_conditions/"

const SCENE_DIRS := [
	"res://scenes/restoration/artifacts/Basic Artifacts",
	"res://scenes/restoration/artifacts/Historical Artifacts",
]

## condition id -> [texture file, layer_order]. Outer soils sit above corrosion layers.
const CONDITIONS := {
	"dust": ["Dust.png", 30],
	"dirt": ["Grime.png", 29],
	"mud": ["Mud.png", 28],
	"soot": ["Soot.png", 27],
	"salt_crust": ["Salt Crust.png", 26],
	"wax": ["Wax.png", 25],
	"grease": ["Grease.png", 24],
	"mold": ["Mold.png", 23],
	"tape_residue": ["Tape Residue.png", 22],
	"moss": ["Moss.png", 21],
	"tarnish": ["Tarnish.png", 20],
	"rust": ["Rust.png", 19],
	"verdigris": ["Verdigris.png", 18],
	"black_tarnish": ["Black Tarnish.png", 17],
	"old_paint": ["Old Paint.png", 16],
	"dark_varnish": ["Dark Varnish.png", 15],
	"wood_rot": ["Wood Rot.png", 12],
	"woodworm": ["Woodworm.png", 11],
}
## Conditions needing late/bought tools: not added to WHITE artifacts.
const HARD_ON_WHITE := ["tarnish", "rust", "verdigris", "black_tarnish"]

## Which MATERIALS each condition logically appears on (empty = any material).
## Mirrors docs/condition-material-guide.md — keep the two in sync.
const CONDITION_MATERIALS := {
	"dust": [],
	"dirt": [],
	"mud": [],
	"soot": [],
	"salt_crust": [],
	"wax": [],
	"tape_residue": [],
	"grease": ["metal", "tin", "iron", "steel", "brass", "bronze", "silver", "gold", "wood"],
	"mold": ["wood", "fabric", "paper", "leather", "bamboo", "rattan"],
	"moss": ["wood", "stone", "ceramic", "clay", "bamboo", "rattan"],
	"old_paint": ["wood", "metal", "tin", "brass", "bronze", "iron", "ceramic"],
	"dark_varnish": ["wood", "bamboo", "rattan"],
	"wood_rot": ["wood", "bamboo", "rattan"],
	"woodworm": ["wood", "bamboo", "rattan"],
	"rust": ["iron", "tin", "steel", "metal"],
	"tarnish": ["silver", "brass", "copper", "bronze", "metal"],
	"black_tarnish": ["silver", "brass"],
	"verdigris": ["bronze", "copper", "brass"],
}

## Scene-file stem -> data template id, mirroring ArtifactCatalog._FILENAME_ALIAS.
const FILENAME_ALIAS := {"gold_locket": "dusty_locket", "gold_pendant": "tarnished_pendant"}

## Materials for scene-only artifacts (no objects.json template carries them).
const NAME_MATERIALS := {
	"Cup": ["ceramic"],
	"Plate": ["ceramic"],
	"vase": ["ceramic"],
	"wood_pipe": ["wood"],
	"banjo": ["wood"],
	"lamp": ["metal", "glass"],
}


func _init() -> void:
	var touched := 0
	for dir_path in SCENE_DIRS:
		var dir := DirAccess.open(dir_path)
		if dir == null:
			continue
		for file in dir.get_files():
			if file.ends_with(".tscn"):
				if _process_scene("%s/%s" % [dir_path, file]):
					touched += 1
	print("gen_condition_overlays: updated %d artifact scene(s)." % touched)
	quit(0)


func _process_scene(path: String) -> bool:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return false
	var original := f.get_as_text()
	f.close()
	var text := original

	# Strip every block THIS generator previously appended (exact shape, our node
	# names), so re-running with new material rules REPLACES rather than stacks.
	# Hand-authored overlays (different names/props) are never touched.
	text = _remove_generated_blocks(text)

	var existing := _existing_overlay_conditions_from_text(text)
	var materials := _artifact_materials(path)
	var is_white := text.contains("rarity = 0")
	var missing: Array[String] = []
	for condition_id in CONDITIONS.keys():
		if existing.has(condition_id):
			continue
		if is_white and HARD_ON_WHITE.has(condition_id):
			continue
		if not _condition_fits_materials(condition_id, materials):
			continue
		missing.append(condition_id)
	missing.sort()  # deterministic output order

	# --- ext_resources: reuse the overlay script / texture entries when present ---
	var new_ext_lines: Array[String] = []
	var script_id := _ext_id_for_path(text, OVERLAY_SCRIPT_PATH)
	if script_id.is_empty() and not missing.is_empty():
		script_id = "ovl_script"
		new_ext_lines.append(
			(
				'[ext_resource type="Script" uid="%s" path="%s" id="%s"]'
				% [OVERLAY_SCRIPT_UID, OVERLAY_SCRIPT_PATH, script_id]
			)
		)
	var tex_ids := {}
	for condition_id in missing:
		var tex_path: String = TEX_DIR + CONDITIONS[condition_id][0]
		var tex_id := _ext_id_for_path(text, tex_path)
		if tex_id.is_empty():
			tex_id = "ovl_tex_%s" % condition_id
			new_ext_lines.append(
				'[ext_resource type="Texture2D" path="%s" id="%s"]' % [tex_path, tex_id]
			)
		tex_ids[condition_id] = tex_id

	# --- insert the new ext_resource lines after the last existing one ---
	if not new_ext_lines.is_empty():
		var insert_at := text.rfind("\n[ext_resource")
		if insert_at >= 0:
			insert_at = text.find("\n", insert_at + 1)  # end of that ext_resource line
		else:
			insert_at = text.find("\n")  # right after the gd_scene header
		text = (
			text.substr(0, insert_at + 1)
			+ "\n".join(new_ext_lines)
			+ "\n"
			+ text.substr(insert_at + 1)
		)

	# --- append one ArtifactOverlay node per missing condition at the end ---
	if not missing.is_empty() and not text.ends_with("\n"):
		text += "\n"
	for condition_id in missing:
		var pascal := String(condition_id).capitalize().replace(" ", "")
		text += '\n[node name="Overlay%s" type="Node3D" parent="."]\n' % pascal
		text += 'script = ExtResource("%s")\n' % script_id
		text += 'condition_texture = ExtResource("%s")\n' % tex_ids[condition_id]
		text += "layer_order = %d\n" % int(CONDITIONS[condition_id][1])

	# --- drop our now-orphaned ext lines, then fix load_steps by the net delta ---
	text = _repair_missing_generated_ext(text)
	text = _purge_unreferenced_generated_ext(text)
	text = _adjust_load_steps(original, text)

	if text == original:
		return false  # idempotent: nothing to change
	var out := FileAccess.open(path, FileAccess.WRITE)
	if out == null:
		push_error("gen_condition_overlays: cannot write %s" % path)
		return false
	out.store_string(text)
	out.close()
	print("  + %s: now adds %s" % [path.get_file(), ", ".join(missing)])
	return true


## Removes the node blocks THIS generator wrote on earlier runs: name "Overlay<Pascal>"
## for one of our conditions, with EXACTLY our script/condition_texture/layer_order
## property shape. The header match tolerates extra attributes (the editor re-saves our
## blocks with unique_id=...). Hand-authored overlays (instanced scenes, richer
## properties) never match the fingerprint and are left alone.
func _remove_generated_blocks(text: String) -> String:
	for condition_id in CONDITIONS.keys():
		var pascal := String(condition_id).capitalize().replace(" ", "")
		# Attr-tolerant: match up to parent="." and require type="Node3D" in the header.
		var header := '[node name="Overlay%s" type="Node3D" parent="."' % pascal
		var at := text.find(header)
		while at >= 0:
			var block_end := text.find("\n[", at + header.length())
			if block_end < 0:
				block_end = text.length()
			var block := text.substr(at, block_end - at)
			if _is_generated_block(block):
				var start := at
				if start >= 1 and text[start - 1] == "\n":
					start -= 1  # take the blank separator line with the block
				text = text.substr(0, start) + text.substr(block_end)
				at = text.find(header, start)
			else:
				at = text.find(header, at + header.length())
	return text


## True when a node block contains ONLY the three properties this generator writes —
## the fingerprint that it is ours, not a designer-tuned overlay.
func _is_generated_block(block: String) -> bool:
	var lines := block.strip_edges().split("\n")
	if lines.size() != 4:
		return false
	return (
		lines[1].begins_with("script = ExtResource(")
		and lines[2].begins_with("condition_texture = ExtResource(")
		and lines[3].begins_with("layer_order = ")
	)


## Drops [ext_resource] lines with our generated ids ("ovl_*") that nothing references
## anymore after block removal.
func _purge_unreferenced_generated_ext(text: String) -> String:
	var out_lines: Array[String] = []
	for line in text.split("\n"):
		if line.begins_with("[ext_resource") and line.contains(' id="ovl_'):
			var ext_id := _attr(line, "id")  # word-boundary parse: never grabs uid="..."
			if not ext_id.is_empty() and not text.contains('ExtResource("%s")' % ext_id):
				continue  # orphaned — drop it
		out_lines.append(line)
	return "\n".join(out_lines)


## Rewrites the header's load_steps by however many ext_resource lines were added or
## removed relative to the original file (no-op when the attribute is absent).
func _adjust_load_steps(original: String, text: String) -> String:
	var delta := _count_ext(text) - _count_ext(original)
	if delta == 0:
		return text
	var header_end := text.find("]")
	var header := text.substr(0, header_end)
	var steps_at := header.find("load_steps=")
	if steps_at < 0:
		return text
	var num_start := steps_at + "load_steps=".length()
	var num_end := num_start
	while num_end < header.length() and header[num_end].is_valid_int():
		num_end += 1
	var count := int(header.substr(num_start, num_end - num_start)) + delta
	return header.substr(0, num_start) + str(count) + text.substr(num_end)


func _count_ext(text: String) -> int:
	var count := 0
	for line in text.split("\n"):
		if line.begins_with("[ext_resource"):
			count += 1
	return count


## The scene the hand-authored overlays are instanced from (DustOverlay etc. use
## `instance=ExtResource(...)` of this scene rather than a bare scripted Node3D).
const OVERLAY_SCENE_PATH := "res://scenes/restoration/artifact_overlay.tscn"


## Condition ids of overlays present in the (already block-stripped) scene TEXT.
## Detects BOTH forms: bare nodes scripted with artifact_overlay.gd (our generated
## blocks) AND instances of artifact_overlay.tscn (the hand-authored DustOverlay /
## GrimeOverlay / ... nodes). Condition comes from an explicit condition_id, else the
## condition_texture's file name, else the node's own name ("DustOverlay" -> dust).
func _existing_overlay_conditions_from_text(text: String) -> Dictionary:
	var out := {}
	var ext_paths := {}  # ext id -> resource path
	for line in text.split("\n"):
		if line.begins_with("[ext_resource"):
			var ext_id := _attr(line, "id")
			var ext_path := _attr(line, "path")
			if ext_id.is_empty() or ext_path.is_empty():
				continue
			ext_paths[ext_id] = ext_path
	var overlay_refs := {}  # ext ids that mean "this node IS an ArtifactOverlay"
	for ext_id in ext_paths.keys():
		var p := str(ext_paths[ext_id])
		if p == OVERLAY_SCRIPT_PATH or p == OVERLAY_SCENE_PATH:
			overlay_refs[ext_id] = true
	if overlay_refs.is_empty():
		return out
	# Walk node blocks; overlay-scripted or overlay-instanced blocks name one condition.
	var blocks := text.split("\n[node ")
	for i in range(1, blocks.size()):
		var block: String = blocks[i]
		var uses_overlay := false
		for ext_id in overlay_refs.keys():
			if (
				block.contains('script = ExtResource("%s")' % ext_id)
				or block.contains('instance=ExtResource("%s")' % ext_id)
			):
				uses_overlay = true
				break
		if not uses_overlay:
			continue
		var explicit := _property_string(block, "condition_id")
		if not explicit.is_empty():
			out[explicit] = true
			continue
		var tex_ref := _property_ext_id(block, "condition_texture")
		if not tex_ref.is_empty() and ext_paths.has(tex_ref):
			out[_slug_to_condition(str(ext_paths[tex_ref]).get_file().get_basename())] = true
			continue
		# Fall back to the node's name: "WaterStainOverlay" -> water_stain.
		var node_name := ""
		var name_at := block.find('name="')
		if name_at >= 0:
			var name_end := block.find('"', name_at + 6)
			node_name = block.substr(name_at + 6, name_end - (name_at + 6))
		if node_name.ends_with("Overlay"):
			var stem := node_name.substr(0, node_name.length() - "Overlay".length())
			# CamelCase -> snake_case ("WaterStain" -> water_stain).
			var snake := ""
			for ci in stem.length():
				var ch := stem[ci]
				if ch == ch.to_upper() and ci > 0 and ch.to_lower() != ch.to_upper():
					snake += "_"
				snake += ch.to_lower()
			out[_slug_to_condition(snake)] = true
	return out


## `name = "value"` string property from a node block ("" when absent).
func _property_string(block: String, prop: String) -> String:
	var at := block.find('%s = "' % prop)
	if at < 0:
		return ""
	var start := at + prop.length() + 4
	var end := block.find('"', start)
	return block.substr(start, end - start)


## `name = ExtResource("id")` id from a node block ("" when absent).
func _property_ext_id(block: String, prop: String) -> String:
	var needle := '%s = ExtResource("' % prop
	var at := block.find(needle)
	if at < 0:
		return ""
	var start := at + needle.length()
	var end := block.find('"', start)
	return block.substr(start, end - start)


## Texture file-name slug -> journal condition id (mirrors ArtifactOverlay.get_condition_id).
func _slug_to_condition(file_stem: String) -> String:
	var slug := file_stem.to_lower().replace(" ", "_").replace("-", "_")
	if slug.begins_with("dust"):
		return "dust"
	if slug == "cracking":
		return "crack"
	if slug == "grime":
		return "dirt"
	return slug


## The artifact's materials: its data template's `materials` (objects.json), else the
## NAME_MATERIALS fallback for scene-only artifacts, else [] (= generic conditions only...
## actually [] means unknown; conditions with material lists are skipped).
func _artifact_materials(scene_path: String) -> Array:
	var stem := scene_path.get_file().get_basename()
	var template_id: String = FILENAME_ALIAS.get(stem, stem)
	var by_template := _template_materials()
	if by_template.has(template_id):
		return by_template[template_id]
	return NAME_MATERIALS.get(stem, [])


var _template_materials_cache: Dictionary = {}
var _template_materials_loaded := false


## template id -> materials[] parsed straight from data/objects/objects.json (no
## autoloads exist under --script, so read the JSON directly).
func _template_materials() -> Dictionary:
	if _template_materials_loaded:
		return _template_materials_cache
	_template_materials_loaded = true
	var f := FileAccess.open("res://data/objects/objects.json", FileAccess.READ)
	if f == null:
		return _template_materials_cache
	var doc: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	if not (doc is Dictionary):
		return _template_materials_cache
	for raw in (doc as Dictionary).get("items", []):
		if raw is Dictionary and (raw as Dictionary).get("record_type", "") == "template":
			var id := str((raw as Dictionary).get("id", ""))
			_template_materials_cache[id] = (raw as Dictionary).get("materials", [])
	return _template_materials_cache


## True when the condition belongs on any of the artifact's materials (an empty rule
## list = universal condition; an unknown material set only takes universal ones).
func _condition_fits_materials(condition_id: String, materials: Array) -> bool:
	var allowed: Array = CONDITION_MATERIALS.get(condition_id, [])
	if allowed.is_empty():
		return true
	for m in materials:
		if allowed.has(str(m).to_lower()):
			return true
	return false


## The id="..." of an existing [ext_resource ...] line whose path matches, or "".
func _ext_id_for_path(text: String, res_path: String) -> String:
	var needle := ' path="%s"' % res_path
	var at := text.find(needle)
	if at < 0:
		return ""
	var line_end := text.find("\n", at)
	var line_start := text.rfind("\n", at) + 1
	var line := text.substr(line_start, line_end - line_start)
	if not line.begins_with("[ext_resource"):
		return ""
	return _attr(line, "id")


## `name="value"` attribute from a tag line, matched on a WORD BOUNDARY so `id=` never
## matches inside `uid=` (the bug that once wrote ExtResource("uid://...") refs).
static func _attr(line: String, attr_name: String) -> String:
	var needle := ' %s="' % attr_name
	var at := line.find(needle)
	if at < 0:
		return ""
	var start := at + needle.length()
	var end := line.find('"', start)
	if end < 0:
		return ""
	return line.substr(start, end - start)
