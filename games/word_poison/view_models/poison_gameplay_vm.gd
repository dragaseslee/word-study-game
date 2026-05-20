class_name PoisonGameplayVM
extends ViewModel

const BOARD_DIMENSIONS := {3: 9, 4: 16, 5: 25}

var _config: Dictionary = {}
var _selected_word_set: Dictionary = {}
var _all_words: Array[Dictionary] = []
var _board_size := 4
var _players: Array[Dictionary] = []
var _current_player_index := -1
var _finished_player_count := 0
var _finish_counter := 0
var _turn_is_waiting := false


func _on_initialize(config: Dictionary) -> void:
	_config = config.duplicate(true)
	_selected_word_set = Dictionary(_config.get("word_set", {})).duplicate(true)
	var requested_board_size := int(_config.get("board_size", 4))
	_board_size = requested_board_size if BOARD_DIMENSIONS.has(requested_board_size) else 4
	_all_words = WordSetStore.parse_word_file(String(_selected_word_set.get("file_path", "")))
	_init_players()
	_start_player_turn(0)


func on_cell_pressed(cell_index: int, player_index: int) -> void:
	if _turn_is_waiting or _current_player_index < 0:
		return
	if player_index != _current_player_index:
		return
	if _players[_current_player_index]["is_eliminated"]:
		return

	var clicked_indices: Array = _players[_current_player_index]["clicked_indices"]
	if clicked_indices.has(cell_index):
		return

	clicked_indices.append(cell_index)
	_players[_current_player_index]["clicked_indices"] = clicked_indices

	var poison_indices: Array = _players[_current_player_index].get("poison_indices", [])
	if poison_indices.has(cell_index):
		_players[_current_player_index]["health"] -= 1
		if _players[_current_player_index]["health"] <= 0:
			_players[_current_player_index]["is_eliminated"] = true
			_players[_current_player_index]["finish_order"] = _finish_counter
			_finish_counter += 1
			_finished_player_count += 1
			_turn_is_waiting = true
			notify_view()
			return
	else:
		_players[_current_player_index]["safe_click_count"] = int(_players[_current_player_index].get("safe_click_count", 0)) + 1

	if _check_all_cells_clicked():
		_turn_is_waiting = true
		notify_view()
		return

	var next_player_index := (_current_player_index + 1) % _players.size()
	_start_player_turn(next_player_index)
	notify_view()


func request_end_game() -> void:
	_open_results()


func is_game_over() -> bool:
	return _turn_is_waiting


func get_sorted_results() -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	for player in _players:
		results.append(player.duplicate(true))
	results.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var score_a := int(a.get("safe_click_count", 0))
		var score_b := int(b.get("safe_click_count", 0))
		if score_a == score_b:
			return int(a.get("finish_order", 9999)) < int(b.get("finish_order", 9999))
		return score_a > score_b
	)
	return results


func _init_players() -> void:
	_players.clear()
	var player_seeds := _config.get("players", []) as Array
	for index in range(player_seeds.size()):
		var player_seed := player_seeds[index] as Dictionary
		var player_name := String(player_seed.get("name", "")).strip_edges()
		if player_name.is_empty():
			player_name = "玩家%d" % (index + 1)
		var p_state := _build_player_state({"id": index, "name": player_name})
		var poison_count := int(_config.get("poison_count", 2))
		var available_indices := range(p_state["board_cells"].size())
		available_indices.shuffle()
		for i in range(min(poison_count, available_indices.size())):
			var p_indices: Array = p_state["poison_indices"]
			p_indices.append(available_indices[i])
		_players.append(p_state)


func _generate_single_board() -> Array[Dictionary]:
	var board_cells: Array[Dictionary] = []
	var cell_count := int(BOARD_DIMENSIONS.get(_board_size, 16))
	for i in range(cell_count):
		var entry := _all_words[randi() % _all_words.size()]
		board_cells.append({
			"cell_index": i,
			"english": entry.get("english", ""),
			"chinese": entry.get("chinese", ""),
		})
	return board_cells


func _build_player_state(seed: Dictionary) -> Dictionary:
	return {
		"id": int(seed.get("id", 0)),
		"name": String(seed.get("name", "玩家")),
		"health": int(_config.get("initial_health", 2)),
		"safe_click_count": 0,
		"is_eliminated": false,
		"poison_indices": [],
		"clicked_indices": [],
		"finish_order": 9999,
		"board_cells": _generate_single_board(),
	}


func _start_player_turn(player_index: int) -> void:
	_current_player_index = player_index
	_turn_is_waiting = false


func _check_all_cells_clicked() -> bool:
	var cell_count := int(BOARD_DIMENSIONS.get(_board_size, 16))
	for player in _players:
		var clicked: Array = player.get("clicked_indices", [])
		if clicked.size() < cell_count:
			return false
	return true


func _open_results() -> void:
	var results := get_sorted_results()
	SceneRouter.goto_result("word_poison", results)


func build_view_data() -> Dictionary:
	var current_player_name := ""
	var current_player_id := -1
	if _current_player_index >= 0 and _current_player_index < _players.size():
		current_player_name = String(_players[_current_player_index].get("name", ""))
		current_player_id = int(_players[_current_player_index].get("id", -1))

	var status_text := ""
	if _current_player_index >= 0 and _current_player_index < _players.size():
		if _turn_is_waiting:
			var player := _players[_current_player_index]
			if bool(player.get("is_eliminated", false)):
				status_text = "%s 中毒，生命耗尽，游戏结束！" % player.get("name", "玩家")
			elif _check_all_cells_clicked():
				status_text = "所有格子已点完，游戏结束！"
		else:
			status_text = "当前回合：%s，请选择一个单词" % _players[_current_player_index].get("name", "玩家")

	var players_view_data: Array[Dictionary] = []
	for player_index in range(_players.size()):
		var player = _players[player_index]
		var view_cells: Array[Dictionary] = []
		var clicked_lookup: Array = player.get("clicked_indices", [])
		var poison_indices: Array = player.get("poison_indices", [])
		var is_current_player := player_index == _current_player_index
		var is_eliminated := bool(player.get("is_eliminated", false))
		var board_cells: Array[Dictionary] = player.get("board_cells", [])

		for cell in board_cells:
			var cell_index := int(cell.get("cell_index", -1))
			var is_clicked := clicked_lookup.has(cell_index)
			view_cells.append({
				"cell_index": cell_index,
				"display_text": cell.get("chinese", "") if is_clicked else cell.get("english", ""),
				"disabled": is_clicked or _turn_is_waiting or not is_current_player or is_eliminated,
				"effect_type": "poison" if poison_indices.has(cell_index) else "normal",
			})

		players_view_data.append({
			"player_index": player_index,
			"player": player,
			"cells": view_cells,
		})

	var best_score := 0
	for player in _players:
		best_score = maxi(best_score, int(player.get("safe_click_count", 0)))

	return {
		"word_set_name": _selected_word_set.get("file_name", ""),
		"board_size": _board_size,
		"current_player_name": current_player_name,
		"current_player_id": current_player_id,
		"status_text": status_text,
		"best_score": best_score,
		"players": _players,
		"players_view_data": players_view_data,
		"is_game_over": _turn_is_waiting,
	}
