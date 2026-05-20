extends Node

signal game_list_changed

var _games: Dictionary = {}  # game_id -> GameDef


func register_game(def: GameDef) -> void:
	_games[def.game_id] = def
	game_list_changed.emit()


func get_game(game_id: String) -> GameDef:
	return _games.get(game_id)


func get_all_games() -> Array:
	var result: Array = []
	for def in _games.values():
		result.append(def)
	result.sort_custom(func(a: GameDef, b: GameDef) -> bool:
		return a.display_order < b.display_order
	)
	return result


func _ready() -> void:
	_register_builtin_games()


func _register_builtin_games() -> void:
	register_game(preload("res://games/word_poison/poison_def.gd").new())
	register_game(preload("res://games/word_match/match_def.gd").new())


