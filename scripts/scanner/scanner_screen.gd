class_name ScannerScreen
extends CanvasLayer
## Full-screen 2D scanner interface.
##
## Displays advisory scanner evidence for a cleaned object and requires an
## explicit player verdict. The scanner output never sets authenticity; the
## player chooses AUTHENTIC, REPLICA, MODIFIED, or UNCERTAIN. The interface
## acquires/releases DayClock.PAUSE_SCANNER ownership on open/close.

signal closed  ## Emitted after the screen closes.
signal verdict_committed(instance_id: String, verdict: int)

const VERDICT_BUTTONS: Dictionary = {
	ModelEnums.Verdict.AUTHENTIC: "Authentic",
	ModelEnums.Verdict.REPLICA: "Replica",
	ModelEnums.Verdict.MODIFIED: "Modified",
	ModelEnums.Verdict.UNCERTAIN: "Uncertain",
}

const STATUS_TEXT: Dictionary = {
	ScannerResult.Status.SUCCESS: "Analysis complete.",
	ScannerResult.Status.FALLBACK: "Analysis complete (cached fallback).",
	ScannerResult.Status.NOT_CLEAN: "This object must be cleaned before scanning.",
	ScannerResult.Status.MISSING_CACHE: "No scanner data is available for this object offline.",
	ScannerResult.Status.MALFORMED_RESPONSE: "Scanner data is corrupted. Try again later.",
	ScannerResult.Status.TRANSPORT_ERROR:
	"Scanner connection failed. Offline fallback unavailable.",
}

var _service: ScannerService
var _instance: ObjectInstance = null
var _selected_verdict: int = ModelEnums.Verdict.UNKNOWN
var _result: ScannerResult = null
var _owns_pause: bool = false
var _committed: bool = false

@onready var _object_label: Label = %ObjectLabel
@onready var _status_label: Label = %StatusLabel
@onready var _content: VBoxContainer = %Content
@onready var _verdict_section: VBoxContainer = %VerdictSection
@onready var _verdict_hint: Label = %VerdictHint
@onready var _verdict_buttons: HBoxContainer = %VerdictButtons
@onready var _confirm_button: Button = %ConfirmButton
@onready var _back_button: Button = %BackButton
@onready var _close_button: Button = %CloseButton


func _ready() -> void:
	visible = false
	_verdict_section.visible = false
	_confirm_button.pressed.connect(_on_confirm)
	_back_button.pressed.connect(_on_back)
	_close_button.pressed.connect(close)
	_build_verdict_buttons()


## Backspace backs out of the scanner (Esc stays the global pause toggle).
func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("back"):
		get_viewport().set_input_as_handled()
		_on_back()


## Opens the scanner for the given cleaned instance. Requests clock pause.
func open(instance: ObjectInstance) -> void:
	_instance = instance
	_selected_verdict = ModelEnums.Verdict.UNKNOWN
	_committed = false
	_service = ScannerService.new()
	visible = true
	if not _owns_pause:
		DayClock.request_pause(DayClock.PAUSE_SCANNER)
		_owns_pause = true
	_clear_content()
	_update_object_label()
	_verdict_section.visible = false
	_confirm_button.disabled = true
	_back_button.text = "Back"
	_run_scan()
	_grab_initial_focus()


## Closes the screen and releases pause ownership exactly once.
func close() -> void:
	if visible:
		visible = false
		_release_pause_if_owned()
	closed.emit()


func _exit_tree() -> void:
	_release_pause_if_owned()


func _release_pause_if_owned() -> void:
	if _owns_pause:
		DayClock.release_pause(DayClock.PAUSE_SCANNER)
		_owns_pause = false


func _build_verdict_buttons() -> void:
	for child in _verdict_buttons.get_children():
		child.queue_free()
	for verdict in VERDICT_BUTTONS.keys():
		var button := Button.new()
		button.text = VERDICT_BUTTONS[verdict]
		button.toggle_mode = true
		button.focus_mode = Control.FOCUS_ALL
		button.pressed.connect(_on_verdict_pressed.bind(verdict))
		button.set_meta("verdict", verdict)
		_verdict_buttons.add_child(button)


func _on_verdict_pressed(verdict: int) -> void:
	_select_verdict(verdict)


func _select_verdict(verdict: int) -> void:
	_selected_verdict = verdict
	_update_verdict_buttons()
	_confirm_button.disabled = false


func _update_verdict_buttons() -> void:
	for child in _verdict_buttons.get_children():
		if child is Button:
			var verdict: int = child.get_meta("verdict")
			child.button_pressed = verdict == _selected_verdict


