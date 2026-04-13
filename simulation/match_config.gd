class_name MatchConfig
extends RefCounted

const AIPresetsClass = preload("res://simulation/presets/ai_presets.gd")
const ColorPresetsClass = preload("res://simulation/presets/color_presets.gd")
const MapPresetsClass = preload("res://simulation/presets/map_presets.gd")
const EnemyPlanDefinitionsClass = preload("res://simulation/enemy_plans/enemy_plan_definitions.gd")
const MapDefinitionsClass = preload("res://simulation/maps/map_definitions.gd")
const ScenarioDefinitionsClass = preload("res://simulation/scenarios/scenario_definitions.gd")

## Canonical source of match-level configuration.
## Pass one instance from the pregame screen into the gameplay scene.
## All fields have defaults so the game launches without explicit configuration.

var scenario_id: String = ScenarioDefinitionsClass.DEFAULT_SCENARIO_ID
var scenario_title: String = ""
var scenario_subtitle: String = ""
var scenario_briefing: String = ""
var scenario_map_id: String = MapDefinitionsClass.DEFAULT_MAP_ID
var scenario_enemy_plan_id: String = EnemyPlanDefinitionsClass.DEFAULT_ENEMY_PLAN_ID
var scenario_objectives: Array[Dictionary] = []
var scenario_events: Array[Dictionary] = []
var scenario_victory_condition: Dictionary = {}
var scenario_defeat_condition: Dictionary = {}
var starting_resources: Dictionary = {}
var player_start_structures: Array[Dictionary] = []
var player_start_units: Array[Dictionary] = []
var enemy_start_structures: Array[Dictionary] = []
var enemy_start_units: Array[Dictionary] = []

var map_preset_id: String = MapPresetsClass.DEFAULT_MAP_PRESET_ID
var ai_aggression_preset_id: String = AIPresetsClass.DEFAULT_AI_PRESET_ID
var color_preset_id: String = ColorPresetsClass.DEFAULT_COLOR_PRESET_ID
var map_display_name: String = ""
var ai_aggression_display_name: String = ""
var color_display_name: String = ""

# ── map ──────────────────────────────────────────────────────────────────────
var map_width: int = 20
var map_height: int = 14
var blocked_cells: Array[Vector2i] = []
var player_stockpile_cell: Vector2i = Vector2i(2, 2)
var player_worker_cells: Array[Vector2i] = []
var enemy_base_cell: Vector2i = Vector2i(17, 8)
var enemy_producer_type: String = "barracks"
var enemy_producer_cell: Vector2i = Vector2i(15, 9)
var enemy_unit_cells: Array[Vector2i] = []
var resource_nodes: Array[Dictionary] = []

# ── colors (player faction 1) ─────────────────────────────────────────────────
var player_soldier_color: Color = Color("#4a7fc1")
var player_unit_color: Color = Color("#d6d2c4")
var player_archer_color: Color = Color("#2ec4b6")
var player_stockpile_color: Color = Color("#3a6ea5")

# ── colors (enemy faction 2) ──────────────────────────────────────────────────
var enemy_unit_color: Color = Color("#e84a1e")
var enemy_structure_color: Color = Color("#c93a1a")

# ── AI timing ────────────────────────────────────────────────────────────────
var ai_production_start_tick: int = 180
var ai_production_interval_ticks: int = 55
var ai_attack_start_tick: int = 420
var ai_attack_wave_interval_ticks: int = 120
var ai_min_attackers_per_wave: int = 3


func _init() -> void:
	apply_scenario(scenario_id)
	apply_color_preset(color_preset_id)


func apply_scenario(next_scenario_id: String) -> void:
	var scenario: Dictionary = ScenarioDefinitionsClass.get_definition(next_scenario_id)
	scenario_id = next_scenario_id
	scenario_title = str(scenario.get("title", scenario_id))
	scenario_subtitle = str(scenario.get("subtitle", ""))
	scenario_briefing = str(scenario.get("briefing", ""))
	scenario_map_id = str(scenario.get("map_id", MapDefinitionsClass.DEFAULT_MAP_ID))
	scenario_enemy_plan_id = str(scenario.get("enemy_plan_id", EnemyPlanDefinitionsClass.DEFAULT_ENEMY_PLAN_ID))
	scenario_objectives = _copy_dict_array(scenario.get("objectives", []))
	scenario_events = _copy_dict_array(scenario.get("events", []))
	scenario_victory_condition = _copy_dictionary(scenario.get("victory_condition", {}))
	scenario_defeat_condition = _copy_dictionary(scenario.get("defeat_condition", {}))
	starting_resources = _copy_dictionary(scenario.get("starting_resources", {}))

	var player_layout: Dictionary = _copy_dictionary(scenario.get("player_layout", {}))
	var enemy_layout: Dictionary = _copy_dictionary(scenario.get("enemy_layout", {}))
	player_start_structures = _copy_dict_array(player_layout.get("structures", []))
	player_start_units = _copy_dict_array(player_layout.get("units", []))
	enemy_start_structures = _copy_dict_array(enemy_layout.get("structures", []))
	enemy_start_units = _copy_dict_array(enemy_layout.get("units", []))

	apply_map_definition(scenario_map_id)
	apply_enemy_plan(scenario_enemy_plan_id)
	_sync_legacy_layout_fields()


