class_name DebugIncrementCommand
extends SimulationCommand

var amount: int
var debug_command_id: String


func _init(
	initial_scheduled_tick: int = 0,
	initial_issuer_id: int = 0,
	initial_sequence_number: int = 0,
	initial_debug_command_id: String = "",
	initial_amount: int = 1
) -> void:
	super(initial_scheduled_tick, initial_issuer_id, initial_sequence_number, "debug_increment")
	amount = initial_amount
	debug_command_id = initial_debug_command_id


func to_record() -> Dictionary:
	var record: Dictionary = super.to_record()
	record["amount"] = amount
	record["debug_command_id"] = debug_command_id
	return record
