extends VBoxContainer

signal replay_requested
signal back_to_hub_requested

@onready var results_list: VBoxContainer = %ResultsList
@onready var replay_button: Button = %ReplayButton
@onready var back_button: Button = %BackToHubButton


func _ready() -> void:
	replay_button.pressed.connect(func() -> void: replay_requested.emit())
	back_button.pressed.connect(func() -> void: back_to_hub_requested.emit())


func show_results(results: Array[Dictionary]) -> void:
	for child in results_list.get_children():
		child.queue_free()

	for index in range(results.size()):
		var rank := index + 1
		var player := results[index]
		var row := PanelContainer.new()
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL

		var row_box := HBoxContainer.new()
		row_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL

		var rank_label := Label.new()
		var name_label := Label.new()
		var score_label := Label.new()
		var status_label := Label.new()

		rank_label.custom_minimum_size = Vector2(48, 0)
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL

		rank_label.text = "#%d" % rank
		name_label.text = String(player.get("name", ""))
		score_label.text = "点击 %d" % int(player.get("safe_click_count", 0))
		status_label.text = "中毒结束"

		row_box.add_child(rank_label)
		row_box.add_child(name_label)
		row_box.add_child(score_label)
		row_box.add_child(status_label)
		row.add_child(row_box)

		_style_rank_row(row, rank)
		results_list.add_child(row)
		if rank <= 3:
			_animate_rank_row(row)


func _style_rank_row(panel: PanelContainer, rank: int) -> void:
	if rank == 1:
		panel.modulate = Color("ffd700")
	elif rank == 2:
		panel.modulate = Color("d9d9d9")
	elif rank == 3:
		panel.modulate = Color("cd7f32")


func _animate_rank_row(panel: Control) -> void:
	panel.scale = Vector2.ONE
	var tween := create_tween()
	tween.tween_property(panel, "scale", Vector2.ONE * 1.03, 0.18)
	tween.tween_property(panel, "scale", Vector2.ONE, 0.18)
