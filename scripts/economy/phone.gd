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
var _said_label: Label = null  ## The buyer's spoken-line label, upgraded with live banter.
var _ai_label: Label = null  ## "AI: live / offline" indicator in the haggle view.

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
	# The phone does NOT pause the in-game clock (only dialogue and the pause menu do),
	# so time keeps flowing while you browse — which lets new buyers arrive over time.
	if not visible:
		visible = true
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


## Opens an app by id: "tools_shop" (buy tools) or "marketplace" (sell artifacts).
func open_app(app_id: String) -> void:
	_current_app = app_id
	_home.visible = false
	_app_view.visible = true
	_home_button.visible = true
	match app_id:
		"tools_shop":
			_app_title.text = "Local PH Tools Shop"
			_render_tools_shop()
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
	_app_grid.add_child(_make_app_icon("Local PH\nTools Shop", "tools_shop", false))
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


# --- Local PH Tools Shop app (buy tools) -------------------------------------


func _render_tools_shop() -> void:
	for child in _app_content.get_children():
		child.queue_free()

	var money := Label.new()
	money.text = "Money: ₱%d" % GameState.save_state.loop.money
	money.add_theme_font_size_override("font_size", 18)
	_app_content.add_child(money)

	_app_content.add_child(_make_section_label("Restoration tools"))
	for def in MarketplaceService.get_catalog():
		_app_content.add_child(_make_buy_row(def as ToolDefinition))

	var pending: int = GameState.save_state.loop.tool_shipments.size()
	var ship := Label.new()
	ship.text = "On the way: %d tool(s)" % pending if pending > 0 else "No incoming shipments."
	ship.add_theme_font_size_override("font_size", 13)
	ship.add_theme_color_override("font_color", Color(0.7, 0.85, 0.7))
	_app_content.add_child(ship)


# --- Marketplace app (sell artifacts + banter) -------------------------------


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


## Tracks how many buyers were on screen last paint, so the picker only re-renders when
## a new buyer actually arrives (arrivals are time-based in MarketplaceService).
var _last_arrived_count: int = -1
var _picker_repaint: Timer = null


## Lists an item and shows the buyers who have arrived so far. Arrivals are time-based
## in the service, so they persist across opening/closing the phone and keep coming
## even while the phone is closed. Test seam.
func open_buyers(uid: String) -> void:
	_sell_uid = uid
	_market_view = "buyers"
	_last_arrived_count = -1
	_render_marketplace()
	_start_picker_repaint()


func _render_buyer_picker() -> void:
	_app_content.add_child(_make_back_button())
	var template := DataRepository.singleton().get_template(_sold_template_id())
	var title := Label.new()
	title.text = "Who'll buy it? (≈₱%d)" % MarketplaceService.assessed_value(_sell_uid)
	title.add_theme_font_size_override("font_size", 16)
	_app_content.add_child(title)
	if template != null:
		_app_content.add_child(_make_section_label(template.display_name))
	var arrived := MarketplaceService.arrived_buyers(_sell_uid)
	_last_arrived_count = arrived.size()
	for persona in arrived:
		_app_content.add_child(_make_buyer_row(persona as BuyerPersona))
	if arrived.size() < MarketplaceService.interested_buyers(_sell_uid).size():
		_app_content.add_child(_make_section_label("More buyers are still on their way…"))


## A light 1s poll that re-renders the picker only when a new buyer has arrived, so the
## list updates live without constantly rebuilding the view.
func _start_picker_repaint() -> void:
	if _picker_repaint == null:
		_picker_repaint = Timer.new()
		_picker_repaint.wait_time = 1.0
		add_child(_picker_repaint)
		_picker_repaint.timeout.connect(_on_picker_repaint)
	_picker_repaint.start()


func _on_picker_repaint() -> void:
	if not (visible and _current_app == "marketplace" and _market_view == "buyers"):
		_picker_repaint.stop()
		return
	if MarketplaceService.arrived_buyers(_sell_uid).size() != _last_arrived_count:
		_render_marketplace()


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
	_refresh_ai_status()  # probe the backend so the indicator is accurate on open


