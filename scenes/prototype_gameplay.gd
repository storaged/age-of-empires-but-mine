extends Node2D

const GameDefinitionsClass = preload("res://simulation/game_definitions.gd")
const EnemyAIControllerClass = preload("res://simulation/enemy_ai_controller.gd")
const MatchConfigClass = preload("res://simulation/match_config.gd")
const FoodReadinessClass = preload("res://simulation/food_readiness.gd")
const GameStateClass = preload("res://simulation/game_state.gd")
const StrategicTimingClass = preload("res://simulation/strategic_timing.gd")
const ScenarioRuntimeClass = preload("res://simulation/scenario_runtime.gd")
const DeterministicPathfinderClass = preload("res://simulation/deterministic_pathfinder.gd")
const BuildCommandSystemClass = preload("res://simulation/systems/build_command_system.gd")
const CombatSystemClass = preload("res://simulation/systems/combat_system.gd")
const GatherCommandSystemClass = preload("res://simulation/systems/gather_command_system.gd")
const MoveCommandSystemClass = preload("res://simulation/systems/move_command_system.gd")
const MovementSystemClass = preload("res://simulation/systems/movement_system.gd")
const ProductionSystemClass = preload("res://simulation/systems/production_system.gd")
const StructureEconomySystemClass = preload("res://simulation/systems/structure_economy_system.gd")
const WorkerEconomySystemClass = preload("res://simulation/systems/worker_economy_system.gd")
const CommandBufferClass = preload("res://runtime/command_buffer.gd")
const ReplayLogClass = preload("res://runtime/replay_log.gd")
const StateHasherClass = preload("res://runtime/state_hasher.gd")
const TickManagerClass = preload("res://runtime/tick_manager.gd")
const ClientStateClass = preload("res://client/client_state.gd")
const InputHandlerClass = preload("res://client/input_handler.gd")
const CommandPanelClass = preload("res://client/command_panel.gd")
const QueueProductionCommandClass = preload("res://commands/queue_production_command.gd")
const AssetCatalogClass = preload("res://rendering/asset_catalog.gd")

const CELL_SIZE: int = 64
const CAMERA_SPEED: float = 900.0
const DEFAULT_CAMERA_ZOOM: float = 0.82
const MIN_CAMERA_ZOOM: float = 0.55
const MAX_CAMERA_ZOOM: float = 1.45
const ZOOM_STEP: float = 0.08
const CLICK_SELECTION_THRESHOLD: float = 10.0

@onready var camera: Camera2D = $Camera2D
@onready var renderer: GameRenderer = $GameRenderer
@onready var status_label: RichTextLabel = $CanvasLayer/SummaryMargin/SummaryPanel/StatusLabel
@onready var debug_label: RichTextLabel = $CanvasLayer/DebugMargin/DebugPanel/DebugLabel

var _match_config: MatchConfigClass = null

var game_state: GameState
var command_buffer: CommandBuffer
var replay_log: ReplayLog
var state_hasher: StateHasher
var tick_manager: TickManager
var client_state: ClientState
var input_handler: InputHandler
var command_panel: Control
var enemy_ai_controller: EnemyAIController
var endgame_overlay: ColorRect
var endgame_label: Label
var mission_label: RichTextLabel
var alert_label: RichTextLabel
var show_debug_overlay: bool = false
var _shown_scenario_alert_count: int = 0
var _presentation_alerts: Array[Dictionary] = []
var _last_structure_constructed: Dictionary = {}
var _last_player_hp: Dictionary = {}
var _last_attack_alert_tick: int = -999
var _alert_player: AudioStreamPlayer

func set_match_config(cfg: MatchConfigClass) -> void:
	_match_config = cfg


