extends Node

signal scene_changed(scene_id: String)

var _current_scene_id := ""
var _pending_params: Dictionary = {}


func goto(scene_id: String, params: Dictionary = {}) -> void:
	_current_scene_id = scene_id
	_pending_params = params
	var scene_path := _resolve_scene_path(scene_id)
	get_tree().change_scene_to_file(scene_path)


func goto_hub() -> void:
	goto("hub")


func goto_game_setting(game_id: String) -> void:
	goto("setting_%s" % game_id)


func goto_gameplay(game_id: String, config: Dictionary) -> void:
	goto("gameplay_%s" % game_id, {"config": config})


func goto_result(game_id: String, results: Array) -> void:
	goto("result_%s" % game_id, {"results": results})


func get_params() -> Dictionary:
	var params := _pending_params.duplicate(true)
	_pending_params.clear()
	return params


func get_current_scene_id() -> String:
	return _current_scene_id


func _resolve_scene_path(scene_id: String) -> String:
	# 场景路径映射
	var mapping := {
		"hub": "res://scenes/game_hub.tscn",
		"setting_word_poison": "res://games/word_poison/views/setting_view.tscn",
		"gameplay_word_poison": "res://games/word_poison/views/gameplay_view.tscn",
		"result_word_poison": "res://games/word_poison/views/result_view.tscn",
		"setting_word_match": "res://games/word_match/views/setting_view.tscn",
		"gameplay_word_match": "res://games/word_match/views/gameplay_view.tscn",
		"result_word_match": "res://games/word_match/views/result_view.tscn",
		"setting_word_race": "res://games/word_race/views/setting_view.tscn",
		"gameplay_word_race": "res://games/word_race/views/gameplay_view.tscn",
		"result_word_race": "res://games/word_race/views/result_view.tscn",
	}
	return mapping.get(scene_id, "res://scenes/game_hub.tscn")
