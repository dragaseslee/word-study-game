class_name MatchConfig
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


static func build_config(word_set: Dictionary, board_size: int, players: Array[Dictionary], max_errors: int) -> Dictionary:
	return {
		"game_type": "word_match",
		"word_set": word_set.duplicate(true),
		"board_size": normalize_board_size(board_size),
		"players": _normalize_players(players),
		"rules": {"max_errors": normalize_non_negative(max_errors)},
	}


static func validate_config(config: Dictionary) -> Dictionary:
	if String(config.get("game_type", "")) != "word_match":
		return {}
	var word_set := Dictionary(config.get("word_set", {})).duplicate(true)
	if String(word_set.get("file_path", "")).strip_edges().is_empty():
		return {}
	var players := _normalize_players(config.get("players", []) as Array)
	if players.is_empty():
		return {}
	var rules := Dictionary(config.get("rules", {})).duplicate(true)
	rules["max_errors"] = normalize_non_negative(int(rules.get("max_errors", 0)))
	return {
		"game_type": "word_match",
		"word_set": word_set,
		"board_size": normalize_board_size(int(config.get("board_size", 4))),
		"players": players,
		"rules": rules,
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
