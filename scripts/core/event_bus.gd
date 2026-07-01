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

# --- Route / story events ---
signal route_completed(route_id: String)
## Emitted when an authored route beat (e.g. an Auntie showcase step) is completed.
signal route_beat_completed(route_id: String, beat_id: String)
## Emitted the moment a fragment transitions LOCKED -> RELEASED (a route was helped,
## or a debug override fired). The Spawn Director places it; it is never handed over.
signal fragment_released(fragment_id: String)
## Emitted when a scheduled visitor's valid window closes without the player
## answering the door (the visit is consumed). owner is the route id.
signal visit_missed(route_id: String, day: int)

# --- Delivery and triage events ---
signal delivery_generated(day: int, instance_ids: Array[String])
signal triage_completed(kept_ids: Array[String], recycled_ids: Array[String])

# --- Restoration and opening events ---
signal restoration_completed(instance_id: String, condition: float, tool_id: String)
signal object_opened(instance_id: String, result: String, content_id: String)

# --- Tool economy events ---
signal tool_broke(tool_id: String, uid: String)
signal tool_purchased(tool_id: String, arrival_index: int)
signal tool_arrived(tool_id: String, uid: String)

# --- Marketplace / disposition events ---
signal sale_completed(instance_id: String, buyer_id: String, price: int)
## Emitted by the DispositionRouter when an eligible restored+judged instance is
## routed to a final disposition (SELL/RETURN/PRESERVE/JOURNAL). outcome_id is the
## disposition-specific result reference (buyer_id, reward_id, museum_entry_id, or
## journal template id). Idempotent: a given instance disposes at most once.
signal disposition_completed(instance_id: String, disposition: String, outcome_id: String)
## Emitted when an object is returned to its identified owner/route. Never grants a
## fragment (CLAUDE.md §4-B/C); reward_id is the authored non-fragment reward.
signal object_returned(instance_id: String, owner_route_id: String, reward_id: String)

# --- Evening events (Phase 14) ---
## Emitted when the day-close boundary opens the explicit evening state (EVE-R1).
signal evening_started(day: int)
## Emitted when the player commits the evening plan; the day then advances or the
## Day 5 loop reset runs (EVE-R5).
signal evening_plan_committed(day: int, plan_id: String)

# --- Scanner events ---
signal scanner_response_received(instance_id: String, status: String)
signal scanner_verdict_committed(instance_id: String, verdict: String)

# --- Mini-event events (Phase 18) ---
## Emitted when a mini-event starts. UI/dialogue should surface title, body,
## changed rules, consequences, and the accessibility caption.
signal event_triggered(
	event_id: String,
	display_name: String,
	changed_rules: String,
	consequences: String,
	accessibility_caption: String
)
## Emitted when a timed mini-event expires.
signal event_expired(event_id: String, display_name: String)
## Emitted when a mini-event resolves its bounded outcome (e.g. request fulfilled,
## suspicious antique judged, tool broke). Persisted to LoopState for the evening
## summary; the evening summary UI itself is a future Phase 14 dependency.
signal event_outcome_resolved(event_id: String, outcome_type: String, outcome_data: Dictionary)

# --- Tutorial / travel events (TUT) ---
## Emitted when the player hands a scrap selection to Ayla (drives the Day 0
## forage step and any future scrap-flow listeners).
signal scrap_submitted(selection: Dictionary)
## Emitted when the restoration bench opens (Day 0 workbench step).
signal restoration_opened(instance_id: String)
## Emitted when a sale is accepted with a meet-in-person payment: the item is
## handed to the player to deliver; money arrives at the handoff.
signal meet_scheduled(instance_id: String, buyer_id: String, destination_id: String)
## Emitted when the player hands the item to the buyer at the meet location and
## the deferred payment is credited.
signal meet_handoff_completed(
	instance_id: String, buyer_id: String, price: int, destination_id: String
)

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
