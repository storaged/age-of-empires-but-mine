class_name GatherResourceCommand
extends SimulationCommand

var unit_id: int
var resource_node_id: int


func _init(
	initial_scheduled_tick: int = 0,
	initial_issuer_id: int = 0,
	initial_sequence_number: int = 0,
	initial_unit_id: int = 0,
	initial_resource_node_id: int = 0
) -> void:
	super(initial_scheduled_tick, initial_issuer_id, initial_sequence_number, "gather_resource")
	unit_id = initial_unit_id
	resource_node_id = initial_resource_node_id


func to_record() -> Dictionary:
	var record: Dictionary = super.to_record()
	record["unit_id"] = unit_id
	record["resource_node_id"] = resource_node_id
	return record
