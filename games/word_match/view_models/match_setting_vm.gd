class_name MatchSettingVM
extends ViewModel

const MAX_PLAYERS := 10

var _word_sets: Array[Dictionary] = []
var _selected_word_set: Dictionary = {}
var _board_size := 4
var _players: Array[Dictionary] = []
var _max_errors := 3


func _on_initialize(_config: Dictionary) -> void:
    _players = [{"name": _default_player_name(0)}]
    _refresh_word_sets()


func select_word_set(index: int) -> void:
    if index < 0:
        _selected_word_set = {}
    elif index < _word_sets.size():
        _selected_word_set = _word_sets[index].duplicate(true)
    else:
        _selected_word_set = {}
    notify_view()


func set_board_size(size: int) -> void:
    _board_size = size
    notify_view()


func set_max_errors(value: int) -> void:
    _max_errors = maxi(0, value)
    notify_view()


func add_player() -> void:
    if _players.size() >= MAX_PLAYERS:
        return
    _players.append({"name": _default_player_name(_players.size())})
    notify_view()


func remove_player(index: int) -> void:
    if _players.size() <= 1:
        return
    if index < 0 or index >= _players.size():
        return
    _players.remove_at(index)
    notify_view()


func set_player_name(index: int, name: String) -> void:
    if index < 0 or index >= _players.size():
        return
    _players[index]["name"] = name
    notify_view()


func import_word_set(source_path: String) -> Dictionary:
    var result := WordSetStore.import_word_set(source_path)
    if bool(result.get("ok", false)):
        _selected_word_set = {
            "file_name": result.get("file_name", ""),
            "file_path": result.get("file_path", ""),
            "word_count": int(result.get("word_count", 0)),
        }
        _refresh_word_sets()
    return result


func can_start() -> bool:
    if _word_sets.is_empty():
        return false
    if _selected_word_set.is_empty():
        return false
    if int(_selected_word_set.get("word_count", 0)) < _required_pair_count():
        return false
    return true


func status_text() -> String:
    if _word_sets.is_empty():
        return "暂无可用词表，请先导入词表"
    if _selected_word_set.is_empty():
        return "请先选择词表"
    if int(_selected_word_set.get("word_count", 0)) < _required_pair_count():
        return "词表词对不足，当前布局至少需要 %d 对" % _required_pair_count()
    return "已选择 %s，可开始游戏" % String(_selected_word_set.get("file_name", ""))


func start_game() -> Dictionary:
    if not can_start():
        return {}
    var parsed_words := WordSetStore.parse_word_file(String(_selected_word_set.get("file_path", "")))
    if parsed_words.size() < _required_pair_count():
        _selected_word_set["word_count"] = parsed_words.size()
        return {}
    return MatchConfig.build_config(_selected_word_set, _board_size, _players, _max_errors)


func _refresh_word_sets() -> void:
    _word_sets = WordSetStore.list_word_sets()
    if _selected_word_set.is_empty() and not _word_sets.is_empty():
        _selected_word_set = _word_sets[0].duplicate(true)


func _required_pair_count() -> int:
    return int(floor(float(_board_size * _board_size) / 2.0))


func _default_player_name(index: int) -> String:
    return "玩家%d" % (index + 1)


func build_view_data() -> Dictionary:
    return {
        "word_sets": _word_sets,
        "selected_word_set": _selected_word_set,
        "board_size": _board_size,
        "players": _players,
        "max_errors": _max_errors,
        "can_start": can_start(),
        "status_text": status_text(),
        "max_players": MAX_PLAYERS,
        "required_pair_count": _required_pair_count(),
    }
