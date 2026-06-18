extends GutTest
## The restoration bench can open the shared Storage and Marketplace overlays
## (the same screens the Shop HUD opens), like it already opens the Journal.

const VIEW_SCENE := preload("res://scenes/restoration/restoration_view.tscn")
const STORAGE_SCENE := preload("res://scenes/ui/storage_screen.tscn")
const PHONE_SCENE := preload("res://scenes/ui/phone.tscn")
const TEST_SAVE := "user://test_bench_overlays_save.json"
const TEST_TEMP := "user://test_bench_overlays_save.tmp"

var _view: RestorationView


func before_each() -> void:
	SaveService.set_save_paths(TEST_SAVE, TEST_TEMP)
	SaveService.delete_save_files()
	DataRepository.singleton().load_from_filesystem()
	GameState.initialize("bench-overlays-player")
	GameState.new_run()
	DayClock.reset()


func after_each() -> void:
	if is_instance_valid(_view):
		_view.close()
	DayClock.reset()
	SaveService.delete_save_files()
	SaveService.set_save_paths(SaveService.DEFAULT_SAVE_PATH, SaveService.DEFAULT_TEMP_PATH)


func _make_view() -> RestorationView:
	var view: RestorationView = VIEW_SCENE.instantiate()
	add_child_autofree(view)
	await wait_physics_frames(1)
	return view


func test_bench_storage_button_opens_storage() -> void:
	var storage: StorageScreen = STORAGE_SCENE.instantiate()
	add_child_autofree(storage)
	_view = await _make_view()
	_view.set_storage_screen(storage)
	_view.open()

	var button: Button = _view.find_child("StorageButton", true, false)
	assert_not_null(button, "bench has a Storage button")
	button.pressed.emit()
	await wait_physics_frames(1)

	assert_true(storage.visible, "bench Storage button opens the shared Storage screen")


func test_bench_phone_button_opens_phone() -> void:
	var phone: Phone = PHONE_SCENE.instantiate()
	add_child_autofree(phone)
	_view = await _make_view()
	_view.set_phone(phone)
	_view.open()

	var button: Button = _view.find_child("PhoneButton", true, false)
	button.pressed.emit()
	await wait_physics_frames(1)

	assert_true(phone.visible, "bench Phone button opens the shared phone")
