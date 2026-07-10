extends SceneTree

var _frame := 0
var _hud: ScrapyardHud


func _process(_delta: float) -> bool:
	_frame += 1
	if _frame == 1:
		_hud = load("res://scenes/ui/scrapyard_hud.tscn").instantiate() as ScrapyardHud
		root.add_child(_hud)
		return false
	if _frame == 3:
		_dump("BEFORE")
		_hud.set_prompt("Press E to grab scrap")
		return false
	if _frame == 4:
		_dump("AFTER")
		quit()
	return false


func _dump(tag: String) -> void:
	var lbl: Label = _hud.get_node("PromptLabel")
	var hot: Control = _hud.get_node("Hotbar")
	var panel: Control = _hud.get_node_or_null("PromptPanel")
	print("---- ", tag, " viewport=", root.size)
	print("child_order=", _hud.get_children().map(func(c: Node) -> String: return c.name))
	print("label.visible=", lbl.visible, " text='", lbl.text, "' rect=", lbl.get_global_rect())
	print("panel rect=", panel.get_global_rect() if panel != null else "null")
	print("hotbar rect=", hot.get_global_rect())
	print("label intersects hotbar=", lbl.get_global_rect().intersects(hot.get_global_rect()))
	var n: Node = lbl
	while n != null:
		var vis := "n/a"
		if n is CanvasItem:
			vis = str((n as CanvasItem).visible)
		print("  ancestor ", n.name, " visible=", vis)
		n = n.get_parent()
