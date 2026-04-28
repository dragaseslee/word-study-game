class_name WordSetStore
extends RefCounted

const WORD_SET_DIR := "user://word_sets"


func ensure_storage_dir() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(WORD_SET_DIR))


func list_word_sets() -> Array[Dictionary]:
	ensure_storage_dir()
	var summaries: Array[Dictionary] = []
	var absolute_dir := ProjectSettings.globalize_path(WORD_SET_DIR)
	var dir := DirAccess.open(absolute_dir)
	if dir == null:
		return summaries

	dir.list_dir_begin()
	var file_name := dir.get_next()
	while not file_name.is_empty():
		if dir.current_is_dir():
			file_name = dir.get_next()
			continue
		var file_path := WORD_SET_DIR.path_join(file_name)
		var words := parse_word_file(file_path)
		if words.is_empty():
			file_name = dir.get_next()
			continue
		summaries.append({
			"file_name": file_name,
			"file_path": file_path,
			"word_count": words.size(),
		})
		file_name = dir.get_next()
	dir.list_dir_end()

	summaries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return String(a.get("file_name", "")).nocasecmp_to(String(b.get("file_name", ""))) < 0
	)
	return summaries


func parse_word_file(file_path: String) -> Array[Dictionary]:
	var words: Array[Dictionary] = []
	var file := FileAccess.open(file_path, FileAccess.READ)
	if file == null:
		return words

	var content := file.get_as_text()
	for line in content.split("\n"):
		var parsed := _parse_line(line)
		if parsed.is_empty():
			continue
		words.append(parsed)
	return words


func import_word_set(source_path: String) -> Dictionary:
	ensure_storage_dir()
	var source_file := FileAccess.open(source_path, FileAccess.READ)
	if source_file == null:
		return {"ok": false, "message": "无法读取上传文件"}

	var content := source_file.get_as_text()
	var parsed_words := _parse_content(content)
	if parsed_words.is_empty():
		return {"ok": false, "message": "词库为空或格式不正确"}

	var target_name := _build_unique_file_name(source_path.get_file())
	var target_path := WORD_SET_DIR.path_join(target_name)
	var target_file := FileAccess.open(target_path, FileAccess.WRITE)
	if target_file == null:
		return {"ok": false, "message": "无法写入本地词库目录"}

	target_file.store_string(content)
	return {
		"ok": true,
		"message": "上传成功",
		"file_name": target_name,
		"file_path": target_path,
		"word_count": parsed_words.size(),
	}


func _parse_content(content: String) -> Array[Dictionary]:
	var words: Array[Dictionary] = []
	for line in content.split("\n"):
		var parsed := _parse_line(line)
		if parsed.is_empty():
			continue
		words.append(parsed)
	return words


func _parse_line(line: String) -> Dictionary:
	var trimmed := line.strip_edges()
	if trimmed.is_empty():
		return {}

	var parts: PackedStringArray = []
	if trimmed.contains("\t"):
		parts = trimmed.split("\t", false, 1)
	elif trimmed.contains(","):
		parts = trimmed.split(",", false, 1)

	if parts.size() != 2:
		return {}

	var english := parts[0].strip_edges()
	var chinese := parts[1].strip_edges()
	if english.is_empty() or chinese.is_empty():
		return {}

	return {
		"english": english,
		"chinese": chinese,
	}


func _build_unique_file_name(original_name: String) -> String:
	var base_name := original_name.get_basename()
	var extension := original_name.get_extension()
	var candidate := original_name
	var suffix := 1

	while FileAccess.file_exists(WORD_SET_DIR.path_join(candidate)):
		if extension.is_empty():
			candidate = "%s_%d" % [base_name, suffix]
		else:
			candidate = "%s_%d.%s" % [base_name, suffix, extension]
		suffix += 1

	return candidate
