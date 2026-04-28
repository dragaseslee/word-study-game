# Word Poison Game Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a game hub scene and implement a playable word-poison mini-game with local word-set upload, player setup, turn-based board play, and final ranking.

**Architecture:** Use one root hub scene plus one container scene for the mini-game. Keep runtime game state in the container script, split reusable panel logic into focused scripts, and use Godot UI nodes with signals to drive phase changes without switching root scenes inside the mini-game.

**Tech Stack:** Godot 4.6, GDScript, Control-based UI scenes, FileAccess and DirAccess APIs, native Godot dialogs and tweens

---

## File Structure

- Create: `scenes/game_hub.tscn`
- Create: `scripts/game_hub.gd`
- Create: `scenes/word_poison_game.tscn`
- Create: `scripts/word_poison_game.gd`
- Create: `scripts/word_set_store.gd`
- Create: `scripts/word_source_panel.gd`
- Create: `scripts/player_setup_panel.gd`
- Create: `scripts/gameplay_panel.gd`
- Create: `scripts/scoreboard_panel.gd`
- Modify: `project.godot`

### Task 1: Create the game hub entry scene

**Files:**
- Create: `scenes/game_hub.tscn`
- Create: `scripts/game_hub.gd`
- Modify: `project.godot`

- [ ] **Step 1: Create the hub scene**

```gdscript
extends Control

@onready var start_button: Button = %StartWordPoisonButton

func _ready() -> void:
	start_button.pressed.connect(_on_start_pressed)

func _on_start_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/word_poison_game.tscn")
```

- [ ] **Step 2: Set the hub as the main scene**

Update the application config so the project boots into `res://scenes/game_hub.tscn`.

- [ ] **Step 3: Run the project and verify scene boot**

Run: `godot4 --headless --path . --quit`
Expected: exits without scene parse errors

### Task 2: Add persisted word-set storage and parsing

**Files:**
- Create: `scripts/word_set_store.gd`

- [ ] **Step 1: Write the parsing and listing API**

```gdscript
class_name WordSetStore
extends RefCounted

const WORD_SET_DIR := "user://word_sets"

func ensure_storage_dir() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(WORD_SET_DIR))

func list_word_sets() -> Array[Dictionary]:
	return []

func parse_word_file(file_path: String) -> Array[Dictionary]:
	return []
```

- [ ] **Step 2: Implement line parsing for tab and comma separators**

```gdscript
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
	return {"english": english, "chinese": chinese}
```

- [ ] **Step 3: Implement upload copy with auto-rename**

```gdscript
func import_word_set(source_path: String) -> Dictionary:
	ensure_storage_dir()
	# copy file into user://word_sets with a unique destination name
	return {}
```

- [ ] **Step 4: Run the project and verify no syntax errors**

Run: `godot4 --headless --path . --quit`
Expected: exits without script parse errors

### Task 3: Build the word source panel

**Files:**
- Create: `scripts/word_source_panel.gd`
- Modify: `scenes/word_poison_game.tscn`

- [ ] **Step 1: Add the panel UI nodes into the game scene**

```gdscript
signal continue_requested(selected_file: Dictionary)
signal upload_requested

func set_word_sets(word_sets: Array[Dictionary], selected_path: String) -> void:
	pass
```

- [ ] **Step 2: Render the file list and current selection**

```gdscript
func set_word_sets(word_sets: Array[Dictionary], selected_path: String) -> void:
	for child in list_container.get_children():
		child.queue_free()
	for item in word_sets:
		var button := Button.new()
		button.text = "%s (%d)" % [item.file_name, item.word_count]
		button.toggle_mode = true
		button.button_pressed = item.file_path == selected_path
		button.pressed.connect(_on_word_set_pressed.bind(item))
		list_container.add_child(button)
```

- [ ] **Step 3: Wire upload and continue buttons**

```gdscript
func _on_continue_pressed() -> void:
	if _selected_file.is_empty():
		show_error("请选择一个有效词库")
		return
	continue_requested.emit(_selected_file)
```

- [ ] **Step 4: Run the project and verify panel loads**

