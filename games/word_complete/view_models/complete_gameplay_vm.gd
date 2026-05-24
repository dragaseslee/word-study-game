class_name CompleteGameplayVM
extends ViewModel

signal game_finished

var _config: Dictionary = {}
var _selected_word_set: Dictionary = {}
var _all_words: Array[Dictionary] = []
var _total_rounds: int = 10
var _current_round: int = 0
var _current_word: Dictionary = {}
var _missing_index: int = -1
var _correct_letter: String = ""
var _letters: Array[String] = []
var _players: Array[Dictionary] = []
var _active_player_index: int = 0
var _game_finished: bool = false
var _used_word_indices: Array[int] = []


func _on_initialize(config: Dictionary) -> void:
    var validated_config := CompleteConfig.validate_config(config)
    if validated_config.is_empty():
        return
    _config = validated_config
    _selected_word_set = Dictionary(_config.get("word_set", {})).duplicate(true)
    _all_words = WordSetStore.parse_word_file(String(_selected_word_set.get("file_path", "")))
    _total_rounds = int(_config.get("round_count", 10))

    if _all_words.size() < 2:
        return

    _init_players()
    _start_new_round()


func is_initialized() -> bool:
    return not _players.is_empty()


func select_letter(letter: String) -> void:
    if _game_finished:
        return

    var player := _players[_active_player_index]
    if player.get("is_waiting", false):
        return

    if letter.to_upper() == _correct_letter.to_upper():
        # 答对
        player["score"] = int(player.get("score", 0)) + 1
        player["correct_count"] = int(player.get("correct_count", 0)) + 1
        _players[_active_player_index] = player
        _current_round += 1
        if _current_round >= _total_rounds:
            _game_finished = true
            game_finished.emit()
            notify_view()
        else:
            _start_new_round()
    else:
        # 答错，切换活跃玩家
        player["error_count"] = int(player.get("error_count", 0)) + 1
        _players[_active_player_index] = player
        _active_player_index = (_active_player_index + 1) % _players.size()
        notify_view()


func request_end_game() -> void:
    _open_result_scene()


func get_sorted_results() -> Array[Dictionary]:
    var results: Array[Dictionary] = []
    for player in _players:
        results.append(player.duplicate(true))
    results.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
        var score_a := int(a.get("score", 0))
        var score_b := int(b.get("score", 0))
        return score_a > score_b
    )
    return results


func _init_players() -> void:
    _players.clear()
    var player_seeds := _config.get("players", []) as Array
    for index in range(player_seeds.size()):
        var seed := player_seeds[index] as Dictionary
        var player_name := String(seed.get("name", "")).strip_edges()
        if player_name.is_empty():
            player_name = "玩家%d" % (index + 1)
        _players.append({
            "id": index,
            "name": player_name,
            "score": 0,
            "correct_count": 0,
            "error_count": 0,
        })
    _active_player_index = 0


func _start_new_round() -> void:
    _current_word = _pick_random_word()
    var english := String(_current_word.get("english", ""))
    _missing_index = randi() % english.length()
    _correct_letter = english[_missing_index]
    _letters = _generate_letters(_correct_letter)
    notify_view()


func _pick_random_word() -> Dictionary:
    var available_indices: Array[int] = []
    for i in range(_all_words.size()):
        if not _used_word_indices.has(i):
            available_indices.append(i)

    if available_indices.is_empty():
        _used_word_indices.clear()
        for i in range(_all_words.size()):
            available_indices.append(i)

    var chosen_index := available_indices[randi() % available_indices.size()]
    _used_word_indices.append(chosen_index)
    return _all_words[chosen_index]


func _generate_letters(correct_letter: String) -> Array[String]:
    var all_letters := "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
    var result: Array[String] = [correct_letter.to_upper()]

    # 从剩余字母中随机选取干扰字母
    var pool: Array[String] = []
    for c in all_letters:
        if c.to_upper() != correct_letter.to_upper():
            pool.append(c)
    pool.shuffle()

    for i in range(CompleteConfig.DISTRACTOR_COUNT):
        result.append(pool[i])
    result.shuffle()
    return result


func _open_result_scene() -> void:
    var results := get_sorted_results()
    SceneRouter.goto_result("word_complete", results)


func build_view_data() -> Dictionary:
    var english := String(_current_word.get("english", ""))
    var chinese := String(_current_word.get("chinese", ""))

    # 构建带下划线的单词显示
    var masked_word := ""
    for i in range(english.length()):
        if i == _missing_index:
            masked_word += "_"
        else:
            masked_word += english[i]

    var players_view_data: Array[Dictionary] = []
    for i in range(_players.size()):
        var player := _players[i]
        players_view_data.append({
            "name": String(player.get("name", "")),
            "score": int(player.get("score", 0)),
            "is_active": i == _active_player_index,
        })

    return {
        "current_round": _current_round + 1,
        "total_rounds": _total_rounds,
        "meaning": chinese,
        "masked_word": masked_word,
        "players": players_view_data,
        "active_player_index": _active_player_index,
        "letters": _letters,
        "game_finished": _game_finished,
    }
