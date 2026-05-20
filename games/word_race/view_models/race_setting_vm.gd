class_name RaceSettingVM
extends ViewModel

var _word_sets: Array[Dictionary] = []
var _selected_word_set: Dictionary = {}
var _round_count := 10
var _option_count := 3
var _cooldown := 5.0
var _players: Array[Dictionary] = []


func _on_initialize(_config: Dictionary) -> void:
    _players = [{"name": "玩家A"}, {"name": "玩家B"}]
    _refresh_word_sets()


func select_word_set(index: int) -> void:
    if index < 0 or index >= _word_sets.size():
        _selected_word_set = {}
    else:
        _selected_word_set = _word_sets[index].duplicate(true)
    notify_view()


func set_round_count(value: int) -> void:
    _round_count = RaceConfig.normalize_round_count(value)
    notify_view()


func set_option_count(value: int) -> void:
    _option_count = RaceConfig.normalize_option_count(value)
    notify_view()


func set_cooldown(value: float) -> void:
    _cooldown = RaceConfig.normalize_cooldown(value)
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
    if int(_selected_word_set.get("word_count", 0)) < _option_count:
        return false
    return true


func status_text() -> String:
    if _word_sets.is_empty():
        return "暂无可用词表，请先导入词表"
    if _selected_word_set.is_empty():
        return "请先选择词表"
    if int(_selected_word_set.get("word_count", 0)) < _option_count:
        return "词表单词不足，当前选项数至少需要 %d 个单词" % _option_count
    return "已选择 %s，可开始游戏" % String(_selected_word_set.get("file_name", ""))


func start_game() -> Dictionary:
    if not can_start():
        return {}
    return RaceConfig.build_config(
        _selected_word_set,
        _round_count,
        _option_count,
        _cooldown,
        _players,
    )


func _refresh_word_sets() -> void:
    _word_sets = WordSetStore.list_word_sets()
    if _selected_word_set.is_empty() and not _word_sets.is_empty():
        _selected_word_set = _word_sets[0].duplicate(true)


func build_view_data() -> Dictionary:
    return {
        "word_sets": _word_sets,
        "selected_word_set": _selected_word_set,
        "round_count": _round_count,
        "option_count": _option_count,
        "cooldown": _cooldown,
        "players": _players,
        "can_start": can_start(),
        "status_text": status_text(),
    }
