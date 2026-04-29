extends SceneTree

const GameStartupConfigScript = preload("res://scripts/game_startup_config.gd")


func _initialize() -> void:
	var config = GameStartupConfigScript.new()

	var normalized_players := config.normalize_players([
		{"name": "Alice"},
		{"name": "   "},
	])
	_assert(normalized_players.size() == 2, "normalize_players should keep every player")
	_assert(String(normalized_players[0].get("name", "")) == "Alice", "normalize_players should keep non-blank names")
	_assert(String(normalized_players[1].get("name", "")) == "玩家2", "normalize_players should replace blank names with default labels")

	_assert(config.normalize_board_size(5, [3, 4, 5], 4) == 5, "normalize_board_size should keep allowed sizes")
	_assert(config.normalize_board_size(6, [3, 4, 5], 4) == 4, "normalize_board_size should fall back for unsupported sizes")
	_assert(config.normalize_non_negative(-1, 2) == 2, "normalize_non_negative should clamp negative values to the fallback")

	var built := config.build_word_match_config(
		{"file_name": "basic_words.txt", "file_path": "res://sample_word_sets/basic_words.txt"},
		6,
		[
			{"name": "Alice", "score": 99},
			{"name": "   ", "avatar": "ghost"},
		],
		-3
	)
	_assert(String(built.get("game_type", "")) == "word_match", "build_word_match_config should mark the word-match game type")
	_assert(int(built.get("board_size", 0)) == 4, "build_word_match_config should normalize board size to an allowed value")
	_assert((built.get("word_set", {}) as Dictionary).get("file_path", "") == "res://sample_word_sets/basic_words.txt", "build_word_match_config should keep the provided word set")
	var built_players := built.get("players", []) as Array
	_assert(built_players.size() == 2, "build_word_match_config should keep the provided players")
	_assert(String(built_players[0].get("name", "")) == "Alice", "build_word_match_config should keep non-blank names")
	_assert(String(built_players[1].get("name", "")) == "玩家2", "build_word_match_config should normalize blank player names")
	_assert(int(built_players[0].get("id", -1)) == 0, "build_word_match_config should assign runtime-safe player ids")
	_assert(int(built_players[1].get("id", -1)) == 1, "build_word_match_config should reindex runtime-safe player ids")
	_assert(not built_players[0].has("score"), "build_word_match_config should not leak unexpected player fields")
	_assert(not built_players[1].has("avatar"), "build_word_match_config should strip unexpected player fields")
	var rules := built.get("rules", {}) as Dictionary
	_assert(int(rules.get("max_errors", -1)) == 0, "build_word_match_config should normalize negative max_errors")

	var poison_built := config.build_poison_config(
		{"file_name": "basic_words.txt", "file_path": "res://sample_word_sets/basic_words.txt", "extra": true},
		6,
		[
			{"name": "Bob", "score": 42},
			{"name": "   ", "avatar": "ghost"},
		],
		-5,
		-8
	)
	_assert(String(poison_built.get("game_type", "")) == "word_poison", "build_poison_config should mark the poison game type")
	_assert(int(poison_built.get("board_size", 0)) == 4, "build_poison_config should normalize board size to an allowed value")
	_assert((poison_built.get("word_set", {}) as Dictionary).get("file_path", "") == "res://sample_word_sets/basic_words.txt", "build_poison_config should keep the provided word set")
	var poison_players := poison_built.get("players", []) as Array
	_assert(poison_players.size() == 2, "build_poison_config should keep the provided players")
	_assert(String(poison_players[0].get("name", "")) == "Bob", "build_poison_config should keep non-blank names")
	_assert(String(poison_players[1].get("name", "")) == "玩家2", "build_poison_config should normalize blank player names")
	_assert(int(poison_players[0].get("id", -1)) == 0, "build_poison_config should assign runtime-safe player ids")
	_assert(int(poison_players[1].get("id", -1)) == 1, "build_poison_config should reindex runtime-safe player ids")
	_assert(not poison_players[0].has("score"), "build_poison_config should not leak unexpected player fields")
	_assert(not poison_players[1].has("avatar"), "build_poison_config should strip unexpected player fields")
	_assert(int(poison_built.get("initial_health", -1)) == 0, "build_poison_config should normalize negative initial health")
	_assert(int(poison_built.get("poison_count", -1)) == 0, "build_poison_config should normalize negative poison counts")

	var validated := config.validate_word_match_config({
		"game_type": "word_match",
		"word_set": {"file_name": "basic_words.txt", "file_path": "res://sample_word_sets/basic_words.txt"},
		"board_size": 9,
		"players": [{"name": "   "}],
		"rules": {"max_errors": -9},
	})
	_assert(int(validated.get("board_size", 0)) == 4, "validate_word_match_config should normalize unsupported board sizes")
	var validated_players := validated.get("players", []) as Array
	_assert(String(validated_players[0].get("name", "")) == "玩家1", "validate_word_match_config should normalize blank player names")
	var validated_rules := validated.get("rules", {}) as Dictionary
	_assert(int(validated_rules.get("max_errors", -1)) == 0, "validate_word_match_config should normalize negative max_errors")

	var validated_poison := config.validate_poison_config({
		"game_type": "word_poison",
		"word_set": {"file_name": "basic_words.txt", "file_path": "res://sample_word_sets/basic_words.txt"},
		"board_size": 7,
		"players": [{"name": "   "}],
		"initial_health": -4,
		"poison_count": -2,
	})
	_assert(String(validated_poison.get("game_type", "")) == "word_poison", "validate_poison_config should keep the poison game type")
	_assert(int(validated_poison.get("board_size", 0)) == 4, "validate_poison_config should normalize unsupported board sizes")
	var validated_poison_players := validated_poison.get("players", []) as Array
	_assert(String(validated_poison_players[0].get("name", "")) == "玩家1", "validate_poison_config should normalize blank player names")
	_assert(int(validated_poison.get("initial_health", -1)) == 0, "validate_poison_config should normalize negative initial health")
	_assert(int(validated_poison.get("poison_count", -1)) == 0, "validate_poison_config should normalize negative poison counts")

	_assert(config.validate_word_match_config({}).is_empty(), "validate_word_match_config should reject invalid configs")
	_assert(config.validate_poison_config({}).is_empty(), "validate_poison_config should reject invalid configs")
	quit(0)


func _assert(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	quit(1)
