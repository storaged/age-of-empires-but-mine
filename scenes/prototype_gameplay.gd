extends Node2D

const GameDefinitionsClass = preload("res://simulation/game_definitions.gd")
const GameStateClass = preload("res://simulation/game_state.gd")
const BuildCommandSystemClass = preload("res://simulation/systems/build_command_system.gd")
const CombatSystemClass = preload("res://simulation/systems/combat_system.gd")
const GatherCommandSystemClass = preload("res://simulation/systems/gather_command_system.gd")
const MoveCommandSystemClass = preload("res://simulation/systems/move_command_system.gd")
const MovementSystemClass = preload("res://simulation/systems/movement_system.gd")
const ProductionSystemClass = preload("res://simulation/systems/production_system.gd")
const WorkerEconomySystemClass = preload("res://simulation/systems/worker_economy_system.gd")
const CommandBufferClass = preload("res://runtime/command_buffer.gd")
const ReplayLogClass = preload("res://runtime/replay_log.gd")
const StateHasherClass = preload("res://runtime/state_hasher.gd")
const TickManagerClass = preload("res://runtime/tick_manager.gd")
const ClientStateClass = preload("res://client/client_state.gd")
const InputHandlerClass = preload("res://client/input_handler.gd")
const CommandPanelClass = preload("res://client/command_panel.gd")
const QueueProductionCommandClass = preload("res://commands/queue_production_command.gd")

const MAP_WIDTH: int = 20
const MAP_HEIGHT: int = 14
const CELL_SIZE: int = 64
const CAMERA_SPEED: float = 900.0
const MIN_CAMERA_ZOOM: float = 0.5
const MAX_CAMERA_ZOOM: float = 1.8
const ZOOM_STEP: float = 0.1
const CLICK_SELECTION_THRESHOLD: float = 10.0

@onready var camera: Camera2D = $Camera2D
@onready var renderer: GameRenderer = $GameRenderer
@onready var status_label: RichTextLabel = $CanvasLayer/SummaryMargin/SummaryPanel/StatusLabel
@onready var debug_label: RichTextLabel = $CanvasLayer/DebugMargin/DebugPanel/DebugLabel

var game_state: GameState
var command_buffer: CommandBuffer
var replay_log: ReplayLog
var state_hasher: StateHasher
var tick_manager: TickManager
var client_state: ClientState
var input_handler: InputHandler
var command_panel: Control
var show_debug_overlay: bool = false

func _ready() -> void:
	status_label.bbcode_enabled = true
	debug_label.bbcode_enabled = true
	game_state = _create_initial_game_state()
	command_buffer = CommandBufferClass.new()
	replay_log = ReplayLogClass.new()
	state_hasher = StateHasherClass.new()
	client_state = ClientStateClass.new()
	input_handler = InputHandlerClass.new()
	var systems: Array[SimulationSystem] = []
	systems.append(BuildCommandSystemClass.new())
	systems.append(MoveCommandSystemClass.new())
	systems.append(GatherCommandSystemClass.new())
	systems.append(CombatSystemClass.new())
	systems.append(MovementSystemClass.new())
	systems.append(WorkerEconomySystemClass.new())
	systems.append(ProductionSystemClass.new())
	tick_manager = TickManagerClass.new(
		game_state,
		command_buffer,
		replay_log,
		state_hasher,
		systems
	)

	command_panel = CommandPanelClass.new()
	$CanvasLayer.add_child(command_panel)
	command_panel.build_requested.connect(_on_build_requested)
	command_panel.train_requested.connect(_on_train_requested)
	command_panel.debug_toggle_requested.connect(_on_debug_toggle_requested)
	command_panel.cancel_placement_requested.connect(_on_cancel_placement_requested)

	client_state.set_camera_world_position(_map_center_world_position())
	_apply_camera_to_node()
	_sync_client_visuals_from_authoritative_state()

	renderer.configure(game_state, client_state, CELL_SIZE)
	renderer.queue_redraw()
	_refresh_status_label()
	command_panel.refresh(game_state, client_state)

