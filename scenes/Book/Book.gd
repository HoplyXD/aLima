class_name JournalBook
extends Node3D

## The 3D journal book. It has two independent states:
##
##   * presented / stowed — where the book sits. Presented = centered in front of
##     the camera; stowed = parked off to the side near the journal button. The
##     Shop's Journal button toggles this; the page it was last reading is kept, so
##     stowing and re-presenting returns to the same spread.
##   * closed / open — closed shows the book shut: the front cover on the right
##     page, the back cover on the left. Clicking flips the front cover over (the
##     page-turn animation) to reveal the first two-page spread. Once open, clicks
##     on the left/right page turn spreads.
##
## Presentation only: this node owns no game state and talks to the Shop through
## the `presented_changed` signal so the HUD can hide the shop's action buttons
## while the journal is being read.

signal presented_changed(presented: bool)  ## Emitted when the book moves to/from center.
signal opened  ## Emitted the first time the cover is opened into the spread.

const FRONT_COVER_FALLBACK := Color(0.36, 0.24, 0.16)
const BACK_COVER_FALLBACK := Color(0.30, 0.20, 0.13)

## The journal front-cover image, shown on the right page while the book is closed
## and as the face that flips open. Leave unset for a plain placeholder colour.
@export var cover_texture: Texture2D

## The journal back-cover image, shown on the left page while the book is closed.
## Leave unset for a plain placeholder colour.
@export var back_cover_texture: Texture2D

## When true the book starts centered in front of the camera; otherwise it starts
## stowed to the side and is brought in by the Journal button. Defaults true so the
## scene is usable on its own; the Shop overrides this to false so its journal
## starts parked and the Journal button presents it.
@export var start_presented: bool = true

## Offset (in the book's parent space) applied to the authored transform to reach
## the stowed position — pushed fully off the left of the screen while the journal
## isn't being viewed. Tune in the inspector for your camera/framing.
@export var stow_offset: Vector3 = Vector3(-5.0, 0.0, 0.0)

## Extra rotation (degrees) applied while stowed, so the parked book sits at a
## slight, readable angle rather than flat-on.
@export var stow_rotation_deg: Vector3 = Vector3(0.0, 20.0, 0.0)

## Offset applied to the presented transform while the book is still closed, so the
## single front-cover (right) page reads as centered; opening slides it back so the
## spine is centered for the spread. Tune in the inspector to taste.
@export var closed_offset: Vector3 = Vector3(-0.5, 0.0, 0.0)

## Seconds for the present/stow glide.
@export var move_duration: float = 0.45

## Total pages in the journal. The book stops turning forward once the last spread
## (max_pages - 1, max_pages) is showing.
@export var max_pages: int = 20

# The current page is the one on the left
var current_page_number = 1

var _presented: bool = false
var _closing: bool = false  ## True while a cover-close (TurnBack) flip is animating.
var _presented_xform: Transform3D
var _stowed_xform: Transform3D
var _move_tween: Tween

# This is displayed when pages are not moving
@onready var static_page = $Book/Static
# This is displayed when pages are moving
@onready var turning_page = $Book/Turning
@onready var turning_animation = $Book/Turning/AnimationPlayer

# Invisible body that catches 3D clicks to present / open the book.
@onready var click_body: StaticBody3D = $ClickBody

# Pages when turning: left, animated side 1, animated side 2, right
@onready var pf1 = $Book/Turning/PageLeft
@onready var pf2 = $Book/Turning/Page/Skeleton3D/Front
@onready var pf3 = $Book/Turning/Page/Skeleton3D/Back
@onready var pf4 = $Book/Turning/PageRight

# Pages when static: left, right
@onready var ps1 = $Book/Static/PageLeft
@onready var ps2 = $Book/Static/PageRight

# There are 6 viewports. Current page (left) is v3, to its right is v4.
# Moreover, there are 2 pages before (v1, v2) and after (v5, v6)
@onready var v1 = $Viewport1
@onready var v2 = $Viewport2
@onready var v3 = $Viewport3
@onready var v4 = $Viewport4
@onready var v5 = $Viewport5
@onready var v6 = $Viewport6

@onready var sfx: AudioStreamPlayer2D = $AudioStreamPlayer2D
@onready var animation_player: AnimationPlayer = $Book/Turning/AnimationPlayer


func _ready():
	# Capture the authored placement as the presented (centered) transform, then
	# derive the stowed transform from it.
	_presented_xform = transform
	_stowed_xform = _build_stowed_xform(_presented_xform)

	update_page_number()

	# Start closed (current_page_number == 1): only the front cover shows, on the
	# right page, with the left meshes hidden.
	_show_front_cover()

	# Snap to the starting position without a glide.
	_presented = start_presented
	transform = _current_target()

	animation_player.animation_finished.connect(_on_animation_finished)
	click_body.input_event.connect(_on_click_body_input_event)
	EventBus.fragment_seated.connect(_on_fragment_seated)


