class_name Phone
extends CanvasLayer
## The shop phone: an authored phone-frame scene (phone.tscn) with a home screen
## of apps. For now the only app is the Marketplace (buy tools; selling/banter is
## the deferred Phase-14 negotiation).
##
## Presentation only: the structural nodes live in phone.tscn; this script handles
## navigation (home <-> app), renders the dynamic app content, and delegates every
## purchase rule to MarketplaceService. The phone owns DayClock.PAUSE_PHONE.

signal closed

var _owns_pause: bool = false
var _current_app: String = ""

# Marketplace sub-navigation: "home" (buy + sell list), "buyers" (pick a buyer for
# the listed item), "haggle" (negotiate with the chosen buyer).
var _market_view: String = "home"
var _sell_uid: String = ""
var _buyer_id: String = ""
var _negotiation: Negotiation = null

@onready var _close_button: Button = %CloseButton
@onready var _home_button: Button = %HomeButton
@onready var _home: VBoxContainer = %Home
@onready var _app_grid: GridContainer = %AppGrid
@onready var _app_view: VBoxContainer = %AppView
@onready var _app_title: Label = %AppTitle
@onready var _app_content: VBoxContainer = %AppContent
@onready var _feedback_label: Label = %FeedbackLabel


func _ready() -> void:
	visible = false
	_close_button.pressed.connect(close)
	_home_button.pressed.connect(show_home)
	_build_app_grid()


## Opens the phone on its home screen and pauses shop time.
func open() -> void:
	if not visible:
		visible = true
		if not _owns_pause:
			DayClock.request_pause(DayClock.PAUSE_PHONE)
			_owns_pause = true
	show_home()
	_close_button.grab_focus()


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


# Backspace backs out of an app to the home screen, or closes the phone from home
# (Esc is reserved for the pause menu).
func _input(event: InputEvent) -> void:
	if not visible or not event.is_action_pressed("back"):
		return
	if _current_app.is_empty():
		close()
	else:
		show_home()
	get_viewport().set_input_as_handled()


# --- Navigation --------------------------------------------------------------


func show_home() -> void:
	_current_app = ""
	_feedback_label.text = ""
	_market_view = "home"
	_sell_uid = ""
	_buyer_id = ""
	_negotiation = null
	_home.visible = true
	_app_view.visible = false
	_home_button.visible = false


## Opens an app by id. Only "marketplace" exists for now.
func open_app(app_id: String) -> void:
	_current_app = app_id
	_home.visible = false
	_app_view.visible = true
	_home_button.visible = true
	match app_id:
		"marketplace":
			_app_title.text = "Marketplace"
			_market_view = "home"
			_render_marketplace()
		_:
			_app_title.text = "Unknown app"


func get_current_app() -> String:
	return _current_app


func owns_pause() -> bool:
	return _owns_pause


# --- Home screen -------------------------------------------------------------


func _build_app_grid() -> void:
	for child in _app_grid.get_children():
		child.queue_free()
	_app_grid.add_child(_make_app_icon("Marketplace", "marketplace", false))
	# Room for more apps later; shown disabled so the home screen reads as a phone.
	_app_grid.add_child(_make_app_icon("Soon", "", true))


func _make_app_icon(label: String, app_id: String, disabled: bool) -> Button:
	var button := Button.new()
	button.text = label
	button.custom_minimum_size = Vector2(110, 110)
	button.disabled = disabled
	button.focus_mode = Control.FOCUS_ALL
	if not disabled:
		button.pressed.connect(func() -> void: open_app(app_id))
	return button


# --- Marketplace app ---------------------------------------------------------


func _render_marketplace() -> void:
	for child in _app_content.get_children():
		child.queue_free()
	match _market_view:
		"buyers":
			_render_buyer_picker()
		"haggle":
			_render_haggle()
		_:
			_render_market_home()