func _process(delta: float) -> void:
	_update_camera_from_input(delta)
	input_handler.update_hover_from_world_position(
		get_global_mouse_position(),
		game_state,
		client_state,
		CELL_SIZE
	)

	var completed_steps: Array[Dictionary] = tick_manager.advance_by_time(delta)
	if not completed_steps.is_empty():
		_sync_client_visuals_from_authoritative_state()

	client_state.update_visual_interpolation(tick_manager.get_tick_progress())
	_apply_camera_to_node()
	_refresh_status_label()
	command_panel.refresh(game_state, client_state)
	renderer.queue_redraw()

func _unhandled_input(event: InputEvent) -> void:
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
		"wood": 0,
		"stone": 0,
	}
	state.map_data = {
		"width": MAP_WIDTH,
		"height": MAP_HEIGHT,
		"cell_size": CELL_SIZE,
		"blocked_cells": _build_blocked_cells(),
	}

	var stockpile_cell: Vector2i = Vector2i(2, 2)
	var stockpile_id: int = state.allocate_entity_id()
	state.entities[stockpile_id] = {
		"id": stockpile_id,
		"entity_type": "stockpile",
		"owner_id": 1,
		"grid_position": stockpile_cell,
		"production_queue_count": 0,
		"production_progress_ticks": 0,
		"production_duration_ticks": 0,
		"produced_unit_type": "",
		"production_blocked": false,
	}

	var wood_cells: Array[Vector2i] = [
		Vector2i(15, 4),
		Vector2i(15, 5),
	]
	for resource_cell in wood_cells:
		var resource_node_id: int = state.allocate_entity_id()
		state.entities[resource_node_id] = {
			"id": resource_node_id,
			"entity_type": "resource_node",
			"resource_type": "wood",
			"grid_position": resource_cell,
			"remaining_amount": 80,
		}

	var stone_cells: Array[Vector2i] = [
		Vector2i(5, 11),
		Vector2i(6, 11),
	]
	for stone_cell in stone_cells:
		var stone_node_id: int = state.allocate_entity_id()
		state.entities[stone_node_id] = {
			"id": stone_node_id,
			"entity_type": "resource_node",
			"resource_type": "stone",
			"grid_position": stone_cell,
			"remaining_amount": 60,
		}

	var enemy_base_cell: Vector2i = Vector2i(17, 8)
	var enemy_base_id: int = state.allocate_entity_id()
	state.entities[enemy_base_id] = {
		"id": enemy_base_id,
		"entity_type": "structure",
		"structure_type": "enemy_base",
		"owner_id": 2,
		"grid_position": enemy_base_cell,
		"is_constructed": true,
		"construction_progress_ticks": 0,
		"construction_duration_ticks": 0,
		"assigned_builder_id": 0,
		"hp": 50,
		"max_hp": 50,
		"production_queue_count": 0,
		"production_progress_ticks": 0,
		"production_duration_ticks": 0,
		"produced_unit_type": "",
		"production_blocked": false,
	}

	var enemy_unit_cells: Array[Vector2i] = [Vector2i(15, 8), Vector2i(16, 10)]
	for enemy_cell in enemy_unit_cells:
		var enemy_id: int = state.allocate_entity_id()
		state.entities[enemy_id] = {
			"id": enemy_id,
			"entity_type": "unit",
			"unit_role": "enemy_dummy",
			"owner_id": 2,
			"grid_position": enemy_cell,
			"move_target": enemy_cell,
			"path_cells": [],
			"has_move_target": false,
			"worker_task_state": "idle",
			"interaction_slot_cell": Vector2i(-1, -1),
			"traffic_state": "",
			"hp": 20,
			"max_hp": 20,
		}
		state.occupancy["%d,%d" % [enemy_cell.x, enemy_cell.y]] = enemy_id

	var starting_cells: Array[Vector2i] = [
		Vector2i(3, 3),
		Vector2i(4, 3),
		Vector2i(3, 4),
		Vector2i(4, 4),
	]
	for cell in starting_cells:
		var unit_id: int = state.allocate_entity_id()
		state.entities[unit_id] = {
			"id": unit_id,
			"entity_type": "unit",
			"unit_role": "worker",
			"owner_id": 1,
			"grid_position": cell,
			"move_target": cell,
			"path_cells": [],
			"has_move_target": false,
			"worker_task_state": "idle",
			"assigned_resource_node_id": 0,
			"assigned_stockpile_id": stockpile_id,
			"assigned_construction_site_id": 0,
			"carried_resource_type": "",
			"carried_amount": 0,
			"interaction_slot_cell": Vector2i(-1, -1),
			"traffic_state": "",
			"carry_capacity": 10,
			"harvest_amount": 5,
			"gather_duration_ticks": 8,
			"deposit_duration_ticks": 2,
			"gather_progress_ticks": 0,
		}
		state.occupancy["%d,%d" % [cell.x, cell.y]] = unit_id

	return state

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
	var map_size: Vector2 = Vector2(MAP_WIDTH * CELL_SIZE, MAP_HEIGHT * CELL_SIZE)
	return Vector2(
		clampf(world_position.x, 0.0, map_size.x),
		clampf(world_position.y, 0.0, map_size.y)
	)

