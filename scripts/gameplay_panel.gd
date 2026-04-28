extends HBoxContainer

signal cell_pressed(cell_index: int, player_index: int)
signal next_player_requested
signal end_game_requested

const WORD_PANEL_SCENE := preload("res://scenes/components/word_panel.tscn")
const PLAYER_SCORE_SCENE := preload("res://scenes/components/player_score.tscn")
const LIFE_VALUE_SCENE := preload("res://scenes/components/life_value_item.tscn")
const CARD_CLICK_SCALE_UP := Vector2(1.16, 1.16)
const CARD_CLICK_SCALE_NORMAL := Vector2.ONE
const CARD_CLICK_SHAKE_AMPLITUDE_X := 20.0
const CARD_CLICK_SHAKE_AMPLITUDE_Y := 20.0
const CARD_CLICK_SHAKE_DURATION := 2
const CARD_CLICK_SHAKE_FREQUENCY := 15
const CARD_CLICK_SHAKE_DAMPING := 4.2
const CARD_CLICK_SCALE_TIME := 0.5
const CARD_CLICK_RECOVER_TIME := 0.5


var _card_fx_running := false
var _card_fx_cell_index := -1
var _card_fx_tween: Tween
var _card_fx_card: Control
var _card_fx_card_global_position := Vector2.ZERO

@onready var player1_label: Label = %PlayerName1
@onready var board_grid1: GridContainer = %BoardGrid1
@onready var player2_label: Label = %PlayerName2
@onready var board_grid2: GridContainer = %BoardGrid2
@onready var life_box1: HBoxContainer = get_node("Player1Panel/BoardArea/Player1PLifeInfo/LifeBox") as HBoxContainer
@onready var life_box2: HBoxContainer = get_node("Player2Panel/BoardArea/Player2PLifeInfo/LifeBox") as HBoxContainer



func _ready() -> void:
	print("DEBUG: player1_label = ", player1_label, " player2_label = ", player2_label)
	if player1_label:
		print("DEBUG: PlayerName1 initial text = ", player1_label.text)
	if player2_label:
		print("DEBUG: PlayerName2 initial text = ", player2_label.text)


func update_view(view_model: Dictionary) -> void:
	var board_size := int(view_model.get("board_size", 4))
	var players: Array[Dictionary] = view_model.get("players", []).duplicate()
	var current_player_id := int(view_model.get("current_player_id", -1))
	var players_view_data: Array[Dictionary] = view_model.get("players_view_data", [])
	
	# 更新玩家标签
	print("DEBUG update_view: players = ", players)
	if players.size() > 0 and is_instance_valid(player1_label):
		var name1 = players[0].get("name", "")
		player1_label.text = name1
		print("DEBUG: Player1 label set to: '", name1, "'")
	if players.size() > 1 and is_instance_valid(player2_label):
		var name2 = players[1].get("name", "")
		player2_label.text = name2
		print("DEBUG: Player2 label set to: '", name2, "'")
	

	
	# 设置棋盘列数
	board_grid1.columns = board_size
	board_grid2.columns = board_size
	
	# 渲染两个玩家的棋盘
	if players_view_data.size() > 0:
		_render_board_for_player(board_grid1, players_view_data[0].get("cells", []), 0)
	if players_view_data.size() > 1:
		_render_board_for_player(board_grid2, players_view_data[1].get("cells", []), 1)
	
	# 渲染生命值
	if players.size() > 0:
		_render_life(life_box1, players[0])
	if players.size() > 1:
		_render_life(life_box2, players[1])


func _render_life(life_box: Container, player: Dictionary) -> void:
	var health := int(player.get("health", 0))
	var current_items: Array[Node] = []
	for child in life_box.get_children():
		if child.name.begins_with("LifeValueItem"):
			current_items.append(child)
	
	# 如果现有的不够，创建新的
	while current_items.size() < health:
		var life_item = LIFE_VALUE_SCENE.instantiate()
		life_item.name = "LifeValueItem_" + str(current_items.size())
		life_box.add_child(life_item)
		current_items.append(life_item)
	
	# 根据 health 数量显示或隐藏
	for i in range(current_items.size()):
		current_items[i].visible = (i < health)


func _render_board_for_player(grid: GridContainer, cells: Array, player_index: int) -> void:
	_reset_card_fx_state()
	
	# 清空棋盘
	for child in grid.get_children():
		child.queue_free()

	for cell_data in cells:
		var cell := cell_data as Dictionary
		
		# 为玩家创建卡片
		var card := WORD_PANEL_SCENE.instantiate() as Control
		var label := card.get_node("CardRoot/Label") as Label
		label.text = String(cell.get("display_text", ""))
		card.custom_minimum_size = Vector2(140, 120)
		card.mouse_filter = Control.MOUSE_FILTER_STOP
		card.modulate = Color(0.65, 0.65, 0.65, 1.0) if bool(cell.get("disabled", false)) else Color(1, 1, 1, 1)
		card.gui_input.connect(_on_word_panel_input.bind(card, int(cell.get("cell_index", -1)), bool(cell.get("disabled", false)), String(cell.get("effect_type", "normal")), player_index))
		grid.add_child(card)





