class_name BuyerShopScreen
extends CanvasLayer
## Mr. Maverick's evening stall (v3, story.md §16): one overpriced artifact per
## day; buy all five and his Day-5 visit adds the fragment offer. Presentation
## only — the rules live in BuyerShopService; built in code like the showcase.

signal closed
## The player paid for the fragment: the shop controller runs the release ->
## Found -> Portal -> seat chain (it owns the overlay and the portal flow).
signal fragment_bought

const RARITY_COLORS := {
	"white": Color(0.85, 0.85, 0.85),
	"green": Color(0.36, 0.77, 0.42),
	"blue": Color(0.30, 0.55, 1.0),
	"purple": Color(0.69, 0.40, 1.0),
	"gold": Color(1.0, 0.72, 0.17),
}

var _service: BuyerShopService
var _owns_pause: bool = false

var _patter_label: Label
var _offers_box: VBoxContainer
var _money_label: Label
var _feedback_label: Label
var _close_button: Button


func _ready() -> void:
	layer = 82
	visible = false
	_build_ui()


## Opens tonight's stall. `service` may be injected for tests.
func open(service: BuyerShopService = null) -> void:
	_service = service if service != null else BuyerShopService.new()
	visible = true
	if not _owns_pause:
		DayClock.request_pause(DayClock.PAUSE_DIALOGUE)
		_owns_pause = true
	_feedback_label.text = ""
	_refresh()
	_close_button.grab_focus()


func is_open() -> bool:
	return visible


func close() -> void:
	if visible:
		visible = false
		if _owns_pause:
			if DayClock.has_pause_owner(DayClock.PAUSE_DIALOGUE):
				DayClock.release_pause(DayClock.PAUSE_DIALOGUE)
			_owns_pause = false
	closed.emit()


func _exit_tree() -> void:
	if _owns_pause and DayClock.has_pause_owner(DayClock.PAUSE_DIALOGUE):
		DayClock.release_pause(DayClock.PAUSE_DIALOGUE)


## Buys today's artifact. Public seam shared by the button and the GUT tests.
func buy_offer() -> void:
	var result := _service.buy_today(DayClock.get_day())
	_feedback_label.text = "A pleasure." if result.ok else str(result.error)
	_refresh()


## Buys the Day-5 fragment. Public seam shared by the button and the GUT tests.
func buy_fragment() -> void:
	var result := _service.buy_fragment(DayClock.get_day())
	if not result.ok:
		_feedback_label.text = str(result.error)
		_refresh()
		return
	visible = false
	if _owns_pause:
		if DayClock.has_pause_owner(DayClock.PAUSE_DIALOGUE):
			DayClock.release_pause(DayClock.PAUSE_DIALOGUE)
		_owns_pause = false
	fragment_bought.emit()


func _refresh() -> void:
	var day := DayClock.get_day()
	_money_label.text = "Your pesos: ₱%d" % GameState.save_state.loop.money
	for child in _offers_box.get_children():
		child.queue_free()

	var offer := _service.offer_for_day(day)
	if offer.is_empty():
		_offers_box.add_child(_make_note("Nothing on the table tonight."))
	else:
		var bought := _service.is_bought(day)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		var name_label := Label.new()
		name_label.text = str(offer["display_name"])
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_label.add_theme_font_size_override("font_size", 20)
		name_label.add_theme_color_override(
			"font_color", RARITY_COLORS.get(str(offer["rarity_name"]), Color.WHITE)
		)
		row.add_child(name_label)
		var buy := Button.new()
		buy.custom_minimum_size = Vector2(190, 48)
		buy.focus_mode = Control.FOCUS_ALL
		if bought:
			buy.text = "Yours already"
			buy.disabled = true
		else:
			buy.text = "Buy — ₱%d" % int(offer["price"])
			buy.disabled = GameState.save_state.loop.money < int(offer["price"])
			buy.pressed.connect(buy_offer)
		row.add_child(buy)
		_offers_box.add_child(row)

	# The real inventory: only for a customer who paid attention all five days.
	if _service.fragment_available(day):
		_offers_box.add_child(_make_note(
			"\"You bought all five. So: the real inventory. I promised a man I'd only "
			+ "sell it to someone who'd already paid attention.\""
		))
		var fragment_row := HBoxContainer.new()
		fragment_row.add_theme_constant_override("separation", 12)
		var fragment_label := Label.new()
		fragment_label.text = "A small cloth bundle, heavier than it should be"
		fragment_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		fragment_label.add_theme_font_size_override("font_size", 20)
		fragment_label.add_theme_color_override("font_color", RARITY_COLORS["gold"])
		fragment_row.add_child(fragment_label)
		var fragment_buy := Button.new()
		fragment_buy.custom_minimum_size = Vector2(190, 48)
		fragment_buy.focus_mode = Control.FOCUS_ALL
		fragment_buy.text = "Buy — ₱%d" % _service.fragment_price()
		fragment_buy.disabled = GameState.save_state.loop.money < _service.fragment_price()
		fragment_buy.pressed.connect(buy_fragment)
		fragment_row.add_child(fragment_buy)
		_offers_box.add_child(fragment_row)


func _make_note(text: String) -> Label:
	var note := Label.new()
	note.text = text
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.add_theme_font_size_override("font_size", 14)
	note.add_theme_color_override("font_color", Color(0.72, 0.68, 0.58))
	return note


func _build_ui() -> void:
	var backdrop := ColorRect.new()
	backdrop.color = Color(0, 0, 0, 0.78)
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(backdrop)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(640, 380)
	center.add_child(panel)

	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_%s" % side, 28)
	panel.add_child(margin)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 14)
	margin.add_child(col)

	var title := Label.new()
	title.text = "Mr. Maverick — Tonight's Stock"
	title.add_theme_font_size_override("font_size", 26)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(title)

	_patter_label = _make_note(
		"\"I sell exactly one thing a day, and it is always overpriced. "
		+ "The trick, kid, is that some days it's worth it.\""
	)
	_patter_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(_patter_label)

	_money_label = Label.new()
	_money_label.add_theme_font_size_override("font_size", 16)
	col.add_child(_money_label)

	_offers_box = VBoxContainer.new()
	_offers_box.add_theme_constant_override("separation", 10)
	_offers_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(_offers_box)

	_feedback_label = Label.new()
	_feedback_label.add_theme_font_size_override("font_size", 14)
	_feedback_label.add_theme_color_override("font_color", Color(0.85, 0.78, 0.5))
	col.add_child(_feedback_label)

	_close_button = Button.new()
	_close_button.text = "Not tonight"
	_close_button.custom_minimum_size = Vector2(0, 48)
	_close_button.pressed.connect(close)
	col.add_child(_close_button)
