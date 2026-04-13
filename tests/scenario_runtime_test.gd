extends SceneTree

const MatchConfigClass = preload("res://simulation/match_config.gd")
const GameDefinitionsClass = preload("res://simulation/game_definitions.gd")
const GameStateClass = preload("res://simulation/game_state.gd")
const ScenarioRuntimeClass = preload("res://simulation/scenario_runtime.gd")
const CommandBufferClass = preload("res://runtime/command_buffer.gd")
const ReplayLogClass = preload("res://runtime/replay_log.gd")
const StateHasherClass = preload("res://runtime/state_hasher.gd")
const TickManagerClass = preload("res://runtime/tick_manager.gd")
const PrototypeGameplayScript = preload("res://scenes/prototype_gameplay.gd")


func _init() -> void:
	var failures: Array[String] = []
	failures.append_array(run_scenario_initial_state_test())
	failures.append_array(run_timed_event_test())
	failures.append_array(run_state_triggered_objective_test())
	failures.append_array(run_hash_stability_test())
	if failures.is_empty():
		print("SCENARIO_RUNTIME_TEST: PASS")
	else:
		print("SCENARIO_RUNTIME_TEST: FAIL")
		for failure in failures:
			print("  FAIL: %s" % failure)
	quit()


func run_scenario_initial_state_test() -> Array[String]:
	var failures: Array[String] = []
	var cfg_a: MatchConfig = MatchConfigClass.new()
	var cfg_b: MatchConfig = MatchConfigClass.new()
	cfg_a.apply_scenario("ridge_breakout")
	cfg_b.apply_scenario("ridge_breakout")
	var state_a: GameState = _build_state_from_config(cfg_a)
	var state_b: GameState = _build_state_from_config(cfg_b)
	if state_a.serialize_canonical() != state_b.serialize_canonical():
		failures.append("[initial] Same scenario should build identical initial state.")
	return failures


func run_timed_event_test() -> Array[String]:
	var failures: Array[String] = []
	var cfg: MatchConfig = MatchConfigClass.new()
	cfg.apply_scenario("hold_the_valley")
	var state: GameState = _build_state_from_config(cfg)
	var tick_manager: TickManager = _make_tick_manager(state)
	for _i in range(471):
		tick_manager.advance_one_tick()
	var alerts: Array[Dictionary] = _get_alerts(state)
	var found_warning: bool = false
	var enemy_count: int = _count_enemy_units(state)
	for alert in alerts:
		var text: String = str(alert.get("text", ""))
		if text.find("Enemy raiders enter the valley") >= 0:
			found_warning = true
			break
	if not found_warning:
		failures.append("[timed] Expected valley raid alert by tick 470.")
	if enemy_count < 3:
		failures.append("[timed] Expected timed raid spawn to add enemy units.")
	return failures


func run_state_triggered_objective_test() -> Array[String]:
	var failures: Array[String] = []
	var cfg: MatchConfig = MatchConfigClass.new()
	cfg.apply_scenario("ridge_breakout")
	var state: GameState = _build_state_from_config(cfg)
	var barracks_id: int = state.allocate_entity_id()
	state.entities[barracks_id] = GameDefinitionsClass.create_structure_entity(
		"barracks",
		barracks_id,
		1,
		Vector2i(6, 11),
		true,
		0
	)
	state.rebuild_static_blocker_cache()
	var tick_manager: TickManager = _make_tick_manager(state)
	tick_manager.advance_one_tick()
	if not _objective_done(state, "build_barracks"):
		failures.append("[trigger] Barracks objective did not complete after structure existed.")
	var found_alert: bool = false
	for alert in _get_alerts(state):
		if str(alert.get("text", "")).find("Barracks ready") >= 0:
			found_alert = true
			break
	if not found_alert:
		failures.append("[trigger] Objective-complete alert did not fire for barracks objective.")
	return failures


func run_hash_stability_test() -> Array[String]:
	var failures: Array[String] = []
	var cfg_a: MatchConfig = MatchConfigClass.new()
	var cfg_b: MatchConfig = MatchConfigClass.new()
	cfg_a.apply_scenario("knife_pass_rush")
	cfg_b.apply_scenario("knife_pass_rush")
	var state_a: GameState = _build_state_from_config(cfg_a)
	var state_b: GameState = _build_state_from_config(cfg_b)
	var tm_a: TickManager = _make_tick_manager(state_a)
	var tm_b: TickManager = _make_tick_manager(state_b)
	for _i in range(360):
		tm_a.advance_one_tick()
		tm_b.advance_one_tick()
	if JSON.stringify(tm_a.authoritative_state_hash_history) != JSON.stringify(tm_b.authoritative_state_hash_history):
		failures.append("[hash] Scenario runtime hashes diverged under identical inputs.")
	return failures


func _make_tick_manager(state: GameState) -> TickManager:
	return TickManagerClass.new(
		state,
		CommandBufferClass.new(),
		ReplayLogClass.new(),
		StateHasherClass.new(),
		[ScenarioRuntimeClass.new()],
		[]
	)


func _build_state_from_config(cfg: MatchConfig) -> GameState:
	var gameplay := PrototypeGameplayScript.new()
	gameplay.set_match_config(cfg)
	var state: GameState = gameplay._create_initial_game_state()
	gameplay.queue_free()
	state.rebuild_static_blocker_cache()
	return state


func _get_alerts(state: GameState) -> Array[Dictionary]:
	var alerts: Array[Dictionary] = []
	var value: Variant = state.scenario_state.get("alerts", [])
	if not (value is Array):
		return alerts
	for item in value:
		if item is Dictionary:
			alerts.append(item)
	return alerts


func _count_enemy_units(state: GameState) -> int:
	var count: int = 0
	for entity_id in state.get_entities_by_type("unit"):
		var entity: Dictionary = state.get_entity_dict(entity_id)
		if state.get_entity_owner_id(entity) == 2:
			count += 1
	return count


func _objective_done(state: GameState, objective_id: String) -> bool:
	var value: Variant = state.scenario_state.get("objectives", [])
	if not (value is Array):
		return false
	for item in value:
		if not (item is Dictionary):
			continue
		var objective: Dictionary = item
		if str(objective.get("id", "")) == objective_id:
			return bool(objective.get("completed", false))
	return false
