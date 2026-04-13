class_name CommandPanel
extends Control

## Context-sensitive command panel. Reads game/client state, emits signals upward.
## No simulation mutation — all signals handled by prototype_gameplay.gd.

const GameDefinitionsClass = preload("res://simulation/game_definitions.gd")

const PANEL_HEIGHT: int = 130
const DETAIL_WIDTH: int = 290
const BUTTON_W: int = 104
const BUTTON_H: int = 48
const BUTTON_COLS: int = 4
const BUTTON_ROWS: int = 2
const BUTTON_GAP: int = 5

signal build_requested(structure_type: String)
signal train_requested(producer_id: int)
signal debug_toggle_requested()
signal cancel_placement_requested()

var _detail_label: RichTextLabel
var _action_buttons: Array[Button] = []
var _debug_button: Button
var _current_actions: Array[Dictionary] = []


func _ready() -> void:
	anchor_left = 0.0
	anchor_top = 1.0
	anchor_right = 1.0
	anchor_bottom = 1.0
	offset_top = -PANEL_HEIGHT
	offset_bottom = 0.0
	offset_left = 0.0
	offset_right = 0.0
	mouse_filter = MOUSE_FILTER_STOP

	var bg := ColorRect.new()
	bg.color = Color("#0d1117")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var top_border := ColorRect.new()
	top_border.color = Color("#30363d")
	top_border.anchor_left = 0.0
	top_border.anchor_top = 0.0
	top_border.anchor_right = 1.0
	top_border.anchor_bottom = 0.0
	top_border.offset_bottom = 2
	add_child(top_border)

	_detail_label = RichTextLabel.new()
	_detail_label.bbcode_enabled = true
	_detail_label.fit_content = false
	_detail_label.scroll_active = false
	_detail_label.position = Vector2(8, 6)
	_detail_label.size = Vector2(DETAIL_WIDTH, PANEL_HEIGHT - 12)
	add_child(_detail_label)

	var buttons_x: int = DETAIL_WIDTH + 16
	for i in range(BUTTON_COLS * BUTTON_ROWS):
		var col: int = i % BUTTON_COLS
		var row: int = i / BUTTON_COLS
		var btn := Button.new()
		btn.position = Vector2(
			buttons_x + col * (BUTTON_W + BUTTON_GAP),
			8 + row * (BUTTON_H + BUTTON_GAP)
		)
		btn.size = Vector2(BUTTON_W, BUTTON_H)
		btn.mouse_filter = Control.MOUSE_FILTER_STOP
		btn.visible = false
		btn.pressed.connect(_on_action_button_pressed.bind(i))
		_action_buttons.append(btn)
		add_child(btn)

	_debug_button = Button.new()
	_debug_button.text = "DBG"
	_debug_button.anchor_left = 1.0
	_debug_button.anchor_right = 1.0
	_debug_button.offset_left = -63.0
	_debug_button.offset_right = -8.0
	_debug_button.offset_top = 8.0
	_debug_button.offset_bottom = 38.0
	_debug_button.pressed.connect(func() -> void: debug_toggle_requested.emit())
	add_child(_debug_button)


func refresh(game_state: GameState, client_state: ClientState) -> void:
	_current_actions = _get_context_actions(game_state, client_state)
	_refresh_buttons()
	_refresh_detail(game_state, client_state)


