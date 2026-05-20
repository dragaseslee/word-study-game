extends GameView

const PLAYER_SCORE_SCENE := preload("res://scenes/components/player_score.tscn")

var _vm: PoisonResultVM

@onready var results_list: VBoxContainer = %ResultsList
@onready var replay_button: Button = %ReplayButton
@onready var back_button: Button = %BackToHubButton


func _ready() -> void:
	AudioMgr.play_bgm(preload("res://asserts/sounds/music.mp3"), 1.0)

	var params := SceneRouter.get_params()
	var results: Array = params.get("results", [])

	_vm = PoisonResultVM.new()
	bind(_vm)
	_vm.initialize({"results": results})

	replay_button.pressed.connect(_on_replay_pressed)
	back_button.pressed.connect(_on_back_pressed)


func render(view_data: Dictionary) -> void:
	var results: Array = view_data.get("results", [])

	for child in results_list.get_children():
		child.queue_free()

	var max_score := 1
	for player_data in results:
		max_score = maxi(max_score, int(player_data.get("safe_click_count", 0)))

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


func _on_replay_pressed() -> void:
	_vm.replay()


func _on_back_pressed() -> void:
	_vm.back_to_hub()
