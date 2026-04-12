class_name MoveUnitCommand
extends SimulationCommand

var unit_id: int
var target_cell: Vector2i


func _init(
	initial_scheduled_tick: int = 0,
	initial_issuer_id: int = 0,
	initial_sequence_number: int = 0,
	initial_unit_id: int = 0,
	initial_target_cell: Vector2i = Vector2i.ZERO
) -> void:
	super(initial_scheduled_tick, initial_issuer_id, initial_sequence_number, "move_unit")
	unit_id = initial_unit_id
	target_cell = initial_target_cell


func to_record() -> Dictionary:
	var record: Dictionary = super.to_record()
	record["unit_id"] = unit_id
	record["target_cell"] = [target_cell.x, target_cell.y]
	return record
