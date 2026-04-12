class_name CommandBuffer
extends RefCounted

## Tick-stamped command queue with deterministic ordering inside each tick.

var _commands_by_tick: Dictionary = {}


func enqueue(command: SimulationCommand) -> void:
	assert(command.is_valid(), "Command must have non-negative scheduled tick.")

	var bucket: Array[SimulationCommand] = get_commands_for_tick(command.scheduled_tick)
	bucket.append(command)
	bucket.sort_custom(Callable(self, "_sort_commands"))
	_commands_by_tick[command.scheduled_tick] = bucket


func pop_commands_for_tick(tick: int) -> Array[SimulationCommand]:
	if not _commands_by_tick.has(tick):
		return []

	var commands: Array[SimulationCommand] = get_commands_for_tick(tick)
	_commands_by_tick.erase(tick)
	return commands


func get_commands_for_tick(tick: int) -> Array[SimulationCommand]:
	if not _commands_by_tick.has(tick):
		return []

	var commands: Array[SimulationCommand] = []
	var bucket_value: Variant = _commands_by_tick[tick]
	if not (bucket_value is Array):
		return commands

	for command_value in bucket_value:
		if command_value is SimulationCommand:
			commands.append(command_value)
	return commands


func has_commands_for_tick(tick: int) -> bool:
	return _commands_by_tick.has(tick)


func get_debug_records() -> Array[Dictionary]:
	var ticks: Array = _commands_by_tick.keys()
	ticks.sort()

	var records: Array[Dictionary] = []
	for tick in ticks:
		for command in get_commands_for_tick(tick):
			records.append(command.to_record())

	return records


func _sort_commands(left: SimulationCommand, right: SimulationCommand) -> bool:
	var left_key: Array = left.sort_key()
	var right_key: Array = right.sort_key()
	return left_key < right_key
