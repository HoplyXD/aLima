extends GutTest
## Regression test for the theme-resource-path consistency fix (commit 473e95c).
##
## Several UI scenes reference Themes/Pause_menu.tres; this test ensures those
## scenes load without missing-resource errors after renames or case changes.

const SCENES_WITH_THEME := [
	"res://scenes/ui/pause_menu.tscn",
	"res://scenes/ui/artifact_found_screen.tscn",
	"res://scenes/ui/echo_hud.tscn",
	"res://scenes/ui/storage_screen.tscn",
	"res://scenes/restoration/restoration_view.tscn",
]


func test_theme_referencing_scenes_load() -> void:
	for path in SCENES_WITH_THEME:
		var scene := load(path) as PackedScene
		assert_not_null(scene, "Scene loads: %s" % path)
		if scene != null:
			var instance := scene.instantiate()
			assert_not_null(instance, "Scene instantiates: %s" % path)
			add_child_autofree(instance)
	await wait_physics_frames(1)
