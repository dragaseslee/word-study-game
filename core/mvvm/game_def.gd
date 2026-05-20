class_name GameDef
extends RefCounted

var game_id: String = ""
var display_name: String = ""
var display_order: int = 0
var icon_path: String = ""
var setting_scene: String = ""
var gameplay_scene: String = ""
var result_scene: String = ""
var bgm_stream: AudioStream = null


func create_setting_vm() -> ViewModel:
	push_error("Override create_setting_vm()")
	return null


func create_gameplay_vm() -> ViewModel:
	push_error("Override create_gameplay_vm()")
	return null


func create_result_vm() -> ViewModel:
	push_error("Override create_result_vm()")
	return null
