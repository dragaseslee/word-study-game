extends SceneTree

const WORD_MATCH_SETTING_SCENE_PATH := "res://scenes/word_match_setting.tscn"
const WORD_MATCH_GAME_SCENE_PATH := "res://scenes/word_match_game.tscn"
const SAMPLE_WORD_SET_PATH := "res://sample_word_sets/basic_words.txt"


func _initialize() -> void:
	var settings_scene := load(WORD_MATCH_SETTING_SCENE_PATH) as PackedScene
	_assert(settings_scene != null, "Word match setting scene should load")

	var settings_root := settings_scene.instantiate()
	_assert(settings_root != null, "Word match setting scene should instantiate")
	get_root().add_child(settings_root)
	await process_frame

	var controller := settings_root
	_assert(controller.get_script() != null, "Word match setting controller script should exist")
	_assert(controller._players.size() == 1, "Word match setting should seed one default player")

	var player_list := settings_root.get_node("%PlayerList") as Container
	_assert(player_list != null, "Player list should exist")
	_assert(player_list.get_child_count() == 1, "Word match setting should render one default player")

	var max_errors_spin_box := settings_root.get_node("%MaxErrorsSpinBox") as SpinBox
	_assert(max_errors_spin_box != null, "Max errors spin box should exist")
	_assert(int(max_errors_spin_box.value) == 3, "Max errors should default to 3")

	var start_button := settings_root.get_node("%StartButton") as BaseButton
	_assert(start_button != null, "Start button should exist")
	_assert(start_button.disabled, "Start should stay disabled until a word set is selected")

	var store := WordSetStore.new()
	var import_result: Dictionary = store.import_word_set(ProjectSettings.globalize_path(SAMPLE_WORD_SET_PATH))
	_assert(bool(import_result.get("ok", false)), "Sample word set should import successfully")
	controller._setup_word_set_options()
	await process_frame

	var selected_index: int = controller._find_word_set_index(String(import_result.get("file_path", "")))
	_assert(selected_index >= 0, "Imported word set should appear in the selector")

	var word_set_option := settings_root.get_node("%WordSetOption") as OptionButton
	word_set_option.select(selected_index)
	controller._on_word_set_selected(selected_index)
	controller._on_layout_selected(5)
	controller._on_add_player_pressed()
	controller._players[0]["name"] = "   "
	controller._players[0]["score"] = 99
	controller._players[1]["name"] = "   "
	controller._players[1]["avatar"] = "ghost"
	controller._on_player_name_changed("   ", 1)
	max_errors_spin_box.value = 2
	controller._update_start_state()
	await process_frame

	_assert(not start_button.disabled, "Start should enable for a valid word set, layout, players, and error limit")

	controller._on_start_pressed()
	await process_frame

	var current_scene := get_root().get_child(get_root().get_child_count() - 1)
	_assert(current_scene != null, "Starting should open a gameplay scene")
	_assert(current_scene.scene_file_path == WORD_MATCH_GAME_SCENE_PATH, "Starting should navigate to the word match gameplay scene")
	_assert(current_scene.has_node("%BoardGrid"), "Word match gameplay scene should expose the runtime board grid")

	var startup_config := current_scene.get("_startup_config") as Dictionary
	_assert(String(startup_config.get("game_type", "")) == "word_match", "Startup config should mark the word match game type")
	_assert(int(startup_config.get("board_size", 0)) == 5, "Startup config should keep the selected board size")
	var players := startup_config.get("players", []) as Array
	_assert(players.size() == 2, "Startup config should include both players")
	_assert(String((players[0] as Dictionary).get("name", "")) == "玩家1", "Startup config should normalize blank player names")
	_assert(String((players[1] as Dictionary).get("name", "")) == "玩家2", "Startup config should normalize blank player names")
	_assert(int((players[0] as Dictionary).get("id", -1)) == 0, "Startup config should reindex player ids from the builder")
	_assert(int((players[1] as Dictionary).get("id", -1)) == 1, "Startup config should reindex player ids from the builder")
	_assert(not (players[0] as Dictionary).has("score"), "Startup config should strip unexpected player fields")
	_assert(not (players[1] as Dictionary).has("avatar"), "Startup config should strip unexpected player fields")
	var rules := startup_config.get("rules", {}) as Dictionary
	_assert(int(rules.get("max_errors", -1)) == 2, "Startup config should keep the selected allowed mistakes")

	quit(0)


func _assert(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	quit(1)
