extends SceneTree

const GAME_SETTING_SCENE_PATH := "res://scenes/game_setting.tscn"
const PLAYER_SCROLL_PATH := "PanelCenter/PanelContentMargin/PanelContent/PlayerSettingSection/PlayerHbox/HBoxContainer/PlayerListScroll"
const PLAYER_LIST_PATH := PLAYER_SCROLL_PATH + "/PlayerList"


func _initialize() -> void:
	var settings_scene := load(GAME_SETTING_SCENE_PATH) as PackedScene
	_assert(settings_scene != null, "Game setting scene should load")

	var settings_root := settings_scene.instantiate()
	_assert(settings_root != null, "Game setting scene should instantiate")
	get_root().add_child(settings_root)
	await process_frame

	var controller := settings_root
	controller._on_plus_pressed()

	var player_scroll := settings_root.get_node(PLAYER_SCROLL_PATH) as ScrollContainer
	var player_list := settings_root.get_node(PLAYER_LIST_PATH) as HBoxContainer
	_assert(player_list.get_child_count() == 2, "Player list should render one avatar per player")

	var first_avatar := player_list.get_child(0) as Control
	_assert(player_scroll.custom_minimum_size.y >= first_avatar.custom_minimum_size.y, "Player scroll area should be tall enough to show the full avatar card")

	settings_root.free()
	quit(0)


func _assert(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	quit(1)
