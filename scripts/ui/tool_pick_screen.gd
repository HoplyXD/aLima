class_name ToolPickScreen
extends CanvasLayer
## v3 artisan reward (story.md §16): after each of Nong Lave's quests the player
## PICKS ONE of three random tools to keep. Presentation only — built in code
## like the ShowcaseScreen; granting goes through ToolService so durability
## instances and the bench loadout behave exactly like bought tools.

signal closed(picked_tool_id: String)

const CHOICES: int = 3

var _owns_pause: bool = false
var _picked: String = ""

var _title_label: Label
var _buttons_box: VBoxContainer


func _ready() -> void:
	layer = 82  # above the shop/yard HUD, below the pause menu
	visible = false
	_build_ui()


## Rolls three distinct random tools (never debug-only) and shows the choice.
func open() -> void:
	var repo := DataRepository.singleton()
	var pool: Array[String] = []
	for tool_id in repo.tool_definitions.keys():
		var def: ToolDefinition = repo.tool_definitions[tool_id]
		if def == null or def.debug_only:
			continue
		pool.append(tool_id)
	pool.shuffle()
	var offers := pool.slice(0, mini(CHOICES, pool.size()))

	for child in _buttons_box.get_children():
		child.queue_free()
	for tool_id in offers:
		var def: ToolDefinition = repo.tool_definitions[tool_id]
		var button := Button.new()
		button.custom_minimum_size = Vector2(0, 56)
		button.focus_mode = Control.FOCUS_ALL
		var uses := "∞ uses" if def.durability <= 0 else "%d uses" % def.durability
		button.text = "%s  ·  %s" % [def.display_name, uses]
		button.pressed.connect(_on_pick.bind(tool_id))
		_buttons_box.add_child(button)

	_picked = ""
	visible = true
	if not _owns_pause:
		DayClock.request_pause(DayClock.PAUSE_DIALOGUE)
		_owns_pause = true
	if _buttons_box.get_child_count() > 0:
		(_buttons_box.get_child(0) as Button).grab_focus()


func is_open() -> bool:
	return visible


## Grants the chosen tool and closes. Public seam for the GUT tests.
func pick(tool_id: String) -> void:
	_on_pick(tool_id)


func _on_pick(tool_id: String) -> void:
	if not visible:
		return
	_picked = tool_id
	var tools := ToolService.new()
	tools.grant_tool(tool_id)
	close()


func close() -> void:
	if visible:
		visible = false
		if _owns_pause:
			if DayClock.has_pause_owner(DayClock.PAUSE_DIALOGUE):
				DayClock.release_pause(DayClock.PAUSE_DIALOGUE)
			_owns_pause = false
	closed.emit(_picked)


func _exit_tree() -> void:
	if _owns_pause and DayClock.has_pause_owner(DayClock.PAUSE_DIALOGUE):
		DayClock.release_pause(DayClock.PAUSE_DIALOGUE)


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
	panel.custom_minimum_size = Vector2(560, 340)
	center.add_child(panel)

	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_%s" % side, 28)
	panel.add_child(margin)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 16)
	margin.add_child(col)

	_title_label = Label.new()
	_title_label.text = "Nong Lave opens his tool roll — take one."
	_title_label.add_theme_font_size_override("font_size", 24)
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(_title_label)

	_buttons_box = VBoxContainer.new()
	_buttons_box.add_theme_constant_override("separation", 10)
	_buttons_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(_buttons_box)
