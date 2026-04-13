extends SceneTree

const PregameScene: PackedScene = preload("res://scenes/pregame.tscn")
const MatchConfigClass = preload("res://simulation/match_config.gd")
const ScenarioDefinitionsClass = preload("res://simulation/scenarios/scenario_definitions.gd")
const ColorPresetsClass = preload("res://simulation/presets/color_presets.gd")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var failures: Array[String] = []
	var scenario_ids: Array[String] = ScenarioDefinitionsClass.get_ids()
	var color_ids: Array[String] = ColorPresetsClass.get_ids()
	for scenario_id in scenario_ids:
		for color_id in color_ids:
			failures.append_array(await _run_start_flow_case(scenario_id, color_id))
	if failures.is_empty():
		print("PREGAME_START_FLOW_TEST: PASS")
	else:
		print("PREGAME_START_FLOW_TEST: FAIL")
		for failure in failures:
			print("  FAIL: %s" % failure)
	quit()


func _run_start_flow_case(scenario_id: String, color_id: String) -> Array[String]:
	var failures: Array[String] = []
	var pregame: Node = PregameScene.instantiate()
	root.add_child(pregame)
	current_scene = pregame
	await process_frame

	pregame.call("_on_scenario_selected", ScenarioDefinitionsClass.get_ids().find(scenario_id), ScenarioDefinitionsClass.get_ids())
	pregame.call("_on_colors_selected", ColorPresetsClass.get_ids().find(color_id), ColorPresetsClass.get_ids())
	await process_frame

	var start_button: Button = _find_start_button(pregame)
	if start_button == null:
		failures.append("[%s/%s] Start button not found." % [scenario_id, color_id])
		pregame.queue_free()
		await process_frame
		return failures
	var start_connections: Array = start_button.pressed.get_connections()
	var has_start_handler: bool = false
	for connection in start_connections:
		var callable_value: Variant = connection.get("callable", Callable())
		if callable_value is Callable:
			var signal_callable: Callable = callable_value
			if signal_callable.get_object() == pregame and signal_callable.get_method() == "_on_start_pressed":
				has_start_handler = true
				break
	if not has_start_handler:
		failures.append("[%s/%s] Start button is not wired to _on_start_pressed." % [scenario_id, color_id])
		pregame.queue_free()
		await process_frame
		return failures

	pregame.call("_on_start_pressed")

	if current_scene == null or current_scene.name != "PrototypeGameplay":
		failures.append("[%s/%s] Clicking Start Match did not enter gameplay." % [scenario_id, color_id])
	else:
		var match_config_value: Variant = current_scene.get("_match_config")
		if match_config_value == null:
			failures.append("[%s/%s] Gameplay scene missing MatchConfig." % [scenario_id, color_id])
		elif match_config_value is MatchConfigClass:
			var cfg: MatchConfigClass = match_config_value
			if cfg.scenario_id != scenario_id:
				failures.append("[%s/%s] Gameplay got wrong scenario id %s." % [scenario_id, color_id, cfg.scenario_id])
			if cfg.color_preset_id != color_id:
				failures.append("[%s/%s] Gameplay got wrong color preset %s." % [scenario_id, color_id, cfg.color_preset_id])
		else:
			failures.append("[%s/%s] Gameplay MatchConfig has wrong type." % [scenario_id, color_id])

	var gameplay_scene: Node = current_scene
	current_scene = null
	if gameplay_scene != null and is_instance_valid(gameplay_scene):
		if gameplay_scene.get_parent() != null:
			gameplay_scene.get_parent().remove_child(gameplay_scene)
		gameplay_scene.free()
	if is_instance_valid(pregame):
		if pregame.get_parent() != null:
			pregame.get_parent().remove_child(pregame)
		pregame.free()
	await process_frame
	return failures


func _find_start_button(node: Node) -> Button:
	if node is Button and (node as Button).text == "Start Match":
		return node
	for child in node.get_children():
		var found: Button = _find_start_button(child)
		if found != null:
			return found
	return null
