class_name SimulationCommand
extends RefCounted

## Validated command object.
## Intent only. Systems decide how command changes simulation state.

var scheduled_tick: int
var issuer_id: int
var sequence_number: int
var command_type: String


func _init(
	initial_scheduled_tick: int = 0,
	initial_issuer_id: int = 0,
	initial_sequence_number: int = 0,
	initial_command_type: String = "base"
) -> void:
	scheduled_tick = initial_scheduled_tick
	issuer_id = initial_issuer_id
	sequence_number = initial_sequence_number
	command_type = initial_command_type


func is_valid() -> bool:
	return scheduled_tick >= 0


func sort_key() -> Array:
	return [scheduled_tick, issuer_id, sequence_number, command_type]


func to_record() -> Dictionary:
	return {
		"scheduled_tick": scheduled_tick,
		"issuer_id": issuer_id,
		"sequence_number": sequence_number,
		"command_type": command_type,
	}
