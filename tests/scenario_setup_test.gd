extends SceneTree

const ClientStateClass = preload("res://client/client_state.gd")
const MatchConfigClass = preload("res://simulation/match_config.gd")
const EnemyAIControllerClass = preload("res://simulation/enemy_ai_controller.gd")
const GameStateClass = preload("res://simulation/game_state.gd")
const RendererClass = preload("res://rendering/renderer.gd")
const PrototypeGameplayScript = preload("res://scenes/prototype_gameplay.gd")


func _init() -> void:
	var failures: Array[String] = []
	failures.append_array(run_map_preset_layout_test())
	failures.append_array(run_ai_aggression_preset_test())
	failures.append_array(run_color_transport_default_test())
	if failures.is_empty():
		print("SCENARIO_SETUP_TEST: PASS")
	else:
		print("SCENARIO_SETUP_TEST: FAIL")
		for failure in failures:
			print("  FAIL: %s" % failure)
	quit()


func run_map_preset_layout_test() -> Array[String]:
	var failures: Array[String] = []
	var classic_cfg: MatchConfig = MatchConfigClass.new()
	var ridge_cfg: MatchConfig = MatchConfigClass.new()
	ridge_cfg.apply_map_preset("split_ridge")

	var classic_state: GameState = _build_state_from_config(classic_cfg)
	var ridge_state: GameState = _build_state_from_config(ridge_cfg)

	if classic_state.get_map_width() == ridge_state.get_map_width():
		failures.append("[map] Expected different map widths between presets.")
	if JSON.stringify(classic_state.get_blocked_cells()) == JSON.stringify(ridge_state.get_blocked_cells()):
		failures.append("[map] Expected different blocked layouts between presets.")

	var classic_stockpile: Dictionary = classic_state.get_entity_dict(classic_state.get_entities_by_type("stockpile")[0])
	var ridge_stockpile: Dictionary = ridge_state.get_entity_dict(ridge_state.get_entities_by_type("stockpile")[0])
	if classic_state.get_entity_grid_position(classic_stockpile) == ridge_state.get_entity_grid_position(ridge_stockpile):
		failures.append("[map] Expected different player stockpile cells between presets.")
	return failures


func run_ai_aggression_preset_test() -> Array[String]:
	var failures: Array[String] = []
	var relaxed_cfg: MatchConfig = MatchConfigClass.new()
	var rush_cfg: MatchConfig = MatchConfigClass.new()
	relaxed_cfg.apply_ai_aggression_preset("relaxed")
	rush_cfg.apply_ai_aggression_preset("rush")

	var relaxed_ai: EnemyAIController = EnemyAIControllerClass.new()
	var rush_ai: EnemyAIController = EnemyAIControllerClass.new()
	relaxed_ai.configure(relaxed_cfg)
	rush_ai.configure(rush_cfg)

	var relaxed_timing: Dictionary = relaxed_ai.get_timing_config()
	var rush_timing: Dictionary = rush_ai.get_timing_config()
	if int(relaxed_timing.get("attack_start_tick", 0)) <= int(rush_timing.get("attack_start_tick", 0)):
		failures.append("[ai] Relaxed attack timing should start later than rush.")
	if int(relaxed_timing.get("production_start_tick", 0)) <= int(rush_timing.get("production_start_tick", 0)):
		failures.append("[ai] Relaxed production timing should start later than rush.")
	return failures


func run_color_transport_default_test() -> Array[String]:
	var failures: Array[String] = []
	var default_cfg: MatchConfig = MatchConfigClass.new()
	var custom_cfg: MatchConfig = MatchConfigClass.new()
	custom_cfg.apply_color_preset("emerald_vs_ember")

	var renderer: GameRenderer = RendererClass.new()
	renderer.configure(GameStateClass.new(), ClientStateClass.new(), 64, custom_cfg)
	if renderer.stockpile_color != custom_cfg.player_stockpile_color:
		failures.append("[color] Renderer did not receive player stockpile color from MatchConfig.")
	if renderer.enemy_structure_color != custom_cfg.enemy_structure_color:
		failures.append("[color] Renderer did not receive enemy structure color from MatchConfig.")
	if default_cfg.map_preset_id == "" or default_cfg.ai_aggression_preset_id == "" or default_cfg.color_preset_id == "":
		failures.append("[color] MatchConfig defaults are incomplete for direct gameplay launch.")
	renderer.free()
	return failures


func _build_state_from_config(cfg: MatchConfig) -> GameState:
	var gameplay := PrototypeGameplayScript.new()
	gameplay.set_match_config(cfg)
	var state: GameState = gameplay._create_initial_game_state()
	gameplay.queue_free()
	return state
