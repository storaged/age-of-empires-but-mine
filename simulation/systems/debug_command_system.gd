class_name DebugCommandSystem
extends SimulationSystem

const DEBUG_INCREMENT_TYPE: String = "debug_increment"


func apply(game_state: GameState, commands_for_tick: Array[SimulationCommand], _tick: int) -> void:
	for command in commands_for_tick:
		if command.command_type != DEBUG_INCREMENT_TYPE:
			continue

		if command is DebugIncrementCommand:
			var increment_command: DebugIncrementCommand = command
			game_state.debug_counter += increment_command.amount
			game_state.executed_command_ids.append(increment_command.debug_command_id)
