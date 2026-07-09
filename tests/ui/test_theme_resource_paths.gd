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
	# Shared alima_ui.tres theme surfaces (Tutorial UI restyle).
	"res://dialogue/tutorial_hint_box.tscn",
	"res://scenes/ui/quest_tracker.tscn",
	"res://scenes/ui/quest_entry.tscn",
	"res://scenes/restoration/artifact_card.tscn",
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


func test_shared_theme_resource_loads() -> void:
	var theme := load("res://Themes/alima_ui.tres") as Theme
	assert_not_null(theme, "alima_ui.tres loads as a Theme")
	if theme != null:
		assert_not_null(theme.default_font, "shared theme sets a default font")


func test_artifact_card_states_are_distinct() -> void:
	var scene := load("res://scenes/restoration/artifact_card.tscn") as PackedScene
	var restored := scene.instantiate() as ArtifactCard
	var unrestored := scene.instantiate() as ArtifactCard
	add_child_autofree(restored)
	add_child_autofree(unrestored)
	restored.configure("a", "Restored", UiPalette.RARITY_GOLD, false, true)
	unrestored.configure("b", "Unrestored", UiPalette.RARITY_GOLD, false, false)
	var r_style := restored.get_theme_stylebox("panel") as StyleBoxFlat
	var u_style := unrestored.get_theme_stylebox("panel") as StyleBoxFlat
	assert_not_null(r_style, "restored card has a panel stylebox")
	assert_not_null(u_style, "unrestored card has a panel stylebox")
	assert_ne(r_style.border_color, u_style.border_color, "the two card states differ visually")
