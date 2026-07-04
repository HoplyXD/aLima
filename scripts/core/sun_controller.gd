class_name SunController
extends Node
## Drives a scene's DirectionalLight3D so the sun follows the in-game clock: low and
## warm at 7:00, high and white around noon, sinking gold-red toward 20:00.
##
## Day 0 (TUT) is clockless, so the sun is SCRIPTED by tutorial step instead:
##   * sunrise — from the intro until the artifact is cleaned,
##   * noon    — from the scan/sell lesson through the mall delivery,
##   * sunset  — once the player heads home (return_to_shop and later).
## On Day 1+ it simply tracks DayClock hours via EventBus.hour_changed.
##
## Attach from code (SunController.attach(host, light)) so no scene edits are needed;
## the host scene keeps its authored light as the fallback look when no light exists.

## Tutorial steps -> scripted phase t (0 = dawn, 0.5 = noon, 1 = dusk).
const DAY0_PHASES := {
	"intro_greeting": 0.06,
	"head_inside": 0.06,
	"triage_delivery": 0.08,
	"restoration_intro": 0.10,
	"restore_artifact": 0.12,
	"scan_artifact": 0.50,
	"list_and_sell": 0.50,
	"ride_to_mall": 0.52,
	"board_tricycle": 0.52,
	"deliver_to_buyer": 0.55,
	"return_to_shop": 0.92,
	"enter_the_shop": 0.94,
	"journal_finale": 0.96,
}

## The shop day runs 07:00-20:00; the sun tracks that window.
const DAY_START_HOUR := 7.0
const DAY_END_HOUR := 20.0

var _light: DirectionalLight3D


## Adds a SunController under `host` driving `light`. Returns null (and changes
## nothing) when the light is missing, so callers can pass get_node_or_null results.
static func attach(host: Node, light: DirectionalLight3D) -> SunController:
	if host == null or light == null:
		return null
	var sun := SunController.new()
	sun.name = "SunController"
	sun._light = light
	host.add_child(sun)
	return sun


func _ready() -> void:
	if not EventBus.hour_changed.is_connected(_on_hour_changed):
		EventBus.hour_changed.connect(_on_hour_changed)
	if (
		TutorialService.is_tutorial_active()
		and not TutorialService.step_changed.is_connected(_on_step_changed)
	):
		TutorialService.step_changed.connect(_on_step_changed)
	apply_now()


func _exit_tree() -> void:
	if EventBus.hour_changed.is_connected(_on_hour_changed):
		EventBus.hour_changed.disconnect(_on_hour_changed)
	if TutorialService.step_changed.is_connected(_on_step_changed):
		TutorialService.step_changed.disconnect(_on_step_changed)


func _on_hour_changed(_day: int, _hour: int) -> void:
	apply_now()


func _on_step_changed(_step_id: String) -> void:
	apply_now()


## Recomputes and applies the sun for the current clock (or Day 0 phase).
func apply_now() -> void:
	apply_phase(current_phase())


## Where the sun is in its arc right now: Day 0 reads the scripted step phase,
## normal days map the clock hour across the 07:00-20:00 shop day.
func current_phase() -> float:
	if TutorialService.is_tutorial_active():
		return float(DAY0_PHASES.get(TutorialService.current_step_id(), 0.06))
	var hour := float(DayClock.get_hour())
	return clampf((hour - DAY_START_HOUR) / (DAY_END_HOUR - DAY_START_HOUR), 0.0, 1.0)


## Positions/colours the light for phase `t` (0 dawn .. 0.5 noon .. 1 dusk).
func apply_phase(t: float) -> void:
	if _light == null or not is_instance_valid(_light):
		return
	t = clampf(t, 0.0, 1.0)
	# Arc: low at the edges, high at noon; the sun sweeps east -> west in yaw.
	var elevation := lerpf(12.0, 62.0, sin(t * PI))
	var yaw := lerpf(-70.0, 70.0, t)
	_light.rotation_degrees = Vector3(-elevation, yaw, 0.0)
	_light.light_color = _phase_color(t)
	# Dimmer at dawn/dusk, brightest at noon (keeps each scene's authored peak energy).
	_light.light_energy = lerpf(1.2, 3.0, sin(t * PI))


## Warm sunrise -> white noon -> gold -> red-orange sunset.
func _phase_color(t: float) -> Color:
	var stops: Array = [
		[0.00, Color(1.0, 0.62, 0.38)],
		[0.20, Color(1.0, 0.88, 0.72)],
		[0.50, Color(1.0, 0.97, 0.88)],
		[0.80, Color(1.0, 0.82, 0.55)],
		[1.00, Color(0.98, 0.52, 0.32)],
	]
	for i in range(1, stops.size()):
		var prev: Array = stops[i - 1]
		var next: Array = stops[i]
		if t <= float(next[0]):
			var span := float(next[0]) - float(prev[0])
			var f := 0.0 if span <= 0.0 else (t - float(prev[0])) / span
			return (prev[1] as Color).lerp(next[1] as Color, f)
	return stops[-1][1]
