extends SceneTree

const GAME_SETTING_SCENE_PATH := "res://scenes/game_setting.tscn"
const WORD_POISON_SCENE_PATH := "res://scenes/word_poison_game.tscn"
const GAME_HUB_SCENE_PATH := "res://scenes/game_hub.tscn"


func _initialize() -> void:
	var settings_scene := load(GAME_SETTING_SCENE_PATH) as PackedScene
	_assert(settings_scene != null, "Game setting scene should load")

	var settings_root := settings_scene.instantiate()
	_assert(settings_root != null, "Game setting scene should instantiate")
	get_root().add_child(settings_root)
	await process_frame

	_assert(settings_root.has_node("BackgroundLayer"), "BackgroundLayer node missing")
	_assert(settings_root.has_node("PanelCenter/PanelContentMargin/PanelContent/WordSetSection"), "Refactored word-set section missing")
	_assert(settings_root.has_node("PanelCenter/PanelContentMargin/PanelContent/LayoutSection"), "Layout section missing")
	_assert(settings_root.has_node("PanelCenter/PanelContentMargin/PanelContent/PlayerSettingSection"), "Player setting section missing")
	_assert(settings_root.has_node("ActionSection/ActionButtons"), "Action buttons missing")

	var controller := settings_root
	_assert(controller.get_script() != null, "Game setting controller script missing")
	_assert(controller.has_method("_on_plus_pressed"), "Game setting controller should restore player-management logic")
	var root_music := get_root().get_node_or_null("PoisonMusic") as AudioStreamPlayer2D
	_assert(root_music != null, "Entering the poison-game flow should start the shared poison music")
	_assert(root_music.playing, "Shared poison music should begin playing in the poison-game flow")
	_assert(_count_poison_music_players() == 1, "Poison-game flow should keep exactly one shared music player")
	var music_instance_id := root_music.get_instance_id()

	var start_button := settings_root.get_node("%StartButton") as BaseButton
	_assert(start_button != null, "Start button should exist")
	var initial_word_sets: Array = controller.get("_word_sets")
	_assert(start_button.disabled == initial_word_sets.is_empty(), "Start should only be disabled when no valid word set is available")

	controller._on_plus_pressed()
	_assert(controller._players.size() == 2, "Plus should append one player")
	var player_scroll := settings_root.get_node("PanelCenter/PanelContentMargin/PanelContent/PlayerSettingSection/PlayerHbox/HBoxContainer/PlayerListScroll") as ScrollContainer
	var player_list := settings_root.get_node("PanelCenter/PanelContentMargin/PanelContent/PlayerSettingSection/PlayerHbox/HBoxContainer/PlayerListScroll/PlayerList") as HBoxContainer
	_assert(player_list.get_child_count() == 2, "Player list should render one avatar per player")
	var second_avatar := player_list.get_child(1) as Control
	_assert(second_avatar.has_node("MarginContainer/LineEdit"), "Avatar scene should provide LineEdit for player naming")
	_assert(second_avatar.has_node("AspectRatioContainer/delete"), "Avatar scene should provide delete button")
	_assert(player_scroll.custom_minimum_size.y >= second_avatar.custom_minimum_size.y, "Player scroll area should be tall enough to show the full avatar card")
	controller._on_minus_pressed()
	_assert(controller._players.size() == 1, "Minus should remove the tail player")
	var first_avatar := player_list.get_child(0) as Control
	var delete_button := first_avatar.get_node("AspectRatioContainer/delete") as BaseButton
	_assert(delete_button.disabled, "Avatar delete button should be disabled when only one player remains")

	controller._on_layout_selected(5)
	_assert(controller._board_size == 5, "Layout selection should update board size")

	var store := WordSetStore.new()
	var import_result := store.import_word_set(ProjectSettings.globalize_path("res://sample_word_sets/basic_words.txt"))
	_assert(bool(import_result.get("ok", false)), "Sample word set should import for integration testing")

	controller._setup_word_set_options()
	var imported_sets: Array = controller.get("_word_sets")
	var selected_index := -1
	for index in range(imported_sets.size()):
		var item: Dictionary = imported_sets[index]
		if String(item.get("file_path", "")) == String(import_result.get("file_path", "")):
			selected_index = index
			break
	_assert(selected_index >= 0, "Imported word set should appear in the settings selector")
	controller._on_word_set_selected(selected_index)
	controller._on_plus_pressed()
	controller._on_player_name_changed("   ", 1)
	controller._on_layout_selected(5)
	controller._update_start_state()
	_assert(not start_button.disabled, "Start should enable once a valid word set is selected")

	controller._on_start_pressed()
	await process_frame

	var current_scene := get_root().get_child(get_root().get_child_count() - 1)
	_assert(current_scene != null, "Starting should create a gameplay scene")
	_assert(current_scene.scene_file_path == WORD_POISON_SCENE_PATH, "Starting should navigate to WordPoison")
	var gameplay_music := get_root().get_node_or_null("PoisonMusic") as AudioStreamPlayer2D
	_assert(gameplay_music != null, "Poison music should persist into gameplay")
	_assert(gameplay_music.get_instance_id() == music_instance_id, "Gameplay should reuse the same poison music instance")
	_assert(_count_poison_music_players() == 1, "Gameplay should not duplicate the shared poison music")

	var gameplay_panel := current_scene.get_node("%GameplayPanel") as Control
	_assert(gameplay_panel.visible, "WordPoison should show gameplay immediately when started from GameSetting")
	_assert(current_scene.has_node("GameplayPanel/GamePanel/BoardArea/CurrentPlayerName"), "Refactored current-player label missing")
	_assert(current_scene.has_node("GameplayPanel/GamePanel/BoardArea/MarginContainer/CurrentGameInfo"), "Refactored status label missing")
	_assert(current_scene.has_node("GameplayPanel/SidebarPanel/VBoxContainer/ActionButton/HBoxContainer/EndGameButton"), "EndGameButton missing")

	var runtime_players = current_scene.get("_players") as Array
	_assert(runtime_players.size() == 2, "Startup payload should supply all players")
	_assert(String(runtime_players[1].get("name", "")) == "玩家2", "Blank player names should normalize before gameplay starts")
	_assert(int(current_scene.get("_board_size")) == 5, "Selected board size should reach gameplay")

	current_scene._on_end_game_requested()
	await process_frame

	var replay_scene := get_root().get_child(get_root().get_child_count() - 1)
	_assert(replay_scene.scene_file_path == "res://scenes/word_poison_result.tscn", "End game should navigate to result scene")
	var result_music := get_root().get_node_or_null("PoisonMusic") as AudioStreamPlayer2D
	_assert(result_music != null, "Poison music should persist into the result scene")
	_assert(result_music.get_instance_id() == music_instance_id, "Result scene should reuse the same poison music instance")
	_assert(_count_poison_music_players() == 1, "Result scene should still have exactly one shared poison music player")
	var replay_button := replay_scene.get_node("%ReplayButton") as Button
	replay_button.pressed.emit()
	await process_frame

	var settings_replay_scene := get_root().get_child(get_root().get_child_count() - 1)
	_assert(settings_replay_scene.scene_file_path == GAME_SETTING_SCENE_PATH, "Replay should return to GameSetting")
	var replay_music := get_root().get_node_or_null("PoisonMusic") as AudioStreamPlayer2D
	_assert(replay_music != null, "Poison music should keep playing when replay returns to GameSetting")
	_assert(replay_music.get_instance_id() == music_instance_id, "Replay should not restart the poison music")
	_assert(_count_poison_music_players() == 1, "Replay should not duplicate the shared poison music")
	settings_replay_scene._on_back_pressed()
	await process_frame
	var hub_scene := get_root().get_child(get_root().get_child_count() - 1)
	_assert(hub_scene.scene_file_path == GAME_HUB_SCENE_PATH, "Back from GameSetting should return to game hub")
	_assert(get_root().get_node_or_null("PoisonMusic") == null, "Returning to game hub should stop and remove the poison music")

	hub_scene.free()
	quit(0)


func _assert(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	quit(1)


func _count_poison_music_players() -> int:
	var count := 0
	for child in get_root().get_children():
		if child.name == "PoisonMusic":
			count += 1
	return count
