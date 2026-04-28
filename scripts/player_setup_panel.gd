extends VBoxContainer

signal start_requested(players: Array[Dictionary], board_size: int)
signal back_requested

const MAX_PLAYERS := 10

var _players: Array[Dictionary] = []
var _selected_board_size := 4

@onready var selected_word_set_label: Label = %SetupWordSetLabel
@onready var board_size_option: OptionButton = %BoardSizeOption
@onready var add_player_button: Button = %AddPlayerButton
@onready var player_list: VBoxContainer = %PlayerList
@onready var status_label: Label = %PlayerSetupStatusLabel
@onready var back_button: Button = %BackToWordSourceButton
@onready var start_button: Button = %StartGameButton


func _ready() -> void:
	board_size_option.clear()
	board_size_option.add_item("3 x 3", 3)
	board_size_option.add_item("4 x 4", 4)
	board_size_option.add_item("5 x 5", 5)
	board_size_option.item_selected.connect(_on_board_size_selected)
	add_player_button.pressed.connect(_on_add_player_pressed)
	back_button.pressed.connect(func() -> void: back_requested.emit())
	start_button.pressed.connect(_on_start_pressed)


func set_context(word_set_name: String, players: Array[Dictionary], board_size: int) -> void:
	selected_word_set_label.text = "当前词库: %s" % word_set_name
	_players = players.duplicate(true)
	_selected_board_size = board_size
	_select_board_size(board_size)
	_render_players()


func _default_player_name(index: int) -> String:
	return "玩家%d" % (index + 1)


func _on_board_size_selected(index: int) -> void:
	_selected_board_size = board_size_option.get_item_id(index)


func _on_add_player_pressed() -> void:
	if _players.size() >= MAX_PLAYERS:
		_render_players()
		return
	_players.append({
		"id": _players.size(),
		"name": _default_player_name(_players.size()),
	})
	_render_players()


func _on_remove_player_pressed(index: int) -> void:
	if _players.size() <= 1:
		return
	_players.remove_at(index)
	for i in range(_players.size()):
		_players[i]["id"] = i
	_render_players()


func _on_name_changed(new_text: String, index: int) -> void:
	_players[index]["name"] = new_text


func _on_start_pressed() -> void:
	var payload: Array[Dictionary] = []
	for i in range(_players.size()):
		var name := String(_players[i].get("name", "")).strip_edges()
		if name.is_empty():
			name = _default_player_name(i)
		payload.append({
			"id": i,
			"name": name,
		})
	start_requested.emit(payload, _selected_board_size)


func _render_players() -> void:
	for child in player_list.get_children():
		child.queue_free()

	for i in range(_players.size()):
		var row := HBoxContainer.new()
		var label := Label.new()
		label.text = "玩家 %d" % (i + 1)
		label.custom_minimum_size = Vector2(80, 0)

		var name_edit := LineEdit.new()
		name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_edit.placeholder_text = _default_player_name(i)
		name_edit.text = String(_players[i].get("name", _default_player_name(i)))
		name_edit.text_changed.connect(_on_name_changed.bind(i))

		var delete_button := Button.new()
		delete_button.text = "删除"
		delete_button.disabled = _players.size() <= 1
		delete_button.pressed.connect(_on_remove_player_pressed.bind(i))

		row.add_child(label)
		row.add_child(name_edit)
		row.add_child(delete_button)
		player_list.add_child(row)

	add_player_button.disabled = _players.size() >= MAX_PLAYERS
	status_label.text = "玩家数量: %d / %d" % [_players.size(), MAX_PLAYERS]


func _select_board_size(board_size: int) -> void:
	for index in range(board_size_option.item_count):
		if board_size_option.get_item_id(index) == board_size:
			board_size_option.select(index)
			return
	board_size_option.select(1)
	_selected_board_size = 4
