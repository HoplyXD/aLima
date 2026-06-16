extends Node
## Global event bus for cross-system communication.
##
## EventBus exposes the Stable Interfaces signals defined in docs/phase-task.md.
## Systems emit and connect here rather than holding hard references. This
## autoload does not manipulate scene nodes directly.

# --- Clock and loop events ---
signal hour_changed(day: int, hour: int)
signal day_changed(day: int)
signal loop_reset(loop_index: int)
signal clock_pause_changed(is_paused: bool, owner_id: String)

# --- Delivery and triage events ---
signal delivery_generated(day: int, instance_ids: Array[String])
signal triage_completed(kept_ids: Array[String], recycled_ids: Array[String])

# --- Restoration and opening events ---
signal restoration_completed(instance_id: String, condition: float, tool_id: String)
signal object_opened(instance_id: String, result: String, content_id: String)

# --- Scanner events ---
signal scanner_response_received(instance_id: String, status: String)
signal scanner_verdict_committed(instance_id: String, verdict: String)

# --- Discovery events ---
signal carrier_activated(instance_id: String, fragment_id: String)
signal echo_proximity_changed(instance_id: String, proximity: float, band: String)
signal fragment_discovered(fragment_id: String, instance_id: String)
signal portal_completed(
	fragment_id: String, museum_entry_id: String, used_fallback: bool, fact_card: String
)
signal fragment_seated(fragment_id: String, slot_index: int)


func _ready() -> void:
	pass
