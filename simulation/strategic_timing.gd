class_name StrategicTiming
extends RefCounted

const EnemyAIControllerClass = preload("res://simulation/enemy_ai_controller.gd")
const FoodReadinessClass = preload("res://simulation/food_readiness.gd")
const GameDefinitionsClass = preload("res://simulation/game_definitions.gd")

const HOUSE_TARGET_TICK: int = 90
const BARRACKS_TARGET_TICK: int = 180
const FARM_TARGET_TICK: int = 220
const ARMY_TARGET_TICK: int = 250
const READY_COMBAT_UNITS: int = 2


static func build_player_summary(game_state: GameState, owner_id: int = 1) -> Dictionary:
	var worker_count: int = _count_units_by_role(game_state, owner_id, "worker")
	var soldier_count: int = _count_units_by_role(game_state, owner_id, "soldier")
	var archer_count: int = _count_units_by_role(game_state, owner_id, "archer")
	var combat_unit_count: int = soldier_count + archer_count
	var queued_combat_unit_count: int = _count_queued_combat_units(game_state, owner_id)
	var house_count: int = _count_constructed_structures(game_state, owner_id, "house")
	var farm_count: int = _count_constructed_structures(game_state, owner_id, "farm")
	var barracks_count: int = _count_constructed_structures(game_state, owner_id, "barracks")
	var range_count: int = _count_constructed_structures(game_state, owner_id, "archery_range")
	var food_summary: Dictionary = FoodReadinessClass.build_food_summary(game_state, owner_id)
	var current_tick: int = game_state.current_tick

	var stage_id: String = "stabilize"
	var stage_label: String = "Stabilize"
	var next_goal: String = "Build House"
	var target_tick: int = HOUSE_TARGET_TICK
	var bottleneck: String = _get_house_bottleneck(game_state)

	if house_count > 0:
		stage_id = "scale"
		stage_label = "Scale"
		next_goal = "Build Barracks"
		target_tick = BARRACKS_TARGET_TICK
		bottleneck = _get_barracks_bottleneck(game_state)

	if barracks_count > 0:
		stage_id = "pressure"
		stage_label = "Pressure"
		if farm_count == 0:
			next_goal = "Build Farm"
			target_tick = FARM_TARGET_TICK
			bottleneck = _get_farm_bottleneck(game_state)
		elif bool(food_summary.get("needs_more_farms", false)) and combat_unit_count < READY_COMBAT_UNITS:
			next_goal = "Add Farm"
			target_tick = ARMY_TARGET_TICK
			bottleneck = str(food_summary.get("guidance", "Food flow thin"))
		else:
			next_goal = "Field %d Combat Units" % READY_COMBAT_UNITS
			target_tick = ARMY_TARGET_TICK
			bottleneck = _get_army_bottleneck(game_state, owner_id, food_summary)

	if combat_unit_count >= READY_COMBAT_UNITS:
		stage_id = "ready"
		stage_label = "Pressure Ready"
		var can_sustain_another: bool = bool(food_summary.get("can_sustain_another_producer", false))
		if can_sustain_another and barracks_count + range_count < 2:
			next_goal = "Add Barracks — Food Surplus Ready"
			target_tick = EnemyAIControllerClass.ATTACK_START_TICK
			bottleneck = _get_ready_bottleneck(game_state, owner_id)
		else:
			next_goal = "Attack Before The Next Wave"
			target_tick = EnemyAIControllerClass.ATTACK_START_TICK
			bottleneck = _get_ready_bottleneck(game_state, owner_id)

	var army_pipeline: Dictionary = _get_army_pipeline(game_state, owner_id)

	return {
		"stage_id": stage_id,
		"stage_label": stage_label,
		"next_goal": next_goal,
		"target_tick": target_tick,
		"timing_state": _build_timing_state(current_tick, target_tick),
		"bottleneck": bottleneck,
		"worker_count": worker_count,
		"soldier_count": soldier_count,
		"archer_count": archer_count,
		"combat_unit_count": combat_unit_count,
		"queued_combat_unit_count": queued_combat_unit_count,
		"house_count": house_count,
		"army_pipeline": army_pipeline,
		"farm_count": farm_count,
		"barracks_count": barracks_count,
		"archery_range_count": range_count,
		"food_summary": food_summary,
	}


