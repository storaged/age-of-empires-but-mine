class_name ReplayLog
extends RefCounted

## Minimal replay log for command stream and authoritative state hashes.

var enqueued_commands: Array[Dictionary] = []
var executed_commands: Array[Dictionary] = []
var authoritative_state_hashes: Array[Dictionary] = []


func record_enqueued(command: SimulationCommand) -> void:
	enqueued_commands.append(command.to_record())


func record_executed(execution_tick: int, command: SimulationCommand) -> void:
	var entry: Dictionary = command.to_record()
	entry["execution_tick"] = execution_tick
	executed_commands.append(entry)


func record_authoritative_state_hash(completed_tick: int, authoritative_state_hash: String) -> void:
	authoritative_state_hashes.append({
		"completed_tick": completed_tick,
		"authoritative_state_hash": authoritative_state_hash,
	})
