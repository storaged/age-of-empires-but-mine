class_name EnemyAIController
extends RefCounted

const AttackCommandClass = preload("res://commands/attack_command.gd")
const QueueProductionCommandClass = preload("res://commands/queue_production_command.gd")

const PRODUCTION_START_TICK: int = 120
const PRODUCTION_INTERVAL_TICKS: int = 45
const ATTACK_START_TICK: int = 260
const ATTACK_WAVE_INTERVAL_TICKS: int = 90
const MIN_ATTACKERS_PER_WAVE: int = 2

var issuer_id: int = 2
var controlled_owner_id: int = 2
var next_sequence_number: int = 0


func build_commands_for_tick(game_state: GameState, scheduled_tick: int) -> Array[SimulationCommand]:
	if game_state.win_condition_met or game_state.lose_condition_met:
		return []

	var commands: Array[SimulationCommand] = []
	commands.append_array(_build_production_commands(game_state, scheduled_tick))
	commands.append_array(_build_attack_commands(game_state, scheduled_tick))
	return commands


func get_status_text(game_state: GameState) -> String:
	if game_state.current_tick < PRODUCTION_START_TICK:
		return "Enemy scouting"
	if game_state.current_tick < ATTACK_START_TICK:
		return "Enemy mobilizing"
	if _is_wave_tick(game_state.current_tick):
		if _count_enemy_attackers(game_state) >= MIN_ATTACKERS_PER_WAVE:
			return "Enemy wave advancing"
		return "Enemy regrouping"
	return "Enemy pressure active"


func _build_production_commands(game_state: GameState, scheduled_tick: int) -> Array[SimulationCommand]:
	var commands: Array[SimulationCommand] = []
	if game_state.current_tick < PRODUCTION_START_TICK:
		return commands
	if not _is_production_tick(game_state.current_tick):
		return commands

	for structure_id in game_state.get_entities_by_type("structure"):
		var structure_entity: Dictionary = game_state.get_entity_dict(structure_id)
		if game_state.get_entity_owner_id(structure_entity) != controlled_owner_id:
			continue
		if not game_state.get_entity_is_constructed(structure_entity):
			continue
		if game_state.get_entity_structure_type(structure_entity) != "barracks":
			continue
		if game_state.get_entity_production_queue_count(structure_entity) > 0:
			continue

		commands.append(
			QueueProductionCommandClass.new(
				scheduled_tick,
				issuer_id,
				_next_sequence_number(),
				structure_id,
				"soldier"
			)
		)
		break
	return commands


func _build_attack_commands(game_state: GameState, scheduled_tick: int) -> Array[SimulationCommand]:
	var commands: Array[SimulationCommand] = []
	if game_state.current_tick < ATTACK_START_TICK:
		return commands
	if not _is_wave_tick(game_state.current_tick):
		return commands
	if _count_enemy_attackers(game_state) < MIN_ATTACKERS_PER_WAVE:
		return commands

	var player_base_id: int = _find_player_stockpile_id(game_state)
	if player_base_id == 0:
		return commands

	for unit_id in game_state.get_entities_by_type("unit"):
		var unit_entity: Dictionary = game_state.get_entity_dict(unit_id)
		if game_state.get_entity_owner_id(unit_entity) != controlled_owner_id:
			continue
		if not game_state.get_entity_can_attack(unit_entity):
			continue

		var current_target_id: int = game_state.get_entity_attack_target_id(unit_entity)
		var task_state: String = game_state.get_entity_task_state(unit_entity)
		if current_target_id == player_base_id and (task_state == "to_target" or task_state == "attacking"):
			continue

		commands.append(
			AttackCommandClass.new(
				scheduled_tick,
				issuer_id,
				_next_sequence_number(),
				unit_id,
				player_base_id
			)
		)
	return commands


func _count_enemy_attackers(game_state: GameState) -> int:
	var attacker_count: int = 0
	for unit_id in game_state.get_entities_by_type("unit"):
		var unit_entity: Dictionary = game_state.get_entity_dict(unit_id)
		if game_state.get_entity_owner_id(unit_entity) != controlled_owner_id:
			continue
		if not game_state.get_entity_can_attack(unit_entity):
			continue
		attacker_count += 1
	return attacker_count


func _is_production_tick(current_tick: int) -> bool:
	return current_tick >= PRODUCTION_START_TICK and (
		(current_tick - PRODUCTION_START_TICK) % PRODUCTION_INTERVAL_TICKS == 0
	)


func _is_wave_tick(current_tick: int) -> bool:
	return current_tick >= ATTACK_START_TICK and (
		(current_tick - ATTACK_START_TICK) % ATTACK_WAVE_INTERVAL_TICKS == 0
	)


func _find_player_stockpile_id(game_state: GameState) -> int:
	for stockpile_id in game_state.get_entities_by_type("stockpile"):
		var stockpile_entity: Dictionary = game_state.get_entity_dict(stockpile_id)
		if game_state.get_entity_owner_id(stockpile_entity) == 1:
			return stockpile_id
	return 0


func _next_sequence_number() -> int:
	var sequence_number: int = next_sequence_number
	next_sequence_number += 1
	return sequence_number