func _ready() -> void:
	if _match_config == null:
		_match_config = MatchConfigClass.new()
	status_label.bbcode_enabled = true
	debug_label.bbcode_enabled = true
	game_state = _create_initial_game_state()
	game_state.rebuild_static_blocker_cache()
	command_buffer = CommandBufferClass.new()
	replay_log = ReplayLogClass.new()
	state_hasher = StateHasherClass.new()
	client_state = ClientStateClass.new()
	client_state.set_camera_zoom(DEFAULT_CAMERA_ZOOM)
	input_handler = InputHandlerClass.new()
	enemy_ai_controller = EnemyAIControllerClass.new()
	enemy_ai_controller.configure(_match_config)
	var systems: Array[SimulationSystem] = []
	systems.append(BuildCommandSystemClass.new())
	systems.append(MoveCommandSystemClass.new())
	systems.append(GatherCommandSystemClass.new())
	systems.append(CombatSystemClass.new())
	systems.append(MovementSystemClass.new())
	systems.append(WorkerEconomySystemClass.new())
	systems.append(StructureEconomySystemClass.new())
	systems.append(ProductionSystemClass.new())
	systems.append(ScenarioRuntimeClass.new())
	tick_manager = TickManagerClass.new(
		game_state,
		command_buffer,
		replay_log,
		state_hasher,
		systems,
		[enemy_ai_controller]
	)

	command_panel = CommandPanelClass.new()
	$CanvasLayer.add_child(command_panel)
	command_panel.build_requested.connect(_on_build_requested)
	command_panel.train_requested.connect(_on_train_requested)
	command_panel.debug_toggle_requested.connect(_on_debug_toggle_requested)
	command_panel.cancel_placement_requested.connect(_on_cancel_placement_requested)
	_create_endgame_overlay()
	_create_mission_hud()
	_apply_hud_skin()
	_prime_presentation_alert_state()

	client_state.set_camera_world_position(_map_center_world_position())
	_apply_camera_to_node()
	_sync_client_visuals_from_authoritative_state()

	renderer.configure(game_state, client_state, CELL_SIZE, _match_config)
	renderer.queue_redraw()
	_refresh_status_label()
	_refresh_mission_panel()
	command_panel.refresh(game_state, client_state)

func _process(delta: float) -> void:
	_update_camera_from_input(delta)
	input_handler.update_hover_from_world_position(
		get_global_mouse_position(),
		game_state,
		client_state,
		CELL_SIZE
	)

	var completed_steps: Array[Dictionary] = []
	if not game_state.is_game_over():
		completed_steps = tick_manager.advance_by_time(delta)
	if not completed_steps.is_empty():
		_sync_client_visuals_from_authoritative_state()
		_refresh_alert_feed()

	client_state.update_visual_interpolation(tick_manager.get_tick_progress())
	_apply_camera_to_node()
	_refresh_status_label()
	_refresh_mission_panel()
	_refresh_endgame_overlay()
	command_panel.refresh(game_state, client_state)
	renderer.queue_redraw()

func _unhandled_input(event: InputEvent) -> void:
	if game_state.is_game_over():
		return

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		var left_mouse_event: InputEventMouseButton = event
		if left_mouse_event.pressed:
			client_state.begin_drag_selection(get_global_mouse_position())
			renderer.queue_redraw()
			return

		var selection_rect: Rect2 = client_state.get_drag_world_rect()
		var is_click_selection: bool = selection_rect.size.length() <= CLICK_SELECTION_THRESHOLD
		client_state.end_drag_selection()

		if is_click_selection:
			input_handler.select_unit_at_world_position(
				get_global_mouse_position(),
				game_state,
				client_state,
				CELL_SIZE
			)
		else:
			client_state.set_selection(
				input_handler.build_selection_for_world_rect(
					selection_rect,
					game_state,
					client_state,
					CELL_SIZE
				)
			)

		_refresh_status_label()
		command_panel.refresh(game_state, client_state)
		renderer.queue_redraw()
		return

	if event is InputEventMouseMotion and client_state.is_drag_selecting:
		client_state.update_drag_selection(get_global_mouse_position())
		renderer.queue_redraw()
		return

	if event is InputEventMouseButton and event.pressed:
		var mouse_button_event: InputEventMouseButton = event
		if mouse_button_event.button_index == MOUSE_BUTTON_RIGHT:
			var commands: Array[SimulationCommand] = input_handler.build_commands_for_world_position(
				get_global_mouse_position(),
				game_state,
				client_state,
				CELL_SIZE,
				game_state.current_tick + 1
			)
			for command in commands:
				tick_manager.queue_command(command)
		elif mouse_button_event.button_index == MOUSE_BUTTON_WHEEL_UP:
			client_state.set_camera_zoom(maxf(MIN_CAMERA_ZOOM, client_state.camera_zoom - ZOOM_STEP))
		elif mouse_button_event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			client_state.set_camera_zoom(minf(MAX_CAMERA_ZOOM, client_state.camera_zoom + ZOOM_STEP))

		_apply_camera_to_node()
		_refresh_status_label()
		renderer.queue_redraw()
		return

	if event is InputEventKey and event.pressed and not event.echo:
		var key_event: InputEventKey = event
		if key_event.keycode == KEY_F3:
			_on_debug_toggle_requested()
		elif key_event.keycode == KEY_B:
			if client_state.is_in_structure_placement_mode():
				_on_cancel_placement_requested()
			else:
				_on_build_requested("house")
		elif key_event.keycode == KEY_F:
			if client_state.is_in_structure_placement_mode():
				_on_cancel_placement_requested()
			else:
				_on_build_requested("farm")
		elif key_event.keycode == KEY_N:
			if client_state.is_in_structure_placement_mode():
				_on_cancel_placement_requested()
			else:
				_on_build_requested("barracks")
		elif key_event.keycode == KEY_M:
			if client_state.is_in_structure_placement_mode():
				_on_cancel_placement_requested()
			else:
				_on_build_requested("archery_range")
		elif key_event.keycode == KEY_ESCAPE and client_state.is_in_structure_placement_mode():
			_on_cancel_placement_requested()
		elif key_event.keycode == KEY_Q:
			var production_commands: Array[SimulationCommand] = input_handler.build_production_commands_for_selection(
				game_state,
				client_state,
				game_state.current_tick + 1
			)
			for command in production_commands:
				tick_manager.queue_command(command)
			_refresh_status_label()
			command_panel.refresh(game_state, client_state)
			renderer.queue_redraw()

