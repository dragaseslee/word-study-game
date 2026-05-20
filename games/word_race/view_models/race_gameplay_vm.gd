class_name RaceGameplayVM
extends ViewModel

signal round_finished(winner_index: int)
signal game_finished
signal player_cooldown_started(player_index: int)

var _config: Dictionary = {}
var _selected_word_set: Dictionary = {}
var _all_words: Array[Dictionary] = []
var _total_rounds: int = 10
var _option_count: int = 3
var _cooldown_duration: float = 5.0
var _current_round: int = 0
var _current_word: Dictionary = {}
var _options: Array[Dictionary] = []
var _correct_index: int = -1
var _players: Array[Dictionary] = []
var _round_finished: bool = false
var _game_finished: bool = false
var _used_word_indices: Array[int] = []


func _on_initialize(config: Dictionary) -> void:
    var validated_config := RaceConfig.validate_config(config)
    if validated_config.is_empty():
        return
    _config = validated_config
    _selected_word_set = Dictionary(_config.get("word_set", {})).duplicate(true)
    _all_words = WordSetStore.parse_word_file(String(_selected_word_set.get("file_path", "")))
    _total_rounds = int(_config.get("round_count", 10))
    _option_count = int(_config.get("option_count", 3))
    _cooldown_duration = float(_config.get("cooldown", 5.0))

    if _all_words.size() < _option_count:
        return

    _init_players()
    _start_new_round()


func is_initialized() -> bool:
    return not _players.is_empty()


func on_option_pressed(player_index: int, option_index: int) -> void:
    if _game_finished or _round_finished:
        return
    if player_index < 0 or player_index >= _players.size():
        return
    if option_index < 0 or option_index >= _options.size():
        return

    var player := _players[player_index]
    if player.get("is_cooldown", false):
        return

    if option_index == _correct_index:
        # 答对
        player["score"] = int(player.get("score", 0)) + 1
        player["correct_count"] = int(player.get("correct_count", 0)) + 1
        _round_finished = true
        _players[player_index] = player
        round_finished.emit(player_index)
        notify_view()
    else:
        # 答错，进入冷却
        player["is_cooldown"] = true
        player["cooldown_remaining"] = _cooldown_duration
        player["error_count"] = int(player.get("error_count", 0)) + 1
        _players[player_index] = player
        player_cooldown_started.emit(player_index)
        notify_view()


func on_cooldown_tick(player_index: int) -> void:
    if _game_finished or _round_finished:
        return
    if player_index < 0 or player_index >= _players.size():
        return

    var player := _players[player_index]
    if not player.get("is_cooldown", false):
        return

    player["cooldown_remaining"] = float(player.get("cooldown_remaining", 0.0)) - 1.0
    if player["cooldown_remaining"] <= 0.0:
        player["is_cooldown"] = false
        player["cooldown_remaining"] = 0.0
    _players[player_index] = player
    notify_view()


func advance_round() -> void:
    if _game_finished:
        return
    _current_round += 1
    if _current_round >= _total_rounds:
        _game_finished = true
        game_finished.emit()
        notify_view()
        return
    _start_new_round()


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
            "is_cooldown": false,
            "cooldown_remaining": 0.0,
        })


func _start_new_round() -> void:
    _round_finished = false
    _current_word = _pick_random_word()
    _options = _generate_options(_current_word)
    _correct_index = _find_correct_index()
    for player in _players:
        player["is_cooldown"] = false
        player["cooldown_remaining"] = 0.0
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


func _generate_options(correct_word: Dictionary) -> Array[Dictionary]:
    var options: Array[Dictionary] = []
    options.append({
        "text": String(correct_word.get("chinese", "")),
        "is_correct": true,
    })

    var wrong_words: Array[Dictionary] = []
    var seen_chinese: Dictionary = {}
    seen_chinese[String(correct_word.get("chinese", ""))] = true
    for word in _all_words:
        var chinese := String(word.get("chinese", ""))
        if String(word.get("english", "")) != String(correct_word.get("english", "")) and not seen_chinese.has(chinese):
            wrong_words.append(word)
            seen_chinese[chinese] = true

    wrong_words.shuffle()
    for i in range(min(_option_count - 1, wrong_words.size())):
        options.append({
            "text": String(wrong_words[i].get("chinese", "")),
            "is_correct": false,
        })

    options.shuffle()
    return options


func _find_correct_index() -> int:
    for i in range(_options.size()):
        if bool(_options[i].get("is_correct", false)):
            return i
    return -1


func _open_result_scene() -> void:
    var results := get_sorted_results()
    SceneRouter.goto_result("word_race", results)


func build_view_data() -> Dictionary:
    var players_view_data: Array[Dictionary] = []
    for player in _players:
        players_view_data.append({
            "name": String(player.get("name", "")),
            "score": int(player.get("score", 0)),
            "is_cooldown": bool(player.get("is_cooldown", false)),
            "cooldown_remaining": float(player.get("cooldown_remaining", 0.0)),
        })

    return {
        "current_word": String(_current_word.get("english", "")),
        "options": _options,
        "current_round": _current_round + 1,
        "total_rounds": _total_rounds,
        "players": players_view_data,
        "round_finished": _round_finished,
        "game_finished": _game_finished,
    }
