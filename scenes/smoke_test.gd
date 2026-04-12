extends Control

const GameStateClass = preload("res://simulation/game_state.gd")
const DebugCommandSystemClass = preload("res://simulation/systems/debug_command_system.gd")
const DebugIncrementCommandClass = preload("res://commands/debug_increment_command.gd")
const CommandBufferClass = preload("res://runtime/command_buffer.gd")
const ReplayLogClass = preload("res://runtime/replay_log.gd")
const StateHasherClass = preload("res://runtime/state_hasher.gd")
const TickManagerClass = preload("res://runtime/tick_manager.gd")

@onready var report_label: RichTextLabel = $MarginContainer/ReportLabel


func _ready() -> void:
	var result: Dictionary = run_smoke_demo()
	var report_text: String = _build_report_text(result)
	report_label.text = report_text
	print(report_text)

	var failures: Array[String] = _get_result_string_array(result, "failures")
	if failures.is_empty():
		print("PHASE1_SMOKE_TEST: PASS")
		return

	push_error("PHASE1_SMOKE_TEST: FAIL")
	for failure in failures:
		push_error(failure)


func run_smoke_demo() -> Dictionary:
	var game_state: GameState = GameStateClass.new()
	var command_buffer: CommandBuffer = CommandBufferClass.new()
	var replay_log: ReplayLog = ReplayLogClass.new()
	var state_hasher: StateHasher = StateHasherClass.new()
	var systems: Array[SimulationSystem] = []
	systems.append(DebugCommandSystemClass.new())
	var tick_manager: TickManager = TickManagerClass.new(
		game_state,
		command_buffer,
		replay_log,
		state_hasher,
		systems
	)

	var failures: Array[String] = []

	var tick_zero_command: DebugIncrementCommand = DebugIncrementCommandClass.new(0, 1, 0, "tick-0", 1)
	var tick_two_command: DebugIncrementCommand = DebugIncrementCommandClass.new(2, 1, 1, "tick-2", 3)
	tick_manager.queue_command(tick_zero_command)
	tick_manager.queue_command(tick_two_command)

	if game_state.debug_counter != 0:
		failures.append("Counter changed before simulation tick executed.")

	if not command_buffer.has_commands_for_tick(2):
		failures.append("Command for tick 2 not queued.")

	var step_results: Array[Dictionary] = []
	step_results.append(tick_manager.advance_one_tick())
	step_results.append(tick_manager.advance_one_tick())
	step_results.append(tick_manager.advance_one_tick())

	if _get_step_result_int(step_results, 0, "debug_counter") != 1:
		failures.append("Tick 0 command did not execute on tick 0.")

	if _get_step_result_int(step_results, 1, "debug_counter") != 1:
		failures.append("Simulation changed between ticks without queued command.")

	if _get_step_result_int(step_results, 2, "debug_counter") != 4:
		failures.append("Tick 2 command did not execute on tick 2.")

	if tick_manager.authoritative_state_hash_history.size() != 3:
		failures.append("Authoritative state hash not recorded after each simulation step.")

	return {
		"queued_commands": replay_log.enqueued_commands,
		"executed_commands": replay_log.executed_commands,
		"step_results": step_results,
		"final_authoritative_state": game_state.to_authoritative_dict(),
		"replay_log": replay_log,
		"failures": failures,
	}


func _build_report_text(result: Dictionary) -> String:
	var failures: Array[String] = _get_result_string_array(result, "failures")
	var queued_commands: Array[Dictionary] = _get_result_dictionary_array(result, "queued_commands")
	var executed_commands: Array[Dictionary] = _get_result_dictionary_array(result, "executed_commands")
	var step_results: Array[Dictionary] = _get_result_dictionary_array(result, "step_results")
	var final_authoritative_state: Dictionary = {}
	if result.has("final_authoritative_state"):
		var final_state_value: Variant = result["final_authoritative_state"]
		if final_state_value is Dictionary:
			final_authoritative_state = final_state_value

	var replay_log: ReplayLog = ReplayLog.new()
	if result.has("replay_log"):
		var replay_log_value: Variant = result["replay_log"]
		if replay_log_value is ReplayLog:
			replay_log = replay_log_value
	var lines: Array[String] = []

	lines.append("Phase 1 Deterministic Smoke Test")
	lines.append("")
	lines.append("Result: %s" % ("PASS" if failures.is_empty() else "FAIL"))
	lines.append("")
	lines.append("Queued Commands:")
	for command in queued_commands:
		lines.append("  %s" % JSON.stringify(command))

	lines.append("")
	lines.append("Executed Commands:")
	for command in executed_commands:
		lines.append("  %s" % JSON.stringify(command))

	lines.append("")
	lines.append("Per-Tick Results:")
	for step_index in range(step_results.size()):
		var step_result: Dictionary = _get_step_result_dictionary(step_results, step_index)
		lines.append(
			"  tick=%d current_tick=%d debug_counter=%d hash=%s" % [
				_get_dictionary_int(step_result, "completed_tick"),
				_get_dictionary_int(step_result, "current_tick"),
				_get_dictionary_int(step_result, "debug_counter"),
				_get_dictionary_string(step_result, "authoritative_state_hash"),
			]
		)

	lines.append("")
	lines.append("Current Authoritative State:")
	lines.append("  %s" % JSON.stringify(final_authoritative_state))

	lines.append("")
	lines.append("Replay Authoritative State Hashes:")
	for state_hash_entry in replay_log.authoritative_state_hashes:
		lines.append("  %s" % JSON.stringify(state_hash_entry))

	lines.append("")
	if failures.is_empty():
		lines.append("Failure Reasons: none")
	else:
		lines.append("Failure Reasons:")
		for failure in failures:
			lines.append("  - %s" % failure)

	return "\n".join(lines)


func _get_result_string_array(result: Dictionary, key: String) -> Array[String]:
	var values: Array[String] = []
	if not result.has(key):
		return values

	var result_value: Variant = result[key]
	if not (result_value is Array):
		return values

	for item in result_value:
		if item is String:
			values.append(item)
	return values


func _get_result_dictionary_array(result: Dictionary, key: String) -> Array[Dictionary]:
	var values: Array[Dictionary] = []
	if not result.has(key):
		return values

	var result_value: Variant = result[key]
	if not (result_value is Array):
		return values

	for item in result_value:
		if item is Dictionary:
			values.append(item)
	return values


func _get_step_result_int(step_results: Array[Dictionary], index: int, key: String) -> int:
	return _get_dictionary_int(_get_step_result_dictionary(step_results, index), key)


func _get_step_result_dictionary(step_results: Array[Dictionary], index: int) -> Dictionary:
	if index < 0 or index >= step_results.size():
		return {}
	var step_result_value: Variant = step_results[index]
	if step_result_value is Dictionary:
		return step_result_value
	return {}


func _get_dictionary_int(source: Dictionary, key: String) -> int:
	if not source.has(key):
		return 0

	var value: Variant = source[key]
	if value is int:
		return value
	return 0


func _get_dictionary_string(source: Dictionary, key: String) -> String:
	if not source.has(key):
		return ""

	var value: Variant = source[key]
	if value is String:
		return value
	return ""
