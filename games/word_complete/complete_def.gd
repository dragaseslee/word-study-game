extends GameDef


func _init() -> void:
    game_id = "word_complete"
    display_name = "补全单词"
    display_order = 4
    icon_path = "res://asserts/buttons/button_word_complete.png"
    setting_scene = "res://games/word_complete/views/setting_view.tscn"
    gameplay_scene = "res://games/word_complete/views/gameplay_view.tscn"
    result_scene = "res://games/word_complete/views/result_view.tscn"
    bgm_stream = null


func create_setting_vm() -> ViewModel:
    return CompleteSettingVM.new()


func create_gameplay_vm() -> ViewModel:
    return CompleteGameplayVM.new()


func create_result_vm() -> ViewModel:
    return CompleteResultVM.new()