func _render_haggle() -> void:
	_app_content.add_child(_make_back_button())
	var persona := DataRepository.singleton().get_buyer(_buyer_id)
	var who := Label.new()
	who.text = persona.display_name if persona != null else _buyer_id
	who.add_theme_font_size_override("font_size", 16)
	_app_content.add_child(who)

	# Shows whether banter is using the live AI or the offline fallback.
	_ai_label = Label.new()
	_ai_label.add_theme_font_size_override("font_size", 11)
	_refresh_ai_label()
	_app_content.add_child(_ai_label)

	_said_label = Label.new()
	_said_label.text = "\"%s\"" % _negotiation.history.back()["text"]
	_said_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_said_label.add_theme_font_size_override("font_size", 14)
	_said_label.add_theme_color_override("font_color", Color(0.92, 0.9, 0.7))
	_app_content.add_child(_said_label)

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

	# Accept the standing offer, or type how much to ask for.
	_app_content.add_child(_make_action("Accept ₱%d" % _negotiation.current_offer, accept_offer))
	var ask_row := HBoxContainer.new()
	ask_row.add_theme_constant_override("separation", 8)
	var ask_input := LineEdit.new()
	ask_input.placeholder_text = "Ask for ₱…"
	ask_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ask_input.focus_mode = Control.FOCUS_ALL
	ask_input.text_submitted.connect(func(t: String) -> void: _submit_ask(t))
	ask_row.add_child(ask_input)
	ask_row.add_child(_make_action("Ask", func() -> void: _submit_ask(ask_input.text)))
	_app_content.add_child(ask_row)

	# Conversational banter moves (each usable once) — one full-width row each so the
	# longer labels stay easy to read.
	var moves := _negotiation.available_moves()
	if not moves.is_empty():
		_app_content.add_child(_make_section_label("Quick banter"))
		var banter_box := VBoxContainer.new()
		banter_box.add_theme_constant_override("separation", 6)
		for move_id in moves:
			var label: String = Negotiation.BANTER_MOVES[move_id]["label"]
			var b := _make_action(label, func() -> void: haggle_banter(move_id))
			b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			banter_box.add_child(b)
		_app_content.add_child(banter_box)

	# Free-text chat: type anything to banter. Keep it civil — offensive/NSFW messages
	# disgust the buyer, end the deal, and ghost them.
	_app_content.add_child(_make_section_label("Say something"))
	var chat_row := HBoxContainer.new()
	chat_row.add_theme_constant_override("separation", 8)
	var chat_input := LineEdit.new()
	chat_input.placeholder_text = "Type a message…"
	chat_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	chat_input.focus_mode = Control.FOCUS_ALL
	chat_input.text_submitted.connect(func(text: String) -> void: haggle_chat(text))
	chat_row.add_child(chat_input)
	chat_row.add_child(_make_action("Send", func() -> void: haggle_chat(chat_input.text)))
	_app_content.add_child(chat_row)


## Player accepts the buyer's standing offer and completes the sale. Test seam.
func accept_offer() -> void:
	if _negotiation == null:
		return
	_settle(_negotiation.accept())


## Parses a typed asking amount (digits only) and counters with it. Test seam.
func _submit_ask(text: String) -> void:
	var price := _parse_price(text)
	if price > 0:
		haggle_ask(price)


static func _parse_price(text: String) -> int:
	var digits := ""
	for ch in text:
		if ch >= "0" and ch <= "9":
			digits += ch
	return int(digits) if not digits.is_empty() else 0


## Player counters with an asking price. Closes the sale if the buyer accepts; if the
## buyer runs out of patience and walks, that's a failed banter (day ghost). Otherwise
## re-renders with the new offer. Test seam.
func haggle_ask(price: int) -> void:
	if _negotiation == null:
		return
	var result := _negotiation.counter(price)
	if result["accepted"]:
		_settle(_negotiation.final_price)
		return
	if result.get("walked", false):
		MarketplaceService.ghost_failed_banter(_sell_uid, _buyer_id)
		_feedback_label.text = "%s walked away." % _buyer_display()
		_back_to_market_home()
		return
	_render_marketplace()
	await _upgrade_buyer_line("How about ₱%d?" % price)


## Replaces the buyer's canned line with a live LLM banter line when online services
## are on and the backend is reachable; otherwise leaves the offline line in place.
func _upgrade_buyer_line(player_text: String) -> void:
	if _negotiation == null or _negotiation.is_closed():
		return
	var persona := DataRepository.singleton().get_buyer(_buyer_id)
	var line: String = await NegotiationClient.fetch_banter(
		persona, _negotiation.current_offer, player_text, _negotiation.history
	)
	_refresh_ai_label()
	if line.is_empty():
		return
	if _current_app == "marketplace" and _market_view == "haggle" and is_instance_valid(_said_label):
		_said_label.text = "\"%s\"" % line


## Player plays a banter move (chat) to shift the buyer's mood, then re-renders.
## Test seam.
func haggle_banter(move_id: String) -> void:
	if _negotiation == null:
		return
	_negotiation.banter(move_id)
	_render_marketplace()
	await _upgrade_buyer_line(str(Negotiation.BANTER_MOVES[move_id]["say"]))


