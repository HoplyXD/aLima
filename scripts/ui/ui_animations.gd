extends Node
## Reusable tween presets and ambient effects for the aLima UI redesign.
## Autoload as `UiAnimations` so any UI script can play consistent fade, scale,
## slide, glow, and dust animations without duplicating tween boilerplate.

const DEFAULT_DURATION := 0.25
const EASE := Tween.EASE_OUT
const TRANS := Tween.TRANS_QUAD


## Fade `node` (any CanvasItem) from its current modulate to `target_alpha`.
## If `from_alpha` is >= 0 the modulate is reset first.
static func fade_to(
	node: CanvasItem, target_alpha: float, duration: float = DEFAULT_DURATION
) -> Tween:
	if not is_instance_valid(node):
		return null
	var tween := node.create_tween()
	tween.set_ease(EASE)
	tween.set_trans(TRANS)
	tween.tween_property(node, "modulate:a", target_alpha, duration)
	return tween


## Fade in and optionally scale-pop a panel for pop-up open animations.
static func popup_open(node: Control, duration: float = 0.3, pop: bool = true) -> Tween:
	if not is_instance_valid(node):
		return null
	node.modulate = Color(1.0, 1.0, 1.0, 0.0)
	node.scale = Vector2(0.96, 0.96) if pop else Vector2.ONE
	node.visible = true

	var tween := node.create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_BACK)
	tween.set_parallel(true)
	tween.tween_property(node, "modulate:a", 1.0, duration)
	if pop:
		tween.tween_property(node, "scale", Vector2.ONE, duration)
	return tween


## Fade out and scale down a panel for pop-up close animations.
static func popup_close(node: Control, duration: float = 0.2, hide_on_finish: bool = true) -> Tween:
	if not is_instance_valid(node):
		return null
	var tween := node.create_tween()
	tween.set_ease(Tween.EASE_IN)
	tween.set_trans(TRANS)
	tween.set_parallel(true)
	tween.tween_property(node, "modulate:a", 0.0, duration)
	tween.tween_property(node, "scale", Vector2(0.96, 0.96), duration)
	if hide_on_finish:
		tween.finished.connect(func() -> void: node.visible = false)
	return tween


## Slide `node` in from `direction` ("left", "right", "top", "bottom").
static func slide_in(
	node: Control, direction: StringName = &"bottom", duration: float = 0.35, distance: float = 64.0
) -> Tween:
	if not is_instance_valid(node):
		return null
	var start := node.position
	var offset := Vector2.ZERO
	match direction:
		&"left":
			offset = Vector2(-distance, 0.0)
		&"right":
			offset = Vector2(distance, 0.0)
		&"top":
			offset = Vector2(0.0, -distance)
		&"bottom":
			offset = Vector2(0.0, distance)
	node.position = start + offset
	node.modulate = Color(1.0, 1.0, 1.0, 0.0)
	node.visible = true

	var tween := node.create_tween()
	tween.set_ease(EASE)
	tween.set_trans(TRANS)
	tween.set_parallel(true)
	tween.tween_property(node, "position", start, duration)
	tween.tween_property(node, "modulate:a", 1.0, duration)
	return tween


## Brief golden shimmer over a node for success feedback.
static func success_shimmer(node: CanvasItem, duration: float = 0.35) -> Tween:
	if not is_instance_valid(node):
		return null
	var tween := node.create_tween()
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.set_trans(Tween.TRANS_SINE)
	tween.tween_property(node, "modulate", Color(1.3, 1.2, 0.9, node.modulate.a), duration * 0.4)
	tween.tween_property(node, "modulate", Color(1.0, 1.0, 1.0, node.modulate.a), duration * 0.6)
	return tween


## Muted crimson flash for error/warning feedback.
static func error_flash(node: CanvasItem, duration: float = 0.35) -> Tween:
	if not is_instance_valid(node):
		return null
	var tween := node.create_tween()
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.set_trans(Tween.TRANS_SINE)
	tween.tween_property(node, "modulate", Color(1.2, 0.8, 0.8, node.modulate.a), duration * 0.4)
	tween.tween_property(node, "modulate", Color(1.0, 1.0, 1.0, node.modulate.a), duration * 0.6)
	return tween


## Soft hover glow on a Control by tinting its modulate (use on a texture/icon node).
static func hover_glow(node: CanvasItem, enabled: bool, intensity: float = 1.15) -> Tween:
	if not is_instance_valid(node):
		return null
	var tween := node.create_tween()
	tween.set_ease(EASE)
	tween.set_trans(TRANS)
	var target := (
		Color(intensity, intensity, intensity, node.modulate.a)
		if enabled
		else Color(1.0, 1.0, 1.0, node.modulate.a)
	)
	tween.tween_property(node, "modulate", target, 0.15)
	return tween


## Press a button down by slightly offsetting and darkening it.
static func press_depth(node: Control, pressed: bool) -> Tween:
	if not is_instance_valid(node):
		return null
	var tween := node.create_tween()
	tween.set_ease(EASE)
	tween.set_trans(TRANS)
	tween.set_parallel(true)
	if pressed:
		tween.tween_property(node, "position:y", 2.0, 0.08)
		tween.tween_property(node, "modulate", Color(0.9, 0.9, 0.9, node.modulate.a), 0.08)
	else:
		tween.tween_property(node, "position:y", 0.0, 0.12)
		tween.tween_property(node, "modulate", Color(1.0, 1.0, 1.0, node.modulate.a), 0.12)
	return tween


## Gentle bobbing animation for continue indicators / pointers.
static func bob(node: Control, distance: float = 6.0, duration: float = 1.2) -> Tween:
	if not is_instance_valid(node):
		return null
	var base := node.position
	var tween := node.create_tween()
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_loops()
	tween.tween_property(node, "position:y", base.y + distance, duration * 0.5)
	tween.tween_property(node, "position:y", base.y, duration * 0.5)
	return tween


## Add a subtle dust-mote particle overlay to a panel.
## Returns the created CPUParticles2D node so the caller can cache it.
static func add_dust_particles(parent: Control, count: int = 24) -> CPUParticles2D:
	if not is_instance_valid(parent):
		return null
	var particles := CPUParticles2D.new()
	particles.name = "DustParticles"
	particles.emitting = true
	particles.amount = count
	particles.lifetime = 6.0
	particles.preprocess = 3.0
	particles.explosiveness = 0.0
	particles.randomness = 1.0
	particles.local_coords = false
	particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	particles.emission_rect_extents = Vector2(960.0, 540.0)
	particles.direction = Vector2(0.0, -1.0)
	particles.spread = 30.0
	particles.gravity = Vector2.ZERO
	particles.initial_velocity_min = 4.0
	particles.initial_velocity_max = 12.0
	particles.angular_velocity_min = -20.0
	particles.angular_velocity_max = 20.0
	particles.scale_amount_min = 0.5
	particles.scale_amount_max = 1.5
	particles.color = Color(0.9, 0.82, 0.64, 0.12)
	particles.position = parent.size * 0.5
	# Keep particles centered when the parent control resizes.
	parent.resized.connect(func() -> void: particles.position = parent.size * 0.5)
	parent.add_child(particles)
	return particles


## Stop and free dust particles created by `add_dust_particles`.
static func remove_dust_particles(parent: Control) -> void:
	if not is_instance_valid(parent):
		return
	var particles := parent.get_node_or_null("DustParticles")
	if particles is CPUParticles2D:
		particles.emitting = false
		particles.finished.connect(particles.queue_free)
