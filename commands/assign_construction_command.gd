class_name AssignConstructionCommand
extends SimulationCommand

var unit_id: int
var structure_id: int


func _init(
	initial_scheduled_tick: int = 0,
	initial_issuer_id: int = 0,
	initial_sequence_number: int = 0,
	initial_unit_id: int = 0,
	initial_structure_id: int = 0
) -> void:
	super(initial_scheduled_tick, initial_issuer_id, initial_sequence_number, "assign_construction")
	unit_id = initial_unit_id
	structure_id = initial_structure_id


func to_record() -> Dictionary:
	var record: Dictionary = super.to_record()
	record["unit_id"] = unit_id
	record["structure_id"] = structure_id
	return record
