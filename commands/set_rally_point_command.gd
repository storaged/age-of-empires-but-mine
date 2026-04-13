class_name SetRallyPointCommand
extends SimulationCommand

var producer_entity_id: int
var rally_mode: String
var rally_cell: Vector2i
var rally_target_id: int


func _init(
	initial_scheduled_tick: int = 0,
	initial_issuer_id: int = 0,
	initial_sequence_number: int = 0,
	initial_producer_entity_id: int = 0,
	initial_rally_mode: String = "",
	initial_rally_cell: Vector2i = Vector2i(-1, -1),
	initial_rally_target_id: int = 0
) -> void:
	super(initial_scheduled_tick, initial_issuer_id, initial_sequence_number, "set_rally_point")
	producer_entity_id = initial_producer_entity_id
	rally_mode = initial_rally_mode
	rally_cell = initial_rally_cell
	rally_target_id = initial_rally_target_id


func to_record() -> Dictionary:
	var record: Dictionary = super.to_record()
	record["producer_entity_id"] = producer_entity_id
	record["rally_mode"] = rally_mode
	record["rally_cell"] = rally_cell
	record["rally_target_id"] = rally_target_id
	return record
