extends GameView

var _vm: RaceGameplayVM

@onready var _word_label: Label = %WordLabel
@onready var _round_label: Label = %RoundLabel
@onready var _player_a_panel: VBoxContainer = %PlayerAPanel
@onready var _player_b_panel: VBoxContainer = %PlayerBPanel
@onready var _player_a_score_label: Label = %PlayerAScoreLabel
@onready var _player_b_score_label: Label = %PlayerBScoreLabel
@onready var _player_a_status_label: Label = %PlayerAStatusLabel
@onready var _player_b_status_label: Label = %PlayerBStatusLabel
@onready var _player_a_options_container: VBoxContainer = %PlayerAOptionsContainer
@onready var _player_b_options_container: VBoxContainer = %PlayerBOptionsContainer
@onready var _next_round_button: Button = %NextRoundButton
@onready var _end_game_button: Button = %EndGameButton

var _player_a_cooldown_timer: Timer
var _player_b_cooldown_timer: Timer
var _round_transition_timer: Timer


func _ready() -> void:
    var params := SceneRouter.get_params()
    var config: Dictionary = params.get("config", {})

    _vm = RaceGameplayVM.new()
    bind(_vm)
    _vm.initialize(config)

    if not _vm.is_initialized():
        SceneRouter.goto_game_setting("word_race")
        return

    _setup_timers()
    _connect_signals()


func _setup_timers() -> void:
    _player_a_cooldown_timer = Timer.new()
    _player_a_cooldown_timer.wait_time = 1.0
    _player_a_cooldown_timer.timeout.connect(_on_player_a_cooldown_tick)
    add_child(_player_a_cooldown_timer)

    _player_b_cooldown_timer = Timer.new()
    _player_b_cooldown_timer.wait_time = 1.0
    _player_b_cooldown_timer.timeout.connect(_on_player_b_cooldown_tick)
    add_child(_player_b_cooldown_timer)

    _round_transition_timer = Timer.new()
    _round_transition_timer.one_shot = true
    _round_transition_timer.wait_time = 1.5
    _round_transition_timer.timeout.connect(_on_round_transition)
    add_child(_round_transition_timer)


func _connect_signals() -> void:
    _next_round_button.pressed.connect(_on_next_round_pressed)
    _end_game_button.pressed.connect(_vm.request_end_game)
    _vm.round_finished.connect(_on_round_finished)
    _vm.game_finished.connect(_on_game_finished)
    _vm.player_cooldown_started.connect(_on_player_cooldown_started)


func render(view_data: Dictionary) -> void:
    _word_label.text = String(view_data.get("current_word", ""))
    _round_label.text = "回合 %d/%d" % [int(view_data.get("current_round", 1)), int(view_data.get("total_rounds", 10))]

    var players: Array = view_data.get("players", [])
    if players.size() >= 2:
        _render_player_panel(0, players[0], _player_a_score_label, _player_a_status_label, _player_a_options_container)
        _render_player_panel(1, players[1], _player_b_score_label, _player_b_status_label, _player_b_options_container)

    var is_round_finished := bool(view_data.get("round_finished", false))
    var is_game_finished := bool(view_data.get("game_finished", false))
    _next_round_button.visible = is_round_finished and not is_game_finished
    _end_game_button.visible = is_game_finished


func _render_player_panel(
    player_index: int,
    player_data: Dictionary,
    score_label: Label,
    status_label: Label,
    options_container: VBoxContainer
) -> void:
    score_label.text = "得分: %d" % int(player_data.get("score", 0))

    var is_cooldown := bool(player_data.get("is_cooldown", false))
    var cooldown_remaining := float(player_data.get("cooldown_remaining", 0.0))

    if is_cooldown:
        status_label.text = "冷却中: %.1fs" % cooldown_remaining
    else:
        status_label.text = "正常"

    _render_options(options_container, player_index, is_cooldown)


func _render_options(container: VBoxContainer, player_index: int, is_disabled: bool) -> void:
    for child in container.get_children():
        child.queue_free()

    var view_data := _vm.build_view_data()
    var options: Array = view_data.get("options", [])

    for i in range(options.size()):
        var option: Dictionary = options[i]
        var button := Button.new()
        button.text = String(option.get("text", ""))
        button.disabled = is_disabled
        button.pressed.connect(_on_option_pressed.bind(player_index, i))
        container.add_child(button)


func _on_option_pressed(player_index: int, option_index: int) -> void:
    _vm.on_option_pressed(player_index, option_index)


func _on_player_a_cooldown_tick() -> void:
    _vm.on_cooldown_tick(0)


func _on_player_b_cooldown_tick() -> void:
    _vm.on_cooldown_tick(1)


func _on_player_cooldown_started(player_index: int) -> void:
    if player_index == 0:
        _player_a_cooldown_timer.start()
    elif player_index == 1:
        _player_b_cooldown_timer.start()


func _on_round_finished(_winner_index: int) -> void:
    _player_a_cooldown_timer.stop()
    _player_b_cooldown_timer.stop()
    _round_transition_timer.start()


func _on_game_finished() -> void:
    _player_a_cooldown_timer.stop()
    _player_b_cooldown_timer.stop()


func _on_next_round_pressed() -> void:
    _vm.advance_round()


func _on_round_transition() -> void:
    _vm.advance_round()
