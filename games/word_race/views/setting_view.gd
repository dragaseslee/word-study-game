extends GameView

var _vm: RaceSettingVM

@onready var _status_label: Label = %StatusLabel
@onready var _word_set_option: OptionButton = %WordSetOption
@onready var _import_button: Button = %ImportButton
@onready var _round_count_spin_box: SpinBox = %RoundCountSpinBox
@onready var _option_count_spin_box: SpinBox = %OptionCountSpinBox
@onready var _cooldown_spin_box: SpinBox = %CooldownSpinBox
@onready var _player_a_name_edit: LineEdit = %PlayerANameEdit
@onready var _player_b_name_edit: LineEdit = %PlayerBNameEdit
@onready var _back_button: Button = %BackButton
@onready var _start_button: Button = %StartButton
@onready var _upload_file_dialog: FileDialog = %UploadFileDialog


func _ready() -> void:
    _vm = RaceSettingVM.new()
    bind(_vm)

    _setup_file_dialog()
    _connect_signals()

    var params := SceneRouter.get_params()
    _vm.initialize(params)


func _setup_file_dialog() -> void:
    _upload_file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
    _upload_file_dialog.access = FileDialog.ACCESS_FILESYSTEM
    _upload_file_dialog.filters = PackedStringArray(["*.txt ; Text Word Set", "*.csv ; CSV Word Set", "*.tsv ; TSV Word Set"])


func _connect_signals() -> void:
    _word_set_option.item_selected.connect(_on_word_set_selected)
    _import_button.pressed.connect(_on_import_pressed)
    _round_count_spin_box.value_changed.connect(func(value: float) -> void: _vm.set_round_count(int(value)))
    _option_count_spin_box.value_changed.connect(func(value: float) -> void: _vm.set_option_count(int(value)))
    _cooldown_spin_box.value_changed.connect(func(value: float) -> void: _vm.set_cooldown(value))
    _player_a_name_edit.text_changed.connect(_vm.set_player_name.bind(0))
    _player_b_name_edit.text_changed.connect(_vm.set_player_name.bind(1))
    _back_button.pressed.connect(_on_back_pressed)
    _start_button.pressed.connect(_on_start_pressed)
    _upload_file_dialog.file_selected.connect(_on_file_selected)


func render(view_data: Dictionary) -> void:
    _render_word_set_option(view_data)
    _round_count_spin_box.value = int(view_data.get("round_count", 10))
    _option_count_spin_box.value = int(view_data.get("option_count", 3))
    _cooldown_spin_box.value = float(view_data.get("cooldown", 5.0))

    var players: Array = view_data.get("players", [])
    if players.size() >= 1:
        _player_a_name_edit.text = String(players[0].get("name", "玩家A"))
    if players.size() >= 2:
        _player_b_name_edit.text = String(players[1].get("name", "玩家B"))

    _status_label.text = String(view_data.get("status_text", ""))
    _start_button.disabled = not bool(view_data.get("can_start", false))


func _render_word_set_option(view_data: Dictionary) -> void:
    var word_sets: Array = view_data.get("word_sets", [])
    var selected: Dictionary = view_data.get("selected_word_set", {})

    _word_set_option.clear()
    for word_set in word_sets:
        _word_set_option.add_item("%s (%d 词)" % [word_set.get("file_name", ""), int(word_set.get("word_count", 0))])

    var selected_path := String(selected.get("file_path", ""))
    var found := false
    for index in range(word_sets.size()):
        if String(word_sets[index].get("file_path", "")) == selected_path:
            _word_set_option.select(index)
            found = true
            break
    if not found and not word_sets.is_empty():
        _word_set_option.select(0)

    if word_sets.is_empty():
        _word_set_option.add_item("暂无可用词表")
        _word_set_option.select(0)
    _word_set_option.disabled = word_sets.is_empty()


func _on_word_set_selected(index: int) -> void:
    _vm.select_word_set(index)


func _on_import_pressed() -> void:
    _upload_file_dialog.popup_centered_ratio(0.7)


func _on_file_selected(path: String) -> void:
    _vm.import_word_set(path)


func _on_back_pressed() -> void:
    SceneRouter.goto_hub()


func _on_start_pressed() -> void:
    var config := _vm.start_game()
    if config.is_empty():
        return
    SceneRouter.goto_gameplay("word_race", config)