func _create_initial_game_state() -> GameState:
	var state: GameState = GameStateClass.new()
	state.resources = {
		"food": int(_match_config.starting_resources.get("food", 0)),
		"wood": int(_match_config.starting_resources.get("wood", 0)),
		"stone": int(_match_config.starting_resources.get("stone", 0)),
	}
	state.map_data = {
		"width": _match_config.map_width,
		"height": _match_config.map_height,
		"cell_size": CELL_SIZE,
		"blocked_cells": _build_blocked_cells_from_config(),
	}
	state.scenario_state = _build_initial_scenario_state()

	var player_stockpile_id: int = _spawn_start_structures(state, _match_config.player_start_structures, 1)
	_spawn_start_structures(state, _match_config.enemy_start_structures, 2)

	for resource_node in _match_config.resource_nodes:
		var resource_node_id: int = state.allocate_entity_id()
		var resource_cell: Vector2i = Vector2i.ZERO
		if resource_node.has("cell"):
			var resource_cell_value: Variant = resource_node["cell"]
			if resource_cell_value is Vector2i:
				resource_cell = resource_cell_value
		var resource_type: String = str(resource_node.get("type", "wood"))
		var resource_amount: int = int(resource_node.get("amount", 0))
		state.entities[resource_node_id] = GameDefinitionsClass.create_resource_node_entity(
			resource_type,
			resource_node_id,
			resource_cell,
			resource_amount
		)
		state.mark_static_blocker(resource_cell)
	_spawn_start_units(state, _match_config.player_start_units, 1, player_stockpile_id)
	_spawn_start_units(state, _match_config.enemy_start_units, 2, 0)
	return state


func _spawn_start_structures(state: GameState, layout: Array[Dictionary], owner_id: int) -> int:
	var first_stockpile_id: int = 0
	for entry in layout:
		var structure_type: String = str(entry.get("structure_type", ""))
		var cell_value: Variant = entry.get("cell", Vector2i.ZERO)
		if structure_type == "" or not (cell_value is Vector2i):
			continue
		var spawn_cell: Vector2i = DeterministicPathfinderClass.find_nearest_valid_structure_cell(state, cell_value)
		if spawn_cell == DeterministicPathfinderClass.INVALID_CELL:
			push_error("No valid structure spawn for %s at %s" % [structure_type, str(cell_value)])
			continue
		var entity_id: int = state.allocate_entity_id()
		var is_constructed: bool = bool(entry.get("is_constructed", true))
		state.entities[entity_id] = GameDefinitionsClass.create_structure_entity(
			structure_type,
			entity_id,
			owner_id,
			spawn_cell,
			is_constructed,
			0
		)
		state.reserve_cell(spawn_cell)
		if structure_type == "stockpile" and first_stockpile_id == 0:
			first_stockpile_id = entity_id
	return first_stockpile_id


