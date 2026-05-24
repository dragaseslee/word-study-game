extends GameView

var _vm: CompleteGameplayVM

@onready var _round_label: Label = %RoundLabel
@onready var _meaning_label: Label = %MeaningLabel
@onready var _word_label: Label = %WordLabel
@onready var _player_a_panel: Panel = %PlayerAPanel
@onready var _player_b_panel: Panel = %PlayerBPanel
@onready var _player_a_name_label: Label = %PlayerANameLabel
@onready var _player_b_name_label: Label = %PlayerBNameLabel
@onready var _player_a_score_label: Label = %PlayerAScoreLabel
@onready var _player_b_score_label: Label = %PlayerBScoreLabel
@onready var _player_a_status_label: Label = %PlayerAStatusLabel
@onready var _player_b_status_label: Label = %PlayerBStatusLabel
@onready var _player_a_letters_container: GridContainer = %PlayerALettersContainer
@onready var _player_b_letters_container: GridContainer = %PlayerBLettersContainer
@onready var _end_game_button: Button = %EndGameButton

var _round_transition_timer: Timer


func _ready() -> void:
    var params := SceneRouter.get_params()
    var config: Dictionary = params.get("config", {})

    _vm = CompleteGameplayVM.new()
    bind(_vm)
    _vm.initialize(config)

    if not _vm.is_initialized():
        SceneRouter.goto_game_setting("word_complete")
        return

    _setup_timers()
    _connect_signals()


func _setup_timers() -> void:
    _round_transition_timer = Timer.new()
    _round_transition_timer.one_shot = true
    _round_transition_timer.wait_time = 1.0
    _round_transition_timer.timeout.connect(_on_round_transition)
    add_child(_round_transition_timer)


func _connect_signals() -> void:
    _end_game_button.pressed.connect(_vm.request_end_game)
    _vm.game_finished.connect(_on_game_finished)


func render(view_data: Dictionary) -> void:
    _round_label.text = "第 %d/%d 题" % [
        int(view_data.get("current_round", 1)),
        int(view_data.get("total_rounds", 10))
    ]
    _meaning_label.text = "中文意思：%s" % String(view_data.get("meaning", ""))
    _word_label.text = String(view_data.get("masked_word", ""))

    var players: Array = view_data.get("players", [])
    var letters: Array = view_data.get("letters", [])
    var active_index := int(view_data.get("active_player_index", 0))
    var is_game_finished := bool(view_data.get("game_finished", false))

    if players.size() >= 2:
        _render_player_panel(0, players[0], letters, active_index, is_game_finished,
            _player_a_panel, _player_a_name_label, _player_a_score_label,
            _player_a_status_label, _player_a_letters_container)
        _render_player_panel(1, players[1], letters, active_index, is_game_finished,
            _player_b_panel, _player_b_name_label, _player_b_score_label,
            _player_b_status_label, _player_b_letters_container)

    _end_game_button.visible = is_game_finished


func _render_player_panel(
    player_index: int,
    player_data: Dictionary,
    letters: Array,
    active_index: int,
    is_game_finished: bool,
    panel: Panel,
    name_label: Label,
    score_label: Label,
    status_label: Label,
    letters_container: GridContainer
) -> void:
    var is_active := player_index == active_index

    name_label.text = String(player_data.get("name", ""))
    score_label.text = "得分: %d" % int(player_data.get("score", 0))

    if is_game_finished:
        status_label.text = "游戏结束"
        panel.modulate = Color(0.5, 0.5, 0.5, 1.0)
    elif is_active:
        status_label.text = "回答中"
        panel.modulate = Color(1.0, 1.0, 1.0, 1.0)
    else:
        status_label.text = "等待"
        panel.modulate = Color(0.5, 0.5, 0.5, 1.0)

    _render_letters(letters_container, player_index, letters, not is_active or is_game_finished)


func _render_letters(container: GridContainer, player_index: int, letters: Array, is_disabled: bool) -> void:
    for child in container.get_children():
        child.queue_free()

    for i in range(letters.size()):
        var letter: String = letters[i]
        var button := Button.new()
        button.text = letter
        button.disabled = is_disabled
        button.custom_minimum_size = Vector2(60, 60)
        button.pressed.connect(_on_letter_pressed.bind(letter))
        container.add_child(button)


func _on_letter_pressed(letter: String) -> void:
    _vm.select_letter(letter)


func _on_game_finished() -> void:
    _round_transition_timer.stop()
    # 延迟跳转到结果页
    var timer := Timer.new()
    timer.one_shot = true
    timer.wait_time = 1.5
    timer.timeout.connect(func() -> void:
        var results := _vm.get_sorted_results()
        SceneRouter.goto_result("word_complete", results)
    )
    add_child(timer)
    timer.start()


func _on_round_transition() -> void:
    pass  # 由 VM 直接处理题目切换
