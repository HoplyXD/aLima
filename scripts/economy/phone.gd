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


# Esc backs out of an app to the home screen, or closes the phone from home.
func _input(event: InputEvent) -> void:
	if not visible or not event.is_action_pressed("ui_cancel"):
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

	var money := Label.new()
	money.text = "Money: ₱%d" % GameState.save_state.loop.money
	money.add_theme_font_size_override("font_size", 18)
	_app_content.add_child(money)

	for def in MarketplaceService.get_catalog():
		_app_content.add_child(_make_buy_row(def as ToolDefinition))

	var pending: int = GameState.save_state.loop.tool_shipments.size()
	var ship := Label.new()
	ship.text = "On the way: %d tool(s)" % pending if pending > 0 else "No incoming shipments."
	ship.add_theme_font_size_override("font_size", 13)
	ship.add_theme_color_override("font_color", Color(0.7, 0.85, 0.7))
	_app_content.add_child(ship)

	var sell := Label.new()
	sell.text = "Sell — list restored pieces and haggle online. Coming soon."
	sell.add_theme_font_size_override("font_size", 12)
	sell.add_theme_color_override("font_color", Color(0.6, 0.6, 0.65))
	_app_content.add_child(sell)


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
