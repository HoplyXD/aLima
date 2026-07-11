class_name MuseumGallery
extends CanvasLayer
## In-game museum gallery (MUS-R3): a full-screen mirror of the persisted Gold +
## Master Artifact museum records. Works offline from save data; can refresh
## from the Portal when the online-services toggle is enabled.

signal closed

const REFRESH_TEXT_ONLINE := "Refresh from Portal"
const REFRESH_TEXT_OFFLINE := "Offline mode — local records only"

var _owns_pause: bool = false
var _refresh_pending: bool = false

@onready var _dim: ColorRect = $Dim
@onready var _body: PanelContainer = $Dim/Center/Body
@onready var _title_label: Label = %TitleLabel
@onready var _status_label: Label = %StatusLabel
@onready var _cards_container: VBoxContainer = %CardsContainer
@onready var _refresh_button: Button = %RefreshButton
@onready var _close_button: Button = %CloseButton


func _ready() -> void:
	visible = false
	_body.add_theme_stylebox_override("panel", UiPalette.wooden_panel_style())
	_title_label.add_theme_color_override("font_color", UiPalette.BRASS_BRIGHT)
	_close_button.pressed.connect(close)
	_refresh_button.pressed.connect(_on_refresh_pressed)
	EventBus.museum_gallery_refreshed.connect(_on_gallery_refreshed)
	EventBus.museum_entry_recorded.connect(_on_museum_entry_recorded)


func _input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()


func open() -> void:
	if not visible:
		visible = true
	_request_pause()
	UiAnimations.popup_open(_body)
	UiAnimations.fade_to(_dim, 1.0, 0.2)
	_refresh_status()
	_refresh_button.text = (
		REFRESH_TEXT_ONLINE if SettingsService.ai_mode_is_online() else REFRESH_TEXT_OFFLINE
	)
	_refresh_button.disabled = not SettingsService.ai_mode_is_online()
	_render_entries()
	_close_button.grab_focus()


func close() -> void:
	if not visible:
		return
	UiAnimations.popup_close(_body)
	UiAnimations.fade_to(_dim, 0.0, 0.15)
	visible = false
	_release_pause_if_owned()
	closed.emit()


func _render_entries() -> void:
	for child in _cards_container.get_children():
		child.queue_free()

	var entries := MuseumService.get_gallery_entries()
	if entries.is_empty():
		_cards_container.add_child(_make_empty_label())
		return

	var header := Label.new()
	header.text = "%d record(s)" % entries.size()
	header.add_theme_font_size_override("font_size", 22)
	header.add_theme_color_override("font_color", UiPalette.BONE_DIM)
	_cards_container.add_child(header)

	for entry in entries:
		_cards_container.add_child(_make_entry_card(entry))


func _make_entry_card(entry: MuseumEntry) -> Control:
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", UiPalette.manuscript_card_style())

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	card.add_child(box)

	var title := Label.new()
	title.text = entry.artifact_id
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", UiPalette.BRASS_BRIGHT)
	box.add_child(title)

	var fact := _wrap_field("Fact card", entry.fact_card)
	box.add_child(fact)

	if not entry.timeline_entry.is_empty():
		box.add_child(_wrap_field("Timeline", entry.timeline_entry))
	if not entry.regional_story.is_empty():
		box.add_child(_wrap_field("Regional story", entry.regional_story))
	if entry.character_memory_refs.size() > 0:
		box.add_child(_wrap_field("Character memories", ", ".join(entry.character_memory_refs)))

	var placeholder := _make_photo_placeholder(entry.artifact_id)
	box.add_child(placeholder)

	return card


func _make_photo_placeholder(artifact_id: String) -> Control:
	var frame := PanelContainer.new()
	frame.custom_minimum_size = Vector2(0, 120)
	frame.add_theme_stylebox_override("panel", UiPalette.panel_style(UiPalette.INK))

	var label := Label.new()
	label.text = "Photo: %s" % artifact_id
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", UiPalette.BONE_DIM)
	frame.add_child(label)
	return frame


func _wrap_field(label_text: String, body_text: String) -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	var label := Label.new()
	label.text = label_text
	label.add_theme_font_size_override("font_size", 20)
	label.add_theme_color_override("font_color", UiPalette.BRASS)
	box.add_child(label)
	var body := Label.new()
	body.text = body_text
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_theme_font_size_override("font_size", 22)
	body.add_theme_color_override("font_color", UiPalette.BONE)
	box.add_child(body)
	return box


func _make_empty_label() -> Label:
	var label := Label.new()
	label.text = (
		"No museum records yet.\n" + "Preserve a Gold find or seat a fragment to begin the gallery."
	)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", 24)
	label.add_theme_color_override("font_color", UiPalette.BONE_DIM)
	return label


func _on_refresh_pressed() -> void:
	if _refresh_pending or not SettingsService.ai_mode_is_online():
		return
	_refresh_pending = true
	_status_label.text = "Reaching the Portal…"
	MuseumService.refresh_gallery()


func _on_gallery_refreshed(_entries: Array, used_fallback: bool) -> void:
	_refresh_pending = false
	if used_fallback:
		_status_label.text = "Offline mirror — showing local records"
	else:
		_status_label.text = "Online — gallery mirrored from the Portal"
	_render_entries()


func _on_museum_entry_recorded(_entry_id: String, _record_id: String, _used_fallback: bool) -> void:
	if visible:
		_render_entries()


func _refresh_status() -> void:
	if SettingsService.ai_mode_is_online():
		_status_label.text = "Online — tap Refresh to mirror the Portal"
	else:
		_status_label.text = "Offline mirror — local records"


func _request_pause() -> void:
	if not _owns_pause:
		DayClock.request_pause(DayClock.PAUSE_MUSEUM)
		_owns_pause = true


func _release_pause_if_owned() -> void:
	if _owns_pause and DayClock.has_pause_owner(DayClock.PAUSE_MUSEUM):
		DayClock.release_pause(DayClock.PAUSE_MUSEUM)
	_owns_pause = false
