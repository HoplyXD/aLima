extends GutTest
## Tests the folder-driven ArtifactCatalog: it discovers artifact scenes under
## scenes/restoration/artifacts/, maps them to template ids (with legacy filename aliases),
## inherits rarity/value by default, and exposes the quest-assignment pool.

const ArtifactCatalog := preload("res://scripts/restoration/artifact_catalog.gd")


func before_all() -> void:
	ArtifactCatalog.refresh()  # ensure a clean scan independent of other suites


func test_scan_discovers_real_artifacts() -> void:
	assert_true(ArtifactCatalog.has_scene("brass_hand_bell"), "the bell scene is discovered")
	assert_true(ArtifactCatalog.has_scene("silver_pendant"), "the silver pendant is discovered")


func test_placeholder_templates_have_no_scene() -> void:
	# rusted_tin / cracked_photo_frame have no .tscn in the artifacts folder.
	assert_false(ArtifactCatalog.has_scene("rusted_tin"), "placeholder templates are not discovered")


func test_legacy_filename_alias_maps_to_template_id() -> void:
	# gold_locket.tscn represents the data template "dusty_locket"; gold_pendant -> tarnished_pendant.
	assert_true(ArtifactCatalog.has_scene("dusty_locket"), "alias maps gold_locket -> dusty_locket")
	assert_not_null(ArtifactCatalog.scene_for("dusty_locket"))
	assert_true(ArtifactCatalog.has_scene("tarnished_pendant"))


func test_rarity_and_value_default_to_inherit() -> void:
	# No existing scene overrides rarity/value yet, so the catalog signals "inherit the data template".
	assert_eq(ArtifactCatalog.rarity_override("brass_hand_bell"), -1, "rarity inherits by default")
	var range := ArtifactCatalog.value_range_override("brass_hand_bell")
	assert_eq(range, Vector2i.ZERO, "value range inherits by default")


func test_non_quest_artifact_is_spawnable() -> void:
	assert_false(ArtifactCatalog.is_quest_item("brass_hand_bell"), "the bell is not a quest item")
	var spawnable := ArtifactCatalog.spawnable_template_ids()
	assert_true(spawnable.has("brass_hand_bell"), "non-quest artifacts are spawnable")


func test_quest_items_are_excluded_from_the_spawn_pool() -> void:
	# Any artifact flagged is_quest_item in its scene must NOT appear in the random delivery pool.
	var spawnable := ArtifactCatalog.spawnable_template_ids()
	for tid in spawnable:
		assert_false(ArtifactCatalog.is_quest_item(tid), "%s is spawnable so must not be a quest item" % tid)


func test_quest_pool_for_an_unassigned_step_is_empty() -> void:
	# A step with no artifact assigned returns nothing (the random pick yields an empty id).
	assert_eq(ArtifactCatalog.quest_artifacts("buyer", 99).size(), 0)
	assert_eq(ArtifactCatalog.random_quest_artifact("buyer", 99, null), "")
