extends GutTest
## Revamp B: the sun follows the in-game clock, and Day 0 uses scripted phases
## (sunrise -> noon after the cleaning lesson -> sunset once heading home).

const TEST_SAVE := "user://test_sun_save.json"
const TEST_TEMP := "user://test_sun_save.tmp"


func before_each() -> void:
	SaveService.set_save_paths(TEST_SAVE, TEST_TEMP)
	SaveService.delete_save_files()
	GameState.initialize("sun-test-player")
	DayClock.reset()


func after_each() -> void:
	DayClock.reset()
	SaveService.delete_save_files()
	SaveService.set_save_paths(SaveService.DEFAULT_SAVE_PATH, SaveService.DEFAULT_TEMP_PATH)


func _make_sun() -> Array:
	var host := Node3D.new()
	add_child_autofree(host)
	var light := DirectionalLight3D.new()
	host.add_child(light)
	var sun := SunController.attach(host, light)
	return [sun, light]


func test_attach_requires_a_light() -> void:
	var host := Node3D.new()
	add_child_autofree(host)
	assert_null(SunController.attach(host, null), "no light -> no controller, no crash")


func test_noon_is_higher_and_brighter_than_dawn() -> void:
	var pair := _make_sun()
	var sun: SunController = pair[0]
	var light: DirectionalLight3D = pair[1]
	sun.apply_phase(0.0)
	var dawn_elevation: float = -light.rotation_degrees.x
	var dawn_energy: float = light.light_energy
	sun.apply_phase(0.5)
	assert_gt(-light.rotation_degrees.x, dawn_elevation, "noon sun sits higher")
	assert_gt(light.light_energy, dawn_energy, "noon sun is brighter")
	sun.apply_phase(1.0)
	assert_lt(-light.rotation_degrees.x, 20.0, "sunset sinks low again")


func test_sunset_is_warmer_than_noon() -> void:
	var pair := _make_sun()
	var sun: SunController = pair[0]
	var light: DirectionalLight3D = pair[1]
	sun.apply_phase(0.5)
	var noon_blue := light.light_color.b
	sun.apply_phase(1.0)
	assert_lt(light.light_color.b, noon_blue, "sunset light is warmer (less blue)")


func test_day0_steps_map_sunrise_noon_sunset() -> void:
	assert_lt(float(SunController.DAY0_PHASES["restore_artifact"]), 0.25, "cleaning = morning")
	assert_almost_eq(
		float(SunController.DAY0_PHASES["scan_artifact"]), 0.5, 0.1, "post-clean = noon"
	)
	assert_gt(float(SunController.DAY0_PHASES["return_to_shop"]), 0.85, "heading home = sunset")


func test_clock_hours_map_across_the_shop_day() -> void:
	GameState.save_state.persistent.tutorial_completed = true
	var pair := _make_sun()
	var sun: SunController = pair[0]
	DayClock.start_day(1)  # 07:00
	assert_almost_eq(sun.current_phase(), 0.0, 0.05, "07:00 is dawn")
