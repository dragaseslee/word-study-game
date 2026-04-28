extends Control

const PLAYER_SCORE_SCENE := preload("res://scenes/components/player_score.tscn")
const PoisonMusic = preload("res://scripts/poison_music.gd")

var _pending_results: Array[Dictionary] = []

@onready var results_list: VBoxContainer = %ResultsList
@onready var replay_button: Button = %ReplayButton
@onready var back_button: Button = %BackToHubButton


func _ready() -> void:
	PoisonMusic.ensure_playing(get_tree())
	replay_button.pressed.connect(func() -> void: get_tree().change_scene_to_file("res://scenes/game_setting.tscn"))
	back_button.pressed.connect(func() -> void: get_tree().change_scene_to_file("res://scenes/game_hub.tscn"))
	_render_results(_pending_results)


func set_results(results: Array[Dictionary]) -> void:
	_pending_results = results.duplicate(true)
	if not is_node_ready():
		return
	_render_results(_pending_results)


func _render_results(results: Array[Dictionary]) -> void:
	for child in results_list.get_children():
		child.queue_free()

	var max_score := 1
	for player_data in results:
		max_score = max(max_score, int(player_data.get("safe_click_count", 0)))

	for index in range(results.size()):
		var player := results[index] as Dictionary
		var score_card := PLAYER_SCORE_SCENE.instantiate() as Control
		var avatar := score_card.get_node("HBoxContainer/Avatar") as Control
		var avatar_name_edit := avatar.get_node("MarginContainer/LineEdit") as LineEdit
		var avatar_delete := avatar.get_node("AspectRatioContainer/delete") as BaseButton
		var progress_bar := score_card.get_node("HBoxContainer/TextureProgressBar") as TextureProgressBar
		var score_label := score_card.get_node("HBoxContainer/Label") as Label
		avatar_name_edit.text = String(player.get("name", ""))
		avatar_name_edit.editable = false
		avatar_delete.visible = false
		progress_bar.max_value = float(max_score)
		progress_bar.value = float(int(player.get("safe_click_count", 0)))
		score_label.text = "%d" % int(player.get("safe_click_count", 0))
		results_list.add_child(score_card)