func _on_word_panel_input(event: InputEvent, card: Control, cell_index: int, disabled: bool, effect_type: String, player_index: int) -> void:
	if disabled or _card_fx_running:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_play_card_click_fx(card, cell_index, effect_type, player_index)


func _play_card_click_fx(card: Control, cell_index: int, effect_type: String, player_index: int) -> void:
	if not is_instance_valid(card):
		return

	var card_root := card.get_node("CardRoot") as Control
	var white_burst := card.get_node_or_null("CardRoot/WhiteBurst")
	var black_burst := card.get_node_or_null("CardRoot/BlackBurst")
	var success_sfx := card.get_node_or_null("Node2D/SuccessSFX") as AudioStreamPlayer2D
	var fail_sfx := card.get_node_or_null("Node2D/FailSFX") as AudioStreamPlayer2D
	if card_root == null:
		cell_pressed.emit(cell_index, player_index)
		return

	_card_fx_running = true
	_card_fx_cell_index = cell_index
	_elevate_card_overlay(card)
	card_root.scale = CARD_CLICK_SCALE_NORMAL
	card_root.position = Vector2.ZERO

	var active_burst := black_burst if effect_type == "poison" else white_burst
	_set_particle_scene_active(white_burst, false)
	_set_particle_scene_active(black_burst, false)
	_set_particle_scene_active(active_burst, true)
	_set_card_sfx_state(success_sfx, false)
	_set_card_sfx_state(fail_sfx, false)
	_set_card_sfx_state(fail_sfx if effect_type == "poison" else success_sfx, true)

	_card_fx_tween = create_tween()
	_card_fx_tween.set_trans(Tween.TRANS_SINE)
	_card_fx_tween.set_ease(Tween.EASE_OUT)
	_card_fx_tween.tween_property(card_root, "scale", CARD_CLICK_SCALE_UP, CARD_CLICK_SCALE_TIME)
	_card_fx_tween.parallel().tween_method(_update_card_shake.bind(card_root), 0.0, CARD_CLICK_SHAKE_DURATION, CARD_CLICK_SHAKE_DURATION)
	_card_fx_tween.parallel().tween_property(card_root, "scale", CARD_CLICK_SCALE_NORMAL, CARD_CLICK_RECOVER_TIME)
	_card_fx_tween.finished.connect(func() -> void:
		if is_instance_valid(card_root):
			card_root.scale = CARD_CLICK_SCALE_NORMAL
			card_root.position = Vector2.ZERO
		_set_particle_scene_active(white_burst, false)
		_set_particle_scene_active(black_burst, false)
		_set_card_sfx_state(success_sfx, false)
		_set_card_sfx_state(fail_sfx, false)
		_reset_card_fx_state()
		cell_pressed.emit(cell_index, player_index)
	)


func _reset_card_fx_state() -> void:
	if _card_fx_tween != null and _card_fx_tween.is_valid():
		_card_fx_tween.kill()
	_restore_card_overlay()
	_card_fx_tween = null
	_card_fx_running = false
	_card_fx_cell_index = -1


func _set_particle_scene_active(scene_root: Node, is_active: bool) -> void:
	if not is_instance_valid(scene_root):
		return
	if scene_root is CanvasItem:
		(scene_root as CanvasItem).visible = is_active
	for child in scene_root.get_children():
		if child is GPUParticles2D:
			var particles := child as GPUParticles2D
			if is_active:
				particles.restart()
				particles.emitting = true
			else:
				particles.emitting = false


func _set_card_sfx_state(player: AudioStreamPlayer2D, is_active: bool) -> void:
	if not is_instance_valid(player):
		return
	if is_active:
		player.stop()
		player.play()
		return
	player.stop()


func _update_card_shake(elapsed: float, card_root: Control) -> void:
	if not is_instance_valid(card_root):
		return
	var shake_x := sin(elapsed * CARD_CLICK_SHAKE_FREQUENCY) * exp(-elapsed * CARD_CLICK_SHAKE_DAMPING)
	var shake_y := cos(elapsed * (CARD_CLICK_SHAKE_FREQUENCY * 0.82)) * exp(-elapsed * (CARD_CLICK_SHAKE_DAMPING * 1.15))
	card_root.position = Vector2(
		shake_x * CARD_CLICK_SHAKE_AMPLITUDE_X,
		shake_y * CARD_CLICK_SHAKE_AMPLITUDE_Y
	)


func _elevate_card_overlay(card: Control) -> void:
	if not is_instance_valid(card):
		return
	_card_fx_card = card
	_card_fx_card_global_position = card.global_position
	card.top_level = true
	card.global_position = _card_fx_card_global_position


func _restore_card_overlay() -> void:
	if not is_instance_valid(_card_fx_card):
		_card_fx_card = null
		return
	_card_fx_card.top_level = false
	_card_fx_card.position = Vector2.ZERO
	_card_fx_card = null
