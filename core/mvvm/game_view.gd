class_name GameView
extends Control

var _view_model: ViewModel


func bind(view_model: ViewModel) -> void:
	if _view_model != null:
		_view_model.view_updated.disconnect(_on_view_updated)
	_view_model = view_model
	_view_model.view_updated.connect(_on_view_updated)


func _on_view_updated(view_data: Dictionary) -> void:
	render(view_data)


func render(_view_data: Dictionary) -> void:
	push_error("GameView subclass must override render()")


func _exit_tree() -> void:
	if _view_model != null and _view_model.view_updated.is_connected(_on_view_updated):
		_view_model.view_updated.disconnect(_on_view_updated)
