extends RefCounted
## Maps a template id to its authored presentation scene (custom model + placed decals).
## Preloaded by consumers (no class_name) so it resolves without a global-class-cache pass.
##
## The folder-scanning ArtifactCatalog is now the source of truth (drop a scene in
## scenes/restoration/artifacts/ and it is discovered automatically). This hardcoded `_SCENES` map
## is kept only as a legacy fallback for anything the scan can't resolve, so existing call sites
## (`scene_for`/`has_scene`) keep working unchanged.

const _ArtifactCatalog := preload("res://scripts/restoration/artifact_catalog.gd")

const _SCENES := {
	"dusty_locket":
	preload("res://scenes/restoration/artifacts/Basic Artifacts/gold_locket.tscn"),
	"tarnished_pendant":
	preload("res://scenes/restoration/artifacts/Basic Artifacts/gold_pendant.tscn"),
	"oton_death_mask":
	preload("res://scenes/restoration/artifacts/Historical Artifacts/oton_death_mask.tscn"),
	"silver_locket":
	preload("res://scenes/restoration/artifacts/Basic Artifacts/silver_locket.tscn"),
	"silver_pendant":
	preload("res://scenes/restoration/artifacts/Basic Artifacts/silver_pendant.tscn"),
	"bronze_locket":
	preload("res://scenes/restoration/artifacts/Basic Artifacts/bronze_locket.tscn"),
	"bronze_pendant":
	preload("res://scenes/restoration/artifacts/Basic Artifacts/bronze_pendant.tscn"),
	"brass_hand_bell":
	preload("res://scenes/restoration/artifacts/Basic Artifacts/brass_hand_bell.tscn"),
}


## The authored scene for `template_id`, or `fallback` (the placeholder) when none is set. The
## folder-scanning ArtifactCatalog wins; the hardcoded map is a legacy fallback.
static func scene_for(template_id: String, fallback: PackedScene) -> PackedScene:
	var scanned: PackedScene = _ArtifactCatalog.scene_for(template_id)
	if scanned != null:
		return scanned
	return _SCENES.get(template_id, fallback)


static func has_scene(template_id: String) -> bool:
	return _ArtifactCatalog.has_scene(template_id) or _SCENES.has(template_id)
