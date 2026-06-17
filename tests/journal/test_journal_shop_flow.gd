extends GutTest
## Tests that the journal opens through the existing Shop controller/book flow.

const SHOP_SCENE := preload("res://scenes/Shop.tscn")


func before_each() -> void:
	DataRepository.singleton().load_from_filesystem()
	GameState.initialize("test-player")
	DayClock.reset()
	DayClock.running = true


func after_each() -> void:
	DayClock.reset()


func test_shop_journal_button_opens_book_viewport_and_pauses_clock() -> void:
	var shop: Node3D = SHOP_SCENE.instantiate()
	add_child_autofree(shop)
	await wait_physics_frames(1)

	var book_viewport: BookViewport = shop.get_node("BookViewport")
	assert_false(book_viewport.visible, "Journal starts closed")
	assert_true(DayClock.is_running(), "Clock runs before opening journal")

	var hud: ShopHud = shop.get_node("HUD")
	hud.journal_pressed.emit()
	await wait_physics_frames(1)

	assert_true(book_viewport.visible, "Journal button opens the book viewport")
	assert_true(book_viewport.owns_pause(), "Book viewport owns the journal pause")
	assert_false(DayClock.is_running(), "Clock pauses while journal is open")

	book_viewport.close()
	await wait_physics_frames(1)

	assert_false(book_viewport.visible, "Journal closes")
	assert_true(DayClock.is_running(), "Clock resumes after journal closes")
