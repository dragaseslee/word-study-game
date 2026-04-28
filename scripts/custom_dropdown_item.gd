extends Button

signal item_pressed(index: int)

var _item_index := -1

@onready var title_label: Label = get_node_or_null("TextBlock/TitleLabel") as Label
@onready var subtitle_label: Label = get_node_or_null("TextBlock/SubtitleLabel") as Label


func _ready() -> void:
	_ensure_references()
	pressed.connect(func() -> void: item_pressed.emit(_item_index))


func setup(index: int, title: String, subtitle: String, disabled: bool) -> void:
	_ensure_references()
	_item_index = index
	if title_label == null or subtitle_label == null:
		push_error("CustomDropdownItem labels are missing from scene")
		return
	title_label.text = title
	subtitle_label.text = subtitle
	self.disabled = disabled


func _ensure_references() -> void:
	if title_label == null:
		title_label = get_node_or_null("TextBlock/TitleLabel") as Label
	if subtitle_label == null:
		subtitle_label = get_node_or_null("TextBlock/SubtitleLabel") as Label