func _render_market_home() -> void:
	var money := Label.new()
	money.text = "Money: ₱%d" % GameState.save_state.loop.money
	money.add_theme_font_size_override("font_size", 18)
	_app_content.add_child(money)

	_app_content.add_child(_make_section_label("Buy tools"))
	for def in MarketplaceService.get_catalog():
		_app_content.add_child(_make_buy_row(def as ToolDefinition))

	var pending: int = GameState.save_state.loop.tool_shipments.size()
	var ship := Label.new()
	ship.text = "On the way: %d tool(s)" % pending if pending > 0 else "No incoming shipments."
	ship.add_theme_font_size_override("font_size", 13)
	ship.add_theme_color_override("font_color", Color(0.7, 0.85, 0.7))
	_app_content.add_child(ship)

	_app_content.add_child(_make_section_label("Sell your work"))
	var sellable := MarketplaceService.get_sellable()
	if sellable.is_empty():
		var none := Label.new()
		none.text = "Restore a piece first, then list it here to haggle."
		none.add_theme_font_size_override("font_size", 12)
		none.add_theme_color_override("font_color", Color(0.6, 0.6, 0.65))
		_app_content.add_child(none)
	else:
		for inst in sellable:
			_app_content.add_child(_make_sell_row(inst))


# --- Selling: list -> pick a buyer -> haggle ---------------------------------


func _make_sell_row(inst: ObjectInstance) -> Control:
	var template := DataRepository.singleton().get_template(inst.template_id)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var name_label := Label.new()
	name_label.text = template.display_name if template != null else inst.template_id
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.add_theme_font_size_override("font_size", 15)
	row.add_child(name_label)
	var detail := Label.new()
	detail.text = "≈₱%d · %d%%" % [MarketplaceService.assessed_value(inst.uid), int(round(inst.condition))]
	detail.add_theme_font_size_override("font_size", 12)
	detail.add_theme_color_override("font_color", Color(0.8, 0.8, 0.85))
	row.add_child(detail)
	var list_button := Button.new()
	list_button.text = "List"
	list_button.focus_mode = Control.FOCUS_ALL
	var uid := inst.uid
	list_button.pressed.connect(func() -> void: open_buyers(uid))
	row.add_child(list_button)
	return row


## Lists an item and shows the interested buyers. Test seam.
func open_buyers(uid: String) -> void:
	_sell_uid = uid
	_market_view = "buyers"
	_render_marketplace()


func _render_buyer_picker() -> void:
	_app_content.add_child(_make_back_button())
	var template := DataRepository.singleton().get_template(_sold_template_id())
	var title := Label.new()
	title.text = "Who'll buy it? (≈₱%d)" % MarketplaceService.assessed_value(_sell_uid)
	title.add_theme_font_size_override("font_size", 16)
	_app_content.add_child(title)
	if template != null:
		_app_content.add_child(_make_section_label(template.display_name))
	for persona in MarketplaceService.interested_buyers(_sell_uid):
		_app_content.add_child(_make_buyer_row(persona as BuyerPersona))


func _make_buyer_row(persona: BuyerPersona) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var name_label := Label.new()
	name_label.text = persona.display_name
	name_label.add_theme_font_size_override("font_size", 15)
	box.add_child(name_label)
	var motive := Label.new()
	motive.text = persona.motive
	motive.add_theme_font_size_override("font_size", 11)
	motive.add_theme_color_override("font_color", Color(0.7, 0.7, 0.78))
	motive.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(motive)
	row.add_child(box)
	var talk := Button.new()
	talk.text = "Haggle"
	talk.focus_mode = Control.FOCUS_ALL
	var persona_id := persona.id
	talk.pressed.connect(func() -> void: begin_haggle(persona_id))
	row.add_child(talk)
	return row


## Opens the haggle session with the chosen buyer. Test seam.
func begin_haggle(persona_id: String) -> void:
	_buyer_id = persona_id
	_negotiation = MarketplaceService.start_negotiation(_sell_uid, persona_id)
	if _negotiation == null:
		_feedback_label.text = "That item can't be sold right now."
		_back_to_market_home()
		return
	_market_view = "haggle"
	_render_marketplace()


