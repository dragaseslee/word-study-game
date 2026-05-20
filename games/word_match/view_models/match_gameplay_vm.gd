class_name MatchGameplayVM
extends ViewModel

var _config: Dictionary = {}
var _selected_word_set: Dictionary = {}
var _all_words: Array = []
var _board_size := 4
var _board_cells: Array = []
var _players: Array = []
var _current_player_index := -1
var _selected_cell_indices: Array[int] = []
var _finished_player_count := 0
var _finish_counter := 0
var _turn_is_waiting := false
var _max_errors := 0
var _status_text := ""


func _on_initialize(config: Dictionary) -> void:
	var validated_config := MatchConfig.validate_config(config)
	if validated_config.is_empty():
		return
	_config = validated_config
	_selected_word_set = Dictionary(_config.get("word_set", {})).duplicate(true)
	_all_words = WordSetStore.parse_word_file(String(_selected_word_set.get("file_path", "")))
	_board_size = int(_config.get("board_size", 4))
	_max_errors = int(Dictionary(_config.get("rules", {})).get("max_errors", 0))
	if _all_words.size() < _required_pair_count():
		return

	_board_cells = _generate_board_cells()
	_players.clear()
	var player_seeds := _config.get("players", []) as Array
	for index in range(player_seeds.size()):
		var seed := (player_seeds[index] as Dictionary).duplicate(true)
		seed["id"] = index
		_players.append(_build_player_state(seed))
	if _players.is_empty():
		return

	_current_player_index = -1
	_selected_cell_indices.clear()
	_finished_player_count = 0
	_finish_counter = 0
	_turn_is_waiting = false
	_start_player_turn(0)


func on_cell_pressed(cell_index: int) -> void:
	if _turn_is_waiting or _current_player_index < 0:
		return
	if cell_index < 0 or cell_index >= _board_cells.size():
		return

	var player := _players[_current_player_index] as Dictionary
	var matched_indices := player.get("matched_cell_indices", []) as Array
	if matched_indices.has(cell_index):
		return

	var cell := _board_cells[cell_index] as Dictionary
	if String(cell.get("kind", "")) == "blank":
		return
	if _selected_cell_indices.has(cell_index):
		return

	_selected_cell_indices.append(cell_index)
	if _selected_cell_indices.size() == 1:
		_status_text = "已选择第一个单词"
		player["status_text"] = _status_text
		notify_view()
		return

	_evaluate_selection()


func on_next_player_requested() -> void:
	if not _turn_is_waiting:
		return
	var next_player_index := _current_player_index + 1
	if next_player_index >= _players.size():
		_open_result_scene()
		return
	_start_player_turn(next_player_index)
	notify_view()


func is_initialized() -> bool:
	return not _players.is_empty()


func _evaluate_selection() -> void:
	if _current_player_index < 0 or _selected_cell_indices.size() < 2:
		return

	var player := _players[_current_player_index] as Dictionary
	var first_index := _selected_cell_indices[0]
	var second_index := _selected_cell_indices[1]
	var first_cell := _board_cells[first_index] as Dictionary
	var second_cell := _board_cells[second_index] as Dictionary
	var is_match := int(first_cell.get("pair_id", -1)) == int(second_cell.get("pair_id", -1)) \
		and String(first_cell.get("language", "")) != String(second_cell.get("language", ""))

	if is_match:
		var matched_indices := player.get("matched_cell_indices", []) as Array
		matched_indices.append(first_index)
		matched_indices.append(second_index)
		player["matched_cell_indices"] = matched_indices
		player["matched_pair_count"] = int(player.get("matched_pair_count", 0)) + 1
		_selected_cell_indices.clear()
		if int(player.get("matched_pair_count", 0)) >= _required_pair_count():
			_finish_current_player(true, "全部配对完成")
			return
		_status_text = "配对成功，继续寻找"
	else:
		player["error_count"] = int(player.get("error_count", 0)) + 1
		_selected_cell_indices.clear()
		if int(player.get("error_count", 0)) > _max_errors:
			_finish_current_player(false, "错误次数超限")
			return
		_status_text = "配对错误，请重试"

	player["status_text"] = _status_text
	notify_view()


