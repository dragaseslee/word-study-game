extends GameView

const RESULT_ROW_SCENE := preload("res://scenes/components/result_row.tscn")

var _vm: MatchResultVM

@onready var _results_list: VBoxContainer = %ResultsList
@onready var _replay_button: Button = %ReplayButton
@onready var _back_to_hub_button: Button = %BackToHubButton


func _ready() -> void:
	var params := SceneRouter.get_params()
	var results: Array = params.get("results", [])

	_vm = MatchResultVM.new()
	bind(_vm)
	_vm.initialize({"results": results})

	_replay_button.pressed.connect(_vm.replay)
	_back_to_hub_button.pressed.connect(_vm.back_to_hub)

	if results.is_empty():
		SceneRouter.goto_game_setting("word_match")
		return


func render(view_data: Dictionary) -> void:
	var results: Array = view_data.get("results", [])

	for child in _results_list.get_children():
		child.free()

	var sorted_results := _sort_results(results)
	for index in range(sorted_results.size()):
		var row := RESULT_ROW_SCENE.instantiate()
		row.setup(index + 1, String(sorted_results[index].get("name", "玩家")), _build_status_text(sorted_results[index]))
		_results_list.add_child(row)


func _sort_results(results: Array) -> Array[Dictionary]:
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


func _build_status_text(result: Dictionary) -> String:
	var state_text := "已完成" if bool(result.get("is_cleared", false)) else "未完成"
	return "%s | 配对 %d | 错误 %d | 顺位 %d" % [
		state_text,
		int(result.get("matched_pair_count", 0)),
		int(result.get("error_count", 0)),
		int(result.get("finish_order", 9999)) + 1,
	]
