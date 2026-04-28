extends Control

const MIN_PLAYERS := 2
const MAX_PLAYERS := 2
const GameStartupConfig = preload("res://scripts/game_startup_config.gd")
const PoisonMusic = preload("res://scripts/poison_music.gd")
const WORD_POISON_SCENE := preload("res://scenes/word_poison_game.tscn")
const AVATAR_SCENE := preload("res://scenes/components/avatar.tscn")
const WORD_SET_OPTION_PATH := ^"PanelCenter/PanelContentMargin/PanelContent/WordSetSection/WordSetBox/AspectRatioContainer/OptionButton"
const PLAYER_SCROLL_PATH := ^"PanelCenter/PanelContentMargin/PanelContent/PlayerSettingSection/PlayerHbox/HBoxContainer/PlayerListScroll"
const PLAYER_LIST_PATH := ^"PanelCenter/PanelContentMargin/PanelContent/PlayerSettingSection/PlayerHbox/HBoxContainer/PlayerListScroll/PlayerList"
const PLAYER_ADD_BUTTON_PATH := ^"PanelCenter/PanelContentMargin/PanelContent/PlayerSettingSection/PlayerHbox/HBoxContainer/AspectRatioContainer/TextureButton"
const LAYOUT_33_BUTTON_PATH := ^"PanelCenter/PanelContentMargin/PanelContent/LayoutSection/LayoutVBox/Layout33/Button"
const LAYOUT_44_BUTTON_PATH := ^"PanelCenter/PanelContentMargin/PanelContent/LayoutSection/LayoutVBox/Layout44/Button"
const LAYOUT_55_BUTTON_PATH := ^"PanelCenter/PanelContentMargin/PanelContent/LayoutSection/LayoutVBox/Layout55/Button"

var _store := WordSetStore.new()
var _word_sets: Array[Dictionary] = []
var _selected_word_set: Dictionary = {}
var _board_size := 4
var _players: Array[Dictionary] = []

@onready var word_set_option: OptionButton = get_node(WORD_SET_OPTION_PATH) as OptionButton
@onready var layout_33_button: BaseButton = get_node(LAYOUT_33_BUTTON_PATH) as BaseButton
@onready var layout_44_button: BaseButton = get_node(LAYOUT_44_BUTTON_PATH) as BaseButton
@onready var layout_55_button: BaseButton = get_node(LAYOUT_55_BUTTON_PATH) as BaseButton
@onready var import_button: TextureButton = %ImportButton
@onready var file_dialog: FileDialog = %UploadFileDialog
@onready var back_button: BaseButton = %BackButton
@onready var start_button: BaseButton = %StartButton
@onready var health_spin: SpinBox = %HealthSpin
@onready var poison_spin: SpinBox = %PoisonSpin


func _ready() -> void:
	PoisonMusic.ensure_playing(get_tree())
	_players = [_make_player(0), _make_player(1)]
	_setup_file_dialog()
	_connect_signals()
	_setup_word_set_options()
	_select_layout(_board_size)
	_render_players()
	_update_start_state()


func _setup_file_dialog() -> void:
	file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	file_dialog.access = FileDialog.ACCESS_FILESYSTEM
	file_dialog.filters = PackedStringArray(["*.txt ; 文本词库", "*.csv ; CSV 词库", "*.tsv ; TSV 词库"])


func _connect_signals() -> void:
	word_set_option.item_selected.connect(_on_word_set_selected)
	import_button.pressed.connect(_on_import_pressed)
	back_button.pressed.connect(_on_back_pressed)
	start_button.pressed.connect(_on_start_pressed)
	file_dialog.file_selected.connect(_on_file_selected)
	layout_33_button.pressed.connect(_on_layout_selected.bind(3))
	layout_44_button.pressed.connect(_on_layout_selected.bind(4))
	layout_55_button.pressed.connect(_on_layout_selected.bind(5))


func _setup_word_set_options() -> void:
	var previous_path := String(_selected_word_set.get("file_path", ""))
	_word_sets = _store.list_word_sets()
	word_set_option.clear()
	if _word_sets.is_empty():
		_selected_word_set = {}
		word_set_option.disabled = true
		word_set_option.add_item("暂无可用词表", -1)
		word_set_option.select(0)
		_update_start_state()
		return

	word_set_option.disabled = false
	for index in range(_word_sets.size()):
		var item := _word_sets[index]
		word_set_option.add_item("%s (%d 词)" % [item.get("file_name", ""), int(item.get("word_count", 0))], index)

	_select_word_set_by_path(previous_path)
	var selected_index := _selected_word_index()
	if selected_index >= 0:
		word_set_option.select(selected_index)
	_update_start_state()


