extends Button

signal cell_pressed(cell_index: int)

var _cell_index := -1


func setup(cell_index: int, display_text: String, is_disabled: bool = false) -> void:
    _cell_index = cell_index
    text = display_text
    disabled = is_disabled


func _ready() -> void:
    pressed.connect(func() -> void: cell_pressed.emit(_cell_index))
