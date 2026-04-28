class_name CustomDropdown
extends Control

signal item_selected(index: int, item: Dictionary)

@export var use_preview_items := true
@export var max_popup_height := 320.0
@export var visible_rows := 3

var _items: Array[Dictionary] = []
var _selected_index := -1


@onready var closed_button: TextureButton = $MarginContainer/ClosedButton
@onready var selected_title_label: Label = $ClosedMargin/SelectedTextBlock/WordSetDropdownSelectedTitle
@onready var selected_subtitle_label: Label = $ClosedMargin/SelectedTextBlock/WordSetDropdownSelectedSubtitle

@onready var closed_shell: MarginContainer = $MarginContainer
@onready var popup_panel: MarginContainer = $PopupPanel
@onready var popup_margin: MarginContainer = $PopupPanel/Panel/PopupMargin
@onready var item_list: VBoxContainer = $PopupPanel/Panel/PopupMargin/PopupScroll/ItemList
@onready var popup_scroll: ScrollContainer = $PopupPanel/Panel/PopupMargin/PopupScroll

const ITEM_SCENE := preload("res://scenes/components/custom_dropdown_item.tscn")


func _ready() -> void:
	closed_button.pressed.connect(_toggle_popup)
	_set_popup_open(false)
	if use_preview_items and _items.is_empty():
		set_items([
			{
				"id": "preview_basic",
				"title": "basic_words.txt",
				"subtitle": "120 词",
				"disabled": false,
			},
			{
				"id": "preview_animals",
				"title": "animals.txt",
				"subtitle": "80 词",
				"disabled": false,
			},
			{
				"id": "preview_phrases",
				"title": "phrases.txt",
				"subtitle": "45 词",
				"disabled": false,
			},
		])


func set_items(items: Array[Dictionary]) -> void:
	_items = items.duplicate(true)
	if _items.is_empty():
		_selected_index = -1
	else:
		_selected_index = clampi(_selected_index, 0, _items.size() - 1)
		if _selected_index < 0:
			_selected_index = 0
	_render_selected_state()
	_render_items()


func select_index(index: int) -> void:
	if index < 0 or index >= _items.size():
		_selected_index = -1
	else:
		_selected_index = index
	_render_selected_state()
	_render_items()


func get_selected_index() -> int:
	return _selected_index


func get_selected_item() -> Dictionary:
	if _selected_index < 0 or _selected_index >= _items.size():
		return {}
	return _items[_selected_index]


func _toggle_popup() -> void:
	_set_popup_open(not popup_panel.visible and not _items.is_empty())


func _render_selected_state() -> void:
	if _selected_index < 0 or _selected_index >= _items.size():
		selected_title_label.text = "暂无可用词表"
		selected_subtitle_label.text = "请先导入或刷新列表"
		closed_button.disabled = true
		_set_popup_open(false)
		return

	var item := _items[_selected_index]
	selected_title_label.text = String(item.get("title", ""))
	selected_subtitle_label.text = String(item.get("subtitle", ""))
	closed_button.disabled = bool(item.get("disabled", false))


func _render_items() -> void:
	for child in item_list.get_children():
		child.queue_free()

	for index in range(_items.size()):
		var item := _items[index]
		var row := ITEM_SCENE.instantiate()
		item_list.add_child(row)
		row.setup(
			index,
			String(item.get("title", "")),
			String(item.get("subtitle", "")),
			bool(item.get("disabled", false))
		)
		row.item_pressed.connect(_on_item_pressed)
	call_deferred("_update_popup_height")


func _get_minimum_size() -> Vector2:
	if not is_node_ready() or closed_shell == null:
		return Vector2(500, 200)
	return closed_shell.get_combined_minimum_size()


func _update_popup_height() -> void:
	var popup_chrome_height := float(
		popup_margin.get_theme_constant("margin_top")
		+ popup_margin.get_theme_constant("margin_bottom")
	)
	var max_content_height := maxf(0.0, max_popup_height - popup_chrome_height)
	var visible_content_height := minf(max_content_height, _get_visible_rows_height())
	var popup_height := visible_content_height + popup_chrome_height
	var closed_rect := closed_shell.get_global_rect()
	popup_panel.global_position = Vector2(closed_rect.position.x, closed_rect.end.y + 8.0)
	popup_panel.size = Vector2(closed_rect.size.x, popup_height)
	popup_panel.custom_minimum_size = Vector2(0, popup_height)
	popup_scroll.custom_minimum_size = Vector2(0, visible_content_height)
	popup_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO


func _get_visible_rows_height() -> float:
	if item_list.get_child_count() == 0:
		return 0.0
	var first_row := item_list.get_child(0) as Control
	if first_row == null:
		return 0.0
	var row_height: float = first_row.get_combined_minimum_size().y
	var row_count: int = maxi(1, visible_rows)
	var separation: int = item_list.get_theme_constant("separation")
	var gap_count: int = maxi(0, row_count - 1)
	return row_height * row_count + float(separation * gap_count)


func _on_item_pressed(index: int) -> void:
	if index < 0 or index >= _items.size():
		return
	if bool(_items[index].get("disabled", false)):
		return
	_selected_index = index
	_set_popup_open(false)
	_render_selected_state()
	_render_items()
	item_selected.emit(index, _items[index])


func _unhandled_input(event: InputEvent) -> void:
	if not popup_panel.visible:
		return
	if event is InputEventMouseButton and event.pressed:
		var mouse_position := get_global_mouse_position()
		var closed_rect := closed_button.get_global_rect()
		var popup_rect := popup_panel.get_global_rect()
		if not closed_rect.has_point(mouse_position) and not popup_rect.has_point(mouse_position):
			_set_popup_open(false)


func _set_popup_open(is_open: bool) -> void:
	popup_panel.visible = is_open
	if is_open:
		call_deferred("_update_popup_height")
	if closed_button != null:
		closed_button.set_pressed_no_signal(is_open)
