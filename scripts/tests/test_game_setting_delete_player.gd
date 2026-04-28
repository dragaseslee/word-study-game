extends SceneTree

const GAME_SETTING_SCENE_PATH := "res://scenes/game_setting.tscn"
const PLAYER_LIST_PATH := "PanelCenter/PanelContentMargin/PanelContent/PlayerSettingSection/PlayerHbox/HBoxContainer/PlayerListScroll/PlayerList"


func _initialize() -> void:
	var settings_scene := load(GAME_SETTING_SCENE_PATH) as PackedScene
	_assert(settings_scene != null, "Game setting scene should load")

	var settings_root := settings_scene.instantiate()
	_assert(settings_root != null, "Game setting scene should instantiate")
	get_root().add_child(settings_root)
	await process_frame

	var controller := settings_root
	controller._on_plus_pressed()
	await process_frame

	var player_list := settings_root.get_node(PLAYER_LIST_PATH) as HBoxContainer
	_assert(player_list.get_child_count() == 2, "Two avatars should render before delete")

	var second_avatar := player_list.get_child(1) as Control
	var delete_button := second_avatar.get_node("AspectRatioContainer/delete") as BaseButton
	_assert(delete_button != null, "Delete button should exist on avatar")

	delete_button.pressed.emit()
	await process_frame

	_assert(controller._players.size() == 1, "Delete should remove one player from controller state")
	_assert(player_list.get_child_count() == 1, "Delete should re-render exactly one avatar")

	settings_root.free()
	quit(0)


func _assert(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	quit(1)
