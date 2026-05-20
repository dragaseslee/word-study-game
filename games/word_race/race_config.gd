class_name RaceConfig
extends RefCounted

const MIN_OPTION_COUNT := 2
const MAX_OPTION_COUNT := 6
const DEFAULT_OPTION_COUNT := 3
const DEFAULT_ROUND_COUNT := 10
const DEFAULT_COOLDOWN := 5.0


static func normalize_option_count(value: int) -> int:
    return clampi(value, MIN_OPTION_COUNT, MAX_OPTION_COUNT)


static func normalize_round_count(value: int) -> int:
    return clampi(value, 1, 50)


static func normalize_cooldown(value: float) -> float:
    return clampf(value, 1.0, 10.0)


static func build_config(
    word_set: Dictionary,
    round_count: int,
    option_count: int,
    cooldown: float,
    players: Array[Dictionary]
) -> Dictionary:
    return {
        "game_type": "word_race",
        "word_set": word_set.duplicate(true),
        "round_count": normalize_round_count(round_count),
        "option_count": normalize_option_count(option_count),
        "cooldown": normalize_cooldown(cooldown),
        "players": _normalize_players(players),
    }


static func validate_config(config: Dictionary) -> Dictionary:
    if String(config.get("game_type", "")) != "word_race":
        return {}
    var word_set := Dictionary(config.get("word_set", {})).duplicate(true)
    if String(word_set.get("file_path", "")).strip_edges().is_empty():
        return {}
    var players := _normalize_players(config.get("players", []) as Array)
    if players.size() < 2:
        return {}
    return {
        "game_type": "word_race",
        "word_set": word_set,
        "round_count": normalize_round_count(int(config.get("round_count", DEFAULT_ROUND_COUNT))),
        "option_count": normalize_option_count(int(config.get("option_count", DEFAULT_OPTION_COUNT))),
        "cooldown": normalize_cooldown(float(config.get("cooldown", DEFAULT_COOLDOWN))),
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
