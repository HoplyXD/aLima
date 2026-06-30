class_name DataRepository
## Typed repository/service that loads and validates all authored JSON data.
##
## The repository reads every .json file under data/objects/, data/artifacts/,
## data/echoes/, data/routes/, and data/scanner-cache/. It validates schema
## versions, duplicate IDs, enum values, numeric ranges, required references,
## and container compatibility without hardcoding slice IDs.

const SCHEMA_VERSION: int = 1

static var _singleton: DataRepository = null

var data_root: String = "res://data"  ## Overridable for tests.

var scrap_object_templates: Dictionary = {}  ## id -> ScrapObjectTemplate
var object_instance_fixtures: Dictionary = {}  ## id -> ObjectInstance
var fragments: Dictionary = {}  ## id -> Fragment
var master_artifacts: Dictionary = {}  ## id -> MasterArtifact
var echo_sets: Dictionary = {}  ## id -> EchoSet
var tool_definitions: Dictionary = {}  ## id -> ToolDefinition
var technique_definitions: Dictionary = {}  ## id -> TechniqueDefinition
var character_routes: Dictionary = {}  ## id -> CharacterRoute
var placement_containers: Dictionary = {}  ## id -> PlacementContainer
var scanner_cache_entries: Dictionary = {}  ## id -> ScannerCacheEntry
var surface_conditions: Dictionary = {}  ## id -> SurfaceCondition
var buyer_personas: Dictionary = {}  ## id -> BuyerPersona
var event_definitions: Dictionary = {}  ## id -> EventDefinition
var return_owners: Dictionary = {}  ## id -> return_owner record dict (Phase 14 returns).
var evening_config: Dictionary = {}  ## Evening upkeep/plan tuning (Phase 14).
var delivery_config: DeliveryConfig = DeliveryConfig.new()
var spawn_config: SpawnConfig = SpawnConfig.new()
var scrap_config: ScrapConfig = ScrapConfig.new()
var starting_kit: Dictionary = {"tool_ids": [], "technique_ids": []}

var _loaded := false
var _validation: ValidationResult = ValidationResult.new()


## Returns a shared, loaded repository instance. Tests that need an isolated
## repository should still use DataRepository.new() directly.
static func singleton() -> DataRepository:
	if _singleton == null or not _singleton.is_loaded():
		_singleton = DataRepository.new()
		_singleton.load_from_filesystem()
	return _singleton


func _init() -> void:
	pass


## Loads all authored data and returns a ValidationResult. If the result is
## invalid, the repository collections are left empty to avoid publishing a
## partially valid state.
func load_from_filesystem() -> ValidationResult:
	_clear_state()
	_validation = ValidationResult.new()

	_load_directory("objects", _parse_object_file)
	_load_directory("artifacts", _parse_artifact_file)
	_load_directory("echoes", _parse_echo_file)
	_load_directory("routes", _parse_route_file)
	_load_directory("scanner-cache", _parse_scanner_cache_file)
	_load_directory("delivery", _parse_delivery_file)
	_load_directory("journal", _parse_journal_file)
	_load_directory("buyers", _parse_buyer_file)
	_load_directory("events", _parse_event_file)
	_load_directory("scrap", _parse_scrap_file)
	_load_directory("marketplace", _parse_marketplace_file)
	_load_directory("evening", _parse_evening_file)

	if not _validation.is_valid():
		_clear_state()
		return _validation

	_validate_cross_references()
	_validate_container_compatibility()

	if _validation.is_valid():
		_loaded = true
	else:
		_clear_state()
	return _validation


func is_loaded() -> bool:
	return _loaded


func get_validation_result() -> ValidationResult:
	return _validation


func get_template(id: String) -> ScrapObjectTemplate:
	return scrap_object_templates.get(id) as ScrapObjectTemplate


func get_fragment(id: String) -> Fragment:
	return fragments.get(id) as Fragment


func get_master_artifact(id: String) -> MasterArtifact:
	return master_artifacts.get(id) as MasterArtifact


func get_echo_set(id: String) -> EchoSet:
	return echo_sets.get(id) as EchoSet


func get_tool(id: String) -> ToolDefinition:
	return tool_definitions.get(id) as ToolDefinition


func get_technique(id: String) -> TechniqueDefinition:
	return technique_definitions.get(id) as TechniqueDefinition


func get_route(id: String) -> CharacterRoute:
	return character_routes.get(id) as CharacterRoute


