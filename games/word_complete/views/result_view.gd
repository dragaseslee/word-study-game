extends GameView

const RESULT_ROW_SCENE := preload("res://scenes/components/result_row.tscn")

var _vm: CompleteResultVM

@onready var _winner_label: Label = %WinnerLabel
@onready var _results_list: VBoxContainer = %ResultsList
@onready var _replay_button: Button = %ReplayButton
@onready var _back_to_hub_button: Button = %BackToHubButton


func _ready() -> void:
    var params := SceneRouter.get_params()
    var results: Array = params.get("results", [])

    _vm = CompleteResultVM.new()
    bind(_vm)
    _vm.initialize({"results": results})

    _replay_button.pressed.connect(_vm.replay)
    _back_to_hub_button.pressed.connect(_vm.back_to_hub)

    if results.is_empty():
        SceneRouter.goto_game_setting("word_complete")
        return


func render(view_data: Dictionary) -> void:
    var results: Array = view_data.get("results", [])

    if results.size() >= 2:
        var winner_name := String(results[0].get("name", ""))
        var winner_score := int(results[0].get("score", 0))
        var loser_score := int(results[1].get("score", 0))
        if winner_score > loser_score:
            _winner_label.text = "胜利者: %s (得分: %d)" % [winner_name, winner_score]
        else:
            _winner_label.text = "平局！双方得分: %d" % winner_score
    else:
        _winner_label.text = "游戏结束"

    for child in _results_list.get_children():
        child.free()

    for index in range(results.size()):
        var result: Dictionary = results[index]
        var row := RESULT_ROW_SCENE.instantiate()
        row.setup(
            index + 1,
            String(result.get("name", "玩家")),
            _build_status_text(result)
        )
        _results_list.add_child(row)


func _build_status_text(result: Dictionary) -> String:
    return "得分: %d | 正确: %d | 错误: %d" % [
        int(result.get("score", 0)),
        int(result.get("correct_count", 0)),
        int(result.get("error_count", 0)),
    ]
