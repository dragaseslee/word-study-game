extends GameDef


func _init() -> void:
	game_id = "word_poison"
	display_name = "女巫的药水"
	display_order = 1
	icon_path = "res://asserts/buttons/button_witch's_potion.png"
	setting_scene = "res://games/word_poison/views/setting_view.tscn"
	gameplay_scene = "res://games/word_poison/views/gameplay_view.tscn"
	result_scene = "res://games/word_poison/views/result_view.tscn"
	bgm_stream = preload("res://asserts/sounds/music.mp3")


func create_setting_vm() -> ViewModel:
	return PoisonSettingVM.new()


func create_gameplay_vm() -> ViewModel:
	return PoisonGameplayVM.new()


func create_result_vm() -> ViewModel:
	return PoisonResultVM.new()