func get_container(id: String) -> PlacementContainer:
	return placement_containers.get(id) as PlacementContainer


func get_scanner_cache(id: String) -> ScannerCacheEntry:
	return scanner_cache_entries.get(id) as ScannerCacheEntry


func get_surface_condition(id: String) -> SurfaceCondition:
	return surface_conditions.get(id) as SurfaceCondition


func get_buyer(id: String) -> BuyerPersona:
	return buyer_personas.get(id) as BuyerPersona


func get_event(id: String) -> EventDefinition:
	return event_definitions.get(id) as EventDefinition


## The return-owner record for a template, or {} when the template has no identified
## owner (RETURN is then not an eligible disposition for it; DISP-R1/DISP-R3).
func get_return_for_template(template_id: String) -> Dictionary:
	for id in return_owners.keys():
		var record: Dictionary = return_owners[id]
		if ModelUtils.as_string(record.get("template_id")) == template_id:
			return record
	return {}


func get_return_owner(id: String) -> Dictionary:
	return ModelUtils.as_dictionary(return_owners.get(id))


func get_evening_config() -> Dictionary:
	return evening_config


## Buyer personas sorted by id for a stable marketplace order.
func get_buyers_sorted() -> Array:
	var ids := buyer_personas.keys()
	ids.sort()
	var out: Array = []
	for id in ids:
		out.append(buyer_personas[id])
	return out


## Returns the surface-condition catalog sorted by id for a stable Condition Guide
## order.
func get_surface_conditions_sorted() -> Array:
	var ids := surface_conditions.keys()
	ids.sort()
	var out: Array = []
	for id in ids:
		out.append(surface_conditions[id])
	return out


func get_delivery_config() -> DeliveryConfig:
	return delivery_config


func get_spawn_config() -> SpawnConfig:
	return spawn_config


func get_scrap_config() -> ScrapConfig:
	return scrap_config


func _clear_state() -> void:
	_loaded = false
	scrap_object_templates.clear()
	object_instance_fixtures.clear()
	fragments.clear()
	master_artifacts.clear()
	echo_sets.clear()
	tool_definitions.clear()
	technique_definitions.clear()
	character_routes.clear()
	placement_containers.clear()
	scanner_cache_entries.clear()
	surface_conditions.clear()
	buyer_personas.clear()
	event_definitions.clear()
	return_owners.clear()
	evening_config = {}
	delivery_config = DeliveryConfig.new()
	spawn_config = SpawnConfig.new()
	scrap_config = ScrapConfig.new()
	starting_kit = {"tool_ids": [], "technique_ids": []}


func _load_directory(dir_name: String, parser: Callable) -> void:
	var dir_path := data_root.path_join(dir_name)
	var dir := DirAccess.open(dir_path)
	if dir == null:
		_validation.add_error("Could not open data directory: %s" % dir_path)
		return
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while not file_name.is_empty():
		if file_name.ends_with(".json"):
			var file_path := dir_path.path_join(file_name)
			parser.call(file_path)
		file_name = dir.get_next()
	dir.list_dir_end()


func _read_json_file(file_path: String) -> Variant:
	var file := FileAccess.open(file_path, FileAccess.READ)
	if file == null:
		_validation.add_error(
			"Could not read file: %s (error %d)" % [file_path, FileAccess.get_open_error()]
		)
		return null
	var text := file.get_as_text()
	file.close()
	var parsed: Variant = JSON.parse_string(text)
	if parsed == null:
		_validation.add_error("Malformed JSON in %s" % file_path)
		return null
	if not parsed is Dictionary:
		_validation.add_error("JSON root must be an object with schema_version: %s" % file_path)
		return null
	var doc: Dictionary = parsed
	if not doc.has("schema_version"):
		_validation.add_error("Missing schema_version in %s" % file_path)
		return null
	var version := ModelUtils.as_int(doc["schema_version"])
	if version != SCHEMA_VERSION:
		_validation.add_error(
			(
				"Unsupported schema version %d in %s (expected %d)"
				% [version, file_path, SCHEMA_VERSION]
			)
		)
		return null
	return doc


