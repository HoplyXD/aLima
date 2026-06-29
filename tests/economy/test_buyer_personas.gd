extends GutTest
## Buyer-persona data loads and validates, and the suspicious buyer ties to a route.

var _repo: DataRepository


func before_each() -> void:
	_repo = DataRepository.new()
	_repo.load_from_filesystem()


func test_repository_loads_with_buyers() -> void:
	assert_true(_repo.is_loaded(), "data (including buyers) loads cleanly")
	assert_eq(_repo.buyer_personas.size(), 10, "ten authored buyer personas (MKT-R1 + the Museum)")
	assert_eq(_repo.get_buyers_sorted().size(), 10)


func test_suspicious_buyer_ties_to_the_buyer_route() -> void:
	var suspicious := _repo.get_buyer("suspicious")
	assert_not_null(suspicious)
	assert_eq(suspicious.route_id, "buyer", "the suspicious buyer feeds the Mysterious-Buyer route")


func test_each_persona_has_a_budget_and_banter() -> void:
	for raw in _repo.get_buyers_sorted():
		var persona := raw as BuyerPersona
		assert_gt(
			persona.budget_range.y, persona.budget_range.x, "%s has a real budget" % persona.id
		)
		assert_true(persona.fallback_lines.has("open"), "%s has opening banter" % persona.id)
