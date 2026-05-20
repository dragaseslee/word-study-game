extends HBoxContainer

signal name_changed(new_name: String)
signal remove_requested

@onready var name_edit: LineEdit = $NameEdit
@onready var remove_button: Button = $RemoveButton


func setup(index: int, player_name: String, can_remove: bool) -> void:
    name_edit.placeholder_text = "玩家%d" % (index + 1)
    name_edit.text = player_name
    remove_button.disabled = not can_remove


func _ready() -> void:
    name_edit.text_changed.connect(func(t: String) -> void: name_changed.emit(t))
    remove_button.pressed.connect(func() -> void: remove_requested.emit())
