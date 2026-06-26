extends Node
## Ayla manages the earned delivery loop (RV2-B).
##
## The player hands chosen scrap to Ayla at her scrapyard anchor. She sorts it for
## ~1 in-game hour (clock running), then knocks at the shop door. The sorted batch
## is generated through the SAME DeliveryGenerator pipeline as the old free morning
## delivery, but its rarity weights are biased by the submitted scrap (D10). Higher
## tiers become more likely, but no tier is ever guaranteed.
##
## Registered as the `AylaService` autoload. It owns no scene nodes and communicates
## through EventBus.hour_changed and a typed `sort_ready` signal.

signal sort_ready(day: int, hour: int)

const SORT_HOURS: int = 1
const SORT_STREAM := "ayla_sort"


func _ready() -> void:
	EventBus.hour_changed.connect(_on_hour_changed)


## Submits a selection of scrap from the loop pool. Returns true if the sort starts.
## `selection` is { rarity_name -> count }. The counts are moved out of scrap_pool
## into pending_sort and Ayla knocks after SORT_HOURS of in-game time. This is
## independent of the daily free morning delivery.
func submit_scrap(selection: Dictionary) -> bool:
	var loop := GameState.save_state.loop
	if not _can_start_sort(loop):
		return false
	if not _selection_is_valid(loop.scrap_pool, selection):
		return false

	_deduct_scrap(loop.scrap_pool, selection)
	loop.pending_sort = {
		"submitted": selection.duplicate(),
		"ready_index": _now_index() + SORT_HOURS,
		"active": true,
	}
	SaveService.save_game()
	return true


## True while Ayla is busy sorting a submitted batch (including after it is ready).
func is_sort_active() -> bool:
	return GameState.save_state.loop.pending_sort.get("active", false)


## True when the submitted sort has reached its ready time and Ayla is knocking.
func is_sort_ready() -> bool:
	var pending: Dictionary = GameState.save_state.loop.pending_sort
	if not pending.get("active", false):
		return false
	var ready_index: int = ModelUtils.as_int(pending.get("ready_index"), -1)
	return _now_index() >= ready_index


## The scrap currently committed to the pending sort.
func get_pending_submitted() -> Dictionary:
	return ModelUtils.as_dictionary(GameState.save_state.loop.pending_sort.get("submitted"))


## Clears the pending sort state. Called by ShopController when triage opens so the
## consumed scrap/sort is not double-spent.
func consume_sort() -> void:
	GameState.save_state.loop.pending_sort = {}


## Returns a delivery config whose rarity weights are biased by the submitted scrap.
## If no sort is pending, returns `base_cfg` unchanged. Event modifiers should be
## applied to `base_cfg` BEFORE calling this method; scrap bias is layered on top
## of the event-adjusted weights and only touches rarity weights.
func get_biased_delivery_config(base_cfg: DeliveryConfig) -> DeliveryConfig:
	var cfg := DeliveryConfig.new()
	cfg.schema_version = base_cfg.schema_version
	cfg.batch_min = base_cfg.batch_min
	cfg.batch_max = base_cfg.batch_max
	cfg.storage_cap = base_cfg.storage_cap
	var submitted := get_pending_submitted()
	var scrap_cfg := DataRepository.singleton().get_scrap_config()
	cfg.rarity_weights = apply_scrap_bias(
		base_cfg.rarity_weights, submitted, scrap_cfg.bias_impulses, scrap_cfg.bias_scalar
	)
	return cfg


## Pure, testable bias function. Adds per-scrap-tier output impulses to the base
## rarity weights, clamps negative results to 0, and leaves the weights unnormalized
## so the existing weighted picker can use them directly. Because every base weight
## stays positive and bonuses are finite, no tier can ever reach probability 1.0.
static func apply_scrap_bias(
	base_weights: Dictionary, submitted: Dictionary, impulses: Dictionary, scalar: float
) -> Dictionary:
	var biased := base_weights.duplicate()
	for scrap_rarity in submitted.keys():
		var count: int = int(submitted[scrap_rarity])
		if count <= 0:
			continue
		var impulse: Dictionary = ModelUtils.as_dictionary(impulses.get(scrap_rarity))
		for output_rarity in impulse.keys():
			var bonus: float = float(impulse[output_rarity]) * count * scalar
			biased[output_rarity] = biased.get(output_rarity, 0.0) + bonus
	for rarity_name in ModelEnums.RARITY_NAMES:
		if not biased.has(rarity_name):
			biased[rarity_name] = 0.0
		biased[rarity_name] = maxf(biased[rarity_name], 0.0)
	return biased


func _on_hour_changed(day: int, hour: int) -> void:
	var pending: Dictionary = GameState.save_state.loop.pending_sort
	if not pending.get("active", false):
		return
	var ready_index: int = ModelUtils.as_int(pending.get("ready_index"), -1)
	if _now_index(day, hour) >= ready_index:
		sort_ready.emit(day, hour)


func _can_start_sort(_loop: Variant) -> bool:
	return not is_sort_active()


func _selection_is_valid(pool: Dictionary, selection: Dictionary) -> bool:
	for rarity_name in selection.keys():
		if ModelEnums.RARITY_NAMES.find(rarity_name) < 0:
			return false
		var wanted: int = int(selection[rarity_name])
		if wanted < 0:
			return false
		var owned: int = int(pool.get(rarity_name, 0))
		if wanted > owned:
			return false
	return true


func _deduct_scrap(pool: Dictionary, selection: Dictionary) -> void:
	for rarity_name in selection.keys():
		var count: int = int(selection[rarity_name])
		pool[rarity_name] = int(pool.get(rarity_name, 0)) - count
		if int(pool[rarity_name]) <= 0:
			pool.erase(rarity_name)


func _now_index(day: int = -1, hour: int = -1) -> int:
	if day < 0 or hour < 0:
		var loop := GameState.save_state.loop
		day = loop.current_day
		hour = loop.current_hour
	return day * 24 + hour
