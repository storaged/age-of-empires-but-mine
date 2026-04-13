extends Control

## Minimal pregame entry point.
## Builds a MatchConfig from user difficulty selection and passes it to gameplay.

const MatchConfigClass = preload("res://simulation/match_config.gd")
const ColorPresetsClass = preload("res://simulation/presets/color_presets.gd")
const ScenarioDefinitionsClass = preload("res://simulation/scenarios/scenario_definitions.gd")
const AssetCatalogClass = preload("res://rendering/asset_catalog.gd")

var _match_config: MatchConfigClass = null
var _summary_label: RichTextLabel = null
var _click_player: AudioStreamPlayer = null
var _hover_player: AudioStreamPlayer = null


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_match_config = MatchConfigClass.new()
	_build_ui()


func _build_ui() -> void:
	var panel := ColorRect.new()
	panel.color = Color(0.05, 0.07, 0.09, 1.0)
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_CENTER)
	vbox.position = Vector2(-160.0, -120.0)
	vbox.custom_minimum_size = Vector2(320.0, 240.0)
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(vbox)
	_apply_ui_audio(self)

	var title := Label.new()
	title.text = "Age of Empires But Mine"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 28)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ui_font: FontFile = AssetCatalogClass.get_font()
	if ui_font != null:
		title.add_theme_font_override("font", ui_font)
	vbox.add_child(title)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 16)
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(spacer)

	vbox.add_child(_build_selector("Scenario", ScenarioDefinitionsClass.get_ids(), _match_config.scenario_id, _on_scenario_selected))
	vbox.add_child(_build_selector("Colors", ColorPresetsClass.get_ids(), _match_config.color_preset_id, _on_colors_selected))

	var spacer2 := Control.new()
	spacer2.custom_minimum_size = Vector2(0, 14)
	spacer2.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(spacer2)

	_summary_label = RichTextLabel.new()
	_summary_label.bbcode_enabled = true
	_summary_label.scroll_active = false
	_summary_label.fit_content = false
	_summary_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_summary_label.custom_minimum_size = Vector2(320.0, 140.0)
	_summary_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if ui_font != null:
		_summary_label.add_theme_font_override("normal_font", ui_font)
	vbox.add_child(_summary_label)
	_refresh_summary()

	var spacer3 := Control.new()
	spacer3.custom_minimum_size = Vector2(0, 18)
	spacer3.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(spacer3)

	var start_btn := Button.new()
	start_btn.text = "Start Match"
	_apply_button_skin(start_btn)
	start_btn.pressed.connect(_on_start_pressed)
	start_btn.mouse_entered.connect(_play_hover_sound)
	vbox.add_child(start_btn)


func _build_selector(
	label_text: String,
	ids: Array[String],
	selected_id: String,
	callback: Callable
) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var label := Label.new()
	label.text = label_text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var ui_font: FontFile = AssetCatalogClass.get_font()
	if ui_font != null:
		label.add_theme_font_override("font", ui_font)
	box.add_child(label)

	var option := OptionButton.new()
	for index in range(ids.size()):
		option.add_item(_preset_display_name(ids[index]), index)
	option.selected = maxi(ids.find(selected_id), 0)
	option.item_selected.connect(callback.bind(ids))
	option.item_selected.connect(func(_selected_index: int) -> void: _play_click_sound())
	option.mouse_entered.connect(_play_hover_sound)
	_apply_option_skin(option)
	box.add_child(option)
	return box


func _preset_display_name(preset_id: String) -> String:
	if ScenarioDefinitionsClass.SCENARIOS.has(preset_id):
		return ScenarioDefinitionsClass.get_title(preset_id)
	return ColorPresetsClass.get_display_name(preset_id)


func _on_scenario_selected(index: int, ids: Array[String]) -> void:
	_match_config.apply_scenario(ids[index])
	_refresh_summary()


func _on_colors_selected(index: int, ids: Array[String]) -> void:
	_match_config.apply_color_preset(ids[index])
	_refresh_summary()


func _refresh_summary() -> void:
	if _summary_label == null:
		return
	_summary_label.text = "[b]%s[/b]\n[color=gray]%s[/color]\n\n%s\n\n[b]Map:[/b] %s\n[b]Enemy plan:[/b] %s\n[b]Colors:[/b] %s\n\n[b]Objectives[/b]\n%s" % [
		_match_config.scenario_title,
		_match_config.scenario_subtitle,
		_match_config.scenario_briefing,
		_match_config.map_display_name,
		_match_config.ai_aggression_display_name,
		_match_config.color_display_name,
		_match_config.build_objective_preview_text(),
	]


func _on_start_pressed() -> void:
	_play_click_sound()
	var gameplay_scene := load("res://scenes/prototype_gameplay.tscn") as PackedScene
	if gameplay_scene == null:
		push_error("Pregame: could not load prototype_gameplay.tscn")
		return

	var gameplay_node := gameplay_scene.instantiate()
	if gameplay_node.has_method("set_match_config"):
		gameplay_node.set_match_config(_match_config)

	get_tree().root.add_child(gameplay_node)
	get_tree().current_scene = gameplay_node
	queue_free()


func _apply_ui_audio(parent: Node) -> void:
	_click_player = AudioStreamPlayer.new()
	_click_player.stream = AssetCatalogClass.get_audio_stream("click")
	parent.add_child(_click_player)
	_hover_player = AudioStreamPlayer.new()
	_hover_player.stream = AssetCatalogClass.get_audio_stream("hover")
	parent.add_child(_hover_player)


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


func _apply_option_skin(option: OptionButton) -> void:
	_apply_button_skin(option)


func _play_click_sound() -> void:
	if _click_player != null and _click_player.stream != null:
		_click_player.play()


func _play_hover_sound() -> void:
	if _hover_player != null and _hover_player.stream != null and not _hover_player.playing:
		_hover_player.play()
