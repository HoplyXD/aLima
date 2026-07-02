extends GutTest
## SettingsService: resolution / fullscreen persistence. Display application is a no-op
## under headless, so these assert the saved state, not the window.

const TMP := "user://test_settings.cfg"


func before_each() -> void:
	_clean()
	SettingsService.set_config_path(TMP)
	SettingsService.resolution = Vector2i(1920, 1080)
	SettingsService.fullscreen = false
	SettingsService.ai_mode = SettingsService.DEFAULT_AI_MODE


func after_each() -> void:
	SettingsService.set_config_path(SettingsService.CONFIG_PATH)
	_clean()


func _clean() -> void:
	if FileAccess.file_exists(TMP):
		DirAccess.remove_absolute(TMP)


func _saved() -> ConfigFile:
	var cfg := ConfigFile.new()
	cfg.load(TMP)
	return cfg


func test_set_resolution_persists() -> void:
	SettingsService.set_resolution(Vector2i(1280, 720))
	assert_eq(SettingsService.resolution, Vector2i(1280, 720))
	var cfg := _saved()
	assert_eq(int(cfg.get_value("display", "width")), 1280)
	assert_eq(int(cfg.get_value("display", "height")), 720)


func test_resolution_index_tracks_the_choice() -> void:
	SettingsService.set_resolution(Vector2i(1280, 720))
	assert_eq(SettingsService.resolution_index(), 0)
	SettingsService.set_resolution(Vector2i(1920, 1080))
	assert_eq(SettingsService.resolution_index(), 2)


func test_set_fullscreen_persists() -> void:
	SettingsService.set_fullscreen(true)
	assert_true(SettingsService.fullscreen)
	assert_true(bool(_saved().get_value("display", "fullscreen")))


func test_set_previews_persists() -> void:
	SettingsService.set_artifact_previews(false)
	assert_false(SettingsService.previews_enabled())
	assert_false(bool(_saved().get_value("display", "artifact_previews")))
	SettingsService.set_artifact_previews(true)
	assert_true(SettingsService.previews_enabled())
	assert_true(bool(_saved().get_value("display", "artifact_previews")))


func test_default_ai_mode_is_online() -> void:
	assert_eq(SettingsService.DEFAULT_AI_MODE, "online")
	assert_true(SettingsService.ai_mode_is_online(), "the project defaults to the live backend")


func test_set_ai_mode_persists_and_rejects_unknown() -> void:
	SettingsService.set_ai_mode(SettingsService.AI_ONLINE)
	assert_true(SettingsService.ai_mode_is_online())
	assert_eq(str(_saved().get_value("ai", "mode")), "online")
	# Unknown values are ignored (the stored mode is unchanged).
	SettingsService.set_ai_mode("psychic")
	assert_eq(SettingsService.ai_mode, "online", "an invalid mode is rejected")