func _get_context_actions(game_state: GameState, client_state: ClientState) -> Array[Dictionary]:
	var actions: Array[Dictionary] = []

	if client_state.is_in_structure_placement_mode():
		actions.append({
			"label": "Cancel\nBuild",
			"tooltip": "Cancel placement (ESC)",
			"enabled": true,
			"type": "cancel_placement",
		})
		return actions

	if client_state.selected_entity_ids.is_empty():
		return actions

	var all_workers: bool = true
	for sel_id: int in client_state.selected_entity_ids:
		var entity: Dictionary = game_state.get_entity_dict(sel_id)
		if game_state.get_entity_unit_role(entity) != "worker":
			all_workers = false
			break

	if all_workers:
		for building_type: String in GameDefinitionsClass.BUILDINGS.keys():
			var costs: Dictionary = GameDefinitionsClass.get_building_costs(building_type)
			var display_name: String = GameDefinitionsClass.get_building_display_name(building_type)
			var cost_str: String = GameDefinitionsClass.format_costs_short(costs)
			var prereq: String = GameDefinitionsClass.get_building_prerequisite(building_type)
			var prereq_met: bool = game_state.is_prerequisite_met(building_type)
			var can_afford: bool = game_state.can_afford_building(building_type)
			var enabled: bool = prereq_met and can_afford
			var disabled_reason: String = ""
			if not prereq_met:
				var prereq_name: String = GameDefinitionsClass.get_building_display_name(prereq)
				disabled_reason = "Need %s first" % prereq_name
			elif not can_afford:
				disabled_reason = "Not enough resources"
			actions.append({
				"label": "%s\n%s" % [display_name, cost_str],
				"tooltip": "%s — %s" % [display_name, GameDefinitionsClass.format_costs(costs)],
				"enabled": enabled,
				"disabled_reason": disabled_reason,
				"type": "build",
				"structure_type": building_type,
			})
		return actions

	if client_state.selected_entity_ids.size() == 1:
		var sel_id: int = client_state.selected_entity_ids[0]
		var entity: Dictionary = game_state.get_entity_dict(sel_id)
		var entity_type: String = game_state.get_entity_type(entity)
		var produces: String = ""
		if entity_type == "stockpile":
			produces = GameDefinitionsClass.get_stockpile_produces()
		elif entity_type == "structure" and game_state.get_entity_is_constructed(entity):
			var structure_type: String = game_state.get_entity_structure_type(entity)
			produces = GameDefinitionsClass.get_building_produces(structure_type)
		if produces != "":
			var costs: Dictionary = GameDefinitionsClass.get_unit_production_costs(produces)
			var display_name: String = GameDefinitionsClass.get_unit_display_name(produces)
			var cost_str: String = GameDefinitionsClass.format_costs_short(costs)
			var can_afford: bool = game_state.can_afford_production(produces)
			var owner_id: int = game_state.get_entity_owner_id(entity, 1)
			var has_population_room: bool = game_state.can_queue_population_for_unit(owner_id, produces)
			var can_train: bool = can_afford and has_population_room
			var disabled_reason: String = ""
			if not can_afford:
				disabled_reason = "Not enough resources"
			elif not has_population_room:
				disabled_reason = "Need more houses"
			actions.append({
				"label": "Train\n%s\n%s" % [display_name, cost_str],
				"tooltip": "Train %s — %s" % [display_name, GameDefinitionsClass.format_costs(costs)],
				"enabled": can_train,
				"disabled_reason": disabled_reason,
				"type": "train",
				"producer_id": sel_id,
			})

	return actions


func _refresh_buttons() -> void:
	for i in range(_action_buttons.size()):
		var btn: Button = _action_buttons[i]
		if i >= _current_actions.size():
			btn.visible = false
			continue
		var action: Dictionary = _current_actions[i]
		btn.visible = true
		btn.text = str(action.get("label", ""))
		var enabled: bool = bool(action.get("enabled", true))
		btn.disabled = not enabled
		var tooltip_text: String = str(action.get("tooltip", ""))
		if not enabled:
			var reason: String = str(action.get("disabled_reason", ""))
			if reason != "":
				tooltip_text = tooltip_text + " (" + reason + ")"
		btn.tooltip_text = tooltip_text


