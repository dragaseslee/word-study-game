extends GameView


var _vm: PoisonSettingVM

@onready var word_set_option: OptionButton = get_node(^"PanelCenter/PanelContentMargin/PanelContent/WordSetSection/WordSetBox/AspectRatioContainer/OptionButton") as OptionButton
@onready var layout_33_button: BaseButton = get_node(^"PanelCenter/PanelContentMargin/PanelContent/LayoutSection/LayoutVBox/Layout33/Button") as BaseButton
@onready var layout_44_button: BaseButton = get_node(^"PanelCenter/PanelContentMargin/PanelContent/LayoutSection/LayoutVBox/Layout44/Button") as BaseButton
@onready var layout_55_button: BaseButton = get_node(^"PanelCenter/PanelContentMargin/PanelContent/LayoutSection/LayoutVBox/Layout55/Button") as BaseButton
@onready var import_button: TextureButton = %ImportButton
@onready var file_dialog: FileDialog = %UploadFileDialog
@onready var back_button: BaseButton = %BackButton
@onready var start_button: BaseButton = %StartButton
@onready var health_spin: SpinBox = %HealthSpin
@onready var poison_spin: SpinBox = %PoisonSpin
@onready var player_a_edit: TextEdit = get_node(^"PanelCenter/PanelContentMargin/PanelContent/PlayerSettingSection/PlayerHbox/TextEdit") as TextEdit
@onready var player_b_edit: TextEdit = get_node(^"PanelCenter/PanelContentMargin/PanelContent/PlayerSettingSection/PlayerHbox/TextEdit2") as TextEdit


func _ready() -> void:
	AudioMgr.play_bgm(preload("res://asserts/sounds/music.mp3"), 1.0)

	_vm = PoisonSettingVM.new()
	bind(_vm)

	_setup_file_dialog()
	_connect_signals()

	var params := SceneRouter.get_params()
	_vm.initialize(params)


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
	layout_33_button.pressed.connect(_vm.set_board_size.bind(3))
	layout_44_button.pressed.connect(_vm.set_board_size.bind(4))
	layout_55_button.pressed.connect(_vm.set_board_size.bind(5))
	health_spin.value_changed.connect(func(value: float) -> void: _vm.set_initial_health(int(value)))
	poison_spin.value_changed.connect(func(value: float) -> void: _vm.set_poison_count(int(value)))
	player_a_edit.text_changed.connect(func() -> void: _vm.set_player_name(0, player_a_edit.text))
	player_b_edit.text_changed.connect(func() -> void: _vm.set_player_name(1, player_b_edit.text))


func render(view_data: Dictionary) -> void:
	_render_word_set_option(view_data)
	_render_layout_buttons(view_data)
	_render_players(view_data)
	_render_spins(view_data)
	start_button.disabled = not bool(view_data.get("can_start", false))


func _render_word_set_option(view_data: Dictionary) -> void:
	var word_sets: Array = view_data.get("word_sets", [])
	var selected: Dictionary = view_data.get("selected_word_set", {})

	word_set_option.clear()
	if word_sets.is_empty():
		word_set_option.disabled = true
		word_set_option.add_item("暂无可用词表", -1)
		word_set_option.select(0)
		return

	word_set_option.disabled = false
	for index in range(word_sets.size()):
		var item := word_sets[index] as Dictionary
		word_set_option.add_item("%s (%d 词)" % [item.get("file_name", ""), int(item.get("word_count", 0))], index)

	var selected_path := String(selected.get("file_path", ""))
	for index in range(word_sets.size()):
		if String(word_sets[index].get("file_path", "")) == selected_path:
			word_set_option.select(index)
			return
	word_set_option.select(0)


func _render_layout_buttons(view_data: Dictionary) -> void:
	var board_size := int(view_data.get("board_size", 4))
	layout_33_button.button_pressed = board_size == 3
	layout_44_button.button_pressed = board_size == 4
	layout_55_button.button_pressed = board_size == 5


func _render_players(view_data: Dictionary) -> void:
	var players: Array = view_data.get("players", [])
	if players.size() >= 1:
		var name_a := String(players[0].get("name", ""))
		if player_a_edit.text != name_a:
			player_a_edit.text = name_a
	if players.size() >= 2:
		var name_b := String(players[1].get("name", ""))
		if player_b_edit.text != name_b:
			player_b_edit.text = name_b


func _render_spins(view_data: Dictionary) -> void:
	health_spin.value = int(view_data.get("initial_health", 2))
	poison_spin.value = int(view_data.get("poison_count", 2))


func _on_word_set_selected(index: int) -> void:
	_vm.select_word_set(index)


func _on_import_pressed() -> void:
	file_dialog.popup_centered_ratio(0.7)


func _on_file_selected(path: String) -> void:
	_vm.import_word_set(path)


func _on_back_pressed() -> void:
	SceneRouter.goto_hub()


func _on_start_pressed() -> void:
	var config := _vm.start_game()
	if config.is_empty():
		return
	SceneRouter.goto_gameplay("word_poison", config)