func _parse_object_file(file_path: String) -> void:
	var doc: Variant = _read_json_file(file_path)
	if doc == null:
		return
	var items := _get_items(doc, file_path)
	for item in items:
		if not item is Dictionary:
			_validation.add_field_error(file_path, "", "", "item is not a dictionary")
			continue
		var record_type := ModelUtils.as_string(item.get("record_type"))
		match record_type:
			"template":
				var template := ScrapObjectTemplate.from_dictionary(item)
				_add_record(scrap_object_templates, template.id, template, file_path, "template")
				template.validate(_validation, file_path)
			"instance_fixture":
				var fixture := ObjectInstance.from_dictionary(item)
				_add_record(
					object_instance_fixtures, fixture.uid, fixture, file_path, "instance_fixture"
				)
				fixture.validate(_validation, file_path)
			"tool":
				var tool := ToolDefinition.from_dictionary(item)
				_add_record(tool_definitions, tool.id, tool, file_path, "tool")
				tool.validate(_validation, file_path)
			"technique":
				var technique := TechniqueDefinition.from_dictionary(item)
				_add_record(technique_definitions, technique.id, technique, file_path, "technique")
				technique.validate(_validation, file_path)
			_:
				_validation.add_field_error(
					file_path, "", "record_type", "unknown record_type '%s'" % record_type
				)


func _parse_artifact_file(file_path: String) -> void:
	var doc: Variant = _read_json_file(file_path)
	if doc == null:
		return
	if doc.has("items"):
		var items := _get_items(doc, file_path)
		for item in items:
			if item is Dictionary:
				var fragment := Fragment.from_dictionary(item)
				_add_record(fragments, fragment.id, fragment, file_path, "fragment")
				fragment.validate(_validation, file_path)
	else:
		var artifact := MasterArtifact.from_dictionary(doc)
		_add_record(master_artifacts, artifact.id, artifact, file_path, "master_artifact")
		artifact.validate(_validation, file_path)


func _parse_echo_file(file_path: String) -> void:
	var doc: Variant = _read_json_file(file_path)
	if doc == null:
		return
	var items := _get_items(doc, file_path)
	for item in items:
		if item is Dictionary:
			var echo_set := EchoSet.from_dictionary(item)
			_add_record(echo_sets, echo_set.id, echo_set, file_path, "echo_set")
			echo_set.validate(_validation, file_path)


func _parse_route_file(file_path: String) -> void:
	var doc: Variant = _read_json_file(file_path)
	if doc == null:
		return
	if file_path.get_file() == "starting_kit.json":
		starting_kit["tool_ids"] = ModelUtils.as_string_array(doc.get("tool_ids"))
		starting_kit["technique_ids"] = ModelUtils.as_string_array(doc.get("technique_ids"))
		return
	var items := _get_items(doc, file_path)
	for item in items:
		if not item is Dictionary:
			continue
		var record_type := ModelUtils.as_string(item.get("record_type"))
		match record_type:
			"route":
				var route := CharacterRoute.from_dictionary(item)
				_add_record(character_routes, route.id, route, file_path, "route")
				route.validate(_validation, file_path)
			"container":
				var container := PlacementContainer.from_dictionary(item)
				_add_record(placement_containers, container.id, container, file_path, "container")
				container.validate(_validation, file_path)
			_:
				_validation.add_field_error(
					file_path, "", "record_type", "unknown record_type '%s'" % record_type
				)


func _parse_scanner_cache_file(file_path: String) -> void:
	var doc: Variant = _read_json_file(file_path)
	if doc == null:
		return
	var items := _get_items(doc, file_path)
	for item in items:
		if item is Dictionary:
			var entry := ScannerCacheEntry.from_dictionary(item)
			var key := entry.id if not entry.id.is_empty() else entry.template_id
			_add_record(scanner_cache_entries, key, entry, file_path, "scanner_cache")
			entry.validate(_validation, file_path)


func _parse_delivery_file(file_path: String) -> void:
	var doc: Variant = _read_json_file(file_path)
	if doc == null:
		return
	var file_name := file_path.get_file()
	if file_name == "spawn_config.json":
		var spawn_cfg := SpawnConfig.from_dictionary(doc)
		spawn_cfg.validate(_validation, file_path)
		spawn_config = spawn_cfg
	else:
		var delivery_cfg := DeliveryConfig.from_dictionary(doc)
		delivery_cfg.validate(_validation, file_path)
		delivery_config = delivery_cfg