func _build_stowed_xform(presented: Transform3D) -> Transform3D:
	var stowed := presented
	stowed.origin += stow_offset
	stowed.basis = (
		stowed.basis
		* Basis.from_euler(
			Vector3(
				deg_to_rad(stow_rotation_deg.x),
				deg_to_rad(stow_rotation_deg.y),
				deg_to_rad(stow_rotation_deg.z)
			)
		)
	)
	return stowed


# --- Present / stow ---------------------------------------------------------


func is_presented() -> bool:
	return _presented


## Brings the book to / from the centered reading position. Driven by the Journal
## button; preserves the page that was last open.
func toggle_presented() -> void:
	if _presented:
		stow()
	else:
		present()


func present() -> void:
	if _presented:
		return
	_presented = true
	_move_to(_current_target())
	presented_changed.emit(true)


func stow() -> void:
	if not _presented:
		return
	_presented = false
	_move_to(_current_target())
	presented_changed.emit(false)


## Where the book should sit right now, given its present/stow and open/closed
## state: stowed -> parked far left; presented + closed -> shifted so the front
## cover (right page) reads centered; presented + open -> spine centered.
func _current_target() -> Transform3D:
	if not _presented:
		return _stowed_xform
	if current_page_number <= 1:
		var t := _presented_xform
		t.origin += closed_offset
		return t
	return _presented_xform


func _move_to(target: Transform3D) -> void:
	if _move_tween != null and _move_tween.is_valid():
		_move_tween.kill()
	_move_tween = create_tween()
	_move_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_move_tween.tween_property(self, "transform", target, move_duration)


# --- Cover / open -----------------------------------------------------------


## True once the cover is open onto the paper spread (page 3+).
func is_open() -> bool:
	return current_page_number > 1


## Opens the book from the closed cover — same as turning the cover page forward.
func open_book() -> void:
	if current_page_number <= 1:
		turn_right()


## Front-cover visuals: front cover on the right (turning) page, back cover on its
## reverse, and every left/spare mesh hidden so only the single cover reads.
func _apply_cover_visuals() -> void:
	pf2.material_override = _make_cover_material(cover_texture, FRONT_COVER_FALLBACK)
	# The cover's reverse is the brown inside (page 3), revealed as it flips open.
	pf3.material_override = _make_cover_material(null, FRONT_COVER_FALLBACK)
	pf1.hide()
	pf4.hide()
	ps1.hide()
	ps2.hide()
	static_page.hide()
	turning_page.show()


## Closed book at spawn: cover visuals plus the page sat flat on the right
## (TurnBack's end pose), applied instantly.
func _show_front_cover() -> void:
	_apply_cover_visuals()
	turning_animation.play("TurnBack")
	turning_animation.seek(turning_animation.current_animation_length, true)


## Binds the static spread to the live page viewports. Page 3 renders brown from
## its own texture (see Page.gd), so the inside cover stays brown without any mesh
## override — including while a page is mid-turn.
func _refresh_paper_spread() -> void:
	set_texture(ps1, v3)
	set_texture(ps2, v4)
	ps1.show()
	ps2.show()


