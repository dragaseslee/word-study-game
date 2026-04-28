extends SceneTree

const WORD_POISON_SCENE_PATH := "res://scenes/word_poison_game.tscn"
const RESULT_SCENE_PATH := "res://scenes/word_poison_result.tscn"


func _initialize() -> void:
	var scene := load(WORD_POISON_SCENE_PATH) as PackedScene
	_assert(scene != null, "WordPoison scene should load")

	var root = scene.instantiate()
	_assert(root != null, "WordPoison scene should instantiate")
	root.set_startup_config({
		"word_set": {"file_name": "basic_words.txt", "file_path": "res://sample_word_sets/basic_words.txt"},
		"board_size": 3,
		"players": [{"id": 0, "name": "玩家1"}],
	})
	get_root().add_child(root)
	await process_frame

	var gameplay_panel := root.get_node("%GameplayPanel") as Control
	_assert(gameplay_panel.visible, "Gameplay panel should remain the only visible phase")
	_assert(root.has_node("GameplayPanel/GamePanel/BoardArea/CurrentPlayerName"), "Refactored current-player label missing")
	_assert(root.has_node("GameplayPanel/GamePanel/BoardArea/MarginContainer/CurrentGameInfo"), "Refactored status label missing")

	var board_grid := root.get_node("%BoardGrid") as GridContainer
	_assert(board_grid.get_child_count() == 9, "3x3 board should render 9 word cards")
	var first_card := board_grid.get_child(0) as Control
	_assert(first_card.name == "WordPanel", "Board should render word_panel instances")
	_assert(first_card.has_node("CardRoot"), "Word card should expose CardRoot for click animation")
	_assert(first_card.has_node("CardRoot/WhiteBurst"), "Word card should include white particle burst")
	_assert(first_card.has_node("CardRoot/BlackBurst"), "Word card should include black particle burst")
	var card_label := first_card.get_node("CardRoot/Label") as Label
	_assert(card_label.text.length() > 0, "Word card should display text")

	var gameplay_player_list := root.get_node("%GameplayPlayerList") as VBoxContainer
	gameplay_panel.update_view({
		"board_size": 3,
		"current_player_name": "玩家2",
		"current_player_id": 1,
		"status_text": "测试中",
		"word_set_name": "basic_words.txt",
		"best_score": 5,
		"show_next_button": false,
		"players": [
			{"id": 0, "name": "玩家1", "safe_click_count": 1, "is_eliminated": false},
			{"id": 1, "name": "玩家2", "safe_click_count": 5, "is_eliminated": false},
			{"id": 2, "name": "玩家3", "safe_click_count": 3, "is_eliminated": true},
		],
		"cells": [
			{"cell_index": 0, "display_text": "apple", "disabled": false, "effect_type": "normal"},
			{"cell_index": 1, "display_text": "pear", "disabled": false, "effect_type": "poison"},
		],
	})
	await process_frame
	_assert(board_grid.get_child_count() == 2, "Gameplay board should render cards from cell view model")
	var effect_card := board_grid.get_child(0) as Control
	var effect_label := effect_card.get_node("CardRoot/Label") as Label
	_assert(effect_label.text == "apple", "Card label should render supplied display text")
	_assert(effect_card.has_node("CardRoot/WhiteBurst"), "Normal cards should still have white burst node available")
	_assert(effect_card.has_node("CardRoot/BlackBurst"), "Poison cards should still have black burst node available")
	var delayed_click_state := {"count": 0}
	gameplay_panel.cell_pressed.connect(func(_cell_index: int) -> void:
		delayed_click_state["count"] += 1
	)
	var click_event := InputEventMouseButton.new()
	click_event.button_index = MOUSE_BUTTON_LEFT
	click_event.pressed = true
	var white_burst_root := effect_card.get_node("CardRoot/WhiteBurst") as Node2D
	var black_burst_root := effect_card.get_node("CardRoot/BlackBurst") as Node2D
	var white_particles := effect_card.get_node("CardRoot/WhiteBurst/yellowflash") as GPUParticles2D
	var black_particles := effect_card.get_node("CardRoot/BlackBurst/PoisonSmoke") as GPUParticles2D
	var success_sfx := effect_card.get_node("Node2D/SuccessSFX") as AudioStreamPlayer2D
	var fail_sfx := effect_card.get_node("Node2D/FailSFX") as AudioStreamPlayer2D
	_assert(not white_burst_root.visible, "Normal particle scene root should start hidden")
	_assert(not black_burst_root.visible, "Poison particle scene root should start hidden")
	_assert(not success_sfx.playing, "Success SFX should start idle")
	_assert(not fail_sfx.playing, "Fail SFX should start idle")
	gameplay_panel._on_word_panel_input(click_event, effect_card, 0, false, "normal")
	_assert(int(delayed_click_state["count"]) == 0, "Card click should wait for FX before emitting cell_pressed")
	_assert(effect_card.top_level, "Animated card should switch to top-level so overflow is not clipped by neighbors")
	_assert(white_burst_root.visible, "Normal click should reveal the nested white particle scene")
	_assert(not black_burst_root.visible, "Normal click should keep poison particle scene hidden")
	_assert(white_particles.emitting, "Normal click should leave the visible white particle scene emitting")
	_assert(success_sfx.playing, "Normal click should play success SFX")
	_assert(not fail_sfx.playing, "Normal click should not play fail SFX")
	await create_timer(0.6).timeout
	_assert(int(delayed_click_state["count"]) == 0, "Card click should still be waiting while the longer FX plays")
	await create_timer(1.8).timeout
	_assert(int(delayed_click_state["count"]) == 1, "Card click should emit cell_pressed exactly once after FX completes")
	var refreshed_card := board_grid.get_child(0) as Control
	_assert(not refreshed_card.top_level, "Rebuilt board cards should return to normal layout state after FX completes")
	gameplay_panel.update_view({
		"board_size": 3,
		"current_player_name": "玩家2",
		"current_player_id": 1,
		"status_text": "测试中",
		"word_set_name": "basic_words.txt",
		"best_score": 5,
		"show_next_button": false,
		"players": [
			{"id": 0, "name": "玩家1", "safe_click_count": 1, "is_eliminated": false},
			{"id": 1, "name": "玩家2", "safe_click_count": 5, "is_eliminated": false},
			{"id": 2, "name": "玩家3", "safe_click_count": 3, "is_eliminated": true},
		],
		"cells": [
			{"cell_index": 1, "display_text": "pear", "disabled": false, "effect_type": "poison"},
		],
	})
	await process_frame
	var poison_card := board_grid.get_child(0) as Control
	var poison_success_sfx := poison_card.get_node("Node2D/SuccessSFX") as AudioStreamPlayer2D
	var poison_fail_sfx := poison_card.get_node("Node2D/FailSFX") as AudioStreamPlayer2D
	gameplay_panel._on_word_panel_input(click_event, poison_card, 1, false, "poison")
	_assert(poison_fail_sfx.playing, "Poison click should play fail SFX")
	_assert(not poison_success_sfx.playing, "Poison click should not play success SFX")
	await create_timer(2.5).timeout
	gameplay_panel.update_view({
		"board_size": 3,
		"current_player_name": "玩家2",
		"current_player_id": 1,
		"status_text": "测试中",
		"word_set_name": "basic_words.txt",
		"best_score": 5,
		"show_next_button": false,
		"players": [
			{"id": 0, "name": "玩家1", "safe_click_count": 1, "is_eliminated": false},
			{"id": 1, "name": "玩家2", "safe_click_count": 5, "is_eliminated": false},
			{"id": 2, "name": "玩家3", "safe_click_count": 3, "is_eliminated": true},
		],
		"cells": [],
	})
	await process_frame

	_assert(gameplay_player_list.get_child_count() == 3, "Gameplay player list should render one score card per player")
	var first_player_score := gameplay_player_list.get_child(0) as Control
	var second_player_score := gameplay_player_list.get_child(1) as Control
	var third_player_score := gameplay_player_list.get_child(2) as Control
	_assert(first_player_score.has_node("HBoxContainer/Avatar"), "Player score card should include avatar")
	_assert(first_player_score.has_node("HBoxContainer/Label"), "Player score card should include score label")
	var first_name := first_player_score.get_node("HBoxContainer/Avatar/MarginContainer/LineEdit") as LineEdit
	var second_name := second_player_score.get_node("HBoxContainer/Avatar/MarginContainer/LineEdit") as LineEdit
	var third_name := third_player_score.get_node("HBoxContainer/Avatar/MarginContainer/LineEdit") as LineEdit
	var first_score := first_player_score.get_node("HBoxContainer/Label") as Label
	_assert(first_name.text == "玩家2", "Highest score should render first")
	_assert(second_name.text == "玩家3", "Second highest score should render second")
	_assert(third_name.text == "玩家1", "Lowest score should render last")
	_assert(first_score.text == "5", "Player score label should show only the score")
	_assert(not first_score.text.contains("进行中"), "Player score label should not show running status text")
	_assert(not first_score.text.contains("已结束"), "Player score label should not show eliminated status text")

	gameplay_panel.update_view({
		"board_size": 3,
		"current_player_name": "玩家1",
		"current_player_id": 0,
		"status_text": "测试中",
		"word_set_name": "basic_words.txt",
		"best_score": 6,
		"show_next_button": false,
		"players": [
			{"id": 0, "name": "玩家1", "safe_click_count": 6, "is_eliminated": false},
			{"id": 1, "name": "玩家2", "safe_click_count": 5, "is_eliminated": false},
			{"id": 2, "name": "玩家3", "safe_click_count": 3, "is_eliminated": true},
		],
		"cells": [],
	})
	await process_frame

	var reordered_first := gameplay_player_list.get_child(0) as Control
	var reordered_first_name := reordered_first.get_node("HBoxContainer/Avatar/MarginContainer/LineEdit") as LineEdit
	_assert(reordered_first_name.text == "玩家1", "Player list should re-sort when scores change")
	_assert(reordered_first.top_level, "Rank changes should temporarily switch cards to top-level for movement animation")
	_assert(reordered_first.modulate != Color(1, 1, 1, 1), "Rank changes should trigger a highlight animation state")
	await create_timer(0.35).timeout
	_assert(gameplay_player_list.get_child_count() == 3, "All player cards should still exist after rank animation completes")
	var final_first := gameplay_player_list.get_child(0) as Control
	var final_second := gameplay_player_list.get_child(1) as Control
	var final_third := gameplay_player_list.get_child(2) as Control
	_assert(final_first.global_position.y < final_second.global_position.y, "First and second player cards should not overlap after animation")
	_assert(final_second.global_position.y < final_third.global_position.y, "Second and third player cards should not overlap after animation")

	var end_game_button := root.get_node("%EndGameButton") as Button
	_assert(end_game_button != null, "EndGameButton should exist")
	end_game_button.pressed.emit()
	await process_frame

	var result_scene := get_root().get_child(get_root().get_child_count() - 1)
	_assert(result_scene.scene_file_path == RESULT_SCENE_PATH, "EndGameButton should navigate to the result scene")
	_assert(result_scene.has_method("set_results"), "Result scene controller should expose a set_results entry point")
	var results_list := result_scene.get_node("%ResultsList") as VBoxContainer
	var replay_button := result_scene.get_node("%ReplayButton") as Button
	var back_button := result_scene.get_node("%BackToHubButton") as Button
	_assert(results_list.get_child_count() >= 1, "Result scene should receive at least one ranked row")
	var first_result_score := results_list.get_child(0) as Control
	_assert(first_result_score.has_node("HBoxContainer/Avatar"), "Result rows should render player_score cards")
	_assert(first_result_score.has_node("HBoxContainer/TextureProgressBar"), "Result rows should include score progress bar")
	_assert(first_result_score.has_node("HBoxContainer/Label"), "Result rows should include score label")
	_assert(replay_button != null, "ReplayButton missing from result scene")
	_assert(back_button != null, "BackToHubButton missing from result scene")

	var poison_music := get_root().get_node_or_null("PoisonMusic") as AudioStreamPlayer2D
	if poison_music != null:
		poison_music.stop()
		poison_music.free()
	result_scene.free()
	quit(0)


func _assert(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	quit(1)
