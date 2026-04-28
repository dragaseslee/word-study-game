extends SceneTree

const WORD_MATCH_SCENE_PATH := "res://scenes/word_match_game.tscn"
const WORD_MATCH_SETTING_SCENE_PATH := "res://scenes/word_match_setting.tscn"
const WORD_MATCH_RESULT_SCENE_PATH := "res://scenes/word_match_result.tscn"
const SAMPLE_WORD_SET_PATH := "res://sample_word_sets/basic_words.txt"


func _initialize() -> void:
	await _test_valid_startup_config_opens_gameplay()
	await _test_invalid_config_returns_to_settings()
	quit(0)


func _test_valid_startup_config_opens_gameplay() -> void:
	var gameplay := await _instantiate_gameplay({
		"game_type": "word_match",
		"word_set": {"file_name": "basic_words.txt", "file_path": SAMPLE_WORD_SET_PATH},
		"board_size": 3,
		"players": [{"id": 0, "name": "玩家1"}, {"id": 1, "name": "玩家2"}],
		"rules": {"max_errors": 1},
	})

	var board_grid := gameplay.get_node("%BoardGrid") as GridContainer
	_assert(board_grid != null, "%BoardGrid should exist")
	_assert(gameplay._board_cells.size() == 9, "3x3 gameplay should generate 9 board cells")
	_assert(_count_blank_cells(gameplay._board_cells) == 1, "3x3 gameplay should add exactly one blank cell")

	gameplay._board_cells = [
		{"cell_index": 0, "kind": "word", "pair_id": 0, "text": "apple", "language": "en"},
		{"cell_index": 1, "kind": "word", "pair_id": 0, "text": "苹果", "language": "zh"},
		{"cell_index": 2, "kind": "word", "pair_id": 1, "text": "banana", "language": "en"},
		{"cell_index": 3, "kind": "word", "pair_id": 1, "text": "香蕉", "language": "zh"},
		{"cell_index": 4, "kind": "word", "pair_id": 2, "text": "orange", "language": "en"},
		{"cell_index": 5, "kind": "word", "pair_id": 2, "text": "橙子", "language": "zh"},
		{"cell_index": 6, "kind": "word", "pair_id": 3, "text": "grape", "language": "en"},
		{"cell_index": 7, "kind": "word", "pair_id": 3, "text": "葡萄", "language": "zh"},
		{"cell_index": 8, "kind": "blank", "pair_id": -1, "text": "", "language": ""},
	]
	gameplay._players = [
		gameplay._build_player_state({"id": 0, "name": "玩家1"}),
		gameplay._build_player_state({"id": 1, "name": "玩家2"}),
	]
	gameplay._start_player_turn(0)
	gameplay._refresh_view()
	await process_frame

	var initial_child_count := board_grid.get_child_count()
	var first_button := board_grid.get_child(0) as Button
	first_button.pressed.emit()
	await process_frame
	_assert(board_grid.get_child_count() == initial_child_count, "Clicking a word card should rebuild the board without leaving a locked button behind")
	_assert(gameplay._selected_cell_indices == [0], "Signal-driven card click should still record the selected cell")

	gameplay.set_startup_config({
		"game_type": "word_match",
		"word_set": {"file_name": "basic_words.txt", "file_path": SAMPLE_WORD_SET_PATH},
		"board_size": 4,
		"players": [{"id": 0, "name": "玩家1"}],
		"rules": {"max_errors": 2},
	})
	_assert(gameplay._initialize_from_config(), "4x4 config should initialize successfully")
	_assert(gameplay._board_cells.size() == 16, "4x4 gameplay should generate 16 board cells")
	_assert(_count_blank_cells(gameplay._board_cells) == 0, "4x4 gameplay should not add a blank cell")

	gameplay._board_cells = [
		{"kind": "word", "pair_id": 0, "text": "apple", "language": "en"},
		{"kind": "word", "pair_id": 0, "text": "苹果", "language": "zh"},
		{"kind": "word", "pair_id": 1, "text": "banana", "language": "en"},
		{"kind": "word", "pair_id": 1, "text": "香蕉", "language": "zh"},
		{"kind": "word", "pair_id": 2, "text": "orange", "language": "en"},
		{"kind": "word", "pair_id": 2, "text": "橙子", "language": "zh"},
		{"kind": "word", "pair_id": 3, "text": "grape", "language": "en"},
		{"kind": "word", "pair_id": 3, "text": "葡萄", "language": "zh"},
		{"kind": "blank", "pair_id": -1, "text": "", "language": ""},
	]
	gameplay._board_size = 3
	gameplay._players = [
		gameplay._build_player_state({"id": 0, "name": "玩家1"}),
		gameplay._build_player_state({"id": 1, "name": "玩家2"}),
	]
	gameplay._max_errors = 1
	gameplay._finished_player_count = 0
	gameplay._finish_counter = 0
	gameplay._start_player_turn(0)
	gameplay._refresh_view()

	gameplay._on_cell_pressed(8)
	_assert(gameplay._selected_cell_indices.is_empty(), "Blank cell click should do nothing")

	gameplay._on_cell_pressed(0)
	_assert(gameplay._selected_cell_indices == [0], "First click should store selected cell")
	gameplay._on_cell_pressed(0)
	_assert(gameplay._selected_cell_indices == [0], "Clicking the same cell twice should ignore the second click")
	gameplay._on_cell_pressed(1)
	_assert(int(gameplay._players[0].get("matched_pair_count", 0)) == 1, "Matching pair should increment matched pair count")
	_assert(gameplay._players[0].get("matched_cell_indices", []).has(0), "Matching pair should record the English cell index")
	_assert(gameplay._players[0].get("matched_cell_indices", []).has(1), "Matching pair should record the Chinese cell index")

	gameplay._on_cell_pressed(0)
	_assert(gameplay._selected_cell_indices.is_empty(), "Matched cell click should do nothing")

	gameplay._on_cell_pressed(2)
	gameplay._on_cell_pressed(5)
	_assert(int(gameplay._players[0].get("error_count", 0)) == 1, "Wrong pair should increment error count")
	_assert(not bool(gameplay._players[0].get("is_failed", false)), "First wrong pair should not fail while within limit")

	gameplay._on_cell_pressed(2)
	gameplay._on_cell_pressed(8)
	_assert(int(gameplay._players[0].get("error_count", 0)) == 1, "Blank cell should not become a second selection")
	gameplay._on_cell_pressed(3)
	_assert(int(gameplay._players[0].get("matched_pair_count", 0)) == 2, "Second correct pair should still work after a mistake")

	gameplay._on_cell_pressed(4)
	gameplay._on_cell_pressed(7)
	_assert(int(gameplay._players[0].get("error_count", 0)) == 2, "Second wrong pair should increment error count again")
	_assert(bool(gameplay._players[0].get("is_failed", false)), "Second wrong pair should fail when errors exceed the limit")
	_assert(gameplay._turn_is_waiting, "Failed turn should wait for the next player")

	gameplay._on_next_player_requested()
	_assert(gameplay._current_player_index == 1, "Next player action should advance to player 2")
	_assert(int(gameplay._players[1].get("matched_pair_count", 0)) == 0, "Player 2 should start with independent progress")
	_assert(int(gameplay._players[1].get("error_count", 0)) == 0, "Player 2 should start with independent mistakes")
	_assert(not gameplay._turn_is_waiting, "Player 2 turn should resume interaction")

	gameplay._on_cell_pressed(0)
	gameplay._on_cell_pressed(1)
	_assert(int(gameplay._players[1].get("matched_pair_count", 0)) == 1, "Player 2 should match the same pair independently")
	gameplay._on_cell_pressed(2)
	gameplay._on_cell_pressed(3)
	gameplay._on_cell_pressed(4)
	gameplay._on_cell_pressed(5)
	gameplay._on_cell_pressed(6)
	gameplay._on_cell_pressed(7)
	_assert(bool(gameplay._players[1].get("is_cleared", false)), "Player 2 should clear after matching every real pair")
	_assert(int(gameplay._players[1].get("finish_order", 9999)) == 1, "Player 2 clear should record the second finish order")
	_assert(gameplay._turn_is_waiting, "Player 2 clear should wait for the result handoff action")

	gameplay._on_next_player_requested()
	await process_frame

	var result_scene := get_root().get_child(get_root().get_child_count() - 1)
	_assert(result_scene.scene_file_path == WORD_MATCH_RESULT_SCENE_PATH, "Finished gameplay should open the word match result scene")
	_assert(result_scene.has_method("set_results"), "Finished gameplay should hand off to a result controller with set_results")
	_assert(result_scene.has_node("%ResultsList"), "Finished gameplay should hand off to a result scene with ResultsList")

	result_scene.free()
	await process_frame


