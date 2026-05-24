class_name CompleteConfig
extends RefCounted

const MIN_ROUND_COUNT := 1
const MAX_ROUND_COUNT := 50
const DEFAULT_ROUND_COUNT := 10
const DISTRACTOR_COUNT := 10


static func normalize_round_count(value: int) -> int:
    return clampi(value, MIN_ROUND_COUNT, MAX_ROUND_COUNT)


static func build_config(
    word_set: Dictionary,
    round_count: int,
    players: Array[Dictionary]
) -> Dictionary:
    return {
        "game_type": "word_complete",
        "word_set": word_set.duplicate(true),
        "round_count": normalize_round_count(round_count),
        "players": _normalize_players(players),
    }


static func validate_config(config: Dictionary) -> Dictionary:
    if String(config.get("game_type", "")) != "word_complete":
        return {}
    var word_set := Dictionary(config.get("word_set", {})).duplicate(true)
    if String(word_set.get("file_path", "")).strip_edges().is_empty():
        return {}
    var players := _normalize_players(config.get("players", []) as Array)
    if players.size() < 2:
        return {}
    return {
        "game_type": "word_complete",
        "word_set": word_set,
        "round_count": normalize_round_count(int(config.get("round_count", DEFAULT_ROUND_COUNT))),
        "players": players,
    }


static func _normalize_players(player_seeds: Array) -> Array[Dictionary]:
    var normalized: Array[Dictionary] = []
    for index in range(min(player_seeds.size(), 2)):
        var seed := player_seeds[index] as Dictionary
        var name := String(seed.get("name", "")).strip_edges() if seed != null else ""
        if name.is_empty():
            name = "玩家%d" % (index + 1)
        normalized.append({"id": index, "name": name})
    return normalized
