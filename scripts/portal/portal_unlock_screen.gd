class_name PortalUnlockScreen
extends Control
## UI shown after the backend returns a Portal discovery result.

signal closed

@onready var _title_label: Label = %TitleLabel
@onready var _fact_label: Label = %FactLabel
@onready var _entry_id_label: Label = %EntryIdLabel
@onready var _fallback_label: Label = %FallbackLabel
@onready var _continue_button: Button = %ContinueButton


func _ready() -> void:
	if _fallback_label != null:
		_fallback_label.visible = false
	if _continue_button != null:
		_continue_button.pressed.connect(_on_continue)


func present(response: PortalDiscoveryResponse) -> void:
	if response == null:
		return

	var artifact_name := "Unknown Artifact"
	if response.artifact_meta.has("name"):
		artifact_name = str(response.artifact_meta.get("name"))

	if _title_label != null:
		_title_label.text = "Portal Unlock: %s" % artifact_name
	if _fact_label != null:
		_fact_label.text = response.fact_card
	if _entry_id_label != null:
		_entry_id_label.text = "Museum Entry: %s" % response.museum_entry_id
	if _fallback_label != null:
		_fallback_label.visible = response.used_fallback


func _on_continue() -> void:
	closed.emit()
