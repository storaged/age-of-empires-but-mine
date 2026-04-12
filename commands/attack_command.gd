class_name AttackCommand
extends SimulationCommand

var unit_id: int
var target_id: int


func _init(
	initial_scheduled_tick: int = 0,
	initial_issuer_id: int = 0,
	initial_sequence_number: int = 0,
	initial_unit_id: int = 0,
	initial_target_id: int = 0
) -> void:
	super(initial_scheduled_tick, initial_issuer_id, initial_sequence_number, "attack")
	unit_id = initial_unit_id
	target_id = initial_target_id


func to_record() -> Dictionary:
	var record: Dictionary = super.to_record()
	record["unit_id"] = unit_id
	record["target_id"] = target_id
	return record
