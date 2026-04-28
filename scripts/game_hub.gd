extends Control

const PoisonMusic = preload("res://scripts/poison_music.gd")

@onready var witchs_potion_panel: Control = $"MarginContainer/VBoxContainer/GamesPanel/GridContainer/WitchsPotionPanel"
@onready var witchs_potion_button: TextureButton = $"MarginContainer/VBoxContainer/GamesPanel/GridContainer/WitchsPotionPanel/AspectRatioContainer/TextureButton"
@onready var word_match_panel: Control = $"MarginContainer/VBoxContainer/GamesPanel/GridContainer/WordMatchPanel"
@onready var word_match_button: TextureButton = $"MarginContainer/VBoxContainer/GamesPanel/GridContainer/WordMatchPanel/AspectRatioContainer/TextureButton"

const WORD_POISON_SCENE := "res://scenes/word_poison_setting.tscn"
const WORD_MATCH_SETTING_SCENE := "res://scenes/word_match_setting.tscn"

const CARD_NORMAL_SCALE := Vector2.ONE
const CARD_HOVER_SCALE := Vector2(1.04, 1.04)
const CARD_PRESSED_SCALE := Vector2(0.97, 0.97)
const CARD_NORMAL_MODULATE := Color(1.0, 1.0, 1.0, 1.0)
const CARD_HOVER_MODULATE := Color(1.08, 1.08, 1.08, 1.0)
const CARD_PRESSED_MODULATE := Color(0.96, 0.96, 0.96, 1.0)
const HOVER_DURATION := 0.14
const PRESS_DURATION := 0.08

var _card_tweens: Dictionary = {}


func _ready() -> void:
	PoisonMusic.stop(get_tree())
	_setup_game_card(witchs_potion_panel, witchs_potion_button)
	_setup_game_card(word_match_panel, word_match_button)
	witchs_potion_panel.gui_input.connect(_on_witchs_potion_panel_input)
	witchs_potion_button.pressed.connect(_on_witchs_potion_panel_pressed)
	word_match_panel.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			if _is_mouse_over(word_match_button):
				return
			_on_word_match_panel_pressed()
	)
	word_match_button.pressed.connect(_on_word_match_panel_pressed)


func _on_witchs_potion_panel_pressed() -> void:
	get_tree().change_scene_to_file(WORD_POISON_SCENE)


func _on_word_match_panel_pressed() -> void:
	get_tree().change_scene_to_file(WORD_MATCH_SETTING_SCENE)


func _on_witchs_potion_panel_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if _is_mouse_over(witchs_potion_button):
			return
		_on_witchs_potion_panel_pressed()


func _setup_game_card(panel: Control, button: BaseButton) -> void:
	panel.pivot_offset = panel.size / 2.0
	panel.resized.connect(_on_card_resized.bind(panel))
	button.mouse_entered.connect(_on_card_mouse_entered.bind(panel, button))
	button.mouse_exited.connect(_on_card_mouse_exited.bind(panel, button))
	button.button_down.connect(_on_card_button_down.bind(panel))
	button.button_up.connect(_on_card_button_up.bind(panel, button))
	_animate_card_to(panel, CARD_NORMAL_SCALE, CARD_NORMAL_MODULATE, 0.0)


func _on_card_resized(panel: Control) -> void:
	panel.pivot_offset = panel.size / 2.0


func _on_card_mouse_entered(panel: Control, _button: BaseButton) -> void:
	_animate_card_to(panel, CARD_HOVER_SCALE, CARD_HOVER_MODULATE, HOVER_DURATION)


func _on_card_mouse_exited(panel: Control, button: BaseButton) -> void:
	if _is_mouse_over(button):
		return
	_animate_card_to(panel, CARD_NORMAL_SCALE, CARD_NORMAL_MODULATE, HOVER_DURATION)


func _on_card_button_down(panel: Control) -> void:
	_animate_card_to(panel, CARD_PRESSED_SCALE, CARD_PRESSED_MODULATE, PRESS_DURATION)


func _on_card_button_up(panel: Control, button: BaseButton) -> void:
	if _is_mouse_over(button):
		_animate_card_to(panel, CARD_HOVER_SCALE, CARD_HOVER_MODULATE, HOVER_DURATION)
		return

	_animate_card_to(panel, CARD_NORMAL_SCALE, CARD_NORMAL_MODULATE, HOVER_DURATION)


func _animate_card_to(panel: Control, target_scale: Vector2, target_modulate: Color, duration: float) -> void:
	var existing_tween: Tween = _card_tweens.get(panel)
	if existing_tween != null and existing_tween.is_valid():
		existing_tween.kill()

	if duration <= 0.0:
		panel.scale = target_scale
		panel.modulate = target_modulate
		_card_tweens.erase(panel)
		return

	var tween := create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(panel, "scale", target_scale, duration)
	tween.parallel().tween_property(panel, "modulate", target_modulate, duration)
	_card_tweens[panel] = tween


func _is_mouse_over(control: Control) -> bool:
	return control.get_global_rect().has_point(control.get_global_mouse_position())
