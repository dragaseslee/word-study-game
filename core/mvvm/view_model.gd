class_name ViewModel
extends RefCounted

signal view_updated(view_data: Dictionary)

var _is_initialized := false


func initialize(config: Dictionary = {}) -> void:
	if _is_initialized:
		return
	_is_initialized = true
	_on_initialize(config)
	notify_view()


func notify_view() -> void:
	view_updated.emit(build_view_data())


func build_view_data() -> Dictionary:
	push_error("ViewModel subclass must override build_view_data()")
	return {}


func _on_initialize(_config: Dictionary) -> void:
	pass