func _finish_current_player(is_cleared: bool, status_text: String) -> void:
	if _current_player_index < 0:
		return
	var player := _players[_current_player_index] as Dictionary
	player["is_cleared"] = is_cleared
	player["is_failed"] = not is_cleared
	player["finish_order"] = _finish_counter
	player["status_text"] = status_text
	_finish_counter += 1
	_finished_player_count += 1
	_selected_cell_indices.clear()
	_turn_is_waiting = true
	_status_text = status_text
	notify_view()


func _start_player_turn(player_index: int) -> void:
	if player_index < 0 or player_index >= _players.size():
		return
	_current_player_index = player_index
	_selected_cell_indices.clear()
	_turn_is_waiting = false
	_status_text = "请选择一个单词"
	_players[player_index]["status_text"] = _status_text


func _generate_board_cells() -> Array:
	var cell_count := _board_size * _board_size
	var pair_count := _required_pair_count()
	var selected_words: Array = []
	for index in range(pair_count):
		selected_words.append((_all_words[index] as Dictionary).duplicate(true))

	var cells: Array = []
	for index in range(selected_words.size()):
		var word: Dictionary = selected_words[index] as Dictionary
		cells.append({"kind": "word", "pair_id": index, "text": String(word.get("english", "")), "language": "en"})
		cells.append({"kind": "word", "pair_id": index, "text": String(word.get("chinese", "")), "language": "zh"})

	cells.shuffle()
	if cell_count % 2 == 1:
		cells.append({"kind": "blank", "pair_id": -1, "text": "", "language": ""})

	for index in range(cells.size()):
		cells[index]["cell_index"] = index
	_board_cells = cells
	return _board_cells


func _build_player_state(seed: Dictionary) -> Dictionary:
	return {
		"id": int(seed.get("id", 0)),
		"name": String(seed.get("name", "玩家")).strip_edges(),
		"matched_pair_count": 0,
		"matched_cell_indices": [],
		"error_count": 0,
		"is_failed": false,
		"is_cleared": false,
		"finish_order": 9999,
		"status_text": "",
	}


func _required_pair_count() -> int:
	return int(floor(float(_board_size * _board_size) / 2.0))


func _open_result_scene() -> void:
	var results := _build_sorted_results()
	SceneRouter.goto_result("word_match", results)


func _build_sorted_results() -> Array:
	var results: Array = []
	for player in _players:
		results.append((player as Dictionary).duplicate(true))
	results.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var cleared_a := bool(a.get("is_cleared", false))
		var cleared_b := bool(b.get("is_cleared", false))
		if cleared_a != cleared_b:
			return cleared_a and not cleared_b
		var matched_a := int(a.get("matched_pair_count", 0))
		var matched_b := int(b.get("matched_pair_count", 0))
		if matched_a != matched_b:
			return matched_a > matched_b
		var errors_a := int(a.get("error_count", 0))
		var errors_b := int(b.get("error_count", 0))
		if errors_a != errors_b:
			return errors_a < errors_b
		return int(a.get("finish_order", 9999)) < int(b.get("finish_order", 9999))
	)
	return results


func build_view_data() -> Dictionary:
	var current_name := ""
	var matched_pair_count := 0
	var error_count := 0
	var matched_indices: Array = []
	if _current_player_index >= 0 and _current_player_index < _players.size():
		var player := _players[_current_player_index] as Dictionary
		current_name = String(player.get("name", ""))
		matched_pair_count = int(player.get("matched_pair_count", 0))
		error_count = int(player.get("error_count", 0))
		matched_indices = player.get("matched_cell_indices", []) as Array

	return {
		"current_player_name": current_name,
		"matched_pair_count": matched_pair_count,
		"required_pair_count": _required_pair_count(),
		"error_count": error_count,
		"max_errors": _max_errors,
		"status_text": _status_text,
		"board_size": _board_size,
		"board_cells": _board_cells,
		"selected_cell_indices": _selected_cell_indices,
		"matched_indices": matched_indices,
		"is_turn_waiting": _turn_is_waiting,
		"finished_player_count": _finished_player_count,
		"total_player_count": _players.size(),
	}