func _make_cover_material(tex: Texture2D, fallback: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	if tex != null:
		mat.albedo_texture = tex
	else:
		mat.albedo_color = fallback
	return mat


# --- 3D click ----------------------------------------------------------------


func _on_click_body_input_event(
	_camera: Node, event: InputEvent, pos: Vector3, _normal: Vector3, _shape_idx: int
) -> void:
	if not (event is InputEventMouseButton):
		return
	var mb := event as InputEventMouseButton
	if mb.button_index != MOUSE_BUTTON_LEFT or not mb.pressed:
		return
	# A parked book comes in first. Once presented, clicking the right page goes
	# forward (opening the cover from closed); the left page goes back (closing it).
	if not _presented:
		present()
		return
	if turning_animation.is_playing():
		return
	if to_local(pos).x < 0.0:
		turn_left()
	else:
		turn_right()


## Turns the page on the clicked side. Called by the journal viewport, which does
## its own ray-pick against the book and passes the hit's book-local x. (The book
## is always presented inside the viewport, so there is no stow/present here.)
func click_at_local_x(local_x: float) -> void:
	if turning_animation.is_playing():
		return
	if local_x < 0.0:
		turn_left()
	else:
		turn_right()


func turn_right():
	# Stop at the last spread: current_page_number is the left page, +1 is the right.
	if current_page_number + 1 >= max_pages:
		return
	if current_page_number <= 1:
		_open_cover()
		return

	set_texture(pf1, v3)
	set_texture(pf2, v4)
	set_texture(pf3, v5)
	set_texture(pf4, v6)
	# Show the pages (esp. the revealed right page) up front, not mid-animation.
	pf1.show()
	pf4.show()
	static_page.hide()
	turning_page.show()
	turning_animation.play("Turn1")
	sfx.play()


func turn_left():
	if current_page_number <= 1:
		return
	if current_page_number <= 3:
		_close_cover()
		return

	set_texture(pf1, v1)
	set_texture(pf2, v2)
	set_texture(pf3, v3)
	set_texture(pf4, v4)
	pf1.show()
	pf4.show()
	turning_page.show()
	static_page.hide()
	turning_animation.play("Turn2")
	sfx.play()


## Cover open: flip the front cover from the right over to the left (TurnForward),
## landing on paper pages 3 & 4. The right page (4) is shown before the flip; the
## left page (3) is only revealed once the flip lands (see _on_animation_finished).
func _open_cover() -> void:
	update_page_number(2)  # cover (1) -> first paper spread (3)
	set_texture(pf4, v4)  # destination right page, visible behind the flipping cover
	pf4.show()
	pf1.hide()  # left stays hidden during the flip
	ps1.hide()
	ps2.hide()
	pf2.material_override = _make_cover_material(cover_texture, FRONT_COVER_FALLBACK)
	pf3.material_override = _make_cover_material(null, FRONT_COVER_FALLBACK)  # inside cover (brown)
	static_page.hide()
	turning_page.show()
	turning_animation.play("TurnForward")
	sfx.play()
	_move_to(_current_target())  # spine-centered for the open spread
	opened.emit()


## Cover close: flip the front cover back from the left to the right (TurnBack),
## returning to the single front-cover page.
func _close_cover() -> void:
	update_page_number(-2)  # first paper spread (3) -> cover (1)
	pf2.material_override = _make_cover_material(cover_texture, FRONT_COVER_FALLBACK)
	# The cover's back is the brown inside cover (page 3) — reset it so the close
	# flip doesn't show a stale paper texture left over from the last page turn.
	pf3.material_override = _make_cover_material(null, FRONT_COVER_FALLBACK)
	pf1.hide()
	ps1.hide()
	ps2.hide()
	static_page.hide()
	turning_page.show()
	_closing = true
	turning_animation.play("TurnBack")
	sfx.play()
	_move_to(_current_target())  # back to cover-centered


func update_page_number(page_offset = 0):
	"""Changes current page's number by the offset and updates the viewports."""
	current_page_number += page_offset
	var number_offset = -2
	for v in [v1, v2, v3, v4, v5, v6]:
		v.get_node("Page").set_number(current_page_number + number_offset)
		number_offset += 1


func set_texture(page, viewport):
	"""Binds a page mesh to its viewport texture, unshaded so paper matches the
	covers' lighting. The inside cover (page 3) is drawn as solid brown instead —
	the same material as the front cover — so it reads identically and never
	flickers to paper mid-turn."""
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	if viewport.get_node("Page").number == 3:
		mat.albedo_color = FRONT_COVER_FALLBACK
	else:
		mat.albedo_texture = viewport.get_texture()
	page.material_override = mat


## Re-renders every paper page from current GameState. Called when the book is
## opened and whenever a fragment is seated, so the case and entries stay current.
func refresh_content() -> void:
	_update_max_pages()
	for v in [v1, v2, v3, v4, v5, v6]:
		var page: Page = v.get_node("Page") as Page
		if page != null:
			page.set_number(page.number)


func _update_max_pages() -> void:
	var entry_count: int = Page.entry_page_count()
	# Page 4 = case, pages 5 & 6 = condition guide, page 7 = index, pages 8+ = entries.
	var needed: int = maxi(20, 7 + entry_count)
	max_pages = maxi(max_pages, needed)


func _on_fragment_seated(_fragment_id: String, _slot_index: int) -> void:
	refresh_content()


func _on_animation_finished(anim_name):
	if anim_name == "TurnForward":
		# Cover opened: now reveal the left paper page and show the spread.
		pf1.show()
		_refresh_paper_spread()
		static_page.show()
		turning_page.hide()
		return
	if anim_name == "TurnBack":
		if _closing:
			# Cover-close flip landed: settle back to the single front-cover page.
			_closing = false
			_apply_cover_visuals()
		# Otherwise this is the instant spawn-priming pose — leave it as-is.
		return
	if anim_name == "Turn1":
		update_page_number(2)
	if anim_name == "Turn2":
		update_page_number(-2)
	_refresh_paper_spread()
	static_page.show()
	turning_page.hide()