func _render_haggle() -> void:
	_app_content.add_child(_make_back_button())
	var persona := DataRepository.singleton().get_buyer(_buyer_id)
	var who := Label.new()
	who.text = persona.display_name if persona != null else _buyer_id
	who.add_theme_font_size_override("font_size", 16)
	_app_content.add_child(who)

	var said := Label.new()
	said.text = "\"%s\"" % _negotiation.history.back()["text"]
	said.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	said.add_theme_font_size_override("font_size", 14)
	said.add_theme_color_override("font_color", Color(0.92, 0.9, 0.7))
	_app_content.add_child(said)

	if _negotiation.is_closed():
		var outcome := Label.new()
		if _negotiation.walked:
			outcome.text = "%s walked away. No sale." % (persona.display_name if persona != null else "")
		else:
			outcome.text = "Sold for ₱%d!" % _negotiation.final_price
		outcome.add_theme_font_size_override("font_size", 15)
		_app_content.add_child(outcome)
		return

	var offer := Label.new()
	offer.text = "Current offer: ₱%d" % _negotiation.current_offer
	offer.add_theme_font_size_override("font_size", 18)
	_app_content.add_child(offer)

	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 8)
	buttons.add_child(_make_action("Accept ₱%d" % _negotiation.current_offer, accept_offer))
	var nudge := _round5(int(round(_negotiation.current_offer * 1.15)))
	var push := _round5(int(round(_negotiation.current_offer * 1.35)))
	if nudge <= _negotiation.current_offer:
		nudge = _negotiation.current_offer + 5
	if push <= nudge:
		push = nudge + 5
	buttons.add_child(_make_action("Ask ₱%d" % nudge, func() -> void: haggle_ask(nudge)))
	buttons.add_child(_make_action("Ask ₱%d" % push, func() -> void: haggle_ask(push)))
	buttons.add_child(_make_action("Walk away", haggle_walk))
	_app_content.add_child(buttons)


## Player accepts the buyer's standing offer and completes the sale. Test seam.
func accept_offer() -> void:
	if _negotiation == null:
		return
	_settle(_negotiation.accept())


## Player counters with an asking price. Closes the sale if the buyer accepts, ends
## if they walk, otherwise re-renders with the new offer. Test seam.
func haggle_ask(price: int) -> void:
	if _negotiation == null:
		return
	var result := _negotiation.counter(price)
	if result["accepted"]:
		_settle(_negotiation.final_price)
	elif result["walked"]:
		_render_marketplace()
	else:
		_render_marketplace()


## Player walks away from the deal. Test seam.
func haggle_walk() -> void:
	if _negotiation != null:
		_negotiation.decline()
	_feedback_label.text = "You kept the piece."
	_back_to_market_home()


func _settle(price: int) -> void:
	var result := MarketplaceService.complete_sale(_sell_uid, price, _buyer_id)
	if result.ok:
		_feedback_label.text = "Sold for ₱%d." % result.price
	else:
		_feedback_label.text = result.error
	_back_to_market_home()


func _back_to_market_home() -> void:
	_market_view = "home"
	_sell_uid = ""
	_buyer_id = ""
	_negotiation = null
	if _current_app == "marketplace":
		_render_marketplace()


func _sold_template_id() -> String:
	for raw in GameState.save_state.loop.inventory:
		if raw is Dictionary and raw.get("uid") == _sell_uid:
			return ModelUtils.as_string(raw.get("template_id"))
	return ""


func _make_section_label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 13)
	label.add_theme_color_override("font_color", Color(0.65, 0.7, 0.8))
	return label


func _make_back_button() -> Button:
	var back := Button.new()
	back.text = "← Back"
	back.focus_mode = Control.FOCUS_ALL
	back.pressed.connect(_back_to_market_home)
	return back


func _make_action(text: String, handler: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_ALL
	button.pressed.connect(handler)
	return button


static func _round5(value: int) -> int:
	return int(round(value / 5.0)) * 5


func _make_buy_row(def: ToolDefinition) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var name_label := Label.new()
	name_label.text = def.display_name
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.add_theme_font_size_override("font_size", 15)
	row.add_child(name_label)
	var detail := Label.new()
	var uses := "∞" if def.durability <= 0 else "%d" % def.durability
	detail.text = "₱%d · %s · ~%dh" % [def.cost, uses, def.ship_hours]
	detail.add_theme_font_size_override("font_size", 12)
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


## Buys a tool through MarketplaceService and refreshes the Marketplace app.
func buy(tool_id: String) -> void:
	var result := MarketplaceService.buy(tool_id)
	if result.ok:
		var def := DataRepository.singleton().get_tool(tool_id)
		var name := def.display_name if def != null else tool_id
		_feedback_label.text = "Ordered %s — shipping to the shop." % name
	else:
		_feedback_label.text = result.error
	if _current_app == "marketplace":
		_render_marketplace()
