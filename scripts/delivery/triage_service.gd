class_name TriageService
## Applies the result of a triage session to loop and persistent state.
##
## Kept instances enter the loop inventory. Recycled instances are removed from
## active state and cannot later enter restoration. A recycled carrier does not
## consume its fragment: the fragment stays RELEASED and will be re-placed in a
## future loop. Seated fragments are never touched.

var _game_state: GameState


func _init(game_state: GameState) -> void:
	_game_state = game_state


## Applies decisions from the triage state. Returns true if changes were made.
## Emits EventBus.triage_completed and saves the game atomically on success.
func apply_triage(state: TriageState) -> bool:
	if not state.can_complete():
		return false

	var kept := state.kept_ids()
	var recycled := state.recycled_ids()
	var kept_instances := _instances_by_id(state.instances, kept)
	var recycled_instances := _instances_by_id(state.instances, recycled)

	var inventory := _game_state.save_state.loop.inventory
	for inst in kept_instances:
		inventory.append(inst.to_dictionary())

	_update_neglect_history(recycled_instances)

	state.mark_applied()
	EventBus.triage_completed.emit(kept, recycled)
	SaveService.save_game()
	return true


func _instances_by_id(
	instances: Array[ObjectInstance], ids: Array[String]
) -> Array[ObjectInstance]:
	var out: Array[ObjectInstance] = []
	for id in ids:
		for inst in instances:
			if inst.uid == id:
				out.append(inst)
				break
	return out


func _update_neglect_history(recycled_instances: Array[ObjectInstance]) -> void:
	var neglect := _game_state.save_state.persistent.neglect_history
	for inst in recycled_instances:
		var anchor := inst.assigned_anchor_id
		if anchor.is_empty():
			continue
		neglect[anchor] = neglect.get(anchor, 0) + 1
