class_name BuyerShopService
## Mr. Maverick's evening shop (v3, story.md §16): he SELLS one overpriced
## artifact per day (18:00-20:00, data in data/routes/buyer_shop.json), and once
## the player has bought all five daily offers, his Day-5 visit also sells the
## fifth fragment for a flat price. Plain instantiable class (like TravelService):
## no scene refs, reads live state on demand, deterministic offers per run seed.

const CONFIG_PATH := "res://data/routes/buyer_shop.json"

var _daily_offers: Array = []
var _fragment_price: int = 5000
var _fragment_id: String = "fragment_05"


func _init(path: String = CONFIG_PATH) -> void:
	_load(path)


func fragment_price() -> int:
	return _fragment_price


func fragment_id() -> String:
	return _fragment_id


## Today's offer: {template_id, display_name, rarity_name, price}, or {} when the
## day has no authored offer or no template fits. Deterministic per run seed and
## day (the same offer greets every visit that evening).
func offer_for_day(day: int) -> Dictionary:
	var config := _config_for_day(day)
	if config.is_empty():
		return {}
	var rng := GameState.make_rng("buyer_shop_day_%d" % day)
	var price := rng.randi_range(
		ModelUtils.as_int(config.get("price_min"), 0), ModelUtils.as_int(config.get("price_max"), 0)
	)
	var candidates := _candidate_templates(ModelUtils.as_string_array(config.get("rarities")))
	if candidates.is_empty():
		return {}
	var template: ScrapObjectTemplate = candidates[rng.randi_range(0, candidates.size() - 1)]
	return {
		"template_id": template.id,
		"display_name": template.display_name,
		"rarity_name": ModelEnums.rarity_name(template.base_rarity),
		"price": price,
	}


## Whether today's offer was already bought (one per day).
func is_bought(day: int) -> bool:
	return GameState.save_state.loop.buyer_shop_days_bought.has(day)


## True once every authored day's offer has been bought this loop.
func all_days_bought() -> bool:
	for raw in _daily_offers:
		if raw is Dictionary and not is_bought(ModelUtils.as_int(raw.get("day"), -1)):
			return false
	return not _daily_offers.is_empty()


## The Day-5 fragment offer stands once every daily offer is bought and the
## fragment has not been earned some other way.
func fragment_available(day: int) -> bool:
	if day != 5 or not all_days_bought():
		return false
	return FragmentService.get_state(_fragment_id) == ModelEnums.FragmentState.LOCKED


## Buys today's artifact: deducts the price and drops the piece DIRTY into the
## loop inventory (an ordinary restorable artifact — clean it, sell it, keep it).
## Returns {ok, error}.
func buy_today(day: int) -> Dictionary:
	if is_bought(day):
		return {"ok": false, "error": "Today's piece is already yours."}
	var offer := offer_for_day(day)
	if offer.is_empty():
		return {"ok": false, "error": "Nothing on offer today."}
	var price := int(offer["price"])
	if GameState.save_state.loop.money < price:
		return {"ok": false, "error": "Not enough pesos."}
	var template := DataRepository.singleton().get_template(str(offer["template_id"]))
	if template == null:
		return {"ok": false, "error": "Nothing on offer today."}

	GameState.save_state.loop.money -= price
	var rng := GameState.make_rng("buyer_shop_value_%d" % day)
	var instance := ObjectInstance.new()
	instance.template_id = template.id
	instance.uid = "buyer_shop_%d_%d_%d" % [GameState.loop_index, day, GameState.run_seed]
	instance.condition = 0.0
	instance.state = ModelEnums.ObjState.DIRTY
	instance.storage_cost = template.storage_cost
	instance.true_value = ValueModel.roll_true_value_range(
		int(template.base_value_range.x), int(template.base_value_range.y), rng
	)
	instance.value = int(template.base_value_range.x)
	GameState.save_state.loop.inventory.append(instance.to_dictionary())
	GameState.save_state.loop.buyer_shop_days_bought.append(day)
	var save_result := SaveService.save_game()
	if not save_result.ok:
		push_error("BuyerShopService: save failed: %s" % save_result.get("error", ""))
	return {"ok": true, "error": ""}


## Pays for the fragment: deducts the price and grants the encoded ledger. The
## CALLER runs the release -> Found -> Portal -> seat chain (it owns the overlay).
## Returns {ok, error}.
func buy_fragment(day: int) -> Dictionary:
	if not fragment_available(day):
		return {"ok": false, "error": "That offer is not on the table."}
	if GameState.save_state.loop.money < _fragment_price:
		return {"ok": false, "error": "Not enough pesos."}
	GameState.save_state.loop.money -= _fragment_price
	if not GameState.save_state.persistent.legacy_items.has("encoded_ledger"):
		GameState.save_state.persistent.legacy_items.append("encoded_ledger")
	var save_result := SaveService.save_game()
	if not save_result.ok:
		push_error("BuyerShopService: fragment save failed: %s" % save_result.get("error", ""))
	return {"ok": true, "error": ""}


func _config_for_day(day: int) -> Dictionary:
	for raw in _daily_offers:
		if raw is Dictionary and ModelUtils.as_int(raw.get("day"), -1) == day:
			return raw
	return {}


## Deliverable templates with a real authored scene, never quest-bound, whose
## rarity matches the day's band (mirrors the DeliveryGenerator's pool rules).
func _candidate_templates(rarity_names: Array[String]) -> Array:
	var artifact_catalog := load("res://scripts/restoration/artifact_catalog.gd")
	var artifact_scenes := load("res://scripts/restoration/artifact_scenes.gd")
	artifact_catalog.ensure_ready()
	var repo := DataRepository.singleton()
	var out: Array = []
	var ids := repo.scrap_object_templates.keys()
	ids.sort()  # deterministic order regardless of dictionary iteration
	for id in ids:
		var template: ScrapObjectTemplate = repo.scrap_object_templates[id]
		if not template.deliverable or template.is_quest_item:
			continue
		if not artifact_scenes.has_scene(id) or artifact_catalog.is_quest_item(id):
			continue
		if rarity_names.has(ModelEnums.rarity_name(template.base_rarity)):
			out.append(template)
	return out


func _load(path: String) -> void:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("BuyerShopService: cannot open %s" % path)
		return
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK or not (json.data is Dictionary):
		push_error("BuyerShopService: malformed %s" % path)
		return
	var data: Dictionary = json.data
	if data.get("daily_offers") is Array:
		_daily_offers = data["daily_offers"]
	_fragment_price = ModelUtils.as_int(data.get("fragment_price"), 5000)
	_fragment_id = ModelUtils.as_string(data.get("fragment_id"), "fragment_05")
