extends GameDef


func _init() -> void:
    game_id = "word_race"
    display_name = "单词竞速"
    display_order = 3
    icon_path = "res://asserts/buttons/button_word_race.png"
    setting_scene = "res://games/word_race/views/setting_view.tscn"
    gameplay_scene = "res://games/word_race/views/gameplay_view.tscn"
    result_scene = "res://games/word_race/views/result_view.tscn"
    bgm_stream = null


func create_setting_vm() -> ViewModel:
    return RaceSettingVM.new()


func create_gameplay_vm() -> ViewModel:
    return RaceGameplayVM.new()


func create_result_vm() -> ViewModel:
    return RaceResultVM.new()