func _parse_journal_file(file_path: String) -> void:
	var doc: Variant = _read_json_file(file_path)
	if doc == null:
		return
	var items := _get_items(doc, file_path)
	for item in items:
		if not item is Dictionary:
			continue
		var record_type := ModelUtils.as_string(item.get("record_type"))
		match record_type:
			"surface_condition":
				var condition := SurfaceCondition.from_dictionary(item)
				_add_record(
					surface_conditions, condition.id, condition, file_path, "surface_condition"
				)
				condition.validate(_validation, file_path)
			_:
				_validation.add_field_error(
					file_path, "", "record_type", "unknown record_type '%s'" % record_type
				)


func _parse_buyer_file(file_path: String) -> void:
	var doc: Variant = _read_json_file(file_path)
	if doc == null:
		return
	var items := _get_items(doc, file_path)
	for item in items:
		if not item is Dictionary:
			continue
		var record_type := ModelUtils.as_string(item.get("record_type"))
		if record_type != "buyer_persona":
			_validation.add_field_error(
				file_path, "", "record_type", "unknown record_type '%s'" % record_type
			)
			continue
		var persona := BuyerPersona.from_dictionary(item)
		_add_record(buyer_personas, persona.id, persona, file_path, "buyer_persona")
		persona.validate(_validation, file_path)


func _parse_event_file(file_path: String) -> void:
	var doc: Variant = _read_json_file(file_path)
	if doc == null:
		return
	var items := _get_items(doc, file_path)
	for item in items:
		if not item is Dictionary:
			continue
		var record_type := ModelUtils.as_string(item.get("record_type"))
		if record_type != "event_definition":
			_validation.add_field_error(
				file_path, "", "record_type", "unknown record_type '%s'" % record_type
			)
			continue
		var event_def := EventDefinition.from_dictionary(item)
		_add_record(event_definitions, event_def.id, event_def, file_path, "event_definition")
		event_def.validate(_validation, file_path)


func _parse_scrap_file(file_path: String) -> void:
	var doc: Variant = _read_json_file(file_path)
	if doc == null:
		return
	var scrap_cfg := ScrapConfig.from_dictionary(doc)
	scrap_cfg.validate(_validation, file_path)
	scrap_config = scrap_cfg


func _parse_marketplace_file(file_path: String) -> void:
	var doc: Variant = _read_json_file(file_path)
	if doc == null:
		return
	var items := _get_items(doc, file_path)
	for item in items:
		if not item is Dictionary:
			continue
		var record_type := ModelUtils.as_string(item.get("record_type"))
		match record_type:
			"return_owner":
				var id := ModelUtils.as_string(item.get("id"))
				_add_record(return_owners, id, (item as Dictionary).duplicate(true), file_path, "return_owner")
			"marketplace_listing":
				# Authored listing fixtures are validated as models but not persisted here;
				# runtime listings live in LoopState. Reserved for future tuning content.
				MarketplaceListing.from_dictionary(item).validate(_validation, file_path)
			_:
				_validation.add_field_error(
					file_path, "", "record_type", "unknown record_type '%s'" % record_type
				)


func _parse_evening_file(file_path: String) -> void:
	var doc: Variant = _read_json_file(file_path)
	if doc == null:
		return
	# The evening config is a single document (no items array); the latest file wins.
	evening_config = (doc as Dictionary).duplicate(true)


func _get_items(doc: Dictionary, file_path: String) -> Array:
	if not doc.has("items"):
		return [doc]
	var items := doc.get("items", []) as Array
	if not items is Array:
		_validation.add_field_error(file_path, "", "items", "expected an array")
		return []
	return items


func _add_record(
	collection: Dictionary, id: String, record: Variant, file_path: String, kind: String
) -> void:
	if id.is_empty():
		_validation.add_field_error(file_path, id, "id", "%s record has no id" % kind)
		return
	if collection.has(id):
		_validation.add_field_error(file_path, id, "id", "duplicate %s id '%s'" % [kind, id])
		return
	collection[id] = record


