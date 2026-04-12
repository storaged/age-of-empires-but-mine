class_name BuildStructureCommand
extends SimulationCommand

var builder_unit_id: int
var structure_type: String
var target_cell: Vector2i


func _init(
	initial_scheduled_tick: int = 0,
	initial_issuer_id: int = 0,
	initial_sequence_number: int = 0,
	initial_builder_unit_id: int = 0,
	initial_structure_type: String = "",
	initial_target_cell: Vector2i = Vector2i.ZERO
) -> void:
	super(initial_scheduled_tick, initial_issuer_id, initial_sequence_number, "build_structure")
	builder_unit_id = initial_builder_unit_id
	structure_type = initial_structure_type
	target_cell = initial_target_cell


func to_record() -> Dictionary:
	var record: Dictionary = super.to_record()
	record["builder_unit_id"] = builder_unit_id
	record["structure_type"] = structure_type
	record["target_cell"] = [target_cell.x, target_cell.y]
	return record
