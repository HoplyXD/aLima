class_name TriageState
## Pure logic for a triage session.
##
## Tracks keep/recycle/undecided decisions for a batch of delivered instances and
## enforces the storage cap by storage cost, not object count.

enum Decision { UNDECIDED = 0, KEEP = 1, RECYCLE = 2 }

const DECISION_NAMES: Array[String] = ["undecided", "keep", "recycle"]

var instances: Array[ObjectInstance] = []
var decisions: Dictionary = {}  ## uid -> Decision.
var storage_cap: int = 0
var _applied: bool = false


func _init(delivery: Array[ObjectInstance], cap: int) -> void:
	instances = delivery.duplicate()
	storage_cap = cap
	for inst in instances:
		decisions[inst.uid] = Decision.UNDECIDED


static func decision_from_name(name: String) -> int:
	var idx := DECISION_NAMES.find(name.to_lower().strip_edges())
	return Decision.UNDECIDED if idx < 0 else idx


static func decision_name(value: int) -> String:
	if value < 0 or value >= DECISION_NAMES.size():
		return DECISION_NAMES[Decision.UNDECIDED]
	return DECISION_NAMES[value]


## Returns true if every instance has a keep or recycle decision.
func all_decided() -> bool:
	for uid in decisions.keys():
		if decisions[uid] == Decision.UNDECIDED:
			return false
	return true


## Total storage cost of all kept instances.
func used_storage() -> int:
	var total := 0
	for inst in instances:
		if decisions.get(inst.uid, Decision.UNDECIDED) == Decision.KEEP:
			total += inst.storage_cost
	return total


func available_storage() -> int:
	return storage_cap - used_storage()


## True if the current kept selection fits within the cap.
func within_capacity() -> bool:
	return used_storage() <= storage_cap


## True only when every item is decided AND the kept selection fits AND the
## session has not already been applied.
func can_complete() -> bool:
	return not _applied and all_decided() and within_capacity()


func mark_applied() -> void:
	_applied = true


## Sets the decision for an instance. Returns true if the decision changed.
func set_decision(uid: String, decision: int) -> bool:
	if not decisions.has(uid):
		return false
	var previous: int = decisions[uid]
	decisions[uid] = decision
	return previous != decision


## Returns an array of kept instance uids.
func kept_ids() -> Array[String]:
	var out: Array[String] = []
	for inst in instances:
		if decisions.get(inst.uid, Decision.UNDECIDED) == Decision.KEEP:
			out.append(inst.uid)
	return out


## Returns an array of recycled instance uids.
func recycled_ids() -> Array[String]:
	var out: Array[String] = []
	for inst in instances:
		if decisions.get(inst.uid, Decision.UNDECIDED) == Decision.RECYCLE:
			out.append(inst.uid)
	return out