func _spawn_start_units(
	state: GameState,
	layout: Array[Dictionary],
	owner_id: int,
	default_stockpile_id: int
) -> void:
	for entry in layout:
		var unit_type: String = str(entry.get("unit_type", ""))
		var cell_value: Variant = entry.get("cell", Vector2i.ZERO)
		if unit_type == "" or not (cell_value is Vector2i):
			continue
		var spawn_cell: Vector2i = DeterministicPathfinderClass.find_nearest_valid_unit_spawn_cell(state, cell_value)
		if spawn_cell == DeterministicPathfinderClass.INVALID_CELL:
			push_error("No valid unit spawn for %s at %s" % [unit_type, str(cell_value)])
			continue
		var producer_id: int = default_stockpile_id if unit_type == "worker" else 0
		var entity_id: int = state.allocate_entity_id()
		state.entities[entity_id] = GameDefinitionsClass.create_unit_entity(
			unit_type,
			entity_id,
			owner_id,
			spawn_cell,
			producer_id
		)
		state.occupancy[state.cell_key(spawn_cell)] = entity_id


func _build_initial_scenario_state() -> Dictionary:
	var objectives: Array[Dictionary] = []
	for objective in _match_config.scenario_objectives:
		var next_objective: Dictionary = objective.duplicate(true)
		next_objective["completed"] = false
		next_objective["completed_tick"] = -1
		objectives.append(next_objective)
	return {
		"id": _match_config.scenario_id,
		"title": _match_config.scenario_title,
		"subtitle": _match_config.scenario_subtitle,
		"briefing": _match_config.scenario_briefing,
		"enemy_plan_id": _match_config.scenario_enemy_plan_id,
		"objectives": objectives,
		"events": _match_config.scenario_events.duplicate(true),
		"victory_condition": _match_config.scenario_victory_condition.duplicate(true),
		"defeat_condition": _match_config.scenario_defeat_condition.duplicate(true),
		"alerts": [],
		"fired_event_ids": [],
	}

func _sync_client_visuals_from_authoritative_state() -> void:
	var valid_unit_ids: Array[int] = []
	var entity_ids: Array = game_state.entities.keys()
	entity_ids.sort()

	for entity_id in entity_ids:
		var entity: Dictionary = game_state.get_entity_dict(entity_id)
		if game_state.get_entity_type(entity) != "unit":
			continue

		valid_unit_ids.append(entity_id)
		var grid_position: Vector2i = game_state.get_entity_grid_position(entity)
		client_state.sync_visual_unit_target(
			entity_id,
			_cell_center_world(grid_position)
		)

	client_state.remove_missing_visual_units(valid_unit_ids)
	client_state.update_visual_interpolation(1.0)

func _update_camera_from_input(delta: float) -> void:
	var direction: Vector2 = Vector2.ZERO
	if Input.is_key_pressed(KEY_A):
		direction.x -= 1.0
	if Input.is_key_pressed(KEY_D):
		direction.x += 1.0
	if Input.is_key_pressed(KEY_W):
		direction.y -= 1.0
	if Input.is_key_pressed(KEY_S):
		direction.y += 1.0

	if direction == Vector2.ZERO:
		return

	var normalized_direction: Vector2 = direction.normalized()
	var next_position: Vector2 = client_state.camera_world_position + normalized_direction * CAMERA_SPEED * delta
	client_state.set_camera_world_position(_clamp_camera_world_position(next_position))

func _clamp_camera_world_position(world_position: Vector2) -> Vector2:
	var map_size: Vector2 = Vector2(game_state.get_map_width() * CELL_SIZE, game_state.get_map_height() * CELL_SIZE)
	return Vector2(
		clampf(world_position.x, 0.0, map_size.x),
		clampf(world_position.y, 0.0, map_size.y)
	)

func _apply_camera_to_node() -> void:
	camera.position = client_state.camera_world_position
	camera.zoom = Vector2.ONE * client_state.camera_zoom

func _map_center_world_position() -> Vector2:
	return Vector2(game_state.get_map_width() * CELL_SIZE, game_state.get_map_height() * CELL_SIZE) * 0.5

func _cell_center_world(cell: Vector2i) -> Vector2:
	return Vector2(
		(cell.x + 0.5) * CELL_SIZE,
		(cell.y + 0.5) * CELL_SIZE
	)

