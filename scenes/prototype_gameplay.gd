extends Node2D

const GameStateClass = preload("res://simulation/game_state.gd")
const BuildCommandSystemClass = preload("res://simulation/systems/build_command_system.gd")
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
var show_debug_overlay: bool = false

func _ready() -> void:
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

	client_state.set_camera_world_position(_map_center_world_position())
	_apply_camera_to_node()
	_sync_client_visuals_from_authoritative_state()

	renderer.configure(game_state, client_state, CELL_SIZE)
	renderer.queue_redraw()
	_refresh_status_label()

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
			show_debug_overlay = not show_debug_overlay
			_refresh_status_label()
		elif key_event.keycode == KEY_B:
			if client_state.is_in_structure_placement_mode():
				client_state.cancel_structure_placement()
				client_state.set_order_feedback("Build mode cancelled.", false)
			else:
				client_state.begin_structure_placement("house")
				client_state.set_order_feedback("Build mode: right-click to place a house.", false)
			_refresh_status_label()
			renderer.queue_redraw()
		elif key_event.keycode == KEY_ESCAPE and client_state.is_in_structure_placement_mode():
			client_state.cancel_structure_placement()
			client_state.set_order_feedback("Build mode cancelled.", false)
			_refresh_status_label()
			renderer.queue_redraw()
		elif key_event.keycode == KEY_Q:
			var production_commands: Array[SimulationCommand] = input_handler.build_production_commands_for_selection(
				game_state,
				client_state,
				game_state.current_tick + 1
			)
			for command in production_commands:
				tick_manager.queue_command(command)
			_refresh_status_label()
			renderer.queue_redraw()

func _create_initial_game_state() -> GameState:
	var state: GameState = GameStateClass.new()
	state.resources = {
		"wood": 0,
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

	var resource_cells: Array[Vector2i] = [
		Vector2i(15, 4),
		Vector2i(15, 5),
	]
	for resource_cell in resource_cells:
		var resource_node_id: int = state.allocate_entity_id()
		state.entities[resource_node_id] = {
			"id": resource_node_id,
			"entity_type": "resource_node",
			"resource_type": "wood",
			"grid_position": resource_cell,
			"remaining_amount": 80,
		}

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
	var unit_descriptions: Array[String] = []
	var entity_ids: Array = game_state.entities.keys()
	entity_ids.sort()
	for entity_id in entity_ids:
		var entity: Dictionary = game_state.get_entity_dict(entity_id)
		if game_state.get_entity_type(entity) != "unit":
			continue
		unit_descriptions.append(
			"%d:%s %s traffic=%s carry=%d" % [
				entity_id,
				game_state.get_entity_unit_role(entity),
				game_state.get_entity_task_state(entity),
				game_state.get_entity_string(entity, "traffic_state", ""),
				game_state.get_entity_carried_amount(entity),
			]
		)

	var queued_records: Array[Dictionary] = command_buffer.get_debug_records()
	var selected_summary: String = _build_selected_summary()
	var summary_lines: Array[String] = [
		"RTS Economy + Construction Prototype",
		"",
		"Controls:",
		"  Left click: single select",
		"  Left drag: marquee select",
		"  Right click ground: move",
		"  Right click resource: gather",
		"  Right click stockpile: deposit cargo",
		"  B: house build mode",
		"  Q: produce worker from selected base",
		"  WASD: move camera",
		"  Mouse wheel: zoom",
		"  F3: toggle debug",
		"",
		"Resources: wood=%d" % game_state.get_resource_amount("wood"),
		"Runtime: tick=%d progress=%.2f" % [
			game_state.current_tick,
			tick_manager.get_tick_progress(),
		],
		"Selected count: %d" % client_state.selected_entity_ids.size(),
		"Selection: %s" % str(client_state.selected_entity_ids),
		"Hover: cell=%s unit=%d" % [
			str(client_state.hover_cell),
			client_state.hovered_entity_id,
		],
		"Order: %s" % client_state.last_order_feedback,
		"Build mode: %s" % _build_mode_summary(),
		"Selected: %s" % selected_summary,
		"Units: %s" % ", ".join(unit_descriptions),
	]
	status_label.text = "\n".join(summary_lines)

	var debug_lines: Array[String] = [
		"Debug",
		"",
		"hash=%s" % _last_authoritative_state_hash(),
		"queued_commands=%s" % JSON.stringify(queued_records),
		"rejected_order=%s" % str(client_state.last_order_was_rejected),
		"blocked_hover=%s blocked_cells=%d" % [
			str(game_state.is_cell_blocked(client_state.hover_cell)),
			_get_blocked_cell_count(),
		],
		"drag_selecting=%s drag_rect=%s" % [
			str(client_state.is_drag_selecting),
			str(client_state.get_drag_world_rect()),
		],
		"selection=%s hover_cell=%s hover_unit=%d indicators=%s" % [
			str(client_state.selected_entity_ids),
			str(client_state.hover_cell),
			client_state.hovered_entity_id,
			str(client_state.indicators),
		],
		"wood=%d resource_nodes=%s" % [
			game_state.get_resource_amount("wood"),
			str(game_state.get_entities_by_type("resource_node")),
		],
	]
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


func _get_entity_path_size(entity: Dictionary) -> int:
	return game_state.get_entity_path_cells(entity).size()


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
	]
	for cell in cells:
		blocked_cells["%d,%d" % [cell.x, cell.y]] = true
	return blocked_cells


