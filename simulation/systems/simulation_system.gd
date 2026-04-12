class_name SimulationSystem
extends RefCounted

## Base interface for authoritative simulation systems.


func apply(_game_state: GameState, _commands_for_tick: Array[SimulationCommand], _tick: int) -> void:
	pass
