extends Node

## Minimal pregame entry point.
## Builds a MatchConfig from user difficulty selection and passes it to gameplay.

const MatchConfigClass = preload("res://simulation/match_config.gd")

var _selected_difficulty: String = "normal"
var _match_config: MatchConfigClass = null


func _ready() -> void:
	_build_ui()


func _build_ui() -> void:
	var canvas := CanvasLayer.new()
	add_child(canvas)

	var panel := ColorRect.new()
	panel.color = Color(0.06, 0.08, 0.10, 1.0)
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	canvas.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_CENTER)
	vbox.position = Vector2(-160.0, -120.0)
	vbox.custom_minimum_size = Vector2(320.0, 240.0)
	canvas.add_child(vbox)

	var title := Label.new()
	title.text = "Age of Empires But Mine"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 28)
	vbox.add_child(title)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 24)
	vbox.add_child(spacer)

	var diff_label := Label.new()
	diff_label.text = "Difficulty"
	diff_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(diff_label)

	var option := OptionButton.new()
	option.add_item("Easy", 0)
	option.add_item("Normal", 1)
	option.add_item("Hard", 2)
	option.selected = 1
	option.item_selected.connect(_on_difficulty_selected)
	vbox.add_child(option)

	var spacer2 := Control.new()
	spacer2.custom_minimum_size = Vector2(0, 32)
	vbox.add_child(spacer2)

	var start_btn := Button.new()
	start_btn.text = "Start Match"
	start_btn.pressed.connect(_on_start_pressed)
	vbox.add_child(start_btn)


func _on_difficulty_selected(index: int) -> void:
	match index:
		0:
			_selected_difficulty = "easy"
		1:
			_selected_difficulty = "normal"
		2:
			_selected_difficulty = "hard"


func _on_start_pressed() -> void:
	_match_config = MatchConfigClass.new()
	match _selected_difficulty:
		"easy":
			_match_config.ai_attack_start_tick = 600
			_match_config.ai_attack_wave_interval_ticks = 180
			_match_config.ai_min_attackers_per_wave = 2
		"hard":
			_match_config.ai_production_start_tick = 120
			_match_config.ai_production_interval_ticks = 40
			_match_config.ai_attack_start_tick = 300
			_match_config.ai_attack_wave_interval_ticks = 90
			_match_config.ai_min_attackers_per_wave = 3

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