func _refresh_status_label() -> void:
	var lines: Array[String] = []
	var player_population_used: int = game_state.get_population_used(1)
	var player_population_queued: int = game_state.get_population_queued(1)
	var player_population_cap: int = game_state.get_population_cap(1)
	var strategic_summary: Dictionary = StrategicTimingClass.build_player_summary(game_state, 1)
	var food_summary: Dictionary = strategic_summary.get("food_summary", {})
	var timing_state: Dictionary = strategic_summary.get("timing_state", {})
	var pop_summary: String = "%d / %d" % [player_population_used, player_population_cap]
	if player_population_queued > 0:
		pop_summary = "%d + %dQ / %d" % [
			player_population_used,
			player_population_queued,
			player_population_cap,
		]

	lines.append("[b]Food[/b] %d   [b]Wood[/b] %d   [b]Stone[/b] %d   [b]Pop[/b] %s" % [
		game_state.get_resource_amount("food"),
		game_state.get_resource_amount("wood"),
		game_state.get_resource_amount("stone"),
		pop_summary,
	])
	lines.append("[b]%s[/b]  [color=%s]%s[/color]  [color=gray]%s[/color]" % [
		str(strategic_summary.get("stage_label", "")),
		str(timing_state.get("color", "lightgreen")),
		str(timing_state.get("label", "")),
		_match_config.scenario_title,
	])
	lines.append("[b]Goal[/b] %s   [b]Blocker[/b] %s   [b]Pressure[/b] %s" % [
		str(strategic_summary.get("next_goal", "")),
		str(strategic_summary.get("bottleneck", "")),
		StrategicTimingClass.get_enemy_pressure_text(game_state),
	])
	lines.append("[b]Enemy[/b] %s   [b]Food Flow[/b] %s" % [
		enemy_ai_controller.get_status_text(game_state),
		_format_food_flow_summary(food_summary),
	])

	var feedback: String = client_state.last_order_feedback
	if feedback != "":
		if client_state.last_order_was_rejected:
			lines.append("[color=tomato][b]! %s[/b][/color]" % feedback)
		else:
			lines.append("[color=lightgreen]%s[/color]" % feedback)

	status_label.text = "\n".join(lines)

	var unit_descriptions: Array[String] = []
	var entity_ids: Array = game_state.entities.keys()
	entity_ids.sort()
	for entity_id in entity_ids:
		var entity: Dictionary = game_state.get_entity_dict(entity_id)
		if game_state.get_entity_type(entity) != "unit":
			continue
		unit_descriptions.append(
			"#%d %s/%s carry=%d" % [
				entity_id,
				game_state.get_entity_task_state(entity),
				game_state.get_entity_string(entity, "traffic_state", "-"),
				game_state.get_entity_carried_amount(entity),
			]
		)

	var queued_records: Array[Dictionary] = command_buffer.get_debug_records()
	var debug_lines: Array[String] = [
		"[b]Debug[/b]",
		"tick=%d  hash=%s" % [
			game_state.current_tick,
			_last_authoritative_state_hash().left(8),
		],
		"hover=%s  entity=%d" % [str(client_state.hover_cell), client_state.hovered_entity_id],
		"selection=%s" % str(client_state.selected_entity_ids),
		"queued=%s" % JSON.stringify(queued_records),
		"",
		"[b]Units:[/b]",
	]
	for desc in unit_descriptions:
		debug_lines.append("  %s" % desc)
	debug_lines.append("")
	debug_lines.append("[b]Controls:[/b]")
	debug_lines.append("  LClick: select  Drag: multi-select")
	debug_lines.append("  RClick ground: move  RClick wood/stone: gather")
	debug_lines.append("  RClick base: deposit  RClick enemy: attack")
	debug_lines.append("  B/F/N/M: build house/farm/barracks/archery range  Q: train  RClick producer: rally  ESC: cancel")
	debug_lines.append("  WASD: camera  Wheel: zoom  F3/DBG: debug toggle")

	debug_label.bbcode_enabled = true
	debug_label.text = "\n".join(debug_lines)
	debug_label.visible = show_debug_overlay
	$CanvasLayer/DebugMargin.visible = show_debug_overlay