## Player sends a free-text banter message. Offensive/NSFW input offends the buyer:
## the deal ends and they are ghosted (won't show up again for this item). Civil chat
## warms the mood; online, the buyer's reply is upgraded by the LLM. Test seam.
func haggle_chat(text: String) -> void:
	if _negotiation == null or text.strip_edges().is_empty():
		return
	# Respond INSTANTLY with the deterministic reply + keyword moderation (no network
	# wait, so sending never lags). The LLM then upgrades the reply / catches contextual
	# offenses in the background.
	if _negotiation.chat(text).get("offended", false):
		_ghost_offended()
		return
	_render_marketplace()
	await _upgrade_chat_line(text)


## Replaces the offline reply with a live LLM line and applies the LLM's contextual
## moderation verdict (which catches creepy/inappropriate lines the keyword filter
## misses, e.g. being hit on). Runs after the instant offline response, so there is no
## perceptible delay when sending. No-op offline / when the deal has since closed.
func _upgrade_chat_line(player_text: String) -> void:
	if not SettingsService.online_enabled() or DisplayServer.get_name() == "headless":
		return
	if _negotiation == null or _negotiation.is_closed():
		return
	var persona := DataRepository.singleton().get_buyer(_buyer_id)
	var reply := await NegotiationClient.fetch_chat(
		persona, _negotiation.current_offer, player_text, _negotiation.history
	)
	_refresh_ai_label()
	if _negotiation == null or _negotiation.is_closed() or not reply.get("ok", false):
		return
	if bool(reply.get("offended", false)):
		_negotiation.force_offended()
		_ghost_offended()
		return
	var line := str(reply.get("reply", ""))
	if line.is_empty():
		return
	if _current_app == "marketplace" and _market_view == "haggle" and is_instance_valid(_said_label):
		_said_label.text = "\"%s\"" % line


## Probes the backend status when entering the haggle so the indicator is accurate
## before the player sends anything.
func _refresh_ai_status() -> void:
	await NegotiationClient.refresh_status()
	_refresh_ai_label()


## Updates the AI/offline indicator from the live setting, the status probe, and the
## last real reply.
func _refresh_ai_label() -> void:
	if not is_instance_valid(_ai_label):
		return
	var amber := Color(0.88, 0.6, 0.4)
	var green := Color(0.45, 0.85, 0.5)
	var gray := Color(0.62, 0.62, 0.66)
	if not SettingsService.online_enabled():
		_ai_label.text = "AI banter: OFF — offline replies"
		_ai_label.add_theme_color_override("font_color", gray)
	elif NegotiationClient.last_live:
		_ai_label.text = "AI banter: LIVE"
		_ai_label.add_theme_color_override("font_color", green)
	elif NegotiationClient.status_reachable and NegotiationClient.status_live_capable:
		_ai_label.text = "AI banter: ready — say something to go live"
		_ai_label.add_theme_color_override("font_color", green)
	elif NegotiationClient.status_reachable:
		_ai_label.text = "AI banter: backend up, no model — set a key or LLM_PROVIDER=local"
		_ai_label.add_theme_color_override("font_color", amber)
	else:
		_ai_label.text = "AI banter: offline — start the backend (npm start in server/)"
		_ai_label.add_theme_color_override("font_color", amber)


func _ghost_offended() -> void:
	# Offensive/NSFW: a permanent (whole-loop) block — Maverick only artifact-ghosts.
	if _buyer_id == MarketplaceService.MAVERICK_ID:
		_feedback_label.text = "%s ghosted you for this artifact." % _buyer_display()
	else:
		_feedback_label.text = "You have been blocked by %s." % _buyer_display()
	MarketplaceService.ghost_offensive(_sell_uid, _buyer_id)
	_back_to_market_home()


## Player ghosts the customer (a failed banter) — no sale, and they skip you for the
## rest of the day (Mr. Maverick only skips this one artifact). Test seam.
func haggle_walk() -> void:
	if _negotiation != null:
		_negotiation.decline()
		MarketplaceService.ghost_failed_banter(_sell_uid, _buyer_id)
	_feedback_label.text = "You ghosted %s." % _buyer_display()
	_back_to_market_home()


func _buyer_display() -> String:
	var persona := DataRepository.singleton().get_buyer(_buyer_id)
	return persona.display_name if persona != null else "the customer"


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
	if _current_app == "tools_shop":
		_render_tools_shop()
