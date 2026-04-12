class_name QueueProductionCommand
extends SimulationCommand

var producer_entity_id: int
var produced_unit_type: String


func _init(
	initial_scheduled_tick: int = 0,
	initial_issuer_id: int = 0,
	initial_sequence_number: int = 0,
	initial_producer_entity_id: int = 0,
	initial_produced_unit_type: String = ""
) -> void:
	super(initial_scheduled_tick, initial_issuer_id, initial_sequence_number, "queue_production")
	producer_entity_id = initial_producer_entity_id
	produced_unit_type = initial_produced_unit_type


func to_record() -> Dictionary:
	var record: Dictionary = super.to_record()
	record["producer_entity_id"] = producer_entity_id
	record["produced_unit_type"] = produced_unit_type
	return record
