class_name FoodReadiness
extends RefCounted

const GameDefinitionsClass = preload("res://simulation/game_definitions.gd")

const ANALYSIS_WINDOW_TICKS: int = 120
const MAX_ETA_TICKS: int = 600
const THIN_THRESHOLD_PERCENT: int = 85


static func build_food_summary(game_state: GameState, owner_id: int = 1) -> Dictionary:
	var income_per_window: int = get_passive_income_over_window(
		game_state, owner_id, "food", ANALYSIS_WINDOW_TICKS
	)
	var provider_count: int = count_passive_income_providers(game_state, owner_id, "food")
	var demand_per_window: int = _get_combat_food_demand_per_window(
		game_state, owner_id, ANALYSIS_WINDOW_TICKS
	)
	var military_producer_count: int = _count_military_producers(game_state, owner_id)
	var per_producer_demand: int = _get_per_producer_demand(
		game_state, owner_id, ANALYSIS_WINDOW_TICKS
	)
	var status_id: String = "banking"
	var label: String = "Banking"
	var color: String = "lightgreen"
	var guidance: String = "Bank food for military timing"
	var needs_more_farms: bool = false
	var farm_income_per_window: int = get_structure_income_per_window("farm", "food", ANALYSIS_WINDOW_TICKS)
	var extra_farms_needed: int = 0
	# True when current income can sustain all existing producers PLUS one additional
	var can_sustain_another_producer: bool = false

	if demand_per_window > 0:
		if income_per_window <= 0:
			status_id = "starved"
			label = "Starved"
			color = "tomato"
			guidance = "Add Farm — no food flow for military production"
			needs_more_farms = true
		elif income_per_window < demand_per_window:
			needs_more_farms = true
			if income_per_window * 100 >= demand_per_window * THIN_THRESHOLD_PERCENT:
				status_id = "thin"
				label = "Thin"
				color = "orange"
				guidance = "Food thin — add Farm to sustain military output"
			else:
				status_id = "starved"
				label = "Starved"
				color = "tomato"
				guidance = "Food starving production — add Farm"
			if farm_income_per_window > 0:
				extra_farms_needed = int(
					ceili(float(demand_per_window - income_per_window) / float(farm_income_per_window))
				)
		else:
			status_id = "ready"
			label = "Ready"
			color = "lightgreen"
			guidance = "Food flow supports current military throughput"
			if per_producer_demand > 0 and income_per_window >= demand_per_window + per_producer_demand:
				can_sustain_another_producer = true
				guidance = "Food surplus — ready to scale military output"
	elif provider_count <= 0:
		status_id = "unstarted"
		label = "Unstarted"
		color = "gray"
		guidance = "No food income yet"

	return {
		"status_id": status_id,
		"label": label,
		"color": color,
		"provider_count": provider_count,
		"income_per_window": income_per_window,
		"demand_per_window": demand_per_window,
		"per_producer_demand": per_producer_demand,
		"military_producer_count": military_producer_count,
		"window_ticks": ANALYSIS_WINDOW_TICKS,
		"guidance": guidance,
		"needs_more_farms": needs_more_farms,
		"extra_farms_needed": extra_farms_needed,
		"can_sustain_another_producer": can_sustain_another_producer,
		"farm_income_per_window": farm_income_per_window,
	}


static func build_missing_food_message(
	game_state: GameState,
	owner_id: int,
	missing_costs: Dictionary
) -> String:
	if not missing_costs.has("food"):
		return "Need %s" % GameDefinitionsClass.format_costs(missing_costs)

	var food_value: Variant = missing_costs["food"]
	var missing_food: int = food_value if food_value is int else 0
	var required_total_food: int = game_state.get_resource_amount("food") + missing_food
	var eta_ticks: int = estimate_ticks_until_resource_amount(
		game_state,
		owner_id,
		"food",
		required_total_food
	)
	var base_text: String = "Need %s" % GameDefinitionsClass.format_costs(missing_costs)
	if eta_ticks == -1:
		return "%s — build Farm" % base_text
	return "%s (~%d ticks for food)" % [base_text, eta_ticks]