func _test_invalid_config_returns_to_settings() -> void:
	var scene := load(WORD_MATCH_SCENE_PATH) as PackedScene
	_assert(scene != null, "Word match scene should load")

	var gameplay := scene.instantiate()
	_assert(gameplay != null, "Word match scene should instantiate")
	get_root().add_child(gameplay)
	await process_frame
	await process_frame

	var current_scene := get_root().get_child(get_root().get_child_count() - 1)
	_assert(current_scene != null, "Invalid startup config should still leave an active scene")
	_assert(current_scene.scene_file_path == WORD_MATCH_SETTING_SCENE_PATH, "Missing startup config should return to the word match setting scene")

	current_scene.free()
	await process_frame


func _instantiate_gameplay(startup_config: Dictionary) -> Control:
	var scene := load(WORD_MATCH_SCENE_PATH) as PackedScene
	_assert(scene != null, "Word match scene should load")

	var gameplay := scene.instantiate() as Control
	_assert(gameplay != null, "Word match scene should instantiate")
	gameplay.set_startup_config(startup_config)
	get_root().add_child(gameplay)
	await process_frame
	await process_frame
	return gameplay


func _count_blank_cells(cells: Array) -> int:
	var blank_count := 0
	for cell in cells:
		if String((cell as Dictionary).get("kind", "")) == "blank":
			blank_count += 1
	return blank_count


func _assert(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	quit(1)
