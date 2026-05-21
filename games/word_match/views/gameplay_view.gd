extends GameView

const BOARD_CELL_SCENE := preload("res://scenes/components/board_cell.tscn")

var _vm: MatchGameplayVM

@onready var _current_player_label: Label = %CurrentPlayerLabel
@onready var _progress_label: Label = %ProgressLabel
@onready var _mistake_label: Label = %MistakeLabel
@onready var _status_label: Label = %StatusLabel
@onready var _board_grid: GridContainer = %BoardGrid
@onready var _next_player_button: Button = %NextPlayerButton


func _ready() -> void:
    var params := SceneRouter.get_params()
    var config: Dictionary = params.get("config", {})

    _vm = MatchGameplayVM.new()
    bind(_vm)
    _vm.initialize(config)

    if not _vm.is_initialized():
        SceneRouter.goto_game_setting("word_match")
        return

    _next_player_button.pressed.connect(_vm.on_next_player_requested)


func render(view_data: Dictionary) -> void:
    _current_player_label.text = "当前玩家：%s" % String(view_data.get("current_player_name", ""))
    _progress_label.text = "进度：%d/%d" % [int(view_data.get("matched_pair_count", 0)), int(view_data.get("required_pair_count", 0))]
    _mistake_label.text = "错误：%d/%d" % [int(view_data.get("error_count", 0)), int(view_data.get("max_errors", 0))]
    _status_label.text = String(view_data.get("status_text", ""))

    var is_turn_waiting := bool(view_data.get("is_turn_waiting", false))
    var finished_count := int(view_data.get("finished_player_count", 0))
    var total_count := int(view_data.get("total_player_count", 1))
    _next_player_button.visible = is_turn_waiting
    _next_player_button.text = "查看结算" if finished_count >= total_count else "下一位玩家"

    _render_board(view_data)


func _render_board(view_data: Dictionary) -> void:
    var board_size := int(view_data.get("board_size", 4))
    var board_cells: Array = view_data.get("board_cells", [])
    var selected_indices: Array = view_data.get("selected_cell_indices", [])
    var matched_indices: Array = view_data.get("matched_indices", [])
    var is_turn_waiting := bool(view_data.get("is_turn_waiting", false))

    _board_grid.columns = board_size

    for child in _board_grid.get_children():
        child.queue_free()

    for index in range(board_cells.size()):
        var cell: Dictionary = board_cells[index] as Dictionary
        var display_text := String(cell.get("text", ""))
        var cell_disabled := is_turn_waiting
        if String(cell.get("kind", "")) == "blank":
            display_text = ""
        elif matched_indices.has(index):
            cell_disabled = true
        elif selected_indices.has(index):
            display_text = "[%s]" % display_text
        var board_cell := BOARD_CELL_SCENE.instantiate()
        board_cell.setup(index, display_text, cell_disabled)
        board_cell.cell_pressed.connect(_vm.on_cell_pressed)
        _board_grid.add_child(board_cell)