func apply_map_definition(map_id: String) -> void:
	var definition: Dictionary = MapDefinitionsClass.get_map(map_id)
	scenario_map_id = map_id
	map_preset_id = map_id
	map_display_name = str(definition.get("display_name", map_id))
	map_width = int(definition.get("map_width", map_width))
	map_height = int(definition.get("map_height", map_height))
	blocked_cells = _copy_vector2i_array(definition.get("blocked_cells", []))
	resource_nodes = _copy_resource_nodes(definition.get("resource_nodes", []))


func apply_enemy_plan(plan_id: String) -> void:
	var definition: Dictionary = EnemyPlanDefinitionsClass.get_plan(plan_id)
	scenario_enemy_plan_id = plan_id
	ai_aggression_preset_id = plan_id
	ai_aggression_display_name = str(definition.get("display_name", plan_id))
	ai_production_start_tick = int(definition.get("ai_production_start_tick", ai_production_start_tick))
	ai_production_interval_ticks = int(definition.get("ai_production_interval_ticks", ai_production_interval_ticks))
	ai_attack_start_tick = int(definition.get("ai_attack_start_tick", ai_attack_start_tick))
	ai_attack_wave_interval_ticks = int(definition.get("ai_attack_wave_interval_ticks", ai_attack_wave_interval_ticks))
	ai_min_attackers_per_wave = int(definition.get("ai_min_attackers_per_wave", ai_min_attackers_per_wave))


func apply_map_preset(preset_id: String) -> void:
	if not MapPresetsClass.PRESETS.has(preset_id):
		preset_id = MapPresetsClass.DEFAULT_MAP_PRESET_ID
	var preset: Dictionary = MapPresetsClass.get_preset(preset_id)
	map_preset_id = preset_id
	map_display_name = str(preset.get("display_name", map_preset_id))
	map_width = int(preset.get("map_width", map_width))
	map_height = int(preset.get("map_height", map_height))
	blocked_cells = _copy_vector2i_array(preset.get("blocked_cells", []))
	player_stockpile_cell = _get_vector2i(preset, "player_stockpile_cell", player_stockpile_cell)
	player_worker_cells = _copy_vector2i_array(preset.get("player_worker_cells", []))
	enemy_base_cell = _get_vector2i(preset, "enemy_base_cell", enemy_base_cell)
	enemy_producer_type = str(preset.get("enemy_producer_type", enemy_producer_type))
	enemy_producer_cell = _get_vector2i(preset, "enemy_producer_cell", enemy_producer_cell)
	enemy_unit_cells = _copy_vector2i_array(preset.get("enemy_unit_cells", []))
	resource_nodes = _copy_resource_nodes(preset.get("resource_nodes", []))
	_sync_layout_arrays_from_legacy_fields()


func apply_ai_aggression_preset(preset_id: String) -> void:
	if not AIPresetsClass.PRESETS.has(preset_id):
		preset_id = AIPresetsClass.DEFAULT_AI_PRESET_ID
	var preset: Dictionary = AIPresetsClass.get_preset(preset_id)
	ai_aggression_preset_id = preset_id
	ai_aggression_display_name = str(preset.get("display_name", ai_aggression_preset_id))
	ai_production_start_tick = int(preset.get("ai_production_start_tick", ai_production_start_tick))
	ai_production_interval_ticks = int(preset.get("ai_production_interval_ticks", ai_production_interval_ticks))
	ai_attack_start_tick = int(preset.get("ai_attack_start_tick", ai_attack_start_tick))
	ai_attack_wave_interval_ticks = int(preset.get("ai_attack_wave_interval_ticks", ai_attack_wave_interval_ticks))
	ai_min_attackers_per_wave = int(preset.get("ai_min_attackers_per_wave", ai_min_attackers_per_wave))


func apply_color_preset(preset_id: String) -> void:
	if not ColorPresetsClass.PRESETS.has(preset_id):
		preset_id = ColorPresetsClass.DEFAULT_COLOR_PRESET_ID
	var preset: Dictionary = ColorPresetsClass.get_preset(preset_id)
	color_preset_id = preset_id
	color_display_name = str(preset.get("display_name", color_preset_id))
	player_unit_color = _get_color(preset, "player_unit_color", player_unit_color)
	player_soldier_color = _get_color(preset, "player_soldier_color", player_soldier_color)
	player_archer_color = _get_color(preset, "player_archer_color", player_archer_color)
	player_stockpile_color = _get_color(preset, "player_stockpile_color", player_stockpile_color)
	enemy_unit_color = _get_color(preset, "enemy_unit_color", enemy_unit_color)
	enemy_structure_color = _get_color(preset, "enemy_structure_color", enemy_structure_color)