func _validate_cross_references() -> void:
	for template_id in scrap_object_templates.keys():
		var template: ScrapObjectTemplate = scrap_object_templates[template_id]
		if (
			not template.required_clean_tool.is_empty()
			and not tool_definitions.has(template.required_clean_tool)
		):
			_validation.add_field_error(
				"data/objects",
				template_id,
				"required_clean_tool",
				"unknown tool reference '%s'" % template.required_clean_tool
			)
		for decal in template.decals:
			if not decal.required_tool.is_empty() and not tool_definitions.has(decal.required_tool):
				_validation.add_field_error(
					"data/objects",
					template_id,
					"decals",
					"decal '%s' references unknown tool '%s'" % [decal.id, decal.required_tool]
				)
		if (
			template.requires_join
			and not template.join_tool.is_empty()
			and not tool_definitions.has(template.join_tool)
		):
			_validation.add_field_error(
				"data/objects",
				template_id,
				"join_tool",
				"unknown tool reference '%s'" % template.join_tool
			)

	for fragment_id in fragments.keys():
		var fragment: Fragment = fragments[fragment_id]
		if not master_artifacts.has(fragment.master_artifact_id):
			_validation.add_field_error(
				"data/artifacts",
				fragment_id,
				"master_artifact_id",
				"unknown master artifact '%s'" % fragment.master_artifact_id
			)
		if not character_routes.has(fragment.owning_character_id):
			_validation.add_field_error(
				"data/artifacts",
				fragment_id,
				"owning_character_id",
				"unknown route reference '%s'" % fragment.owning_character_id
			)
		if not echo_sets.has(fragment.echo_set_ref):
			_validation.add_field_error(
				"data/artifacts",
				fragment_id,
				"echo_set_ref",
				"unknown echo set '%s'" % fragment.echo_set_ref
			)

	for artifact_id in master_artifacts.keys():
		var artifact: MasterArtifact = master_artifacts[artifact_id]
		for fragment_id in artifact.fragment_ids:
			if not fragments.has(fragment_id):
				_validation.add_field_error(
					"data/artifacts",
					artifact_id,
					"fragment_ids",
					"unknown fragment reference '%s'" % fragment_id
				)

	for uid in object_instance_fixtures.keys():
		var fixture: ObjectInstance = object_instance_fixtures[uid]
		if not scrap_object_templates.has(fixture.template_id):
			_validation.add_field_error(
				"data/objects",
				fixture.uid,
				"template_id",
				"unknown template reference '%s'" % fixture.template_id
			)

	for entry_id in scanner_cache_entries.keys():
		var entry: ScannerCacheEntry = scanner_cache_entries[entry_id]
		var template_ref := entry.id if not entry.id.is_empty() else entry.template_id
		if not scrap_object_templates.has(template_ref):
			_validation.add_field_error(
				"data/scanner-cache",
				entry_id,
				"id",
				"unknown template reference '%s'" % template_ref
			)

	for route_id in character_routes.keys():
		var route: CharacterRoute = character_routes[route_id]
		if not route.holds_fragment_id.is_empty() and not fragments.has(route.holds_fragment_id):
			_validation.add_field_error(
				"data/routes",
				route_id,
				"holds_fragment_id",
				"unknown fragment reference '%s'" % route.holds_fragment_id
			)
		for prereq in route.prerequisites:
			if (
				prereq != "all_fragments_seated"
				and prereq != "archeologist_lead"
				and not character_routes.has(prereq)
			):
				_validation.add_field_error(
					"data/routes", route_id, "prerequisites", "unknown prerequisite '%s'" % prereq
				)
		for exclusion in route.mutual_exclusions:
			if not character_routes.has(exclusion):
				_validation.add_field_error(
					"data/routes",
					route_id,
					"mutual_exclusions",
					"unknown route reference '%s'" % exclusion
				)
		for beat in route.beats:
			if not beat is Dictionary:
				continue
			var beat_template := ModelUtils.as_string(beat.get("object_template"))
			if not beat_template.is_empty() and not scrap_object_templates.has(beat_template):
				_validation.add_field_error(
					"data/routes",
					route_id,
					"beats",
					"beat references unknown template '%s'" % beat_template
				)

	for condition_id in surface_conditions.keys():
		var condition: SurfaceCondition = surface_conditions[condition_id]
		if (
			not condition.cleaning_tool.is_empty()
			and not tool_definitions.has(condition.cleaning_tool)
		):
			_validation.add_field_error(
				"data/journal",
				condition_id,
				"cleaning_tool",
				"unknown tool reference '%s'" % condition.cleaning_tool
			)

	for buyer_id in buyer_personas.keys():
		var persona: BuyerPersona = buyer_personas[buyer_id]
		if not persona.route_id.is_empty() and not character_routes.has(persona.route_id):
			_validation.add_field_error(
				"data/buyers",
				buyer_id,
				"route_id",
				"unknown route reference '%s'" % persona.route_id
			)

	for return_id in return_owners.keys():
		var record: Dictionary = return_owners[return_id]
		var template_ref := ModelUtils.as_string(record.get("template_id"))
		if template_ref.is_empty() or not scrap_object_templates.has(template_ref):
			_validation.add_field_error(
				"data/marketplace",
				return_id,
				"template_id",
				"unknown or missing template reference '%s'" % template_ref
			)
		var owner_ref := ModelUtils.as_string(record.get("owner_route_id"))
		if owner_ref.is_empty() or not character_routes.has(owner_ref):
			_validation.add_field_error(
				"data/marketplace",
				return_id,
				"owner_route_id",
				"unknown or missing route reference '%s'" % owner_ref
			)
		if ModelUtils.as_string(record.get("reward_id")).is_empty():
			_validation.add_field_error(
				"data/marketplace", return_id, "reward_id", "return reward_id is required"
			)

	const REQUIRED_EVENT_IDS: Array[String] = [
		"rush_delivery",
		"sudden_brownout",
		"community_request",
		"suspicious_antique",
		"rare_buyer_alert",
		"mystery_box",
		"rainy_day_leak",
		"tool_breakdown",
	]
	for event_id in REQUIRED_EVENT_IDS:
		if not event_definitions.has(event_id):
			_validation.add_field_error(
				"data/events", event_id, "id", "missing required event '%s'" % event_id
			)
	for event_id in event_definitions.keys():
		var event_def: EventDefinition = event_definitions[event_id]
		var params: Dictionary = event_def.outcome_params
		var template_ref := ModelUtils.as_string(params.get("request_template_id"))
		if not template_ref.is_empty() and not scrap_object_templates.has(template_ref):
			_validation.add_field_error(
				"data/events",
				event_id,
				"outcome_params.request_template_id",
				"unknown template reference '%s'" % template_ref
			)
		template_ref = ModelUtils.as_string(params.get("antique_template_id"))
		if not template_ref.is_empty() and not scrap_object_templates.has(template_ref):
			_validation.add_field_error(
				"data/events",
				event_id,
				"outcome_params.antique_template_id",
				"unknown template reference '%s'" % template_ref
			)
		template_ref = ModelUtils.as_string(params.get("box_template_id"))
		if not template_ref.is_empty() and not scrap_object_templates.has(template_ref):
			_validation.add_field_error(
				"data/events",
				event_id,
				"outcome_params.box_template_id",
				"unknown template reference '%s'" % template_ref
			)
		var buyer_ref := ModelUtils.as_string(params.get("buyer_persona_id"))
		if not buyer_ref.is_empty() and not buyer_personas.has(buyer_ref):
			_validation.add_field_error(
				"data/events",
				event_id,
				"outcome_params.buyer_persona_id",
				"unknown buyer reference '%s'" % buyer_ref
			)
		var condition_ref := ModelUtils.as_string(params.get("extra_condition_type"))
		if not condition_ref.is_empty() and not surface_conditions.has(condition_ref):
			_validation.add_field_error(
				"data/events",
				event_id,
				"outcome_params.extra_condition_type",
				"unknown surface condition reference '%s'" % condition_ref
			)

	for tool_id in starting_kit.tool_ids:
		if not tool_definitions.has(tool_id):
			_validation.add_field_error(
				"data/routes", "starting_kit", "tool_ids", "unknown tool reference '%s'" % tool_id
			)
	for technique_id in starting_kit.technique_ids:
		if not technique_definitions.has(technique_id):
			_validation.add_field_error(
				"data/routes",
				"starting_kit",
				"technique_ids",
				"unknown technique reference '%s'" % technique_id
			)


func _validate_container_compatibility() -> void:
	if placement_containers.is_empty():
		return
	for template_id in scrap_object_templates.keys():
		var template: ScrapObjectTemplate = scrap_object_templates[template_id]
		var candidate_tags := template.tags.duplicate()
		candidate_tags.append(template.category)
		if not template.openable_type.is_empty():
			candidate_tags.append(template.openable_type)
		var matched := false
		for container_id in placement_containers.keys():
			var container: PlacementContainer = placement_containers[container_id]
			for tag in candidate_tags:
				if container.compatibility_tags.has(tag):
					matched = true
					break
			if matched:
				break
		if not matched:
			_validation.add_field_error(
				"data/objects",
				template_id,
				"tags",
				"no compatible placement container found for tags %s" % str(candidate_tags)
			)