func _create_mission_hud() -> void:
	$CanvasLayer/SummaryMargin.offset_right = 472.0
	$CanvasLayer/SummaryMargin.offset_bottom = 108.0
	$CanvasLayer/SummaryMargin/SummaryPanel.custom_minimum_size = Vector2(436, 72)
	$CanvasLayer/SummaryMargin/SummaryPanel/StatusLabel.custom_minimum_size = Vector2(418, 66)
	$CanvasLayer/SummaryMargin/SummaryPanel/StatusLabel.scroll_active = false

	var mission_margin: MarginContainer = MarginContainer.new()
	mission_margin.name = "MissionMargin"
	mission_margin.anchor_left = 0.0
	mission_margin.anchor_top = 0.0
	mission_margin.anchor_right = 0.0
	mission_margin.anchor_bottom = 0.0
	mission_margin.offset_left = 16.0
	mission_margin.offset_top = 122.0
	mission_margin.offset_right = 336.0
	mission_margin.offset_bottom = 338.0
	mission_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	$CanvasLayer.add_child(mission_margin)

	var mission_panel: PanelContainer = PanelContainer.new()
	mission_panel.custom_minimum_size = Vector2(304, 204)
	mission_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mission_margin.add_child(mission_panel)

	mission_label = RichTextLabel.new()
	mission_label.bbcode_enabled = true
	mission_label.scroll_active = false
	mission_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	mission_label.custom_minimum_size = Vector2(280, 188)
	mission_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mission_panel.add_child(mission_label)

	var alert_margin: MarginContainer = MarginContainer.new()
	alert_margin.name = "AlertMargin"
	alert_margin.anchor_left = 1.0
	alert_margin.anchor_top = 0.0
	alert_margin.anchor_right = 1.0
	alert_margin.anchor_bottom = 0.0
	alert_margin.offset_left = -344.0
	alert_margin.offset_top = 16.0
	alert_margin.offset_right = -16.0
	alert_margin.offset_bottom = 184.0
	alert_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	$CanvasLayer.add_child(alert_margin)

	var alert_panel: PanelContainer = PanelContainer.new()
	alert_panel.custom_minimum_size = Vector2(312, 142)
	alert_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	alert_margin.add_child(alert_panel)

	alert_label = RichTextLabel.new()
	alert_label.bbcode_enabled = true
	alert_label.scroll_active = false
	alert_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	alert_label.custom_minimum_size = Vector2(288, 124)
	alert_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	alert_panel.add_child(alert_label)


func _apply_hud_skin() -> void:
	var panel_style: StyleBoxTexture = AssetCatalogClass.make_panel_style("blue")
	var mission_style: StyleBoxTexture = AssetCatalogClass.make_panel_style("green")
	var ui_font: FontFile = AssetCatalogClass.get_font()
	if panel_style != null:
		$CanvasLayer/SummaryMargin/SummaryPanel.add_theme_stylebox_override("panel", panel_style)
		$CanvasLayer/DebugMargin/DebugPanel.add_theme_stylebox_override("panel", panel_style)
		if mission_label != null and mission_label.get_parent() is PanelContainer:
			var mission_panel: PanelContainer = mission_label.get_parent()
			mission_panel.add_theme_stylebox_override("panel", mission_style if mission_style != null else panel_style)
		if alert_label != null and alert_label.get_parent() is PanelContainer:
			var alert_panel: PanelContainer = alert_label.get_parent()
			alert_panel.add_theme_stylebox_override("panel", panel_style)
	if ui_font != null:
		status_label.add_theme_font_override("normal_font", ui_font)
		debug_label.add_theme_font_override("normal_font", ui_font)
		if mission_label != null:
			mission_label.add_theme_font_override("normal_font", ui_font)
		if alert_label != null:
			alert_label.add_theme_font_override("normal_font", ui_font)
	_alert_player = AudioStreamPlayer.new()
	_alert_player.stream = AssetCatalogClass.get_audio_stream("alert")
	$CanvasLayer.add_child(_alert_player)


func _prime_presentation_alert_state() -> void:
	var entity_ids: Array = game_state.entities.keys()
	entity_ids.sort()
	for entity_id in entity_ids:
		var entity: Dictionary = game_state.get_entity_dict(entity_id)
		if game_state.get_entity_type(entity) == "structure" or game_state.get_entity_type(entity) == "stockpile":
			_last_structure_constructed[entity_id] = game_state.get_entity_is_constructed(entity)
			if game_state.get_entity_owner_id(entity, 0) == 1:
				_last_player_hp[entity_id] = game_state.get_entity_hp(entity)
	_refresh_alert_feed()


func _refresh_mission_panel() -> void:
	if mission_label == null:
		return
	var lines: Array[String] = []
	lines.append("[b]%s[/b]" % _match_config.scenario_title)
	lines.append("[color=gray]%s[/color]" % _match_config.scenario_subtitle)
	lines.append("")
	lines.append("[b]Objectives[/b]")
	for objective in _get_scenario_objectives():
		var done: bool = bool(objective.get("completed", false))
		var mark: String = "[color=lightgreen]✓[/color]" if done else "[color=khaki]•[/color]"
		lines.append("%s %s" % [mark, str(objective.get("text", ""))])
	lines.append("")
	lines.append("[b]Enemy plan[/b] %s" % _match_config.ai_aggression_display_name)
	lines.append("[b]Pressure[/b] %s" % StrategicTimingClass.get_enemy_pressure_text(game_state))
	lines.append("[b]Status[/b] %s" % enemy_ai_controller.get_status_text(game_state))
	mission_label.text = "\n".join(lines)


