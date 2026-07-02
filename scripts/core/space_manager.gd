extends Node
## Headless-testable owner of the two-space shell transition state machine.
##
## The game presents two connected spaces: the seated shop interior and the
## walkable outdoor scrapyard. Only one space is loaded at a time; the inactive
## space is fully unloaded by `get_tree().change_scene_to_file`. The actual
## loader is behind a Callable seam so GUT can exercise the state machine without
## triggering real scene loads.
##
## The day clock is intentionally untouched by a transition: it keeps advancing
## in whichever space is active. Returning to the title screen is the only path
## that resets the clock.

enum Space { SHOP, YARD, MALL }

signal space_changed(space: Space)

const SHOP_SCENE := "res://scenes/Shop.tscn"
const YARD_SCENE := "res://scenes/scrapyard/Scrapyard.tscn"
const MALL_SCENE := "res://scenes/mall/Mall.tscn"
const TITLE_SCENE := "res://scenes/ui/title_screen.tscn"

## Scene path per space, for the generic go_to() transition.
const SPACE_SCENES := {
	Space.SHOP: SHOP_SCENE,
	Space.YARD: YARD_SCENE,
	Space.MALL: MALL_SCENE,
}

## Current active gameplay space. The title screen is treated as a pre-space
## launcher, so this defaults to SHOP and stays SHOP while on the title.
var current_space: Space = Space.SHOP

## True while the title screen is showing. Reset on the first shop entry.
var _on_title: bool = true

## Injectable scene loader. Production uses `get_tree().change_scene_to_file`;
## tests replace this with a recording stub.
var _loader: Callable = _default_load_scene


## Generic space transition (travel system). Guarded against duplicate
## transitions; the clock keeps running across every gameplay transition.
func go_to(space: Space) -> void:
	if space == current_space and not (space == Space.SHOP and _on_title):
		push_warning(
			"SpaceManager.go_to: already in %s" % str(Space.keys()[space]).to_lower()
		)
		return
	if space == Space.SHOP:
		_on_title = false
	current_space = space
	_load(SPACE_SCENES[space])
	space_changed.emit(current_space)


## Transitions to the seated shop. From the title screen this begins the live
## session; from the yard it returns without resetting the clock.
func go_to_shop() -> void:
	if current_space == Space.SHOP and not _on_title:
		push_warning("SpaceManager.go_to_shop: already in the shop")
		return
	go_to(Space.SHOP)


## Transitions to the walkable scrapyard. Guarded against duplicate transitions.
func go_to_yard() -> void:
	if current_space == Space.YARD:
		push_warning("SpaceManager.go_to_yard: already in the yard")
		return
	go_to(Space.YARD)


## Returns to the title screen and resets the running day clock. This is the
## only transition that intentionally stops/resets time.
func return_to_title() -> void:
	_on_title = true
	DayClock.reset()
	_load(TITLE_SCENE)


## Test seam: redirect scene loads to a recording Callable.
func set_loader(loader: Callable) -> void:
	_loader = loader


func _default_load_scene(path: String) -> void:
	get_tree().change_scene_to_file(path)


func _load(path: String) -> void:
	_loader.call(path)
