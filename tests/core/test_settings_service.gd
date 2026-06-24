extends GutTest
## SettingsService: resolution / fullscreen / renderer persistence, the Mobile-default
## renderer, and the Mobile-supported lock logic. Display application is a no-op under
## headless, so these assert the saved state and the decision logic, not the window.

const TMP := "user://test_settings.cfg"


func before_each() -> void:
	_clean()
	SettingsService.set_config_path(TMP)
	SettingsService.resolution = Vector2i(1920, 1080)
	SettingsService.fullscreen = false
	SettingsService.renderer = SettingsService.DEFAULT_RENDERER
	SettingsService.ai_mode = SettingsService.DEFAULT_AI_MODE
	SettingsService.decal_highlight = false


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


func test_default_renderer_is_mobile() -> void:
	assert_eq(SettingsService.DEFAULT_RENDERER, "mobile")


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


func test_request_renderer_saves_without_quitting_in_headless() -> void:
	# Headless never relaunches; it still records the choice.
	var relaunched := SettingsService.request_renderer(SettingsService.RENDERER_COMPAT)
	assert_false(relaunched, "no relaunch under headless")
	assert_eq(SettingsService.renderer, "gl_compatibility")
	assert_eq(str(_saved().get_value("rendering", "renderer")), "gl_compatibility")


func test_request_renderer_rejects_unknown_method() -> void:
	assert_false(SettingsService.request_renderer("ray_tracing"))


func test_default_ai_mode_is_offline() -> void:
	assert_eq(SettingsService.DEFAULT_AI_MODE, "offline")
	assert_false(SettingsService.ai_mode_is_online(), "the exhibit-safe default prefers on-device")


func test_set_ai_mode_persists_and_rejects_unknown() -> void:
	SettingsService.set_ai_mode(SettingsService.AI_ONLINE)
	assert_true(SettingsService.ai_mode_is_online())
	assert_eq(str(_saved().get_value("ai", "mode")), "online")
	# Unknown values are ignored (the stored mode is unchanged).
	SettingsService.set_ai_mode("psychic")
	assert_eq(SettingsService.ai_mode, "online", "an invalid mode is rejected")


func test_decal_highlight_defaults_off_and_persists() -> void:
	assert_false(SettingsService.decal_highlight_enabled(), "the learning aid is off by default")
	SettingsService.set_decal_highlight(true)
	assert_true(SettingsService.decal_highlight_enabled())
	assert_true(bool(_saved().get_value("ui", "decal_highlight")))


func test_mobile_unlocked_when_player_chose_compatibility() -> void:
	# The player opted into Compatibility, so Mobile is assumed still available.
	SettingsService.renderer = SettingsService.RENDERER_COMPAT
	assert_true(SettingsService.mobile_supported())


func test_mobile_locked_when_default_falls_back_to_compatibility() -> void:
	# Headless exposes no RenderingDevice; with Mobile as the saved choice that reads
	# as a forced fallback, so Mobile is locked.
	SettingsService.renderer = SettingsService.RENDERER_MOBILE
	if RenderingServer.get_rendering_device() != null:
		pass_test("RenderingDevice present in this environment; lock path not exercised")
		return
	assert_false(SettingsService.mobile_supported())
