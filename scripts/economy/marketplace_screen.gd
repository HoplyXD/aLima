class_name MarketplaceScreen
extends CanvasLayer
## The phone's Marketplace app (Buy side). Lists buyable tools; purchasing spends
## money and schedules a shipment that arrives after the tool's ship time. Selling
## restored artifacts and the online buyer banter are the Phase-14 server-side
## negotiation and are shown here only as a "coming soon" placeholder.
##
## Presentation only: every rule (price, shipping, money) lives in
## MarketplaceService. The UI is built in code so the scene file stays trivial.

signal closed

const BG_COLOR := Color(0.07, 0.06, 0.09, 0.96)

var _owns_pause: bool = false
var _money_label: Label
var _buy_list: VBoxContainer
var _shipments_label: Label
var _feedback_label: Label
var _close_button: Button


func _ready() -> void:
	visible = false
	_build_ui()


## Opens the Marketplace and pauses shop time.
func open() -> void:
	if not visible:
		visible = true
		if not _owns_pause:
			DayClock.request_pause(DayClock.PAUSE_PHONE)
			_owns_pause = true
	_feedback_label.text = ""
	refresh()
	_close_button.grab_focus()


## Closes the Marketplace and releases pause ownership exactly once.
func close() -> void:
	if visible:
		visible = false
		_release_pause_if_owned()
	closed.emit()


func _exit_tree() -> void:
	_release_pause_if_owned()


func _release_pause_if_owned() -> void:
	if _owns_pause and DayClock.has_pause_owner(DayClock.PAUSE_PHONE):
		DayClock.release_pause(DayClock.PAUSE_PHONE)
	_owns_pause = false


func _input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()


## Buys a tool through MarketplaceService and refreshes the listing.
func buy(tool_id: String) -> void:
	var result := MarketplaceService.buy(tool_id)
	if result.ok:
		var def := DataRepository.singleton().get_tool(tool_id)
		var name := def.display_name if def != null else tool_id
		_feedback_label.text = "Ordered %s — it'll ship to the shop soon." % name
	else:
		_feedback_label.text = result.error
	refresh()


## Re-renders money, the buyable catalog, and pending shipments from current state.
func refresh() -> void:
	_money_label.text = "Money: ₱%d" % GameState.save_state.loop.money
	for child in _buy_list.get_children():
		child.queue_free()
	for def in MarketplaceService.get_catalog():
		_buy_list.add_child(_make_buy_row(def as ToolDefinition))
	var pending: int = GameState.save_state.loop.tool_shipments.size()
	_shipments_label.text = (
		"On the way: %d tool(s)" % pending if pending > 0 else "No incoming shipments."
	)


func owns_pause() -> bool:
	return _owns_pause


# --- UI construction ---------------------------------------------------------


func _make_buy_row(def: ToolDefinition) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var name_label := Label.new()
	name_label.text = def.display_name
	name_label.custom_minimum_size = Vector2(220, 0)
	name_label.add_theme_font_size_override("font_size", 18)
	row.add_child(name_label)

	var detail := Label.new()
	var uses := "∞ uses" if def.durability <= 0 else "%d uses" % def.durability
	detail.text = "₱%d · %s · ~%dh" % [def.cost, uses, def.ship_hours]
	detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail.add_theme_font_size_override("font_size", 14)
	detail.add_theme_color_override("font_color", Color(0.8, 0.8, 0.85))
	row.add_child(detail)

	var buy_button := Button.new()
	buy_button.text = "Buy"
	buy_button.focus_mode = Control.FOCUS_ALL
	buy_button.disabled = GameState.save_state.loop.money < def.cost
	var tool_id := def.id
	buy_button.pressed.connect(func() -> void: buy(tool_id))
	row.add_child(buy_button)
	return row


func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.color = BG_COLOR
	bg.anchors_preset = Control.PRESET_FULL_RECT
	bg.mouse_filter = Control.MOUSE_FILTER_STOP  # block clicks from reaching the shop
	add_child(bg)

	var margin := MarginContainer.new()
	margin.anchors_preset = Control.PRESET_FULL_RECT
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_%s" % side, 48)
	bg.add_child(margin)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 12)
	margin.add_child(root)

	var title := Label.new()
	title.text = "Phone — Marketplace"
	title.add_theme_font_size_override("font_size", 34)
	root.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "Buy tools — they ship to the shop in a few hours."
	subtitle.add_theme_font_size_override("font_size", 15)
	subtitle.add_theme_color_override("font_color", Color(0.75, 0.75, 0.8))
	root.add_child(subtitle)

	_money_label = Label.new()
	_money_label.add_theme_font_size_override("font_size", 20)
	root.add_child(_money_label)

	var buy_header := Label.new()
	buy_header.text = "Tools for sale"
	buy_header.add_theme_font_size_override("font_size", 22)
	root.add_child(buy_header)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(scroll)

	_buy_list = VBoxContainer.new()
	_buy_list.add_theme_constant_override("separation", 8)
	_buy_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_buy_list)

	_shipments_label = Label.new()
	_shipments_label.add_theme_font_size_override("font_size", 15)
	_shipments_label.add_theme_color_override("font_color", Color(0.7, 0.85, 0.7))
	root.add_child(_shipments_label)

	var sell_note := Label.new()
	sell_note.text = "Sell — list your restored pieces and haggle online. Coming soon."
	sell_note.add_theme_font_size_override("font_size", 14)
	sell_note.add_theme_color_override("font_color", Color(0.6, 0.6, 0.65))
	root.add_child(sell_note)

	_feedback_label = Label.new()
	_feedback_label.add_theme_font_size_override("font_size", 15)
	_feedback_label.add_theme_color_override("font_color", Color(0.95, 0.9, 0.6))
	root.add_child(_feedback_label)

	_close_button = Button.new()
	_close_button.text = "Close"
	_close_button.focus_mode = Control.FOCUS_ALL
	_close_button.pressed.connect(close)
	root.add_child(_close_button)
