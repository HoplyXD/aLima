class_name PlacementCandidate
## Typed carrier/container candidate produced by the Phase 5 Spawn Director.
##
## Candidates are built during enumeration, filtered, scored, and then selected.
## Keeping the fields explicit avoids passing loosely structured dictionaries
## through the placement pipeline.

var fragment_id: String = ""
var template_id: String = ""
var container_id: String = ""
var base_weight: float = 0.0
var neglect_bonus: float = 0.0
var day_spread_bonus: float = 0.0
var final_weight: float = 0.0
var soft_reset: bool = false
var rejection_reason: String = ""


func _init(p_fragment_id: String, p_template_id: String, p_container_id: String) -> void:
	fragment_id = p_fragment_id
	template_id = p_template_id
	container_id = p_container_id


func is_eligible() -> bool:
	return rejection_reason.is_empty()


func pair_key() -> String:
	return "%s|%s" % [template_id, container_id]


func to_dictionary() -> Dictionary:
	return {
		"fragment_id": fragment_id,
		"template_id": template_id,
		"container_id": container_id,
		"base_weight": base_weight,
		"neglect_bonus": neglect_bonus,
		"day_spread_bonus": day_spread_bonus,
		"final_weight": final_weight,
		"soft_reset": soft_reset,
		"rejection_reason": rejection_reason,
	}
