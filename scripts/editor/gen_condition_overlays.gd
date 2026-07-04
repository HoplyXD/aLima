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
	"tarnish": ["Tarnish.png", 20],
	"rust": ["Rust.png", 19],
	"verdigris": ["Verdigris.png", 18],
}
## Conditions needing late/bought tools: not added to WHITE artifacts.
const HARD_ON_WHITE := ["tarnish", "rust", "verdigris"]


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
	var existing := _existing_overlay_conditions(path)
	if existing.is_empty() and not ResourceLoader.exists(path):
		return false
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return false
	var text := f.get_as_text()
	f.close()

	var is_white := text.contains("rarity = 0")
	var missing: Array[String] = []
	for condition_id in CONDITIONS.keys():
		if existing.has(condition_id):
			continue
		if is_white and HARD_ON_WHITE.has(condition_id):
			continue
		missing.append(condition_id)
	if missing.is_empty():
		return false
	missing.sort()  # deterministic output order

	# --- ext_resources: reuse the overlay script / texture entries when present ---
	var new_ext_lines: Array[String] = []
	var script_id := _ext_id_for_path(text, OVERLAY_SCRIPT_PATH)
	if script_id.is_empty():
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

	# --- header: bump load_steps by the ext_resources we add (when the attr exists) ---
	if not new_ext_lines.is_empty():
		var header_end := text.find("]")
		var header := text.substr(0, header_end)
		var steps_at := header.find("load_steps=")
		if steps_at >= 0:
			var num_start := steps_at + "load_steps=".length()
			var num_end := num_start
			while num_end < header.length() and header[num_end].is_valid_int():
				num_end += 1
			var count := int(header.substr(num_start, num_end - num_start))
			count += new_ext_lines.size()
			text = header.substr(0, num_start) + str(count) + text.substr(num_end)

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
	if not text.ends_with("\n"):
		text += "\n"
	for condition_id in missing:
		var pascal := String(condition_id).capitalize().replace(" ", "")
		text += '\n[node name="Overlay%s" type="Node3D" parent="."]\n' % pascal
		text += 'script = ExtResource("%s")\n' % script_id
		text += 'condition_texture = ExtResource("%s")\n' % tex_ids[condition_id]
		text += "layer_order = %d\n" % int(CONDITIONS[condition_id][1])

	var out := FileAccess.open(path, FileAccess.WRITE)
	if out == null:
		push_error("gen_condition_overlays: cannot write %s" % path)
		return false
	out.store_string(text)
	out.close()
	print("  + %s: added %s" % [path.get_file(), ", ".join(missing)])
	return true


## The condition ids of overlays ALREADY in the scene (duck-typed: overlay nodes expose
## get_condition_id; decals expose condition_slug and are ignored — they're the legacy layer).
func _existing_overlay_conditions(path: String) -> Dictionary:
	var out := {}
	var packed := load(path) as PackedScene
	if packed == null:
		return out
	var root := packed.instantiate()
	if root == null:
		return out
	_collect_overlay_ids(root, out)
	root.free()
	return out


func _collect_overlay_ids(node: Node, out: Dictionary) -> void:
	for child in node.get_children():
		if child.has_method("get_condition_id") and not child.has_method("condition_slug"):
			out[String(child.call("get_condition_id"))] = true
		_collect_overlay_ids(child, out)


## The id="..." of an existing [ext_resource ...] line whose path matches, or "".
func _ext_id_for_path(text: String, res_path: String) -> String:
	var needle := 'path="%s"' % res_path
	var at := text.find(needle)
	if at < 0:
		return ""
	var line_end := text.find("\n", at)
	var line_start := text.rfind("\n", at) + 1
	var line := text.substr(line_start, line_end - line_start)
	if not line.begins_with("[ext_resource"):
		return ""
	var id_at := line.find('id="')
	if id_at < 0:
		return ""
	var id_end := line.find('"', id_at + 4)
	return line.substr(id_at + 4, id_end - (id_at + 4))
