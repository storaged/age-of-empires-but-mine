class_name CommandPanel
extends Control

## Context-sensitive command panel. Reads game/client state, emits signals upward.
## No simulation mutation — all signals handled by prototype_gameplay.gd.

const GameDefinitionsClass = preload("res://simulation/game_definitions.gd")
const FoodReadinessClass = preload("res://simulation/food_readiness.gd")
const StrategicTimingClass = preload("res://simulation/strategic_timing.gd")
const VisibilityClass = preload("res://simulation/visibility.gd")
const AssetCatalogClass = preload("res://rendering/asset_catalog.gd")

const PANEL_HEIGHT: int = 132
const DETAIL_WIDTH: int = 300
const BUTTON_W: int = 98
const BUTTON_H: int = 44
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
var _click_player: AudioStreamPlayer
var _hover_player: AudioStreamPlayer


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
	var panel_style: StyleBoxTexture = AssetCatalogClass.make_panel_style("blue")
	if panel_style != null:
		add_theme_stylebox_override("panel", panel_style)
	var ui_font: FontFile = AssetCatalogClass.get_font()
	if ui_font != null:
		add_theme_font_override("font", ui_font)

	var bg := ColorRect.new()
	bg.color = Color(0.05, 0.07, 0.09, 0.82)
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
	if ui_font != null:
		_detail_label.add_theme_font_override("normal_font", ui_font)
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
		btn.mouse_entered.connect(_play_hover_sound)
		_apply_button_skin(btn)
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
	_debug_button.mouse_entered.connect(_play_hover_sound)
	_apply_button_skin(_debug_button)
	add_child(_debug_button)

	_click_player = AudioStreamPlayer.new()
	_click_player.stream = AssetCatalogClass.get_audio_stream("click")
	add_child(_click_player)
	_hover_player = AudioStreamPlayer.new()
	_hover_player.stream = AssetCatalogClass.get_audio_stream("hover")
	add_child(_hover_player)


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
			var tooltip_text: String = "%s — %s" % [
				display_name,
				GameDefinitionsClass.format_costs(costs),
			]
			if not prereq_met:
				var prereq_name: String = GameDefinitionsClass.get_building_display_name(prereq)
				disabled_reason = "Need %s first" % prereq_name
			elif not can_afford:
				var missing_costs: Dictionary = game_state.get_missing_building_costs(building_type)
				disabled_reason = "Need %s" % GameDefinitionsClass.format_costs(missing_costs)
			if GameDefinitionsClass.get_building_supply_provided(building_type) > 0:
				tooltip_text += "  (+%d supply)" % GameDefinitionsClass.get_building_supply_provided(building_type)
			var trickle_type: String = GameDefinitionsClass.get_structure_resource_trickle_type(building_type)
			var trickle_amount: int = GameDefinitionsClass.get_structure_resource_trickle_amount(building_type)
			var trickle_interval: int = GameDefinitionsClass.get_structure_resource_trickle_interval_ticks(building_type)
			if trickle_type != "" and trickle_amount > 0 and trickle_interval > 0:
				tooltip_text += "  (+%d %s / %d ticks)" % [trickle_amount, trickle_type, trickle_interval]
			actions.append({
				"label": "%s\n%s" % [display_name, cost_str],
				"tooltip": tooltip_text,
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
		if entity_type == "stockpile" or (entity_type == "structure" and game_state.get_entity_is_constructed(entity)):
			var structure_type: String = game_state.get_entity_structure_type(entity)
			produces = GameDefinitionsClass.get_structure_produces(structure_type)
		if produces != "":
			var costs: Dictionary = GameDefinitionsClass.get_unit_production_costs(produces)
			var display_name: String = GameDefinitionsClass.get_unit_display_name(produces)
			var cost_str: String = GameDefinitionsClass.format_costs_short(costs)
			var can_afford: bool = game_state.can_afford_production(produces)
			var owner_id: int = game_state.get_entity_owner_id(entity, 1)
			var has_population_room: bool = game_state.can_queue_population_for_unit(owner_id, produces)
			var can_train: bool = can_afford and has_population_room
			var disabled_reason: String = ""
			var tooltip_text: String = "Train %s — %s  (pop %d, total %s)" % [
				display_name,
				GameDefinitionsClass.format_costs(costs),
				GameDefinitionsClass.get_unit_population_cost(produces),
				_format_population_summary(game_state, owner_id),
			]
			var unit_counter_label: String = GameDefinitionsClass.get_counter_label(produces)
			if unit_counter_label != "":
				tooltip_text += "\nStrong vs: %s" % unit_counter_label
			if not can_afford:
				var missing_costs: Dictionary = game_state.get_missing_production_costs(produces)
				disabled_reason = FoodReadinessClass.build_missing_food_message(
					game_state,
					owner_id,
					missing_costs
				)
			elif not has_population_room:
				disabled_reason = "Need more houses"
			actions.append({
				"label": "Train\n%s\n%s" % [display_name, cost_str],
				"tooltip": tooltip_text,
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
		if not client_state.placement_preview_valid and client_state.placement_preview_reason != "":
			lines.append("[color=tomato]%s[/color]" % client_state.placement_preview_reason)
		lines.append("[color=gray]Right-click to place. ESC or Cancel to stop.[/color]")
		_detail_label.text = "\n".join(lines)
		return

	var sel_count: int = client_state.selected_entity_ids.size()
	if sel_count == 0:
		var summary: Dictionary = StrategicTimingClass.build_player_summary(game_state, 1)
		var timing_state: Dictionary = summary.get("timing_state", {})
		var timing_label: String = str(timing_state.get("label", ""))
		var timing_color: String = str(timing_state.get("color", "lightgreen"))
		lines.append("[b]Stage:[/b] %s  [color=%s]%s[/color]" % [
			str(summary.get("stage_label", "")),
			timing_color,
			timing_label,
		])
		lines.append("[b]Goal:[/b] %s" % str(summary.get("next_goal", "")))
		lines.append("[b]Bottleneck:[/b] %s" % str(summary.get("bottleneck", "")))
		var food_summary: Dictionary = summary.get("food_summary", {})
		lines.append("[b]Food:[/b] %s" % _format_food_summary(food_summary))
		var army_pipeline: Dictionary = summary.get("army_pipeline", {})
		if int(summary.get("combat_unit_count", 0)) > 0 or int(summary.get("queued_combat_unit_count", 0)) > 0:
			lines.append("[b]Army:[/b] %s" % _format_army_pipeline(army_pipeline, int(summary.get("queued_combat_unit_count", 0))))
		var visible_enemies: int = VisibilityClass.count_visible_enemy_units(game_state, 1)
		if visible_enemies > 0:
			lines.append("[b]Intel:[/b] [color=orange]%d enemy unit%s in sight[/color]" % [
				visible_enemies, "s" if visible_enemies != 1 else ""
			])
		lines.append("[b]Pressure:[/b] %s" % StrategicTimingClass.get_enemy_pressure_text(game_state))
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
		var label: String = GameDefinitionsClass.get_unit_display_name(first_role).to_lower() + "s"
		if first_role == "worker":
			label = "workers"
		var owner_id: int = game_state.get_entity_owner_id(
			game_state.get_entity_dict(client_state.selected_entity_ids[0]),
			1
		)
		return "[b]%d %s:[/b] %s\n[b]Pop:[/b] %s" % [
			sel_count,
			label,
			", ".join(task_parts),
			_format_population_summary(game_state, owner_id),
		]

	var sel_id: int = client_state.selected_entity_ids[0]
	var entity: Dictionary = game_state.get_entity_dict(sel_id)
	var entity_type: String = game_state.get_entity_type(entity)

	if entity_type == "stockpile":
		var hp: int = game_state.get_entity_hp(entity)
		var max_hp: int = game_state.get_entity_max_hp(entity)
		var owner_id: int = game_state.get_entity_owner_id(entity, 1)
		var sp_unit: String = GameDefinitionsClass.get_structure_produces("stockpile")
		var sp_name: String = GameDefinitionsClass.get_unit_display_name(sp_unit).to_lower()
		var queue_count: int = game_state.get_entity_production_queue_count(entity)
		if queue_count > 0:
			var progress: int = game_state.get_entity_production_progress_ticks(entity)
			var duration: int = game_state.get_entity_production_duration_ticks(entity)
			return "[b]Base:[/b] HP %d/%d\n[b]Pop:[/b] %s\n[b]Training:[/b] %s (%d queued)  %d/%d ticks\n[b]Rally:[/b] %s" % [
				hp,
				max_hp,
				_format_population_summary(game_state, owner_id),
				sp_name,
				queue_count,
				progress,
				duration,
				_format_rally_summary(game_state, entity),
			]
		if game_state.get_entity_is_production_blocked(entity):
			return "[color=tomato][b]Base:[/b] HP %d/%d\n[b]Pop:[/b] %s\n[b]Training:[/b] blocked — no spawn space[/color]\n[b]Rally:[/b] %s" % [
				hp,
				max_hp,
				_format_population_summary(game_state, owner_id),
				_format_rally_summary(game_state, entity),
			]
		return "[b]Base:[/b] HP %d/%d\n[b]Pop:[/b] %s\n[b]Training:[/b] idle (%s)\n[b]Rally:[/b] %s\n[color=gray]Right-click ground/resource to set rally.[/color]" % [
			hp,
			max_hp,
			_format_population_summary(game_state, owner_id),
			sp_name,
			_format_rally_summary(game_state, entity),
		]

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
			var pct: int = int(round((float(progress) / float(maxi(duration, 1))) * 100.0))
			var remaining_ticks: int = maxi(duration - progress, 0)
			var active_builder: int = game_state.get_active_builder_id_for_structure(sel_id)
			var builder_status: String
			if active_builder != 0:
				var builder_entity: Dictionary = game_state.get_entity_dict(active_builder)
				var builder_task: String = game_state.get_entity_task_state(builder_entity)
				builder_status = "[color=lightgreen]building[/color]" if builder_task == "constructing" else "[color=yellow]en route[/color]"
			else:
				builder_status = "[color=tomato]idle — no builder assigned[/color]"
			return "[b]%s:[/b] %d%%  (%d/%d ticks, %d left)\n[b]Builder:[/b] %s" % [
				building_label,
				pct,
				progress,
				duration,
				remaining_ticks,
				builder_status,
			]
		var produces: String = GameDefinitionsClass.get_structure_produces(structure_type)
		if produces != "":
			var produce_name: String = GameDefinitionsClass.get_unit_display_name(produces).to_lower()
			var queue_count: int = game_state.get_entity_production_queue_count(entity)
			var queue_suffix: String = "%d queued" % queue_count if queue_count > 0 else "idle"
			var pop_summary: String = _format_population_summary(game_state, owner_id)
			if queue_count > 0:
				var progress: int = game_state.get_entity_production_progress_ticks(entity)
				var duration: int = game_state.get_entity_production_duration_ticks(entity)
				var pct: int = int(round((float(progress) / float(maxi(duration, 1))) * 100.0))
				var readiness_line: String = _build_producer_food_line(game_state, owner_id, produces)
				var batch_eta: int = StrategicTimingClass.get_producer_batch_eta(game_state, entity)
				var batch_suffix: String = ""
				if queue_count > 1:
					batch_suffix = "  [color=gray](batch done ~%dt)[/color]" % batch_eta
				return "[b]%s:[/b] %s\n[b]Pop:[/b] %s\n[b]Training:[/b] %s  %d/%d ticks (%d%%)%s\n[b]Food:[/b] %s\n[b]Rally:[/b] %s" % [
					building_label,
					queue_suffix,
					pop_summary,
					produce_name,
					progress,
					duration,
					pct,
					batch_suffix,
					readiness_line,
					_format_rally_summary(game_state, entity),
				]
			if game_state.get_entity_is_production_blocked(entity):
				return "[color=tomato][b]%s:[/b] %s\n[b]Pop:[/b] %s\n[b]Training:[/b] blocked — no spawn space[/color]\n[b]Food:[/b] %s\n[b]Rally:[/b] %s" % [
					building_label,
					queue_suffix,
					pop_summary,
					_build_producer_food_line(game_state, owner_id, produces),
					_format_rally_summary(game_state, entity),
				]
			return "[b]%s:[/b] built\n[b]Pop:[/b] %s\n[b]Training:[/b] idle (%s)\n[b]Food:[/b] %s\n[b]Rally:[/b] %s\n[color=gray]Right-click ground to set rally.[/color]" % [
				building_label,
				pop_summary,
				produce_name,
				_build_producer_food_line(game_state, owner_id, produces),
				_format_rally_summary(game_state, entity),
			]
		var trickle_type: String = game_state.get_entity_resource_trickle_type(entity)
		var trickle_amount: int = game_state.get_entity_resource_trickle_amount(entity)
		var trickle_interval: int = game_state.get_entity_resource_trickle_interval_ticks(entity)
		if trickle_type != "" and trickle_amount > 0 and trickle_interval > 0:
			var trickle_progress: int = game_state.get_entity_resource_trickle_progress_ticks(entity)
			return "[b]%s:[/b] built\n[b]Income:[/b] +%d %s every %d ticks\n[b]Next payout:[/b] %d/%d ticks" % [
				building_label,
				trickle_amount,
				trickle_type,
				trickle_interval,
				trickle_progress,
				trickle_interval,
			]
		return "[b]%s:[/b] built" % building_label

	var unit_role: String = game_state.get_entity_unit_role(entity)
	var task: String = game_state.get_entity_task_state(entity)

	if game_state.get_entity_can_attack(entity):
		var hp: int = game_state.get_entity_hp(entity)
		var max_hp: int = game_state.get_entity_max_hp(entity)
		var target_id: int = game_state.get_entity_attack_target_id(entity)
		var target_info: String = " → #%d" % target_id if target_id != 0 else ""
		var unit_label: String = GameDefinitionsClass.get_unit_display_name(unit_role)
		var attack_damage: int = game_state.get_entity_int(entity, "attack_damage", 0)
		var attack_range: int = game_state.get_entity_attack_range_cells(entity)
		var attack_cooldown: int = game_state.get_entity_int(entity, "attack_cooldown_ticks", 0)
		var counter_label: String = GameDefinitionsClass.get_counter_label(unit_role)
		var counter_line: String = ""
		if counter_label != "":
			counter_line = "\n[b]Strong vs:[/b] [color=lightgreen]%s[/color]" % counter_label
		var vision_radius: int = game_state.get_entity_vision_radius(entity)
		return "[b]%s:[/b] %s%s  HP %d/%d\n[b]Attack:[/b] %d dmg  range %d  cd %d  vision %d%s" % [
			unit_label,
			task,
			target_info,
			hp,
			max_hp,
			attack_damage,
			attack_range,
			attack_cooldown,
			vision_radius,
			counter_line,
		]

	if unit_role == "enemy_dummy":
		var hp: int = game_state.get_entity_hp(entity)
		var max_hp: int = game_state.get_entity_max_hp(entity)
		return "[color=tomato][b]Enemy unit[/b][/color]  HP %d/%d" % [hp, max_hp]

	var carry: int = game_state.get_entity_carried_amount(entity)
	var capacity: int = game_state.get_entity_capacity(entity)
	var traffic_state: String = game_state.get_entity_string(entity, "traffic_state", "")
	var assignment_summary: String = _build_worker_assignment_summary(game_state, entity)
	var traffic_summary: String = "  traffic %s" % traffic_state if traffic_state != "" else ""
	return "[b]Worker:[/b] %s%s\n[b]Carry:[/b] %d/%d\n[b]Task:[/b] %s" % [
		task,
		traffic_summary,
		carry,
		capacity,
		assignment_summary,
	]


func _format_population_summary(game_state: GameState, owner_id: int) -> String:
	var living: int = game_state.get_population_used(owner_id)
	var queued: int = game_state.get_population_queued(owner_id)
	var cap: int = game_state.get_population_cap(owner_id)
	if queued > 0:
		return "%d + %d queued / %d" % [living, queued, cap]
	return "%d / %d" % [living, cap]


func _format_army_pipeline(pipeline: Dictionary, queued_count: int) -> String:
	var ready: int = int(pipeline.get("ready", 0))
	var assembling: int = int(pipeline.get("assembling", 0))
	var deployed: int = int(pipeline.get("deployed", 0))
	var parts: Array[String] = []
	if ready > 0:
		parts.append("[color=lightgreen]%d ready[/color]" % ready)
	if assembling > 0:
		parts.append("[color=khaki]%d assembling[/color]" % assembling)
	if deployed > 0:
		parts.append("[color=orange]%d deployed[/color]" % deployed)
	if queued_count > 0:
		parts.append("[color=gray]%d training[/color]" % queued_count)
	if parts.is_empty():
		return "none"
	return "  ".join(parts)


func _format_food_summary(food_summary: Dictionary) -> String:
	var label: String = str(food_summary.get("label", ""))
	var income_per_window: int = int(food_summary.get("income_per_window", 0))
	var demand_per_window: int = int(food_summary.get("demand_per_window", 0))
	var provider_count: int = int(food_summary.get("provider_count", 0))
	var can_sustain_another: bool = bool(food_summary.get("can_sustain_another_producer", false))
	var base: String = "%s  (%d farms, ~%d / %dt vs %d demand)" % [
		label,
		provider_count,
		income_per_window,
		FoodReadinessClass.ANALYSIS_WINDOW_TICKS,
		demand_per_window,
	]
	if can_sustain_another:
		return base + "  [color=lightgreen]→ add Barracks[/color]"
	return base


func _build_producer_food_line(game_state: GameState, owner_id: int, produced_unit_type: String) -> String:
	var costs: Dictionary = GameDefinitionsClass.get_unit_production_costs(produced_unit_type)
	if not costs.has("food"):
		return "not required"
	var food_summary: Dictionary = FoodReadinessClass.build_food_summary(game_state, owner_id)
	var text: String = _format_food_summary(food_summary)
	var extra_farms_needed: int = int(food_summary.get("extra_farms_needed", 0))
	if extra_farms_needed > 0:
		text += "  (+%d farm)" % extra_farms_needed
		if extra_farms_needed > 1:
			text += "s"
	return text


func _build_worker_assignment_summary(game_state: GameState, entity: Dictionary) -> String:
	var task: String = game_state.get_entity_task_state(entity)
	var resource_node_id: int = game_state.get_entity_assigned_resource_node_id(entity)
	if resource_node_id != 0:
		var resource_node: Dictionary = game_state.get_entity_dict(resource_node_id)
		var resource_type: String = game_state.get_entity_resource_type(resource_node)
		return "%s #%d" % [task, resource_node_id] if resource_type == "" else "%s %s #%d" % [task, resource_type, resource_node_id]

	var stockpile_id: int = game_state.get_entity_assigned_stockpile_id(entity)
	if stockpile_id != 0:
		return "%s base #%d" % [task, stockpile_id]

	var structure_id: int = game_state.get_entity_assigned_construction_site_id(entity)
	if structure_id != 0:
		var structure_entity: Dictionary = game_state.get_entity_dict(structure_id)
		var structure_type: String = game_state.get_entity_structure_type(structure_entity)
		var structure_name: String = GameDefinitionsClass.get_building_display_name(structure_type)
		return "%s %s #%d" % [task, structure_name.to_lower(), structure_id]

	return task


func _format_rally_summary(game_state: GameState, producer_entity: Dictionary) -> String:
	var rally_mode: String = game_state.get_entity_rally_mode(producer_entity)
	if rally_mode == "":
		return "none"
	if rally_mode == "cell":
		var rally_cell: Vector2i = game_state.get_entity_rally_cell(producer_entity)
		return "(%d,%d)" % [rally_cell.x, rally_cell.y]
	if rally_mode == "resource":
		var resource_id: int = game_state.get_entity_rally_target_id(producer_entity)
		if resource_id != 0 and game_state.entities.has(resource_id):
			var resource_entity: Dictionary = game_state.get_entity_dict(resource_id)
			return "%s #%d" % [
				game_state.get_entity_resource_type(resource_entity),
				resource_id,
			]
		return "resource"
	return rally_mode


func _on_action_button_pressed(index: int) -> void:
	if index >= _current_actions.size():
		return
	var action: Dictionary = _current_actions[index]
	if not bool(action.get("enabled", false)):
		return
	_play_click_sound()
	var action_type: String = str(action.get("type", ""))
	match action_type:
		"build":
			build_requested.emit(str(action.get("structure_type", "")))
		"train":
			train_requested.emit(int(action.get("producer_id", 0)))
		"cancel_placement":
			cancel_placement_requested.emit()


func _apply_button_skin(button: Button) -> void:
	var normal_style: StyleBoxTexture = AssetCatalogClass.make_button_style("normal")
	var hover_style: StyleBoxTexture = AssetCatalogClass.make_button_style("hover")
	var pressed_style: StyleBoxTexture = AssetCatalogClass.make_button_style("pressed")
	var disabled_style: StyleBoxTexture = AssetCatalogClass.make_button_style("disabled")
	var ui_font: FontFile = AssetCatalogClass.get_font()
	if normal_style != null:
		button.add_theme_stylebox_override("normal", normal_style)
	if hover_style != null:
		button.add_theme_stylebox_override("hover", hover_style)
	if pressed_style != null:
		button.add_theme_stylebox_override("pressed", pressed_style)
	if disabled_style != null:
		button.add_theme_stylebox_override("disabled", disabled_style)
	if ui_font != null:
		button.add_theme_font_override("font", ui_font)
	button.add_theme_font_size_override("font_size", 15)


func _play_click_sound() -> void:
	if _click_player != null and _click_player.stream != null:
		_click_player.play()


func _play_hover_sound() -> void:
	if _hover_player != null and _hover_player.stream != null and not _hover_player.playing:
		_hover_player.play()