Run: `godot4 --headless --path . --quit`
Expected: exits without missing-node errors in `_ready`

### Task 4: Build the player setup panel

**Files:**
- Create: `scripts/player_setup_panel.gd`
- Modify: `scenes/word_poison_game.tscn`

- [ ] **Step 1: Add player list UI and board size controls**

```gdscript
signal start_requested(players: Array[Dictionary], board_size: int)

func set_players(players: Array[Dictionary], board_size: int) -> void:
	pass
```

- [ ] **Step 2: Implement add, remove, and edit logic with defaults**

```gdscript
func _default_player_name(index: int) -> String:
	return "玩家%d" % (index + 1)
```

- [ ] **Step 3: Emit validated player config**

```gdscript
func _on_start_pressed() -> void:
	var payload: Array[Dictionary] = []
	for i in _players.size():
		var name := _players[i].name.strip_edges()
		if name.is_empty():
			name = _default_player_name(i)
		payload.append({"id": i, "name": name})
	start_requested.emit(payload, _selected_board_size)
```

- [ ] **Step 4: Run the project and verify controls initialize**

Run: `godot4 --headless --path . --quit`
Expected: exits without panel script errors

### Task 5: Build the gameplay panel and cell rendering

**Files:**
- Create: `scripts/gameplay_panel.gd`
- Modify: `scenes/word_poison_game.tscn`

- [ ] **Step 1: Add gameplay panel API for board and sidebar refresh**

```gdscript
signal cell_pressed(cell_index: int)
signal next_player_requested

func update_view(view_model: Dictionary) -> void:
	pass
```

- [ ] **Step 2: Render the board grid from view data**

```gdscript
func _render_board(cells: Array[Dictionary]) -> void:
	for child in board_grid.get_children():
		child.queue_free()
	for cell in cells:
		var button := Button.new()
		button.text = cell.display_text
		button.disabled = cell.disabled
		button.custom_minimum_size = Vector2(140, 72)
		button.pressed.connect(_on_cell_pressed.bind(cell.cell_index))
		board_grid.add_child(button)
```

- [ ] **Step 3: Render the player sidebar and next-player prompt**

```gdscript
func _render_players(players: Array[Dictionary], current_player_id: int) -> void:
	for child in player_list.get_children():
		child.queue_free()
	for player in players:
		var label := Label.new()
		label.text = "%s: %d" % [player.name, player.safe_click_count]
		if player.id == current_player_id:
			label.add_theme_color_override("font_color", Color.GOLD)
		player_list.add_child(label)
```

- [ ] **Step 4: Run the project and verify gameplay panel parses**

Run: `godot4 --headless --path . --quit`
Expected: exits without script or scene parse errors

### Task 6: Build the scoreboard panel

**Files:**
- Create: `scripts/scoreboard_panel.gd`
- Modify: `scenes/word_poison_game.tscn`

- [ ] **Step 1: Add scoreboard panel API**

```gdscript
signal replay_requested
signal back_to_hub_requested

func show_results(results: Array[Dictionary]) -> void:
	pass
```

- [ ] **Step 2: Render ranked rows with top-three styles**

```gdscript
func _style_rank_row(panel: PanelContainer, rank: int) -> void:
	if rank == 1:
		panel.modulate = Color("ffd700")
	elif rank == 2:
		panel.modulate = Color("c0c0c0")
	elif rank == 3:
		panel.modulate = Color("cd7f32")
```

- [ ] **Step 3: Add a simple tween emphasis for the first three rows**

```gdscript
func _animate_rank_row(panel: Control) -> void:
	var tween := create_tween()
	tween.tween_property(panel, "scale", Vector2.ONE * 1.03, 0.2)
	tween.tween_property(panel, "scale", Vector2.ONE, 0.2)
```

- [ ] **Step 4: Run the project and verify scoreboard scene parses**

Run: `godot4 --headless --path . --quit`
Expected: exits without script errors

### Task 7: Implement the word-poison game controller

**Files:**
- Create: `scripts/word_poison_game.gd`
- Modify: `scenes/word_poison_game.tscn`

- [ ] **Step 1: Define the controller state and panel references**

