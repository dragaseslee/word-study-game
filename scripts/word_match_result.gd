extends Control

var _pending_results: Array[Dictionary] = []

@onready var _results_list: VBoxContainer = %ResultsList
@onready var _replay_button: Button = %ReplayButton
@onready var _back_to_hub_button: Button = %BackToHubButton


func set_results(results: Array) -> void:
	_pending_results = _normalize_results(results)
	if not is_node_ready():
		return
	_render_results()


func _ready() -> void:
	_replay_button.pressed.connect(_go_to_settings)
	_back_to_hub_button.pressed.connect(_go_to_hub)
	if _pending_results.is_empty():
		_go_to_settings()
		return
	_render_results()


func _render_results() -> void:
	for child in _results_list.get_children():
		child.free()

	var sorted_results := _sort_results(_pending_results)
	for index in range(sorted_results.size()):
		_results_list.add_child(_build_result_row(index, sorted_results[index]))


func _normalize_results(results: Array) -> Array[Dictionary]:
	var normalized: Array[Dictionary] = []
	for result in results:
		normalized.append((result as Dictionary).duplicate(true))
	return normalized


func _sort_results(results: Array[Dictionary]) -> Array[Dictionary]:
	var sorted_results: Array[Dictionary] = []
	for result in results:
		sorted_results.append((result as Dictionary).duplicate(true))
	sorted_results.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var cleared_a := bool(a.get("is_cleared", false))
		var cleared_b := bool(b.get("is_cleared", false))
		if cleared_a != cleared_b:
			return cleared_a and not cleared_b

		var matched_a := int(a.get("matched_pair_count", 0))
		var matched_b := int(b.get("matched_pair_count", 0))
		if matched_a != matched_b:
			return matched_a > matched_b

		var errors_a := int(a.get("error_count", 0))
		var errors_b := int(b.get("error_count", 0))
		if errors_a != errors_b:
			return errors_a < errors_b

		return int(a.get("finish_order", 9999)) < int(b.get("finish_order", 9999))
	)
	return sorted_results


func _build_result_row(index: int, result: Dictionary) -> Control:
	var row := HBoxContainer.new()
	row.name = "ResultRow%d" % index
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 12)

	var rank_label := Label.new()
	rank_label.name = "RankLabel"
	rank_label.text = "%d." % (index + 1)
	rank_label.custom_minimum_size = Vector2(48, 0)
	row.add_child(rank_label)

	var name_label := Label.new()
	name_label.name = "NameLabel"
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.text = String(result.get("name", "玩家"))
	row.add_child(name_label)

	var status_label := Label.new()
	status_label.name = "StatusLabel"
	status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_label.text = _build_status_text(result)
	row.add_child(status_label)

	return row


func _build_status_text(result: Dictionary) -> String:
	var state_text := "已完成" if bool(result.get("is_cleared", false)) else "未完成"
	return "%s | 配对 %d | 错误 %d | 顺位 %d" % [
		state_text,
		int(result.get("matched_pair_count", 0)),
		int(result.get("error_count", 0)),
		int(result.get("finish_order", 9999)) + 1,
	]


func _go_to_settings() -> void:
	get_tree().change_scene_to_file("res://scenes/word_match_setting.tscn")


func _go_to_hub() -> void:
	get_tree().change_scene_to_file("res://scenes/game_hub.tscn")