func _refresh_alert_feed() -> void:
	_pull_scenario_alerts()
	_pull_local_state_alerts()
	if alert_label == null:
		return
	var current_tick: int = game_state.current_tick
	var lines: Array[String] = ["[b]Alerts[/b]"]
	var visible_alerts: Array[Dictionary] = []
	for alert in _presentation_alerts:
		var age: int = current_tick - int(alert.get("tick", current_tick))
		if age <= 220:
			visible_alerts.append(alert)
	while visible_alerts.size() > 4:
		visible_alerts.remove_at(0)
	for alert in visible_alerts:
		var kind: String = str(alert.get("kind", "info"))
		var color: String = "lightgray"
		if kind == "warning":
			color = "khaki"
		elif kind == "danger":
			color = "tomato"
		elif kind == "success":
			color = "lightgreen"
		lines.append("[color=%s]%s[/color]" % [color, str(alert.get("text", ""))])
	alert_label.text = "\n".join(lines)


func _pull_scenario_alerts() -> void:
	var alerts_value: Variant = game_state.scenario_state.get("alerts", [])
	if not (alerts_value is Array):
		return
	var alerts: Array = alerts_value
	while _shown_scenario_alert_count < alerts.size():
		var alert_value: Variant = alerts[_shown_scenario_alert_count]
		if alert_value is Dictionary:
			_presentation_alerts.append((alert_value as Dictionary).duplicate(true))
		_shown_scenario_alert_count += 1


func _pull_local_state_alerts() -> void:
	var entity_ids: Array = game_state.entities.keys()
	entity_ids.sort()
	for entity_id in entity_ids:
		var entity: Dictionary = game_state.get_entity_dict(entity_id)
		var entity_type: String = game_state.get_entity_type(entity)
		if entity_type != "structure" and entity_type != "stockpile":
			continue
		var is_constructed: bool = game_state.get_entity_is_constructed(entity)
		if _last_structure_constructed.has(entity_id):
			var previous_constructed: bool = bool(_last_structure_constructed[entity_id])
			if not previous_constructed and is_constructed and game_state.get_entity_owner_id(entity, 0) == 1:
				_push_local_alert("success", "%s complete." % _get_structure_display_name(entity))
		_last_structure_constructed[entity_id] = is_constructed

		if game_state.get_entity_owner_id(entity, 0) != 1:
			continue
		var hp: int = game_state.get_entity_hp(entity)
		var previous_hp: int = hp
		if _last_player_hp.has(entity_id):
			previous_hp = int(_last_player_hp[entity_id])
		if hp < previous_hp and game_state.current_tick - _last_attack_alert_tick >= 20:
			_push_local_alert("danger", "%s under attack." % _get_structure_display_name(entity))
			_last_attack_alert_tick = game_state.current_tick
		_last_player_hp[entity_id] = hp


func _push_local_alert(kind: String, text: String) -> void:
	_presentation_alerts.append({
		"tick": game_state.current_tick,
		"kind": kind,
		"text": text,
	})
	if _alert_player != null and _alert_player.stream != null:
		_alert_player.play()
	while _presentation_alerts.size() > 12:
		_presentation_alerts.remove_at(0)


func _get_scenario_objectives() -> Array[Dictionary]:
	var objectives: Array[Dictionary] = []
	var value: Variant = game_state.scenario_state.get("objectives", [])
	if not (value is Array):
		return objectives
	for item in value:
		if item is Dictionary:
			objectives.append((item as Dictionary).duplicate(true))
	return objectives


func _get_structure_display_name(entity: Dictionary) -> String:
	var entity_type: String = game_state.get_entity_type(entity)
	if entity_type == "stockpile":
		return "Base"
	return GameDefinitionsClass.get_structure_display_name(
		game_state.get_entity_structure_type(entity)
	)


func _create_endgame_overlay() -> void:
	endgame_overlay = ColorRect.new()
	endgame_overlay.color = Color(0.05, 0.05, 0.08, 0.72)
	endgame_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	endgame_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	endgame_overlay.visible = false
	$CanvasLayer.add_child(endgame_overlay)

	endgame_label = Label.new()
	endgame_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	endgame_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	endgame_label.add_theme_font_size_override("font_size", 52)
	var ui_font: FontFile = AssetCatalogClass.get_font()
	if ui_font != null:
		endgame_label.add_theme_font_override("font", ui_font)
	endgame_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	endgame_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	endgame_label.visible = false
	$CanvasLayer.add_child(endgame_label)


