extends GameView

var _vm: PoisonGameplayVM

@onready var gameplay_panel: Control = %GameplayPanel


func _ready() -> void:
	AudioMgr.play_bgm(preload("res://asserts/sounds/music.mp3"), 1.0)
	randomize()

	var params := SceneRouter.get_params()
	var config: Dictionary = params.get("config", {})

	if config.is_empty():
		SceneRouter.goto_game_setting("word_poison")
		return

	_vm = PoisonGameplayVM.new()
	bind(_vm)
	_vm.initialize(config)

	gameplay_panel.cell_pressed.connect(_on_cell_pressed)
	gameplay_panel.next_player_requested.connect(_on_next_player_requested)
	gameplay_panel.end_game_requested.connect(_on_end_game_requested)


func render(view_data: Dictionary) -> void:
	gameplay_panel.update_view(view_data)

	if _vm.is_game_over():
		await get_tree().create_timer(1.5).timeout
		_vm.request_end_game()


func _on_cell_pressed(cell_index: int, player_index: int) -> void:
	_vm.on_cell_pressed(cell_index, player_index)


func _on_next_player_requested() -> void:
	pass


func _on_end_game_requested() -> void:
	_vm.request_end_game()
