class_name ReturnCargoCommand
extends SimulationCommand

var unit_id: int
var stockpile_id: int


func _init(
	initial_scheduled_tick: int = 0,
	initial_issuer_id: int = 0,
	initial_sequence_number: int = 0,
	initial_unit_id: int = 0,
	initial_stockpile_id: int = 0
) -> void:
	super(initial_scheduled_tick, initial_issuer_id, initial_sequence_number, "return_cargo")
	unit_id = initial_unit_id
	stockpile_id = initial_stockpile_id


func to_record() -> Dictionary:
	var record: Dictionary = super.to_record()
	record["unit_id"] = unit_id
	record["stockpile_id"] = stockpile_id
	return record
