extends GutTest
## Tests for the in-game museum gallery: offline hydration, rendering, and
## refresh behavior (MUS-R3).

const TEST_SAVE := "user://test_museum_gallery_save.json"
const TEST_TEMP := "user://test_museum_gallery_save.tmp"
const GalleryScene := preload("res://scenes/museum/museum_gallery.tscn")


func before_each() -> void:
	SaveService.set_save_paths(TEST_SAVE, TEST_TEMP)
	SaveService.delete_save_files()
	DataRepository.singleton().load_from_filesystem()
	GameState.initialize("gallery-player")
	GameState.new_run()


func after_each() -> void:
	SaveService.delete_save_files()
	SaveService.set_save_paths(SaveService.DEFAULT_SAVE_PATH, SaveService.DEFAULT_TEMP_PATH)


func _seed_entry(id: String, fact: String) -> void:
	var entry := MuseumEntry.new()
	entry.artifact_id = id
	entry.fact_card = fact
	GameState.save_state.persistent.museum_entries["entry_%s_gallery-player" % id] = entry


func test_gallery_renders_persisted_entries_offline() -> void:
	_seed_entry("oton_death_mask", "Gold fact card")
	_seed_entry("master_artifact_demo", "Assembled fact card")

	var gallery: MuseumGallery = GalleryScene.instantiate() as MuseumGallery
	add_child_autofree(gallery)
	gallery.open()

	var cards := gallery._cards_container.get_children()
	assert_eq(cards.size(), 3, "header + 2 entry cards")
	var titles: Array[String] = []
	for card in cards:
		if card is PanelContainer:
			for child in card.get_children():
				if child is VBoxContainer:
					for sub in child.get_children():
						if sub is Label and sub.text in ["oton_death_mask", "master_artifact_demo"]:
							titles.append(sub.text)
	assert_true(titles.has("oton_death_mask"))
	assert_true(titles.has("master_artifact_demo"))


func test_gallery_shows_empty_message_when_no_records() -> void:
	var gallery: MuseumGallery = GalleryScene.instantiate() as MuseumGallery
	add_child_autofree(gallery)
	gallery.open()

	var labels: Array[String] = []
	for child in gallery._cards_container.get_children():
		if child is Label:
			labels.append(child.text)
	assert_true(labels.any(func(t: String) -> bool: return t.contains("No museum records")))


func test_gallery_refresh_button_follows_online_toggle() -> void:
	SettingsService.set_ai_mode(SettingsService.AI_ONLINE)
	var gallery: MuseumGallery = GalleryScene.instantiate() as MuseumGallery
	add_child_autofree(gallery)
	gallery.open()
	assert_false(gallery._refresh_button.disabled)

	SettingsService.set_ai_mode(SettingsService.AI_OFFLINE)
	gallery.open()
	assert_true(gallery._refresh_button.disabled)
	assert_eq(gallery._refresh_button.text, MuseumGallery.REFRESH_TEXT_OFFLINE)


func test_gallery_survives_backend_failure_without_crashing() -> void:
	_seed_entry("oton_death_mask", "Local fact")
	var gallery: MuseumGallery = GalleryScene.instantiate() as MuseumGallery
	add_child_autofree(gallery)
	gallery.open()

	# Simulate a failed refresh: the gallery should still show the local record.
	EventBus.museum_gallery_refreshed.emit([], true)

	assert_true(gallery.visible)
	assert_eq(gallery._status_label.text, "Offline mirror — showing local records")
