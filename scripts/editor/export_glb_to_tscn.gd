extends EditorScript
## Convert scrapyard.glb → editable ScrapyardMap.tscn with external .mesh files.
##
## Run from the Godot Script editor: open this script, then press the "Run" play button
## (or Ctrl+Shift+X). It will export every embedded MeshInstance3D mesh into
## assets/3d Assets/Scrapyard/meshes/ and save the scene as
## scenes/scrapyard/ScrapyardMap.tscn.

const GLB_PATH := "res://assets/3d Assets/Scrapyard/scrapyard.glb"
const TSCN_PATH := "res://scenes/scrapyard/ScrapyardMap.tscn"
const MESH_FOLDER := "res://assets/3d Assets/Scrapyard/meshes/"


func _run() -> void:
	var packed := load(GLB_PATH) as PackedScene
	if packed == null:
		push_error("Failed to load: " + GLB_PATH)
		return

	var root := packed.instantiate()
	if root == null:
		push_error("Failed to instantiate packed scene")
		return

	# Ensure mesh folder exists
	if not DirAccess.dir_exists_absolute(MESH_FOLDER):
		var err := DirAccess.make_dir_recursive_absolute(MESH_FOLDER)
		if err != OK:
			push_error("Failed to create mesh folder: " + MESH_FOLDER)
			return

	_externalize_meshes(root)

	var packed_save := PackedScene.new()
	var err := packed_save.pack(root)
	if err != OK:
		push_error("pack failed: " + str(err))
		return

	err = ResourceSaver.save(packed_save, TSCN_PATH)
	if err != OK:
		push_error("save failed: " + str(err))
		return

	print("Success! Exported to: " + TSCN_PATH)
	print("Meshes saved to: " + MESH_FOLDER)


func _externalize_meshes(node: Node) -> void:
	if node is MeshInstance3D:
		var mi := node as MeshInstance3D
		var mesh := mi.mesh
		if mesh != null and mesh.resource_path.is_empty():
			# This mesh is embedded in the glb; externalize it
			var safe_name := String(mesh.resource_name) if not mesh.resource_name.is_empty() else mi.name
			safe_name = _sanitize_filename(safe_name)
			if safe_name.is_empty():
				safe_name = "mesh"
			var mesh_path := MESH_FOLDER + safe_name + ".mesh"

			# Handle duplicates by appending a number
			var final_path := mesh_path
			var counter := 1
			while FileAccess.file_exists(final_path):
				final_path = MESH_FOLDER + safe_name + "_" + str(counter) + ".mesh"
				counter += 1

			var err := ResourceSaver.save(mesh, final_path)
			if err == OK:
				mi.mesh = load(final_path)
				print("  Mesh: " + final_path)
			else:
				push_warning("Failed to save mesh: " + final_path)

	for child in node.get_children():
		_externalize_meshes(child)


func _sanitize_filename(name: String) -> String:
	var forbidden := ["<", ">", ":", "\"", "/", "\\", "|", "?", "*"]
	var result := name
	for ch in forbidden:
		result = result.replace(ch, "_")
	return result.strip_edges()
