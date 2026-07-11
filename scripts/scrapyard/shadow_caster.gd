class_name ShadowCaster
extends Sprite3D
## Sun-facing silhouette that gives the first-person player a person-shaped shadow.
##
## The player's debug capsule casts a tapered streak of a shadow. Instead this
## Sprite3D carries the scavenger silhouette, renders SHADOWS_ONLY (invisible in the
## world, present in the shadow map), and rotates each frame to face the scene's
## DirectionalLight3D so the shadow falls away from the sun like a real one.

var _sun: DirectionalLight3D = null


func _ready() -> void:
	_sun = _find_sun(get_tree().current_scene)


func _process(_delta: float) -> void:
	if _sun == null or not is_instance_valid(_sun):
		_sun = _find_sun(get_tree().current_scene)
		if _sun == null:
			return
	# The sprite stands upright and faces the sun horizontally, so the silhouette is
	# cast onto the ground opposite the light — long at low sun, short at high sun.
	var light_dir := -_sun.global_transform.basis.z
	var flat := Vector3(light_dir.x, 0.0, light_dir.z)
	if flat.length_squared() < 0.0001:
		return  # Sun straight overhead: keep the last facing.
	var facing := -flat.normalized()
	global_rotation = Vector3(0.0, atan2(facing.x, facing.z), 0.0)


func _find_sun(root: Node) -> DirectionalLight3D:
	if root == null:
		return null
	if root is DirectionalLight3D:
		return root as DirectionalLight3D
	for child in root.get_children():
		var found := _find_sun(child)
		if found != null:
			return found
	return null