func build_summary_text() -> String:
	return "%s\n%s\nMap: %s  |  Enemy plan: %s  |  Colors: %s" % [
		scenario_title,
		scenario_subtitle,
		map_display_name,
		ai_aggression_display_name,
		color_display_name,
	]


func build_objective_preview_text() -> String:
	var lines: Array[String] = []
	for objective in scenario_objectives:
		lines.append("- %s" % str(objective.get("text", "")))
	return "\n".join(lines)


func build_briefing_text() -> String:
	return "%s\n\nObjectives:\n%s" % [scenario_briefing, build_objective_preview_text()]


func _copy_vector2i_array(value: Variant) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	if not (value is Array):
		return cells
	for item in value:
		if item is Vector2i:
			cells.append(item)
	return cells


func _copy_resource_nodes(value: Variant) -> Array[Dictionary]:
	var nodes: Array[Dictionary] = []
	if not (value is Array):
		return nodes
	for item in value:
		if item is Dictionary:
			nodes.append(item.duplicate(true))
	return nodes


func _copy_dict_array(value: Variant) -> Array[Dictionary]:
	var items: Array[Dictionary] = []
	if not (value is Array):
		return items
	for item in value:
		if item is Dictionary:
			items.append(item.duplicate(true))
	return items


func _copy_dictionary(value: Variant) -> Dictionary:
	if value is Dictionary:
		return value.duplicate(true)
	return {}


func _get_vector2i(data: Dictionary, key: String, fallback: Vector2i) -> Vector2i:
	var value: Variant = data.get(key, fallback)
	if value is Vector2i:
		return value
	return fallback


func _get_color(data: Dictionary, key: String, fallback: Color) -> Color:
	var value: Variant = data.get(key, fallback)
	if value is Color:
		return value
	return fallback


func _sync_legacy_layout_fields() -> void:
	player_stockpile_cell = _first_structure_cell(player_start_structures, "stockpile", player_stockpile_cell)
	player_worker_cells = _extract_unit_cells(player_start_units, "worker")
	enemy_base_cell = _first_structure_cell(enemy_start_structures, "enemy_base", enemy_base_cell)
	enemy_producer_type = _first_enemy_producer_type(enemy_start_structures, enemy_producer_type)
	enemy_producer_cell = _first_enemy_producer_cell(enemy_start_structures, enemy_producer_cell)
	enemy_unit_cells = _extract_all_unit_cells(enemy_start_units)


func _sync_layout_arrays_from_legacy_fields() -> void:
	player_start_structures = [
		{"structure_type": "stockpile", "cell": player_stockpile_cell},
	]
	player_start_units = []
	for cell in player_worker_cells:
		player_start_units.append({"unit_type": "worker", "cell": cell})
	enemy_start_structures = [
		{"structure_type": "enemy_base", "cell": enemy_base_cell},
		{"structure_type": enemy_producer_type, "cell": enemy_producer_cell},
	]
	enemy_start_units = []
	for cell in enemy_unit_cells:
		enemy_start_units.append({"unit_type": "enemy_dummy", "cell": cell})


func _first_structure_cell(layout: Array[Dictionary], structure_type: String, fallback: Vector2i) -> Vector2i:
	for entry in layout:
		if str(entry.get("structure_type", "")) != structure_type:
			continue
		var cell_value: Variant = entry.get("cell", fallback)
		if cell_value is Vector2i:
			return cell_value
	return fallback


func _first_enemy_producer_type(layout: Array[Dictionary], fallback: String) -> String:
	for entry in layout:
		var structure_type: String = str(entry.get("structure_type", ""))
		if structure_type != "" and structure_type != "enemy_base":
			return structure_type
	return fallback


func _first_enemy_producer_cell(layout: Array[Dictionary], fallback: Vector2i) -> Vector2i:
	for entry in layout:
		var structure_type: String = str(entry.get("structure_type", ""))
		if structure_type == "" or structure_type == "enemy_base":
			continue
		var cell_value: Variant = entry.get("cell", fallback)
		if cell_value is Vector2i:
			return cell_value
	return fallback


func _extract_unit_cells(layout: Array[Dictionary], unit_type: String) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for entry in layout:
		if str(entry.get("unit_type", "")) != unit_type:
			continue
		var cell_value: Variant = entry.get("cell", Vector2i.ZERO)
		if cell_value is Vector2i:
			cells.append(cell_value)
	return cells


func _extract_all_unit_cells(layout: Array[Dictionary]) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for entry in layout:
		var cell_value: Variant = entry.get("cell", Vector2i.ZERO)
		if cell_value is Vector2i:
			cells.append(cell_value)
	return cells
