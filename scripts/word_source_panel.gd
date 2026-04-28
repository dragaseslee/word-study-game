extends VBoxContainer

signal continue_requested(selected_file: Dictionary)
signal upload_requested
signal refresh_requested

var _selected_file: Dictionary = {}

@onready var refresh_button: Button = %RefreshButton
@onready var upload_button: Button = %UploadButton
@onready var selected_label: Label = %SelectedWordSetLabel
@onready var list_container: VBoxContainer = %WordSetList
@onready var empty_label: Label = %EmptyStateLabel
@onready var error_label: Label = %WordSourceErrorLabel
@onready var continue_button: Button = %ContinueButton


func _ready() -> void:
	refresh_button.pressed.connect(func() -> void: refresh_requested.emit())
	upload_button.pressed.connect(func() -> void: upload_requested.emit())
	continue_button.pressed.connect(_on_continue_pressed)
	_update_selected_label()
	show_error("")


func set_word_sets(word_sets: Array[Dictionary], selected_path: String) -> void:
	_selected_file = {}
	for child in list_container.get_children():
		child.queue_free()

	for item in word_sets:
		var button := Button.new()
		button.text = "%s (%d 词)" % [item.get("file_name", ""), item.get("word_count", 0)]
		button.toggle_mode = true
		button.set_meta("file_path", item.get("file_path", ""))
		button.button_pressed = item.get("file_path", "") == selected_path
		button.pressed.connect(_on_word_set_pressed.bind(item))
		list_container.add_child(button)
		if button.button_pressed:
			_selected_file = item

	empty_label.visible = word_sets.is_empty()
	continue_button.disabled = _selected_file.is_empty()
	_update_selected_label()


func show_error(message: String) -> void:
	error_label.text = message
	error_label.visible = not message.is_empty()


func _on_word_set_pressed(item: Dictionary) -> void:
	_selected_file = item
	for child in list_container.get_children():
		if child is Button:
			child.button_pressed = String(child.get_meta("file_path", "")) == String(item.get("file_path", ""))
	show_error("")
	continue_button.disabled = false
	_update_selected_label()


func _on_continue_pressed() -> void:
	if _selected_file.is_empty():
		show_error("请选择一个有效词库")
		return
	continue_requested.emit(_selected_file)


func _update_selected_label() -> void:
	if _selected_file.is_empty():
		selected_label.text = "当前未选择词库"
	else:
		selected_label.text = "当前词库: %s" % _selected_file.get("file_name", "")
