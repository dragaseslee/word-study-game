extends GameView

var _vm: MatchSettingVM

@onready var _status_label: Label = %StatusLabel
@onready var _word_set_option: OptionButton = %WordSetOption
@onready var _import_button: Button = %ImportButton
@onready var _layout_3_button: BaseButton = %Layout3Button
@onready var _layout_4_button: BaseButton = %Layout4Button
@onready var _layout_5_button: BaseButton = %Layout5Button
@onready var _max_errors_spin_box: SpinBox = %MaxErrorsSpinBox
@onready var _add_player_button: Button = %AddPlayerButton
@onready var _player_list: VBoxContainer = %PlayerList
@onready var _back_button: Button = %BackButton
@onready var _start_button: Button = %StartButton
@onready var _upload_file_dialog: FileDialog = %UploadFileDialog


func _ready() -> void:
    _vm = MatchSettingVM.new()
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
    _layout_3_button.pressed.connect(_vm.set_board_size.bind(3))
    _layout_4_button.pressed.connect(_vm.set_board_size.bind(4))
    _layout_5_button.pressed.connect(_vm.set_board_size.bind(5))
    _max_errors_spin_box.value_changed.connect(func(value: float) -> void: _vm.set_max_errors(int(value)))
    _add_player_button.pressed.connect(_vm.add_player)
    _back_button.pressed.connect(_on_back_pressed)
    _start_button.pressed.connect(_on_start_pressed)
    _upload_file_dialog.file_selected.connect(_on_file_selected)


func render(view_data: Dictionary) -> void:
    _render_word_set_option(view_data)
    _render_layout_buttons(view_data)
    _render_players(view_data)
    _max_errors_spin_box.value = int(view_data.get("max_errors", 3))
    _status_label.text = String(view_data.get("status_text", ""))
    _start_button.disabled = not bool(view_data.get("can_start", false))


func _render_word_set_option(view_data: Dictionary) -> void:
    var word_sets: Array = view_data.get("word_sets", [])
    var selected: Dictionary = view_data.get("selected_word_set", {})

    _word_set_option.clear()
    for word_set in word_sets:
        _word_set_option.add_item("%s (%d 对)" % [word_set.get("file_name", ""), int(word_set.get("word_count", 0))])

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


func _render_layout_buttons(view_data: Dictionary) -> void:
    var board_size := int(view_data.get("board_size", 4))
    _layout_3_button.button_pressed = board_size == 3
    _layout_4_button.button_pressed = board_size == 4
    _layout_5_button.button_pressed = board_size == 5


const PLAYER_ROW_SCENE := preload("res://scenes/components/player_row.tscn")


func _render_players(view_data: Dictionary) -> void:
    var players: Array = view_data.get("players", [])
    var max_players := int(view_data.get("max_players", 10))

    for child in _player_list.get_children():
        child.free()

    for index in range(players.size()):
        var row := PLAYER_ROW_SCENE.instantiate()
        _player_list.add_child(row)
        row.setup(index, String(players[index].get("name", "")), players.size() > 1)
        row.name_changed.connect(_vm.set_player_name.bind(index))
        row.remove_requested.connect(_vm.remove_player.bind(index), CONNECT_DEFERRED)

    _add_player_button.disabled = players.size() >= max_players


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
    SceneRouter.goto_gameplay("word_match", config)
