extends SceneTree

const GAME_HUB_SCENE_PATH := "res://scenes/game_hub.tscn"
const WORD_MATCH_SETTING_SCENE_PATH := "res://scenes/word_match_setting.tscn"


func _initialize() -> void:
	var hub_scene := load(GAME_HUB_SCENE_PATH) as PackedScene
	_assert(hub_scene != null, "Game hub scene should load")

	var hub_root := hub_scene.instantiate()
	_assert(hub_root != null, "Game hub scene should instantiate")
	get_root().add_child(hub_root)
	await process_frame

	var controller = hub_root
	_assert(controller.word_match_button != null, "Game hub should expose the word_match_button controller reference")
	_assert(controller.has_method("_on_word_match_panel_pressed"), "Game hub should expose the word-match route handler")

	controller.word_match_button.pressed.emit()
	await process_frame

	var current_scene := get_root().get_child(get_root().get_child_count() - 1)
	_assert(current_scene != null, "Word-match route should load a scene")
	_assert(current_scene.scene_file_path == WORD_MATCH_SETTING_SCENE_PATH, "Word-match route should navigate to the dedicated setting scene")

	current_scene.free()
	quit(0)


func _assert(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	quit(1)
