class_name TutorialGlue
extends CanvasLayer
## Per-scene Day 0 presentation glue (TUT).
##
## The host scene (Shop, Scrapyard, Mall) creates one of these while the
## tutorial is active and hands it named anchor nodes. The glue listens to
## TutorialService.step_changed and presents each step: it auto-plays the
## step's authored dialogue once (own DialogueBox, so it never fights the
## HUD's), then leaves the TutorialHintBox nudge up with its arrow aimed at
## the step's anchor. 3D anchors are re-unprojected every frame so the arrow
## tracks the camera. All narrative content comes from day0_script.json.

const DIALOGUE_BOX_SCENE := preload("res://dialogue/dialogue_box.tscn")
const HINT_BOX_SCENE := preload("res://dialogue/tutorial_hint_box.tscn")

## Layer: above gameplay overlays (restoration etc.), below PauseMenu (128).
const GLUE_LAYER: int = 110

var _space_name: String = ""
var _anchors: Dictionary = {}
var _played_dialogue_step: String = ""
var _anchor_node: Node = null

var _dialogue_box: DialogueBox
var _hint_box: TutorialHintBox


func _ready() -> void:
	layer = GLUE_LAYER
	_dialogue_box = DIALOGUE_BOX_SCENE.instantiate()
	add_child(_dialogue_box)
	_hint_box = HINT_BOX_SCENE.instantiate()
	add_child(_hint_box)
	_dialogue_box.finished.connect(_on_dialogue_finished)
	TutorialService.step_changed.connect(_on_step_changed)
	TutorialService.tutorial_finished.connect(_on_tutorial_finished)
	_present(TutorialService.current_step())


func _exit_tree() -> void:
	if TutorialService.step_changed.is_connected(_on_step_changed):
		TutorialService.step_changed.disconnect(_on_step_changed)
	if TutorialService.tutorial_finished.is_connected(_on_tutorial_finished):
		TutorialService.tutorial_finished.disconnect(_on_tutorial_finished)


## `space_name` is the SpaceManager.Space key this glue lives in ("SHOP"/...).
## `anchors` maps hint anchor names from the script to live nodes (Node3D or
## Control); unknown anchors simply show the hint without an arrow.
func setup(space_name: String, anchors: Dictionary) -> void:
	_space_name = space_name
	_anchors = anchors


func _process(_delta: float) -> void:
	# 3D anchors track the camera; Control anchors are static.
	if _anchor_node is Node3D and _hint_box != null and _hint_box.visible:
		_point_at_node3d(_anchor_node as Node3D)


func _on_step_changed(_step_id: String) -> void:
	_present(TutorialService.current_step())


func _on_tutorial_finished() -> void:
	_hint_box.hide_hint()


func _present(step: Dictionary) -> void:
	_anchor_node = null
	_hint_box.hide_hint()
	if step.is_empty() or not TutorialService.is_tutorial_active():
		return
	if ModelUtils.as_string(step.get("space")) != _space_name:
		return
	var step_id := ModelUtils.as_string(step.get("id"))
	var lines := _dialogue_lines(step)
	if not lines.is_empty() and _played_dialogue_step != step_id:
		_played_dialogue_step = step_id
		_dialogue_box.start(lines)
	else:
		_show_hint(step)


func _on_dialogue_finished() -> void:
	_show_hint(TutorialService.current_step())


func _show_hint(step: Dictionary) -> void:
	var hint := ModelUtils.as_dictionary(step.get("hint"))
	if hint.is_empty() or ModelUtils.as_string(step.get("space")) != _space_name:
		return
	_hint_box.show_hint(
		ModelUtils.as_string(hint.get("speaker"), "yuyu"),
		ModelUtils.as_string(hint.get("text"))
	)
	var anchor_name := ModelUtils.as_string(hint.get("anchor"))
	_anchor_node = _anchors.get(anchor_name) as Node
	if _anchor_node is Control:
		_hint_box.point_at_control(_anchor_node as Control)
	elif _anchor_node is Node3D:
		_point_at_node3d(_anchor_node as Node3D)
	else:
		_hint_box.clear_pointer()


func _point_at_node3d(target: Node3D) -> void:
	var camera := get_viewport().get_camera_3d()
	if camera == null or not target.is_inside_tree():
		_hint_box.clear_pointer()
		return
	var world_pos := target.global_transform.origin
	if camera.is_position_behind(world_pos):
		_hint_box.clear_pointer()
		return
	_hint_box.point_at_screen_pos(camera.unproject_position(world_pos))


## Converts authored {speaker, text} lines into DialogueBox {name, text} lines,
## resolving speaker display names from speakers.json.
func _dialogue_lines(step: Dictionary) -> Array:
	var out: Array = []
	var raw_lines: Variant = step.get("dialogue")
	if not (raw_lines is Array):
		return out
	for raw in raw_lines:
		if not (raw is Dictionary):
			continue
		var speaker_id := ModelUtils.as_string((raw as Dictionary).get("speaker"))
		var text := ModelUtils.as_string((raw as Dictionary).get("text"))
		out.append({"name": TutorialHintBox.speaker_display_name(speaker_id), "text": text})
	return out