func _apply_camera_to_node() -> void:
	camera.position = client_state.camera_world_position
	camera.zoom = Vector2.ONE * client_state.camera_zoom

func _map_center_world_position() -> Vector2:
	return Vector2(MAP_WIDTH * CELL_SIZE, MAP_HEIGHT * CELL_SIZE) * 0.5

func _cell_center_world(cell: Vector2i) -> Vector2:
	return Vector2(
		(cell.x + 0.5) * CELL_SIZE,
		(cell.y + 0.5) * CELL_SIZE
	)

func _refresh_status_label() -> void:
	var lines: Array[String] = []

	lines.append("[b]Wood:[/b] %d  [b]Stone:[/b] %d" % [
		game_state.get_resource_amount("wood"),
		game_state.get_resource_amount("stone"),
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
	debug_lines.append("  RClick ground: move  RClick wood: gather")
	debug_lines.append("  RClick base: deposit  RClick enemy: attack")
	debug_lines.append("  B/N/M: build house/barracks/archery range  Q: train  ESC: cancel")
	debug_lines.append("  WASD: camera  Wheel: zoom  F3/DBG: debug toggle")

	debug_label.bbcode_enabled = true
	debug_label.text = "\n".join(debug_lines)
	debug_label.visible = show_debug_overlay
	$CanvasLayer/DebugMargin.visible = show_debug_overlay

func _last_authoritative_state_hash() -> String:
	var hash_history: Array[String] = []
	for authoritative_state_hash in tick_manager.authoritative_state_hash_history:
		hash_history.append(authoritative_state_hash)
	if hash_history.is_empty():
		return "not-yet-computed"

	return hash_history[hash_history.size() - 1]



func _get_blocked_cell_count() -> int:
	return game_state.get_blocked_cells().size()


func _build_blocked_cells() -> Dictionary:
	var blocked_cells: Dictionary = {}
	var cells: Array[Vector2i] = [
		Vector2i(2, 2),
		Vector2i(8, 3),
		Vector2i(8, 4),
		Vector2i(8, 5),
		Vector2i(8, 6),
		Vector2i(11, 7),
		Vector2i(12, 7),
		Vector2i(13, 7),
		Vector2i(13, 8),
		Vector2i(13, 9),
		Vector2i(15, 4),
		Vector2i(15, 5),
		Vector2i(5, 11),
		Vector2i(6, 11),
	]
	for cell in cells:
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
	var entity_type: String = game_state.get_entity_type(entity)
	var unit_type: String = ""
	if entity_type == "stockpile":
		unit_type = GameDefinitionsClass.get_stockpile_produces()
	elif entity_type == "structure":
		unit_type = GameDefinitionsClass.get_building_produces(
			game_state.get_entity_structure_type(entity)
		)
	if unit_type == "" or not game_state.can_afford_production(unit_type):
		client_state.set_order_feedback("Not enough resources.", true)
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


func _on_debug_toggle_requested() -> void:
	show_debug_overlay = not show_debug_overlay
	_refresh_status_label()


func _on_cancel_placement_requested() -> void:
	client_state.cancel_structure_placement()
	client_state.set_order_feedback("Build cancelled.", false)
	_refresh_status_label()
	command_panel.refresh(game_state, client_state)
	renderer.queue_redraw()
