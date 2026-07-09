extends Node
## The Perfect Loop finale (END-R3/R5, minimal slice).
##
## Seating the fifth fragment IS the Perfect Loop: this autoload watches
## fragment_seated, waits for the Portal Unlock flow to close, then holds the
## clock still and plays the Yuyu return scene followed by the Day-6 end card.
## Fires exactly once per save (persistent.perfect_loop_completed); afterwards
## play continues freely as postgame. The full tactile Master Artifact assembly
## (story.md §9.1) stays deferred behind the artifact lock (D1) — this scene is
## authored artifact-agnostically.

signal finale_started
signal finale_finished

## The Yuyu return scene (story.md §9.2 English rendering; review-pending §4-Q).
const YUYU_LINES: Array[String] = [
	(
		"Yuyu: [i]Where there was only lamplight, there is a man — translucent at "
		+ "the edges, already steadying.[/i] —and that's why the Chronos Emulsion "
		+ "shouldn't ever be sealed with— [i]He stops. Looks at you.[/i] ...Ah."
	),
	"You: Yuyu—",
	(
		"Yuyu: Goodness... look at you. [i]He reaches out, not quite touching your "
		+ "shoulder, like his hands aren't entirely back yet.[/i] How long was I...?"
	),
	"You: Five days. Looped. Over and over, until—",
	(
		"Yuyu: Until five people I trusted held five pieces, and one stubborn kid "
		+ "went and found every single one of them. [i]He laughs, real this time, a "
		+ "little wet at the edges.[/i]"
	),
	(
		"Yuyu: Alima. Passing something forward, hand to hand, until it's too heavy "
		+ "for one person to carry alone. I think I finally understand why your Lola "
		+ "said it like that."
	),
]
const END_CARD_TITLE := "Saturday — Day 6"
const END_CARD_BODY := (
	"The morning that finally comes.\n\n"
	+ "The Emulsion goes quiet — not dead, done. The five pieces sit whole in the "
	+ "journal's case, and for the first time the light keeps moving past eight.\n\n"
	+ "aLima — Team DECYFER"
)
const YUYU_PORTRAIT_PATH := "res://assets/Characters/Uncle.png"

var _pending := false
var _overlay: CanvasLayer = null
var _line_index := 0
var _line_label: RichTextLabel = null
var _portrait: TextureRect = null
var _button: Button = null
var _title_label: Label = null
var _owns_pause := false


func _ready() -> void:
	EventBus.fragment_seated.connect(_on_fragment_seated)


func is_finale_pending_or_running() -> bool:
	return _pending or _overlay != null


func _on_fragment_seated(_fragment_id: String, _slot_index: int) -> void:
	if GameState.save_state == null:
		return
	if GameState.save_state.persistent.perfect_loop_completed:
		return
	if not _all_fragments_seated():
		return
	if _pending or _overlay != null:
		return
	_pending = true
	# The Portal Unlock screen is still up when seating happens; let its flow
	# close first, then open the finale on top of whatever scene is active.
	PortalFlowController.flow_finished.connect(_on_portal_flow_finished, CONNECT_ONE_SHOT)


func _all_fragments_seated() -> bool:
	var fragments: Dictionary = GameState.save_state.persistent.fragments
	if fragments.is_empty():
		return false
	for fragment_id in fragments.keys():
		var fragment: Fragment = fragments[fragment_id]
		if fragment.state != ModelEnums.FragmentState.SEATED:
			return false
	return true


func _on_portal_flow_finished(_fragment_id: String) -> void:
	if not _pending:
		return
	_pending = false
	start_finale()


## Opens the finale overlay. Public so tests (and a reload with all five seated
## but the flag unset) can drive it directly.
func start_finale() -> void:
	if _overlay != null:
		return
	if GameState.save_state.persistent.perfect_loop_completed:
		return
	GameState.save_state.persistent.perfect_loop_completed = true
	var save_result := SaveService.save_game()
	if not save_result.ok:
		push_error("FinaleService: finale save failed: %s" % save_result.get("error", ""))
	if not _owns_pause:
		DayClock.request_pause(DayClock.PAUSE_FINALE)
		_owns_pause = true
	if DisplayServer.get_name() != "headless":
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	_line_index = 0
	_build_overlay()
	_render_line()
	finale_started.emit()


func advance() -> void:
	if _overlay == null:
		return
	if _line_index < YUYU_LINES.size() - 1:
		_line_index += 1
		_render_line()
		return
	if _line_index == YUYU_LINES.size() - 1:
		_line_index += 1
		_render_end_card()
		return
	_close()


func _render_line() -> void:
	_title_label.text = "The Perfect Loop"
	_line_label.text = YUYU_LINES[_line_index]
	_portrait.visible = true
	_button.text = "Continue"


func _render_end_card() -> void:
	_title_label.text = END_CARD_TITLE
	_line_label.text = END_CARD_BODY
	_portrait.visible = false
	_button.text = "Open the shop"


func _close() -> void:
	if _overlay != null:
		_overlay.queue_free()
		_overlay = null
	if _owns_pause:
		if DayClock.has_pause_owner(DayClock.PAUSE_FINALE):
			DayClock.release_pause(DayClock.PAUSE_FINALE)
		_owns_pause = false
	finale_finished.emit()


func _build_overlay() -> void:
	_overlay = CanvasLayer.new()
	_overlay.layer = 95
	Engine.get_main_loop().root.add_child(_overlay)

	var backdrop := ColorRect.new()
	backdrop.color = Color(0.02, 0.02, 0.03, 0.92)
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	_overlay.add_child(backdrop)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(820, 480)
	center.add_child(panel)

	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_%s" % side, 32)
	panel.add_child(margin)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 18)
	margin.add_child(col)

	_title_label = Label.new()
	_title_label.add_theme_font_size_override("font_size", 30)
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(_title_label)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 24)
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(row)

	_portrait = TextureRect.new()
	_portrait.custom_minimum_size = Vector2(200, 280)
	_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var tex := load(YUYU_PORTRAIT_PATH) as Texture2D
	if tex != null:
		_portrait.texture = tex
	row.add_child(_portrait)

	_line_label = RichTextLabel.new()
	_line_label.bbcode_enabled = true
	_line_label.fit_content = true
	_line_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_line_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.add_child(_line_label)

	_button = Button.new()
	_button.custom_minimum_size = Vector2(0, 52)
	_button.pressed.connect(advance)
	col.add_child(_button)
	_button.grab_focus()