static func get_enemy_pressure_text(game_state: GameState) -> String:
	var current_tick: int = game_state.current_tick
	if current_tick < EnemyAIControllerClass.ATTACK_START_TICK:
		return "First wave in %d ticks" % (EnemyAIControllerClass.ATTACK_START_TICK - current_tick)

	var ticks_since_start: int = current_tick - EnemyAIControllerClass.ATTACK_START_TICK
	var ticks_until_next_wave: int = EnemyAIControllerClass.ATTACK_WAVE_INTERVAL_TICKS - (
		ticks_since_start % EnemyAIControllerClass.ATTACK_WAVE_INTERVAL_TICKS
	)
	if ticks_until_next_wave == EnemyAIControllerClass.ATTACK_WAVE_INTERVAL_TICKS:
		return "Enemy wave active now"
	return "Next wave in %d ticks" % ticks_until_next_wave


static func _count_constructed_structures(
	game_state: GameState,
	owner_id: int,
	structure_type: String
) -> int:
	var count: int = 0
	for entity_id in game_state.get_entities_by_type("structure"):
		var entity: Dictionary = game_state.get_entity_dict(entity_id)
		if game_state.get_entity_owner_id(entity) != owner_id:
			continue
		if game_state.get_entity_structure_type(entity) != structure_type:
			continue
		if not game_state.get_entity_is_constructed(entity):
			continue
		count += 1
	return count


static func _count_units_by_role(game_state: GameState, owner_id: int, unit_role: String) -> int:
	var count: int = 0
	for entity_id in game_state.get_entities_by_type("unit"):
		var entity: Dictionary = game_state.get_entity_dict(entity_id)
		if game_state.get_entity_owner_id(entity) != owner_id:
			continue
		if game_state.get_entity_unit_role(entity) != unit_role:
			continue
		count += 1
	return count


static func _build_timing_state(current_tick: int, target_tick: int) -> Dictionary:
	if current_tick <= target_tick - 40:
		return {"label": "Ahead", "color": "lightgreen"}
	if current_tick <= target_tick:
		return {"label": "On Time", "color": "khaki"}
	if current_tick <= target_tick + 40:
		return {"label": "Late", "color": "orange"}
	return {"label": "Behind", "color": "tomato"}


static func _get_house_bottleneck(game_state: GameState) -> String:
	if not game_state.can_afford_building("house"):
		return "Need %s" % GameDefinitionsClass.format_costs(
			game_state.get_missing_building_costs("house")
		)
	return "Assign a worker to place House"


static func _get_barracks_bottleneck(game_state: GameState) -> String:
	if not game_state.can_afford_building("barracks"):
		return "Need %s" % GameDefinitionsClass.format_costs(
			game_state.get_missing_building_costs("barracks")
		)
	return "Assign a worker to place Barracks"


static func _get_farm_bottleneck(game_state: GameState) -> String:
	if not game_state.can_afford_building("farm"):
		return "Need %s" % GameDefinitionsClass.format_costs(
			game_state.get_missing_building_costs("farm")
		)
	return "Assign a worker to place Farm"


static func _get_army_bottleneck(game_state: GameState, owner_id: int, food_summary: Dictionary) -> String:
	if _count_blocked_producers(game_state, owner_id) > 0:
		return "Production blocked — set rally / clear spawn space"
	if _count_queued_combat_units(game_state, owner_id) > 0:
		return "Army still training"
	if game_state.get_population_queued(owner_id) > 0:
		return "Wait for queued units to finish"
	var queued_unit_type: String = _get_available_combat_unit_type(game_state, owner_id)
	if queued_unit_type != "" and game_state.is_population_capped_for_unit(owner_id, queued_unit_type):
		return "Need more houses"
	if bool(food_summary.get("needs_more_farms", false)):
		return str(food_summary.get("guidance", "Food flow thin"))
	if queued_unit_type != "" and not game_state.can_afford_production(queued_unit_type):
		return "Need %s" % GameDefinitionsClass.format_costs(
			game_state.get_missing_production_costs(queued_unit_type)
		)
	if queued_unit_type != "":
		var unit_label: String = GameDefinitionsClass.get_unit_display_name(queued_unit_type)
		return "Queue %ss from your military buildings" % unit_label.to_lower()
	return "Build a military building to train units"


static func _get_ready_bottleneck(game_state: GameState, owner_id: int) -> String:
	if _count_blocked_producers(game_state, owner_id) > 0:
		return "Deployment blocked — clear producer exits or update rally"
	if _count_queued_combat_units(game_state, owner_id) > 0:
		return "Reinforcements still training"
	if game_state.get_population_queued(owner_id) > 0:
		return "Army still training"
	return "Attack now or keep scaling"


