extends SceneTree

const RESULT_SCENE_PATH := "res://scenes/word_match_result.tscn"
const WORD_MATCH_SETTING_SCENE_PATH := "res://scenes/word_match_setting.tscn"
const GAME_HUB_SCENE_PATH := "res://scenes/game_hub.tscn"


func _initialize() -> void:
	await _test_result_scene_renders_ranked_rows_and_actions()
	await _test_missing_results_falls_back_to_settings()
	quit(0)


func _test_result_scene_renders_ranked_rows_and_actions() -> void:
	var result_scene := load(RESULT_SCENE_PATH) as PackedScene
	_assert(result_scene != null, "Word match result scene should load")

	var result_root := result_scene.instantiate() as Control
	_assert(result_root != null, "Word match result scene should instantiate")
	_assert(result_root.has_method("set_results"), "Word match result controller should expose set_results")

	result_root.set_results([
		{
			"name": "玩家4",
			"is_cleared": false,
			"matched_pair_count": 2,
			"error_count": 0,
			"finish_order": 4,
		},
		{
			"name": "玩家2",
			"is_cleared": true,
			"matched_pair_count": 3,
			"error_count": 0,
			"finish_order": 1,
		},
		{
			"name": "玩家3",
			"is_cleared": false,
			"matched_pair_count": 2,
			"error_count": 1,
			"finish_order": 2,
		},
		{
			"name": "玩家1",
			"is_cleared": true,
			"matched_pair_count": 3,
			"error_count": 1,
			"finish_order": 3,
		},
	])
	get_root().add_child(result_root)
	await process_frame

	var results_list := result_root.get_node("%ResultsList") as VBoxContainer
	_assert(results_list != null, "ResultsList should exist")
	_assert(results_list.get_child_count() == 4, "ResultsList should render one row per player")

	var first_row := results_list.get_child(0) as Control
	var second_row := results_list.get_child(1) as Control
	var third_row := results_list.get_child(2) as Control
	var fourth_row := results_list.get_child(3) as Control
	_assert(first_row != null, "First result row should exist")
	_assert(second_row != null, "Second result row should exist")
	_assert(third_row != null, "Third result row should exist")
	_assert(fourth_row != null, "Fourth result row should exist")

	_assert(first_row.has_node("NameLabel"), "Result rows should expose NameLabel")
	_assert(first_row.has_node("StatusLabel"), "Result rows should expose StatusLabel")
	_assert((first_row.get_node("NameLabel") as Label).text == "玩家2", "Cleared players with fewer errors should rank first")
	_assert((second_row.get_node("NameLabel") as Label).text == "玩家1", "Cleared players with more errors should rank after otherwise equal cleared players")
	_assert((third_row.get_node("NameLabel") as Label).text == "玩家4", "Uncleared players with fewer errors should rank before otherwise equal players")
	_assert((fourth_row.get_node("NameLabel") as Label).text == "玩家3", "Uncleared players with more errors should rank later")
	_assert((first_row.get_node("StatusLabel") as Label).text != "", "StatusLabel should describe the ranked result")

	var replay_button := result_root.get_node("%ReplayButton") as Button
	var back_button := result_root.get_node("%BackToHubButton") as Button
	_assert(replay_button != null, "ReplayButton should exist")
	_assert(back_button != null, "BackToHubButton should exist")

	replay_button.pressed.emit()
	await process_frame
	await process_frame

	var replay_scene := get_root().get_child(get_root().get_child_count() - 1)
	_assert(replay_scene.scene_file_path == WORD_MATCH_SETTING_SCENE_PATH, "Replay should return to the word match setting scene")
	replay_scene.free()
	await process_frame

	var replay_result_root := result_scene.instantiate() as Control
	_assert(replay_result_root != null, "Word match result scene should instantiate again")
	replay_result_root.set_results([
		{
			"name": "玩家1",
			"is_cleared": true,
			"matched_pair_count": 1,
			"error_count": 0,
			"finish_order": 0,
		},
	])
	get_root().add_child(replay_result_root)
	await process_frame

	var replay_back_button := replay_result_root.get_node("%BackToHubButton") as Button
	replay_back_button.pressed.emit()
	await process_frame
	await process_frame

	var hub_scene := get_root().get_child(get_root().get_child_count() - 1)
	_assert(hub_scene.scene_file_path == GAME_HUB_SCENE_PATH, "Back should return to the game hub scene")
	hub_scene.free()
	await process_frame


func _test_missing_results_falls_back_to_settings() -> void:
	var result_scene := load(RESULT_SCENE_PATH) as PackedScene
	_assert(result_scene != null, "Word match result scene should load for missing-results fallback")

	var result_root := result_scene.instantiate() as Control
	_assert(result_root != null, "Word match result scene should instantiate for missing-results fallback")
	get_root().add_child(result_root)
	await process_frame
	await process_frame

	var current_scene := get_root().get_child(get_root().get_child_count() - 1)
	_assert(current_scene != null, "Missing results should still leave an active scene")
	_assert(current_scene.scene_file_path == WORD_MATCH_SETTING_SCENE_PATH, "Opening the result scene without set_results should return to the word match setting scene")

	current_scene.free()
	await process_frame


func _assert(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	quit(1)