static func estimate_ticks_until_resource_amount(
	game_state: GameState,
	owner_id: int,
	resource_type: String,
	required_total_amount: int
) -> int:
	if game_state.get_resource_amount(resource_type) >= required_total_amount:
		return 0

	var provider_states: Array[Dictionary] = _get_passive_provider_states(
		game_state,
		owner_id,
		resource_type
	)
	if provider_states.is_empty():
		return -1

	var current_amount: int = game_state.get_resource_amount(resource_type)
	var local_states: Array[Dictionary] = []
	for provider_state in provider_states:
		local_states.append(provider_state.duplicate(true))

	for tick in range(1, MAX_ETA_TICKS + 1):
		for provider_state in local_states:
			var progress: int = int(provider_state.get("progress", 0)) + 1
			var interval: int = int(provider_state.get("interval", 0))
			var amount: int = int(provider_state.get("amount", 0))
			if interval <= 0 or amount <= 0:
				continue
			if progress >= interval:
				progress = 0
				current_amount += amount
			provider_state["progress"] = progress
		if current_amount >= required_total_amount:
			return tick
	return -1


static func count_passive_income_providers(
	game_state: GameState,
	owner_id: int,
	resource_type: String
) -> int:
	return _get_passive_provider_states(game_state, owner_id, resource_type).size()


static func get_passive_income_over_window(
	game_state: GameState,
	owner_id: int,
	resource_type: String,
	window_ticks: int
) -> int:
	var total_income: int = 0
	for provider_state in _get_passive_provider_states(game_state, owner_id, resource_type):
		var interval: int = int(provider_state.get("interval", 0))
		var amount: int = int(provider_state.get("amount", 0))
		if interval <= 0 or amount <= 0:
			continue
		total_income += int(floor(float(window_ticks * amount) / float(interval)))
	return total_income


static func get_structure_income_per_window(
	structure_type: String,
	resource_type: String,
	window_ticks: int
) -> int:
	if GameDefinitionsClass.get_structure_resource_trickle_type(structure_type) != resource_type:
		return 0
	var amount: int = GameDefinitionsClass.get_structure_resource_trickle_amount(structure_type)
	var interval: int = GameDefinitionsClass.get_structure_resource_trickle_interval_ticks(structure_type)
	if amount <= 0 or interval <= 0:
		return 0
	return int(floor(float(window_ticks * amount) / float(interval)))


static func _get_combat_food_demand_per_window(
	game_state: GameState,
	owner_id: int,
	window_ticks: int
) -> int:
	var total_demand: int = 0
	var producer_ids: Array[int] = []
	for entity_id in game_state.get_entities_by_type("stockpile"):
		producer_ids.append(entity_id)
	for entity_id in game_state.get_entities_by_type("structure"):
		producer_ids.append(entity_id)
	producer_ids.sort()

	for producer_id in producer_ids:
		var producer_entity: Dictionary = game_state.get_entity_dict(producer_id)
		if game_state.get_entity_owner_id(producer_entity) != owner_id:
			continue
		if game_state.get_entity_type(producer_entity) == "structure" and not game_state.get_entity_is_constructed(producer_entity):
			continue
		var structure_type: String = game_state.get_entity_structure_type(producer_entity)
		var unit_type: String = GameDefinitionsClass.get_structure_produces(structure_type)
		if unit_type == "":
			continue
		if not GameDefinitionsClass.unit_type_can_attack(unit_type):
			continue
		var food_costs: Dictionary = GameDefinitionsClass.get_unit_production_costs(unit_type)
		if not food_costs.has("food"):
			continue
		var food_cost_value: Variant = food_costs["food"]
		var food_cost: int = food_cost_value if food_cost_value is int else 0
		var duration: int = GameDefinitionsClass.get_unit_production_duration(unit_type)
		if food_cost <= 0 or duration <= 0:
			continue
		total_demand += int(ceili(float(window_ticks * food_cost) / float(duration)))
	return total_demand


