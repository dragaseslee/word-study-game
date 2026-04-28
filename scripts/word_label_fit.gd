extends Label

func _ready() -> void:
	await get_tree().process_frame
	fit_text()
	
func fit_text()-> void:
	var font = get_theme_font("font")
	var font_size = get_theme_font_size("font_size")
	var max_width = size.x
	while font_size > 5:
		var text_size = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
		if text_size.x <= max_width:
			break
		font_size -= 1
	add_theme_font_size_override("font_size", font_size)
