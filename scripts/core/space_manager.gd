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

enum Space { SHOP, YARD, MALL, DUMP_SITE, FORBIDDEN_ZONE, ARCHEOLOGIST_HOUSE }

signal space_changed(space: Space)

const SHOP_SCENE := "res://scenes/Shop.tscn"
const YARD_SCENE := "res://scenes/locations/scrapyard/Scrapyard.tscn"
const MALL_SCENE := "res://scenes/locations/mall/Mall.tscn"
const DUMP_SITE_SCENE := "res://scenes/locations/dump_site/dump_site.tscn"
const FORBIDDEN_ZONE_SCENE := "res://scenes/locations/dump_site_forbidden/forbidden_zone.tscn"
const TITLE_SCENE := "res://scenes/ui/title_screen.tscn"
const ARCHEOLOGIST_HOUSE_SCENE := "res://scenes/locations/archeologist_house/archeologist_house.tscn"

## Scene path per space, for the generic go_to() transition.
const SPACE_SCENES := {
	Space.SHOP: SHOP_SCENE,
	Space.YARD: YARD_SCENE,
	Space.MALL: MALL_SCENE,
	Space.DUMP_SITE: DUMP_SITE_SCENE,
	Space.FORBIDDEN_ZONE: FORBIDDEN_ZONE_SCENE,
	Space.ARCHEOLOGIST_HOUSE: ARCHEOLOGIST_HOUSE_SCENE,
}

## Current active gameplay space. The title screen is treated as a pre-space
## launcher, so this defaults to SHOP and stays SHOP while on the title.
var current_space: Space = Space.SHOP

## The space we just came from (set on every go_to transition). Used so scenes
## can decide which spawn point to use (e.g. shop door vs scrapyard gate).
var previous_space: Space = Space.SHOP

## True when the last transition originated on the title screen (previous_space
## defaults to SHOP, so scenes need this to tell a real shop exit apart from a
## fresh session — e.g. Day 0 opens at the yard gate, not the shop door).
var came_from_title: bool = false

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
	# Any gameplay space leaves the title (a fresh save can open in the yard).
	came_from_title = _on_title
	_on_title = false
	previous_space = current_space
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


## Transitions to the dump site. Guarded against duplicate transitions.
func go_to_dump_site() -> void:
	if current_space == Space.DUMP_SITE:
		push_warning("SpaceManager.go_to_dump_site: already in the dump site")
		return
	if not QuestService.is_location_unlocked("dump_site"):
		push_warning("SpaceManager: dump site is not unlocked yet")
		return
	# Dump Site is only open on days 3 and 4.
	var day := DayClock.get_day()
	if day < 3 or day > 4:
		push_warning("SpaceManager: dump site is only open on days 3-4 (today is day %d)" % day)
		return
	go_to(Space.DUMP_SITE)


## Transitions to the forbidden zone. Guarded against duplicate transitions.
func go_to_forbidden_zone() -> void:
	if current_space == Space.FORBIDDEN_ZONE:
		push_warning("SpaceManager.go_to_forbidden_zone: already in the forbidden zone")
		return
	if not QuestService.is_location_unlocked("forbidden_zone"):
		push_warning("SpaceManager: forbidden zone is not unlocked yet")
		return
	go_to(Space.FORBIDDEN_ZONE)


## Transitions to the archeologist house. Guarded against duplicate transitions.
func go_to_archeologist_house() -> void:
	if current_space == Space.ARCHEOLOGIST_HOUSE:
		push_warning("SpaceManager.go_to_archeologist_house: already in the archeologist house")
		return
	if not QuestService.is_location_unlocked("archeologist_house"):
		push_warning("SpaceManager: archeologist house is not unlocked yet")
		return
	go_to(Space.ARCHEOLOGIST_HOUSE)


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
