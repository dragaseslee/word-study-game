extends Control

const MAX_PLAYERS := 10
const GameStartupConfig = preload("res://scripts/game_startup_config.gd")
const WORD_MATCH_GAME_SCENE := preload("res://scenes/word_match_game.tscn")

var _store := WordSetStore.new()
var _word_sets: Array[Dictionary] = []
var _selected_word_set: Dictionary = {}
var _board_size := 4
var _players: Array[Dictionary] = []
var _max_errors := 3

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
	_players = [{"name": _default_player_name(0)}]
	_setup_file_dialog()
	_connect_signals()
	_setup_word_set_options()
	_select_layout(_board_size)
	_max_errors_spin_box.value = _max_errors
	_render_players()
	_update_start_state()


func _setup_file_dialog() -> void:
	_upload_file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	_upload_file_dialog.access = FileDialog.ACCESS_FILESYSTEM
	_upload_file_dialog.filters = PackedStringArray(["*.txt ; Text Word Set", "*.csv ; CSV Word Set", "*.tsv ; TSV Word Set"])


func _connect_signals() -> void:
	_word_set_option.item_selected.connect(_on_word_set_selected)
	_import_button.pressed.connect(_on_import_pressed)
	_layout_3_button.pressed.connect(_on_layout_selected.bind(3))
	_layout_4_button.pressed.connect(_on_layout_selected.bind(4))
	_layout_5_button.pressed.connect(_on_layout_selected.bind(5))
	_max_errors_spin_box.value_changed.connect(_on_max_errors_changed)
	_add_player_button.pressed.connect(_on_add_player_pressed)
	_back_button.pressed.connect(_on_back_pressed)
	_start_button.pressed.connect(_on_start_pressed)
	_upload_file_dialog.file_selected.connect(_on_file_selected)


func _find_word_set_index(file_path: String) -> int:
	for index in range(_word_sets.size()):
		if String(_word_sets[index].get("file_path", "")) == file_path:
			return index
	return -1


func _setup_word_set_options() -> void:
	var previous_path := String(_selected_word_set.get("file_path", ""))
	_word_sets = _store.list_word_sets()
	_word_set_option.clear()
	for word_set in _word_sets:
		_word_set_option.add_item("%s (%d 对)" % [word_set.get("file_name", ""), int(word_set.get("word_count", 0))])

	var selected_index := _find_word_set_index(previous_path)
	if selected_index >= 0:
		_word_set_option.select(selected_index)
		_selected_word_set = _word_sets[selected_index].duplicate(true)
	else:
		if not _word_sets.is_empty():
			_word_set_option.select(0)
		_selected_word_set = {}

	if _word_sets.is_empty():
		_word_set_option.add_item("暂无可用词表")
		_word_set_option.select(0)
	_word_set_option.disabled = _word_sets.is_empty()
	_update_start_state()


func _on_word_set_selected(index: int) -> void:
	if index < 0:
		_selected_word_set = {}
	else:
		if index < _word_sets.size():
			_selected_word_set = _word_sets[index].duplicate(true)
		else:
			_selected_word_set = {}
	_update_start_state()


func _on_layout_selected(board_size: int) -> void:
	_board_size = board_size
	_select_layout(board_size)
	_update_start_state()


func _on_max_errors_changed(value: float) -> void:
	_max_errors = int(value)
	_update_start_state()


func _on_add_player_pressed() -> void:
	if _players.size() >= MAX_PLAYERS:
		return
	_players.append({"name": _default_player_name(_players.size())})
	_render_players()
	_update_start_state()


func _on_remove_player_pressed(index: int) -> void:
	if _players.size() <= 1:
		return
	if index < 0 or index >= _players.size():
		return
	_players.remove_at(index)
	_render_players()
	_update_start_state()


func _on_player_name_changed(new_text: String, index: int) -> void:
	if index < 0 or index >= _players.size():
		return
	_players[index]["name"] = new_text
	_update_start_state()


func _on_import_pressed() -> void:
	_upload_file_dialog.popup_centered_ratio(0.7)


func _on_file_selected(path: String) -> void:
	var result := _store.import_word_set(path)
	if not bool(result.get("ok", false)):
		_status_label.text = String(result.get("message", "导入失败"))
		_update_start_state()
		return

	_selected_word_set = {
		"file_name": result.get("file_name", ""),
		"file_path": result.get("file_path", ""),
		"word_count": int(result.get("word_count", 0)),
	}
	_setup_word_set_options()


func _render_players() -> void:
	for child in _player_list.get_children():
		child.free()

	for index in range(_players.size()):
		var row := HBoxContainer.new()
		var name_edit := LineEdit.new()
		var remove_button := Button.new()

		name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_edit.placeholder_text = _default_player_name(index)
		name_edit.text = String(_players[index].get("name", ""))
		name_edit.text_changed.connect(_on_player_name_changed.bind(index))

		remove_button.text = "Remove"
		remove_button.disabled = _players.size() <= 1
		remove_button.pressed.connect(_on_remove_player_pressed.bind(index), CONNECT_DEFERRED)

		row.add_child(name_edit)
		row.add_child(remove_button)
		_player_list.add_child(row)

	_add_player_button.disabled = _players.size() >= MAX_PLAYERS


func _select_layout(board_size: int) -> void:
	_layout_3_button.button_pressed = board_size == 3
	_layout_4_button.button_pressed = board_size == 4
	_layout_5_button.button_pressed = board_size == 5


func _required_pair_count() -> int:
	return int(floor(float(_board_size * _board_size) / 2.0))


func _default_player_name(index: int) -> String:
	return "玩家%d" % (index + 1)


func _update_start_state() -> void:
	var status_text := ""
	var can_start := true

	if _word_sets.is_empty():
		status_text = "暂无可用词表，请先导入词表"
		can_start = false
	elif _selected_word_set.is_empty():
		status_text = "请选择词表"
		can_start = false
	elif int(_selected_word_set.get("word_count", 0)) < _required_pair_count():
		status_text = "词表词对不足，当前布局至少需要 %d 对" % _required_pair_count()
		can_start = false
	else:
		status_text = "已选择 %s，可开始游戏" % String(_selected_word_set.get("file_name", ""))

	_status_label.text = status_text
	_start_button.disabled = not can_start


func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/game_hub.tscn")


func _on_start_pressed() -> void:
	if _selected_word_set.is_empty():
		_update_start_state()
		return

	var parsed_words := _store.parse_word_file(String(_selected_word_set.get("file_path", "")))
	if parsed_words.size() < _required_pair_count():
		_selected_word_set["word_count"] = parsed_words.size()
		_update_start_state()
		return

	var startup_config := GameStartupConfig.build_word_match_config(
		_selected_word_set,
		_board_size,
		GameStartupConfig.normalize_players(_players),
		_max_errors
	)
	var next_scene := WORD_MATCH_GAME_SCENE.instantiate()
	next_scene.set_startup_config(startup_config)
	get_tree().root.add_child(next_scene)
	get_tree().current_scene = next_scene
	queue_free()
