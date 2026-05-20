class_name PoisonConfig
extends RefCounted

const BOARD_SIZES: Array[int] = [3, 4, 5]


static func normalize_board_size(requested_size: int) -> int:
	if BOARD_SIZES.has(requested_size):
		return requested_size
	return 4


static func normalize_non_negative(value: int, fallback: int = 0) -> int:
	if value >= 0:
		return value
	return fallback if fallback >= 0 else 0


static func build_config(word_set: Dictionary, board_size: int, players: Array[Dictionary], initial_health: int, poison_count: int) -> Dictionary:
	return {
		"game_type": "word_poison",
		"word_set": word_set.duplicate(true),
		"board_size": normalize_board_size(board_size),
		"players": _normalize_players(players),
		"initial_health": normalize_non_negative(initial_health),
		"poison_count": normalize_non_negative(poison_count),
	}


static func validate_config(config: Dictionary) -> Dictionary:
	if String(config.get("game_type", "")) != "word_poison":
		return {}
	var word_set := Dictionary(config.get("word_set", {})).duplicate(true)
	if String(word_set.get("file_path", "")).strip_edges().is_empty():
		return {}
	var players := _normalize_players(config.get("players", []) as Array)
	if players.is_empty():
		return {}
	return {
		"game_type": "word_poison",
		"word_set": word_set,
		"board_size": normalize_board_size(int(config.get("board_size", 4))),
		"players": players,
		"initial_health": normalize_non_negative(int(config.get("initial_health", 2))),
		"poison_count": normalize_non_negative(int(config.get("poison_count", 2))),
	}


static func _normalize_players(player_seeds: Array, default_prefix: String = "玩家") -> Array[Dictionary]:
	var normalized: Array[Dictionary] = []
	for index in range(player_seeds.size()):
		var seed := player_seeds[index] as Dictionary
		var name := String(seed.get("name", "")).strip_edges() if seed != null else ""
		if name.is_empty():
			name = "%s%d" % [default_prefix, index + 1]
		normalized.append({"id": index, "name": name})
	return normalized
