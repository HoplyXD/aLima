class_name ArtifactFoundScreen
extends Control
## UI shown when a fragment is discovered inside a carrier.

signal continue_pressed
signal closed

var _fragment_id: String = ""

@onready var _title_label: Label = %TitleLabel
@onready var _name_label: Label = %NameLabel
@onready var _origin_label: Label = %OriginLabel
@onready var _condition_label: Label = %ConditionLabel
@onready var _progress_label: Label = %ProgressLabel
@onready var _continue_button: Button = %ContinueButton
@onready var _loading_label: Label = %LoadingLabel
@onready var _error_label: Label = %ErrorLabel


func _ready() -> void:
	_show_loading(false)
	_error_label.visible = false
	if _continue_button != null:
		_continue_button.pressed.connect(_on_continue)


func present(fragment: Fragment, instance: ObjectInstance) -> void:
	_fragment_id = fragment.id if fragment != null else ""
	var fragment_name := "Unknown Fragment"
	var origin := "Unknown origin"
	var condition := 0
	var seated_count := 0
	var total := 5

	if fragment != null:
		fragment_name = _fragment_display_name(fragment)
		origin = (
			fragment.owning_character_id.capitalize()
			if not fragment.owning_character_id.is_empty()
			else origin
		)

	if instance != null:
		condition = int(instance.condition)

	seated_count = _count_seated_fragments()

	if _title_label != null:
		_title_label.text = "Artifact Found"
	if _name_label != null:
		_name_label.text = fragment_name
	if _origin_label != null:
		_origin_label.text = "Origin: %s" % origin
	if _condition_label != null:
		_condition_label.text = "Condition: %d%%" % condition
	if _progress_label != null:
		_progress_label.text = "Fragments: %d / %d" % [seated_count, total]


func show_loading(is_loading: bool) -> void:
	_show_loading(is_loading)


func show_error(message: String) -> void:
	if _error_label != null:
		_error_label.text = message
		_error_label.visible = true


func _on_continue() -> void:
	continue_pressed.emit()


func _show_loading(is_loading: bool) -> void:
	if _loading_label != null:
		_loading_label.visible = is_loading
	if _continue_button != null:
		_continue_button.disabled = is_loading


func _fragment_display_name(fragment: Fragment) -> String:
	var repo := DataRepository.singleton()
	var artifact: MasterArtifact = repo.get_master_artifact(fragment.master_artifact_id)
	if artifact != null:
		return "%s Fragment %d" % [artifact.display_name, fragment.case_slot_index + 1]
	return "Fragment %d" % (fragment.case_slot_index + 1)


func _count_seated_fragments() -> int:
	var count := 0
	for fragment_id in GameState.save_state.persistent.fragments:
		var fragment: Fragment = GameState.save_state.persistent.fragments[fragment_id]
		if fragment.state == ModelEnums.FragmentState.SEATED:
			count += 1
	return count


func _on_close_requested() -> void:
	closed.emit()