static func _get_passive_provider_states(
	game_state: GameState,
	owner_id: int,
	resource_type: String
) -> Array[Dictionary]:
	var provider_states: Array[Dictionary] = []
	var provider_ids: Array[int] = []
	for entity_id in game_state.get_entities_by_type("stockpile"):
		provider_ids.append(entity_id)
	for entity_id in game_state.get_entities_by_type("structure"):
		provider_ids.append(entity_id)
	provider_ids.sort()

	for provider_id in provider_ids:
		var provider_entity: Dictionary = game_state.get_entity_dict(provider_id)
		if game_state.get_entity_owner_id(provider_entity) != owner_id:
			continue
		if game_state.get_entity_type(provider_entity) == "structure" and not game_state.get_entity_is_constructed(provider_entity):
			continue
		if game_state.get_entity_resource_trickle_type(provider_entity) != resource_type:
			continue
		var interval: int = game_state.get_entity_resource_trickle_interval_ticks(provider_entity)
		var amount: int = game_state.get_entity_resource_trickle_amount(provider_entity)
		if interval <= 0 or amount <= 0:
			continue
		provider_states.append({
			"id": provider_id,
			"interval": interval,
			"amount": amount,
			"progress": game_state.get_entity_resource_trickle_progress_ticks(provider_entity),
		})
	return provider_states


## How many food-consuming military producers does this owner have.
static func _count_military_producers(game_state: GameState, owner_id: int) -> int:
	var count: int = 0
	var producer_ids: Array[int] = []
	for entity_id in game_state.get_entities_by_type("stockpile"):
		producer_ids.append(entity_id)
	for entity_id in game_state.get_entities_by_type("structure"):
		producer_ids.append(entity_id)
	for producer_id in producer_ids:
		var producer_entity: Dictionary = game_state.get_entity_dict(producer_id)
		if game_state.get_entity_owner_id(producer_entity) != owner_id:
			continue
		if game_state.get_entity_type(producer_entity) == "structure" and not game_state.get_entity_is_constructed(producer_entity):
			continue
		var structure_type: String = game_state.get_entity_structure_type(producer_entity)
		var unit_type: String = GameDefinitionsClass.get_structure_produces(structure_type)
		if unit_type == "":
			continue
		if not GameDefinitionsClass.unit_type_can_attack(unit_type):
			continue
		var food_costs: Dictionary = GameDefinitionsClass.get_unit_production_costs(unit_type)
		if food_costs.has("food"):
			count += 1
	return count


## Food demand per 120-tick window for a single military producer of the most common type.
## Returns 0 if no military producers exist.
static func _get_per_producer_demand(
	game_state: GameState,
	owner_id: int,
	window_ticks: int
) -> int:
	var producer_ids: Array[int] = []
	for entity_id in game_state.get_entities_by_type("stockpile"):
		producer_ids.append(entity_id)
	for entity_id in game_state.get_entities_by_type("structure"):
		producer_ids.append(entity_id)
	producer_ids.sort()

	for producer_id in producer_ids:
		var producer_entity: Dictionary = game_state.get_entity_dict(producer_id)
		if game_state.get_entity_owner_id(producer_entity) != owner_id:
			continue
		if game_state.get_entity_type(producer_entity) == "structure" and not game_state.get_entity_is_constructed(producer_entity):
			continue
		var structure_type: String = game_state.get_entity_structure_type(producer_entity)
		var unit_type: String = GameDefinitionsClass.get_structure_produces(structure_type)
		if unit_type == "":
			continue
		if not GameDefinitionsClass.unit_type_can_attack(unit_type):
			continue
		var food_costs: Dictionary = GameDefinitionsClass.get_unit_production_costs(unit_type)
		if not food_costs.has("food"):
			continue
		var food_cost_value: Variant = food_costs["food"]
		var food_cost: int = food_cost_value if food_cost_value is int else 0
		var duration: int = GameDefinitionsClass.get_unit_production_duration(unit_type)
		if food_cost <= 0 or duration <= 0:
			continue
		# Return the demand for the first producer found (proxy for representative demand)
		return int(ceili(float(window_ticks * food_cost) / float(duration)))
	return 0