func _run_scan() -> void:
	_status_label.text = "Scanning..."
	_result = _service.scan(_instance)
	_status_label.text = _status_text(_result.status)
	_populate_response(_result.response)
	if _result.is_ok():
		_verdict_section.visible = true
		_confirm_button.disabled = _selected_verdict == ModelEnums.Verdict.UNKNOWN
	else:
		_verdict_section.visible = false
		_confirm_button.disabled = true


func _status_text(status: int) -> String:
	return STATUS_TEXT.get(status, "Unknown scanner state.")


func _update_object_label() -> void:
	if _instance == null:
		_object_label.text = "Object: ---"
		return
	var template: ScrapObjectTemplate = DataRepository.singleton().get_template(
		_instance.template_id
	)
	var name := template.display_name if template != null else _instance.template_id
	_object_label.text = "Object: %s" % name


func _clear_content() -> void:
	for child in _content.get_children():
		child.queue_free()


func _populate_response(response: ScannerResponse) -> void:
	_clear_content()
	if response == null:
		_add_line("No response.")
		return
	if not response.transport_error.is_empty():
		_add_line(response.transport_error)
		return
	if not response.validation_errors.is_empty():
		for err in response.validation_errors:
			_add_line("Validation: %s" % err)
		return

	_add_field("Suggested type", response.type)
	_add_field("Possible period", response.period)
	_add_list("Detected materials", response.materials)
	_add_list("Visible markings", response.markings)
	_add_field("Condition", response.condition_note)
	_add_field("Cultural context", response.cultural_relevance)
	_add_field(
		"Suggested price range", "P%d – P%d" % [response.price_range_min, response.price_range_max]
	)
	if response.modification_signs.is_empty():
		_add_field("Modification signs", "None noted")
	else:
		_add_list("Modification signs", response.modification_signs)
	_add_field("Confidence", response.confidence.capitalize())
	if not response.uncertainty_notes.is_empty():
		_add_field("Uncertainty", response.uncertainty_notes)
	_add_sources(response.source_references)

	# Visual separator between scanner annotations and player verdict.
	var separator := HSeparator.new()
	_content.add_child(separator)
	var note := Label.new()
	note.text = "— Scanner annotations end here. Your judgment belongs below. —"
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	note.add_theme_font_size_override("font_size", 12)
	_content.add_child(note)


func _add_field(label: String, value: String) -> void:
	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var name_label := Label.new()
	name_label.text = "%s:" % label
	name_label.add_theme_font_size_override("font_size", 16)
	name_label.custom_minimum_size = Vector2(200, 0)
	row.add_child(name_label)
	var value_label := Label.new()
	value_label.text = value
	value_label.add_theme_font_size_override("font_size", 16)
	value_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	value_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(value_label)
	_content.add_child(row)


func _add_list(label: String, items: Array[String]) -> void:
	var text := ", ".join(items) if not items.is_empty() else "None noted"
	_add_field(label, text)


func _add_sources(refs: Array[Dictionary]) -> void:
	if refs.is_empty():
		_add_field("Sources", "None listed")
		return
	var parts: Array[String] = []
	for ref in refs:
		var status: String = ModelUtils.as_string(ref.get("status"))
		var note: String = ModelUtils.as_string(ref.get("note"))
		var title: String = ModelUtils.as_string(ref.get("title"))
		if not title.is_empty():
			parts.append("%s (%s)" % [title, status])
		elif not note.is_empty():
			parts.append("%s (%s)" % [note, status])
		else:
			parts.append("(%s)" % status)
	_add_field("Sources", "; ".join(parts))


func _add_line(text: String) -> void:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.add_child(label)


func _on_confirm() -> void:
	if _committed or _instance == null or _selected_verdict == ModelEnums.Verdict.UNKNOWN:
		return
	if _service.commit_verdict(_instance.uid, _selected_verdict):
		_committed = true
		_confirm_button.disabled = true
		_verdict_hint.text = "Verdict recorded: %s" % VERDICT_BUTTONS[_selected_verdict]
		verdict_committed.emit(_instance.uid, _selected_verdict)
		_back_button.text = "Close"


func _on_back() -> void:
	close()


func get_selected_verdict() -> int:
	return _selected_verdict


func get_confirm_button() -> Button:
	return _confirm_button


func get_status_label() -> Label:
	return _status_label


func get_content() -> VBoxContainer:
	return _content


func get_verdict_section() -> VBoxContainer:
	return _verdict_section


func get_verdict_buttons() -> HBoxContainer:
	return _verdict_buttons


## Test seam to select a verdict without simulating input.
func select_verdict(verdict: int) -> void:
	_select_verdict(verdict)


## Test seam to confirm the current verdict without simulating input.
func confirm_verdict() -> void:
	_on_confirm()


func _grab_initial_focus() -> void:
	if _close_button.visible:
		_close_button.grab_focus()
