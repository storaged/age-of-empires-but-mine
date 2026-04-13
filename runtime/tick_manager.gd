class_name TickManager
extends RefCounted

## Fixed-step runtime loop.
## Simulation changes happen only inside advance_one_tick.

const MICROSECONDS_PER_SECOND: int = 1000000

var ticks_per_second: int = 10
var accumulator_microseconds: int = 0

var game_state: GameState
var command_buffer: CommandBuffer
var replay_log: ReplayLog
var state_hasher: StateHasher
var systems: Array[SimulationSystem] = []
var controllers: Array[RefCounted] = []
var authoritative_state_hash_history: Array[String] = []


func _init(
	initial_game_state: GameState,
	initial_command_buffer: CommandBuffer,
	initial_replay_log: ReplayLog,
	initial_state_hasher: StateHasher,
	initial_systems: Array[SimulationSystem] = [],
	initial_controllers: Array[RefCounted] = []
) -> void:
	game_state = initial_game_state
	command_buffer = initial_command_buffer
	replay_log = initial_replay_log
	state_hasher = initial_state_hasher
	systems = initial_systems
	controllers = initial_controllers


func queue_command(command: SimulationCommand) -> void:
	command_buffer.enqueue(command)
	replay_log.record_enqueued(command)


func advance_by_time(delta_seconds: float) -> Array[Dictionary]:
	var completed_steps: Array[Dictionary] = []
	accumulator_microseconds += roundi(delta_seconds * float(MICROSECONDS_PER_SECOND))

	while accumulator_microseconds >= get_fixed_step_microseconds():
		accumulator_microseconds -= get_fixed_step_microseconds()
		completed_steps.append(advance_one_tick())

	return completed_steps


func advance_one_tick() -> Dictionary:
	var execution_tick: int = game_state.current_tick
	_queue_controller_commands(execution_tick + 1)
	var commands_for_tick: Array[SimulationCommand] = command_buffer.pop_commands_for_tick(execution_tick)

	for command in commands_for_tick:
		replay_log.record_executed(execution_tick, command)

	for system in systems:
		system.apply(game_state, commands_for_tick, execution_tick)

	game_state.current_tick += 1

	var authoritative_state_hash: String = state_hasher.compute_authoritative_state_hash(game_state)
	authoritative_state_hash_history.append(authoritative_state_hash)
	replay_log.record_authoritative_state_hash(execution_tick, authoritative_state_hash)

	return {
		"completed_tick": execution_tick,
		"executed_command_count": commands_for_tick.size(),
		"authoritative_state_hash": authoritative_state_hash,
		"current_tick": game_state.current_tick,
		"debug_counter": game_state.debug_counter,
	}


func _queue_controller_commands(scheduled_tick: int) -> void:
	for controller in controllers:
		if controller == null:
			continue
		if not controller.has_method("build_commands_for_tick"):
			continue
		var command_values: Variant = controller.call("build_commands_for_tick", game_state, scheduled_tick)
		if not (command_values is Array):
			continue
		for command_value in command_values:
			if command_value is SimulationCommand:
				queue_command(command_value)


func get_fixed_step_microseconds() -> int:
	assert(ticks_per_second > 0, "ticks_per_second must be positive.")
	return int(round(float(MICROSECONDS_PER_SECOND) / float(ticks_per_second)))


func get_tick_progress() -> float:
	var fixed_step_microseconds: int = get_fixed_step_microseconds()
	if fixed_step_microseconds <= 0:
		return 0.0

	return clampf(
		float(accumulator_microseconds) / float(fixed_step_microseconds),
		0.0,
		1.0
	)