```gdscript
extends Control

const BOARD_DIMENSIONS := {3: 9, 4: 16, 5: 25}

var _store := WordSetStore.new()
var _word_sets: Array[Dictionary] = []
var _selected_word_set: Dictionary = {}
var _all_words: Array[Dictionary] = []
var _board_size := 4
var _board_cells: Array[Dictionary] = []
var _players: Array[Dictionary] = []
var _current_player_index := 0
var _finish_counter := 0
```

- [ ] **Step 2: Implement word-set loading and upload refresh**

```gdscript
func _refresh_word_sets() -> void:
	_word_sets = _store.list_word_sets()
	word_source_panel.set_word_sets(_word_sets, _selected_word_set.get("file_path", ""))
```

- [ ] **Step 3: Implement player setup and board generation**

```gdscript
func _generate_board_cells() -> void:
	var cell_count := BOARD_DIMENSIONS[_board_size]
	_board_cells.clear()
	for i in cell_count:
		var entry := _all_words[randi() % _all_words.size()]
		_board_cells.append({
			"cell_index": i,
			"english": entry.english,
			"chinese": entry.chinese,
		})
```

- [ ] **Step 4: Implement turn start, click resolution, and ranking**

```gdscript
func _start_player_turn(player_index: int) -> void:
	_current_player_index = player_index
	_players[player_index].clicked_indices = []
	_players[player_index].poison_word_index = randi() % _board_cells.size()
	_update_gameplay_panel()

func _on_cell_pressed(cell_index: int) -> void:
	var player := _players[_current_player_index]
	if player.clicked_indices.has(cell_index):
		return
	player.clicked_indices.append(cell_index)
	if cell_index == player.poison_word_index:
		player.is_eliminated = true
		player.finish_order = _finish_counter
		_finish_counter += 1
		_update_gameplay_panel(true)
		return
	player.safe_click_count += 1
	_update_gameplay_panel()
```

- [ ] **Step 5: Implement scoreboard transition and navigation buttons**

```gdscript
func _show_scoreboard() -> void:
	var results := _players.duplicate(true)
	results.sort_custom(func(a, b):
		if a.safe_click_count == b.safe_click_count:
			return a.finish_order < b.finish_order
		return a.safe_click_count > b.safe_click_count
	)
	scoreboard_panel.show_results(results)
```

- [ ] **Step 6: Run the project and verify the full flow parses**

Run: `godot4 --headless --path . --quit`
Expected: exits without missing class or signal errors

### Task 8: Connect the file dialog and replay flow

**Files:**
- Modify: `scenes/word_poison_game.tscn`
- Modify: `scripts/word_poison_game.gd`

- [ ] **Step 1: Add a `FileDialog` to the game scene**

```gdscript
func _on_upload_requested() -> void:
	file_dialog.popup_centered_ratio(0.7)
```

- [ ] **Step 2: Handle file selection and import**

```gdscript
func _on_file_selected(path: String) -> void:
	var result := _store.import_word_set(path)
	if not result.get("ok", false):
		word_source_panel.show_error(result.get("message", "上传失败"))
		return
	_refresh_word_sets()
```

- [ ] **Step 3: Reset controller state for replay**

```gdscript
func _reset_match_state() -> void:
	_all_words.clear()
	_board_cells.clear()
	_players.clear()
	_current_player_index = 0
	_finish_counter = 0
	_show_panel(word_source_panel)
```

- [ ] **Step 4: Run the project and verify upload and replay hooks parse**

Run: `godot4 --headless --path . --quit`
Expected: exits without runtime parse errors

### Task 9: Final verification pass

**Files:**
- Modify: any of the above as needed

- [ ] **Step 1: Launch headless parse check**

Run: `godot4 --headless --path . --quit`
Expected: exit code 0

- [ ] **Step 2: Launch scene import pass**

Run: `godot4 --headless --path . --editor --quit`
Expected: no resource load failures for the new scenes and scripts

- [ ] **Step 3: Fix any remaining parse or scene issues**

```gdscript
# Apply minimal scene/script fixes surfaced by the verification commands.
```
