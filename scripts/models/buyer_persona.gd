class_name BuyerPersona
## A marketplace buyer: a motive, a budget, and a negotiation temperament.
##
## Drives the deterministic haggle engine (Negotiation) now, and is the same
## persona contract the later server-side `POST /api/negotiate` LLM proxy will use
## (PRD §4.10 / MKT-R1..R7). Behaviour tuning lives in data, not code, so personas
## stay distinct and artifact-agnostic.

## PRD §4.10 contract fields.
var id: String = ""
var display_name: String = ""  ## A person's name (first, or first + last).
var occupation: String = ""  ## Short role shown under the name in the buyer list.
var motive: String = ""
var budget_range: Vector2i = Vector2i.ZERO  ## [min interest, max they can pay].
var preferred_categories: Array[String] = []
var negotiation_style: String = ""
var route_id: String = ""  ## "" unless tied to a route (e.g. the suspicious buyer -> "buyer").
var fallback_response_set: String = ""

## Deterministic-engine tuning (kept in data so personas feel different).
var open_factor: float = 0.6  ## Opening offer as a fraction of the buyer's ceiling.
var concession_rate: float = 0.34  ## How far toward the ceiling the buyer moves per round (0..1).
var patience: int = 3  ## Greedy rounds (player asking above the ceiling) tolerated before walking.
var category_bonus: float = 0.15  ## Ceiling bump when the item is a preferred category.
var condition_weight: float = 0.4  ## How strongly restoration condition moves the ceiling (0..1).
var fallback_lines: Dictionary = {}  ## phase ("open"/"counter"/"accept"/"walk") -> Array[String].

## Per-loop wallet (MKT-R economy): a buyer can never pay more than the cash they have.
## `starting_cash` is their wallet at loop start (0 = fall back to budget max); each new
## day adds `daily_allowance`. Mr. Maverick is `unlimited_cash` — never capped, never spent.
var starting_cash: int = 0
var daily_allowance: int = 0
var unlimited_cash: bool = false
## A "robotic"/all-business buyer: banter and the seller's explanation never move their
## price — they value only the object's condition + category. Their AI replies stay terse.
var ignores_banter: bool = false


func _init() -> void:
	pass


static func from_dictionary(data: Dictionary) -> BuyerPersona:
	var b := BuyerPersona.new()
	b.id = ModelUtils.as_string(data.get("id"))
	b.display_name = ModelUtils.as_string(data.get("display_name"))
	b.occupation = ModelUtils.as_string(data.get("occupation"))
	b.motive = ModelUtils.as_string(data.get("motive"))
	var budget := ModelUtils.as_vector2(data.get("budget_range"))
	b.budget_range = Vector2i(int(budget.x), int(budget.y))
	b.preferred_categories = ModelUtils.as_string_array(data.get("preferred_categories"))
	b.negotiation_style = ModelUtils.as_string(data.get("negotiation_style"))
	b.route_id = ModelUtils.as_string(data.get("route_id"))
	b.fallback_response_set = ModelUtils.as_string(data.get("fallback_response_set"))
	b.open_factor = ModelUtils.as_float(data.get("open_factor"), 0.6)
	b.concession_rate = ModelUtils.as_float(data.get("concession_rate"), 0.34)
	b.patience = ModelUtils.as_int(data.get("patience"), 3)
	b.category_bonus = ModelUtils.as_float(data.get("category_bonus"), 0.15)
	b.condition_weight = ModelUtils.as_float(data.get("condition_weight"), 0.4)
	b.starting_cash = ModelUtils.as_int(data.get("starting_cash"), 0)
	b.daily_allowance = ModelUtils.as_int(data.get("daily_allowance"), 0)
	b.unlimited_cash = bool(data.get("unlimited_cash", false))
	b.ignores_banter = bool(data.get("ignores_banter", false))
	b.fallback_lines = ModelUtils.as_dictionary(data.get("lines"))
	return b


func to_dictionary() -> Dictionary:
	return {
		"record_type": "buyer_persona",
		"id": id,
		"display_name": display_name,
		"occupation": occupation,
		"motive": motive,
		"budget_range": [budget_range.x, budget_range.y],
		"preferred_categories": preferred_categories.duplicate(),
		"negotiation_style": negotiation_style,
		"route_id": route_id,
		"fallback_response_set": fallback_response_set,
		"open_factor": open_factor,
		"concession_rate": concession_rate,
		"patience": patience,
		"category_bonus": category_bonus,
		"condition_weight": condition_weight,
		"starting_cash": starting_cash,
		"daily_allowance": daily_allowance,
		"unlimited_cash": unlimited_cash,
		"ignores_banter": ignores_banter,
		"lines": fallback_lines.duplicate(true),
	}


func likes_category(category: String) -> bool:
	return preferred_categories.has(category)


## The buyer's wallet at loop start: their authored starting cash, or their budget max
## when none is set. Maverick is unlimited and not capped by this.
func wallet_start() -> int:
	return starting_cash if starting_cash > 0 else budget_range.y


## A canned banter line for a negotiation phase, with `{offer}` substituted. `index`
## rotates through the authored variants deterministically; falls back to a generic
## line so a missing set never breaks a sale.
func line(phase: String, offer: int, index: int = 0) -> String:
	var variants: Array = fallback_lines.get(phase, [])
	var text := ""
	if variants is Array and not variants.is_empty():
		text = ModelUtils.as_string(variants[index % variants.size()])
	else:
		text = _generic_line(phase)
	return text.replace("{offer}", str(offer))


func _generic_line(phase: String) -> String:
	match phase:
		"open":
			return "I could offer ₱{offer}."
		"counter":
			return "I can go to ₱{offer}."
		"accept":
			return "Deal."
		_:
			return "No deal."


func validate(
	result: ValidationResult = ValidationResult.new(), file_path: String = ""
) -> ValidationResult:
	if id.is_empty():
		result.add_field_error(file_path, id, "id", "buyer persona id is required")
	if display_name.is_empty():
		result.add_field_error(file_path, id, "display_name", "display_name is required")
	if budget_range.x < 0 or budget_range.y < budget_range.x:
		result.add_field_error(
			file_path, id, "budget_range", "budget_range must be [min<=max], min>=0"
		)
	if patience < 1:
		result.add_field_error(file_path, id, "patience", "patience must be >= 1")
	return result