func _select_word_set_by_path(file_path: String) -> void:
	if _word_sets.is_empty():
		_selected_word_set = {}
		return

	for item in _word_sets:
		if String(item.get("file_path", "")) == file_path:
			_selected_word_set = item.duplicate(true)
			return

	_selected_word_set = _word_sets[0].duplicate(true)


func _selected_word_index() -> int:
	if _selected_word_set.is_empty():
		return -1
	var file_path := String(_selected_word_set.get("file_path", ""))
	for index in range(_word_sets.size()):
		if String(_word_sets[index].get("file_path", "")) == file_path:
			return index
	return -1


func _on_word_set_selected(index: int) -> void:
	if index < 0 or index >= _word_sets.size():
		_selected_word_set = {}
	else:
		_selected_word_set = _word_sets[index].duplicate(true)
	_update_start_state()


func _on_layout_selected(board_size: int) -> void:
	_board_size = board_size
	_select_layout(board_size)


func _on_plus_pressed() -> void:
	if _players.size() >= MAX_PLAYERS:
		return
	_players.append(_make_player(_players.size()))
	_render_players()


func _on_minus_pressed() -> void:
	if _players.size() <= MIN_PLAYERS:
		return
	_players.remove_at(_players.size() - 1)
	_reindex_players()
	_render_players()


func _on_remove_player_pressed(index: int) -> void:
	if _players.size() <= MIN_PLAYERS:
		return
	if index < 0 or index >= _players.size():
		return
	_players.remove_at(index)
	_reindex_players()
	_render_players()


func _on_player_name_changed(new_text: String, index: int) -> void:
	if index < 0 or index >= _players.size():
		return
	_players[index]["name"] = new_text


func _on_import_pressed() -> void:
	file_dialog.popup_centered_ratio(0.7)


func _on_file_selected(path: String) -> void:
	var result := _store.import_word_set(path)
	if not bool(result.get("ok", false)):
		_update_start_state()
		return

	_selected_word_set = {
		"file_name": result.get("file_name", ""),
		"file_path": result.get("file_path", ""),
		"word_count": result.get("word_count", 0),
	}
	_setup_word_set_options()


func _render_players() -> void:

	for index in range(_players.size()):
		var avatar := AVATAR_SCENE.instantiate() as Control
		var name_edit := avatar.get_node("MarginContainer/LineEdit") as LineEdit
		var delete_button := avatar.get_node("AspectRatioContainer/delete") as BaseButton
		avatar.custom_minimum_size = Vector2(220, 180)
		name_edit.placeholder_text = _default_player_name(index)
		name_edit.text = String(_players[index].get("name", _default_player_name(index)))
		name_edit.text_changed.connect(_on_player_name_changed.bind(index))
		delete_button.disabled = _players.size() <= MIN_PLAYERS
		delete_button.pressed.connect(_on_remove_player_pressed.bind(index), CONNECT_DEFERRED)

func _update_start_state() -> void:
	start_button.disabled = _selected_word_set.is_empty()


func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/game_hub.tscn")


func _on_start_pressed() -> void:
	if _selected_word_set.is_empty():
		_update_start_state()
		return

	var words := _store.parse_word_file(String(_selected_word_set.get("file_path", "")))
	if words.is_empty():
		_selected_word_set = {}
		_update_start_state()
		return

	var next_scene := WORD_POISON_SCENE.instantiate()
	next_scene.set_startup_config({
		"word_set": _selected_word_set.duplicate(true),
		"board_size": _board_size,
		"players": _normalized_players(),
		"initial_health": int(health_spin.value),
		"poison_count": int(poison_spin.value),
	})
	get_tree().root.add_child(next_scene)
	get_tree().current_scene = next_scene
	queue_free()


func _normalized_players() -> Array[Dictionary]:
	return GameStartupConfig.normalize_players(_players)


func _make_player(index: int) -> Dictionary:
	return {
		"id": index,
		"name": _default_player_name(index),
	}


func _default_player_name(index: int) -> String:
	return "玩家%d" % (index + 1)


func _reindex_players() -> void:
	for index in range(_players.size()):
		_players[index]["id"] = index
		if String(_players[index].get("name", "")).strip_edges().is_empty():
			_players[index]["name"] = _default_player_name(index)


func _select_layout(board_size: int) -> void:
	var selected_buttons := {
		3: layout_33_button,
		4: layout_44_button,
		5: layout_55_button,
	}
	for size in selected_buttons.keys():
		var button: BaseButton = selected_buttons[size]
		button.button_pressed = size == board_size
