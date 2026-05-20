class_name PoisonSettingVM
extends ViewModel

const MIN_PLAYERS := 2
const MAX_PLAYERS := 2

var _word_sets: Array[Dictionary] = []
var _selected_word_set: Dictionary = {}
var _board_size := 4
var _players: Array[Dictionary] = []
var _initial_health := 2
var _poison_count := 2


func _on_initialize(_config: Dictionary) -> void:
	_players = [_make_player(0), _make_player(1)]
	_refresh_word_sets()


func select_word_set(index: int) -> void:
	if index < 0 or index >= _word_sets.size():
		_selected_word_set = {}
	else:
		_selected_word_set = _word_sets[index].duplicate(true)
	notify_view()


func set_board_size(size: int) -> void:
	_board_size = size
	notify_view()


func set_initial_health(value: int) -> void:
	_initial_health = maxi(1, value)
	notify_view()


func set_poison_count(value: int) -> void:
	_poison_count = maxi(1, value)
	notify_view()


func set_player_name(index: int, name: String) -> void:
	if index < 0 or index >= _players.size():
		return
	_players[index]["name"] = name
	notify_view()


func remove_player(index: int) -> void:
	if _players.size() <= MIN_PLAYERS:
		return
	if index < 0 or index >= _players.size():
		return
	_players.remove_at(index)
	_reindex_players()
	notify_view()


func import_word_set(source_path: String) -> Dictionary:
	var result := WordSetStore.import_word_set(source_path)
	if bool(result.get("ok", false)):
		_selected_word_set = {
			"file_name": result.get("file_name", ""),
			"file_path": result.get("file_path", ""),
			"word_count": result.get("word_count", 0),
		}
		_refresh_word_sets()
	return result


func can_start() -> bool:
	return not _selected_word_set.is_empty()


func start_game() -> Dictionary:
	if _selected_word_set.is_empty():
		return {}
	var words := WordSetStore.parse_word_file(String(_selected_word_set.get("file_path", "")))
	if words.is_empty():
		return {}
	return PoisonConfig.build_config(
		_selected_word_set,
		_board_size,
		_players,
		_initial_health,
		_poison_count,
	)


func _refresh_word_sets() -> void:
	_word_sets = WordSetStore.list_word_sets()
	if _selected_word_set.is_empty() and not _word_sets.is_empty():
		_selected_word_set = _word_sets[0].duplicate(true)


func _make_player(index: int) -> Dictionary:
	return {"id": index, "name": "玩家%d" % (index + 1)}


func _reindex_players() -> void:
	for index in range(_players.size()):
		_players[index]["id"] = index
		if String(_players[index].get("name", "")).strip_edges().is_empty():
			_players[index]["name"] = "玩家%d" % (index + 1)


func build_view_data() -> Dictionary:
	return {
		"word_sets": _word_sets,
		"selected_word_set": _selected_word_set,
		"board_size": _board_size,
		"players": _players,
		"initial_health": _initial_health,
		"poison_count": _poison_count,
		"can_start": can_start(),
		"min_players": MIN_PLAYERS,
		"max_players": MAX_PLAYERS,
	}
