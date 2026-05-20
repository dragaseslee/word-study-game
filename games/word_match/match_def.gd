extends GameDef


func _init() -> void:
	game_id = "word_match"
	display_name = "单词配对"
	display_order = 2
	icon_path = "res://asserts/buttons/button_word_match.png"
	setting_scene = "res://games/word_match/views/setting_view.tscn"
	gameplay_scene = "res://games/word_match/views/gameplay_view.tscn"
	result_scene = "res://games/word_match/views/result_view.tscn"
	bgm_stream = null


func create_setting_vm() -> ViewModel:
	return MatchSettingVM.new()


func create_gameplay_vm() -> ViewModel:
	return MatchGameplayVM.new()


func create_result_vm() -> ViewModel:
	return MatchResultVM.new()