static func _count_queued_combat_units(game_state: GameState, owner_id: int) -> int:
	var queued_units: int = 0
	for entity_id in game_state.get_entities_by_type("stockpile"):
		var entity: Dictionary = game_state.get_entity_dict(entity_id)
		if game_state.get_entity_owner_id(entity) != owner_id:
			continue
		queued_units += _combat_queue_count_for_producer(game_state, entity)
	for entity_id in game_state.get_entities_by_type("structure"):
		var entity: Dictionary = game_state.get_entity_dict(entity_id)
		if game_state.get_entity_owner_id(entity) != owner_id:
			continue
		if not game_state.get_entity_is_constructed(entity):
			continue
		queued_units += _combat_queue_count_for_producer(game_state, entity)
	return queued_units


static func _count_blocked_producers(game_state: GameState, owner_id: int) -> int:
	var blocked_count: int = 0
	for entity_id in game_state.get_entities_by_type("stockpile"):
		var entity: Dictionary = game_state.get_entity_dict(entity_id)
		if game_state.get_entity_owner_id(entity) != owner_id:
			continue
		if game_state.get_entity_is_production_blocked(entity):
			blocked_count += 1
	for entity_id in game_state.get_entities_by_type("structure"):
		var entity: Dictionary = game_state.get_entity_dict(entity_id)
		if game_state.get_entity_owner_id(entity) != owner_id:
			continue
		if not game_state.get_entity_is_constructed(entity):
			continue
		if game_state.get_entity_is_production_blocked(entity):
			blocked_count += 1
	return blocked_count


static func _combat_queue_count_for_producer(game_state: GameState, producer_entity: Dictionary) -> int:
	var structure_type: String = game_state.get_entity_structure_type(producer_entity)
	var produced_unit_type: String = GameDefinitionsClass.get_structure_produces(structure_type)
	if produced_unit_type == "":
		return 0
	if not GameDefinitionsClass.unit_type_can_attack(produced_unit_type):
		return 0
	return game_state.get_entity_production_queue_count(producer_entity)


## Army pipeline readiness: how many player combat units are at each stage.
## deployed = in active combat (to_target / attacking)
## ready    = idle or standing — assembled, waiting for orders
## assembling = moving to rally point, not yet at position
static func _get_army_pipeline(game_state: GameState, owner_id: int) -> Dictionary:
	var deployed: int = 0
	var ready: int = 0
	var assembling: int = 0
	for entity_id in game_state.get_entities_by_type("unit"):
		var entity: Dictionary = game_state.get_entity_dict(entity_id)
		if game_state.get_entity_owner_id(entity) != owner_id:
			continue
		if not game_state.get_entity_can_attack(entity):
			continue
		var task: String = game_state.get_entity_task_state(entity)
		if task == "to_rally":
			assembling += 1
		elif task == "attacking" or task == "to_target":
			deployed += 1
		else:
			ready += 1
	return {"deployed": deployed, "ready": ready, "assembling": assembling}


## Ticks until all units in a producer's current queue have finished training.
## Returns 0 if queue is empty.
static func get_producer_batch_eta(game_state: GameState, producer_entity: Dictionary) -> int:
	var queue_count: int = game_state.get_entity_production_queue_count(producer_entity)
	if queue_count <= 0:
		return 0
	var duration: int = maxi(game_state.get_entity_production_duration_ticks(producer_entity), 1)
	var progress: int = game_state.get_entity_production_progress_ticks(producer_entity)
	var ticks_to_first: int = maxi(duration - progress, 0)
	return ticks_to_first + (queue_count - 1) * duration


## First combat unit type available from any constructed military producer.
## Used to give generic production feedback without hardcoding "soldier".
static func _get_available_combat_unit_type(game_state: GameState, owner_id: int) -> String:
	var producer_ids: Array[int] = []
	for entity_id in game_state.get_entities_by_type("stockpile"):
		producer_ids.append(entity_id)
	for entity_id in game_state.get_entities_by_type("structure"):
		producer_ids.append(entity_id)
	producer_ids.sort()
	for producer_id in producer_ids:
		var entity: Dictionary = game_state.get_entity_dict(producer_id)
		if game_state.get_entity_owner_id(entity) != owner_id:
			continue
		if game_state.get_entity_type(entity) == "structure" and not game_state.get_entity_is_constructed(entity):
			continue
		var structure_type: String = game_state.get_entity_structure_type(entity)
		var unit_type: String = GameDefinitionsClass.get_structure_produces(structure_type)
		if unit_type == "" or not GameDefinitionsClass.unit_type_can_attack(unit_type):
			continue
		return unit_type
	return ""