func _build_selected_summary() -> String:
	if client_state.selected_entity_ids.is_empty():
		return "none"

	if client_state.selected_entity_ids.size() > 1:
		return "%d workers" % client_state.selected_entity_ids.size()

	var selected_id_value: Variant = client_state.selected_entity_ids[0]
	if not (selected_id_value is int):
		return "invalid-selection"
	var selected_id: int = selected_id_value
	var entity: Dictionary = game_state.get_entity_dict(selected_id)
	var entity_type: String = game_state.get_entity_type(entity)
	if entity_type == "stockpile" or entity_type == "structure":
		return _build_selected_structure_summary(selected_id, entity)
	var interaction_slot: Vector2i = game_state.get_entity_interaction_slot_cell(entity)
	return "%d role=%s task=%s traffic=%s carry=%d/%d target_resource=%d stockpile=%d slot=%s" % [
		selected_id,
		game_state.get_entity_unit_role(entity),
		game_state.get_entity_task_state(entity),
		game_state.get_entity_string(entity, "traffic_state", ""),
		game_state.get_entity_carried_amount(entity),
		game_state.get_entity_capacity(entity),
		game_state.get_entity_assigned_resource_node_id(entity),
		game_state.get_entity_assigned_stockpile_id(entity),
		str(interaction_slot),
	]


func _build_selected_structure_summary(selected_id: int, entity: Dictionary) -> String:
	var entity_type: String = game_state.get_entity_type(entity)
	var queue_count: int = game_state.get_entity_production_queue_count(entity)
	if entity_type == "stockpile":
		return "%d base queue=%d progress=%d/%d blocked=%s" % [
			selected_id,
			queue_count,
			game_state.get_entity_production_progress_ticks(entity),
			game_state.get_entity_production_duration_ticks(entity),
			str(game_state.get_entity_is_production_blocked(entity)),
		]

	return "%d structure=%s built=%s construction=%d/%d builder=%d" % [
		selected_id,
		game_state.get_entity_structure_type(entity),
		str(game_state.get_entity_is_constructed(entity)),
		game_state.get_entity_construction_progress_ticks(entity),
		game_state.get_entity_construction_duration_ticks(entity),
		game_state.get_entity_int(entity, "assigned_builder_id", 0),
	]


func _build_mode_summary() -> String:
	if not client_state.is_in_structure_placement_mode():
		return "off"
	return "%s at %s valid=%s reason=%s" % [
		client_state.placement_mode_structure_type,
		str(client_state.placement_preview_cell),
		str(client_state.placement_preview_valid),
		client_state.placement_preview_reason,
	]