func _refresh_endgame_overlay() -> void:
	var show_overlay: bool = game_state.win_condition_met or game_state.lose_condition_met
	endgame_overlay.visible = show_overlay
	endgame_label.visible = show_overlay
	if game_state.win_condition_met:
		endgame_label.text = "You Win"
	elif game_state.lose_condition_met:
		endgame_label.text = "You Lose"
	else:
		endgame_label.text = ""

func _last_authoritative_state_hash() -> String:
	var hash_history: Array[String] = []
	for authoritative_state_hash in tick_manager.authoritative_state_hash_history:
		hash_history.append(authoritative_state_hash)
	if hash_history.is_empty():
		return "not-yet-computed"

	return hash_history[hash_history.size() - 1]



func _get_blocked_cell_count() -> int:
	return game_state.get_blocked_cells().size()


func _build_blocked_cells_from_config() -> Dictionary:
	var blocked_cells: Dictionary = {}
	for cell in _match_config.blocked_cells:
		blocked_cells["%d,%d" % [cell.x, cell.y]] = true
	return blocked_cells


func _on_build_requested(structure_type: String) -> void:
	var display_name: String = GameDefinitionsClass.get_building_display_name(structure_type)
	var costs_str: String = GameDefinitionsClass.format_costs(
		GameDefinitionsClass.get_building_costs(structure_type)
	)
	client_state.begin_structure_placement(structure_type)
	client_state.set_order_feedback(
		"Placing %s (%s) — right-click to place." % [display_name, costs_str], false
	)
	_refresh_status_label()
	command_panel.refresh(game_state, client_state)
	renderer.queue_redraw()


func _on_train_requested(producer_id: int) -> void:
	var entity: Dictionary = game_state.get_entity_dict(producer_id)
	var unit_type: String = GameDefinitionsClass.get_structure_produces(
		game_state.get_entity_structure_type(entity)
	)
	if unit_type == "":
		client_state.set_order_feedback("This building cannot produce units.", true)
		_refresh_status_label()
		return
	if not game_state.can_afford_production(unit_type):
		var missing_costs: Dictionary = game_state.get_missing_production_costs(unit_type)
		var owner_id_for_costs: int = game_state.get_entity_owner_id(entity, 1)
		client_state.set_order_feedback(
			"%s." % FoodReadinessClass.build_missing_food_message(
				game_state,
				owner_id_for_costs,
				missing_costs
			),
			true
		)
		_refresh_status_label()
		return
	var owner_id: int = game_state.get_entity_owner_id(entity, 1)
	if game_state.is_population_capped_for_unit(owner_id, unit_type):
		client_state.set_order_feedback("Population cap reached. Need more houses.", true)
		_refresh_status_label()
		return
	var cmd := QueueProductionCommandClass.new(
		game_state.current_tick + 1, 1, 0, producer_id, unit_type
	)
	tick_manager.queue_command(cmd)
	client_state.set_order_feedback(
		"Training %s." % GameDefinitionsClass.get_unit_display_name(unit_type), false
	)
	_refresh_status_label()
	command_panel.refresh(game_state, client_state)
	renderer.queue_redraw()


func _format_food_flow_summary(food_summary: Dictionary) -> String:
	var label: String = str(food_summary.get("label", ""))
	var color: String = str(food_summary.get("color", "lightgreen"))
	var provider_count: int = int(food_summary.get("provider_count", 0))
	var income_per_window: int = int(food_summary.get("income_per_window", 0))
	var demand_per_window: int = int(food_summary.get("demand_per_window", 0))
	var farm_label: String = "%d farm" % provider_count
	if provider_count != 1:
		farm_label += "s"
	var extra_farms_needed: int = int(food_summary.get("extra_farms_needed", 0))
	var suffix: String = ""
	if extra_farms_needed > 0:
		suffix = "  (+%d farm%s)" % [extra_farms_needed, "" if extra_farms_needed == 1 else "s"]
	return "%s  ~%d/%dt vs %d demand  [color=%s]%s[/color]%s" % [
		farm_label,
		income_per_window,
		FoodReadinessClass.ANALYSIS_WINDOW_TICKS,
		demand_per_window,
		color,
		label,
		suffix,
	]


func _on_debug_toggle_requested() -> void:
	show_debug_overlay = not show_debug_overlay
	_refresh_status_label()


func _on_cancel_placement_requested() -> void:
	client_state.cancel_structure_placement()
	client_state.set_order_feedback("Build cancelled.", false)
	_refresh_status_label()
	command_panel.refresh(game_state, client_state)
	renderer.queue_redraw()