func _refresh_detail(game_state: GameState, client_state: ClientState) -> void:
	var lines: Array[String] = []

	if client_state.is_in_structure_placement_mode():
		var struct_type: String = client_state.placement_mode_structure_type
		var build_display: String = GameDefinitionsClass.get_building_display_name(struct_type)
		var build_costs: String = GameDefinitionsClass.format_costs(
			GameDefinitionsClass.get_building_costs(struct_type)
		)
		var place_color: String = "lightgreen" if client_state.placement_preview_valid else "tomato"
		lines.append("[color=%s][b]Place %s[/b] — %s[/color]" % [place_color, build_display, build_costs])
		lines.append("[color=gray]Right-click to place. ESC or Cancel to stop.[/color]")
		_detail_label.text = "\n".join(lines)
		return

	var sel_count: int = client_state.selected_entity_ids.size()
	if sel_count == 0:
		lines.append("[color=gray]Nothing selected.[/color]")
		lines.append("[color=gray]Left-click to select. Drag for multi-select.[/color]")
		_detail_label.text = "\n".join(lines)
		return

	lines.append(_build_selected_summary(game_state, client_state))
	_detail_label.text = "\n".join(lines)


func _build_selected_summary(game_state: GameState, client_state: ClientState) -> String:
	var sel_count: int = client_state.selected_entity_ids.size()

	if sel_count > 1:
		var task_parts: Array[String] = []
		for sel_id: int in client_state.selected_entity_ids:
			var e: Dictionary = game_state.get_entity_dict(sel_id)
			task_parts.append(game_state.get_entity_task_state(e))
		var first_role: String = game_state.get_entity_unit_role(
			game_state.get_entity_dict(client_state.selected_entity_ids[0])
		)
		var label: String
		if first_role == "soldier":
			label = "soldiers"
		elif first_role == "archer":
			label = "archers"
		else:
			label = "workers"
		return "[b]%d %s:[/b] %s" % [sel_count, label, ", ".join(task_parts)]

	var sel_id: int = client_state.selected_entity_ids[0]
	var entity: Dictionary = game_state.get_entity_dict(sel_id)
	var entity_type: String = game_state.get_entity_type(entity)

	if entity_type == "stockpile":
		var hp: int = game_state.get_entity_hp(entity)
		var max_hp: int = game_state.get_entity_max_hp(entity)
		var pop_used: int = game_state.get_population_used(game_state.get_entity_owner_id(entity, 1))
		var pop_cap: int = game_state.get_population_cap(game_state.get_entity_owner_id(entity, 1))
		var sp_unit: String = GameDefinitionsClass.get_stockpile_produces()
		var sp_name: String = GameDefinitionsClass.get_unit_display_name(sp_unit).to_lower()
		var queue_count: int = game_state.get_entity_production_queue_count(entity)
		if queue_count > 0:
			var progress: int = game_state.get_entity_production_progress_ticks(entity)
			var duration: int = game_state.get_entity_production_duration_ticks(entity)
			return "[b]Base:[/b] HP %d/%d  pop %d/%d  producing %s  %d/%d ticks" % [
				hp,
				max_hp,
				pop_used,
				pop_cap,
				sp_name,
				progress,
				duration,
			]
		if game_state.get_entity_is_production_blocked(entity):
			return "[color=tomato][b]Base:[/b] HP %d/%d  pop %d/%d  blocked — no spawn space[/color]" % [
				hp,
				max_hp,
				pop_used,
				pop_cap,
			]
		return "[b]Base:[/b] HP %d/%d  pop %d/%d  idle" % [hp, max_hp, pop_used, pop_cap]

	if entity_type == "structure":
		var owner_id: int = game_state.get_entity_owner_id(entity)
		var structure_type: String = game_state.get_entity_structure_type(entity)
		var structure_label: String = structure_type
		if GameDefinitionsClass.is_known_building_type(structure_type):
			structure_label = GameDefinitionsClass.get_building_display_name(structure_type)
		elif structure_type == "enemy_base":
			structure_label = "Enemy base"
		if owner_id != 1:
			var hp: int = game_state.get_entity_hp(entity)
			var max_hp: int = game_state.get_entity_max_hp(entity)
			return "[color=tomato][b]%s[/b][/color]  HP %d/%d" % [structure_label, hp, max_hp]
		var constructed: bool = game_state.get_entity_is_constructed(entity)
		var building_label: String = structure_label
		if not constructed:
			var progress: int = game_state.get_entity_construction_progress_ticks(entity)
			var duration: int = game_state.get_entity_construction_duration_ticks(entity)
			var active_builder: int = game_state.get_active_builder_id_for_structure(sel_id)
			var builder_status: String
			if active_builder != 0:
				var builder_entity: Dictionary = game_state.get_entity_dict(active_builder)
				var builder_task: String = game_state.get_entity_task_state(builder_entity)
				builder_status = "[color=lightgreen]building[/color]" if builder_task == "constructing" else "[color=yellow]en route[/color]"
			else:
				builder_status = "[color=tomato]no builder — select worker + right-click[/color]"
			return "[b]%s:[/b] %d/%d ticks  %s" % [building_label, progress, duration, builder_status]
		var produces: String = GameDefinitionsClass.get_building_produces(structure_type)
		if produces != "":
			var produce_name: String = GameDefinitionsClass.get_unit_display_name(produces).to_lower()
			var queue_count: int = game_state.get_entity_production_queue_count(entity)
			var pop_used: int = game_state.get_population_used(game_state.get_entity_owner_id(entity, 1))
			var pop_cap: int = game_state.get_population_cap(game_state.get_entity_owner_id(entity, 1))
			if queue_count > 0:
				var progress: int = game_state.get_entity_production_progress_ticks(entity)
				var duration: int = game_state.get_entity_production_duration_ticks(entity)
				return "[b]%s:[/b] pop %d/%d  training %s  %d/%d ticks" % [
					building_label,
					pop_used,
					pop_cap,
					produce_name,
					progress,
					duration,
				]
			if game_state.get_entity_is_production_blocked(entity):
				return "[color=tomato][b]%s:[/b] pop %d/%d  blocked — no spawn space[/color]" % [
					building_label,
					pop_used,
					pop_cap,
				]
			return "[b]%s:[/b] pop %d/%d  built" % [building_label, pop_used, pop_cap]
		return "[b]%s:[/b] built" % building_label

	var unit_role: String = game_state.get_entity_unit_role(entity)
	var task: String = game_state.get_entity_task_state(entity)

	if unit_role == "soldier" or unit_role == "archer":
		var hp: int = game_state.get_entity_hp(entity)
		var max_hp: int = game_state.get_entity_max_hp(entity)
		var target_id: int = game_state.get_entity_attack_target_id(entity)
		var target_info: String = " → #%d" % target_id if target_id != 0 else ""
		var unit_label: String = GameDefinitionsClass.get_unit_display_name(unit_role)
		return "[b]%s:[/b] %s%s  HP %d/%d" % [unit_label, task, target_info, hp, max_hp]

	if unit_role == "enemy_dummy":
		var hp: int = game_state.get_entity_hp(entity)
		var max_hp: int = game_state.get_entity_max_hp(entity)
		return "[color=tomato][b]Enemy unit[/b][/color]  HP %d/%d" % [hp, max_hp]

	var carry: int = game_state.get_entity_carried_amount(entity)
	var capacity: int = game_state.get_entity_capacity(entity)
	return "[b]Worker:[/b] %s  carry %d/%d" % [task, carry, capacity]


func _on_action_button_pressed(index: int) -> void:
	if index >= _current_actions.size():
		return
	var action: Dictionary = _current_actions[index]
	if not bool(action.get("enabled", false)):
		return
	var action_type: String = str(action.get("type", ""))
	match action_type:
		"build":
			build_requested.emit(str(action.get("structure_type", "")))
		"train":
			train_requested.emit(int(action.get("producer_id", 0)))
		"cancel_placement":
			cancel_placement_requested.emit()
