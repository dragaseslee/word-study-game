# Game Setting And Word Poison Separation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make `game_setting.tscn` the only setup entry and make `word_poison_game.tscn` start gameplay directly from externally supplied setup data.

**Architecture:** Restore setup behavior inside `scripts/game_setting.gd` against the refactored settings scene, then add an explicit startup-config handoff into `scripts/word_poison_game.gd`. Preserve the existing gameplay, turn, and scoreboard logic by only removing setup responsibilities from `WordPoison`.

**Tech Stack:** Godot 4.6, GDScript, scene-tree integration tests, `WordSetStore`

---

## File Map

- Modify: `scripts/game_setting.gd`
  Re-enable and adapt settings logic to the refactored `scenes/game_setting.tscn` tree.
- Modify: `scripts/word_poison_game.gd`
  Add explicit startup payload support and direct gameplay initialization.
- Modify: `scripts/tests/test_game_setting_scene.gd`
  Replace stale structure assertions with tests for the refactored settings screen and start handoff.
- Optional minimal modify: `scenes/game_setting.tscn`
  Only if unique-name bindings are missing for required interactive nodes.
- Optional minimal modify: `scenes/word_poison_game.tscn`
  Only if a direct-entry status surface is needed and cannot be handled in script.

### Task 1: Rebuild The GameSetting Controller Around The Refactored Scene

**Files:**
- Modify: `scripts/game_setting.gd`
- Test: `scripts/tests/test_game_setting_scene.gd`

- [ ] **Step 1: Write the failing test**

```gdscript
func _initialize() -> void:
	var packed_scene := load(SCENE_PATH) as PackedScene
	_assert(packed_scene != null, "Game setting scene should load")

	var root := packed_scene.instantiate()
	_assert(root != null, "Game setting scene should instantiate")
	get_root().add_child(root)
	await process_frame

	_assert(root.has_node("PanelCenter/PanelContentMargin/PanelContent/WordSetSection"), "Refactored word-set section missing")
	_assert(root.has_node("PanelCenter/PanelContentMargin/PanelContent/LayoutSection"), "Refactored layout section missing")
	_assert(root.has_node("PanelCenter/PanelContentMargin/PanelContent/PlayerSettingSection"), "Refactored player section missing")

	var controller := root as Control
	_assert(controller.get_script() != null, "Game setting controller script missing")

	var start_button := root.get_node("%StartButton") as BaseButton
	_assert(start_button != null, "StartButton missing")
	_assert(start_button.disabled, "Start should stay disabled before a valid word set is selected")

	root.free()
	quit(0)
```

- [ ] **Step 2: Run test to verify it fails**

Run: `godot --headless --path . -s res://scripts/tests/test_game_setting_scene.gd`
Expected: FAIL because the current test still asserts the old node tree and the current script does not restore setup behavior.

- [ ] **Step 3: Write minimal implementation**

```gdscript
extends Control

const MIN_PLAYERS := 1
const MAX_PLAYERS := 10

var _store := WordSetStore.new()
var _word_sets: Array[Dictionary] = []
var _selected_word_set: Dictionary = {}
var _board_size := 4
var _players: Array[Dictionary] = []

@onready var import_button: BaseButton = %ImportButton
@onready var file_dialog: FileDialog = %UploadFileDialog
@onready var back_button: BaseButton = %BackButton
@onready var start_button: BaseButton = %StartButton

func _ready() -> void:
	_players = [_make_player(0)]
	_setup_file_dialog()
	_setup_word_set_options()
	_update_start_state()

func _setup_file_dialog() -> void:
	file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	file_dialog.access = FileDialog.ACCESS_FILESYSTEM
	file_dialog.filters = PackedStringArray(["*.txt ; 文本词库", "*.csv ; CSV 词库", "*.tsv ; TSV 词库"])

func _setup_word_set_options() -> void:
	_word_sets = _store.list_word_sets()
	if _word_sets.is_empty():
		_selected_word_set = {}
	else:
		_selected_word_set = _word_sets[0]
	_update_start_state()

func _update_start_state() -> void:
	start_button.disabled = _selected_word_set.is_empty()

func _make_player(index: int) -> Dictionary:
	return {"id": index, "name": "玩家%d" % (index + 1)}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `godot --headless --path . -s res://scripts/tests/test_game_setting_scene.gd`
Expected: PASS for the new refactored-structure assertions and default disabled start state.

- [ ] **Step 5: Commit**

Workspace note: this workspace is not a git repo, so do not run a commit. Record the checkpoint by keeping the diff limited to `scripts/game_setting.gd` and `scripts/tests/test_game_setting_scene.gd`.

### Task 2: Restore Word-Set, Layout, And Player Setup Behavior In GameSetting

**Files:**
- Modify: `scripts/game_setting.gd`
- Test: `scripts/tests/test_game_setting_scene.gd`

- [ ] **Step 1: Write the failing test**

```gdscript
	var player_list := root.get_node("PanelCenter/PanelContentMargin/PanelContent/PlayerSettingSection")
	_assert(player_list != null, "Player section should exist")

	var controller_script = root
	controller_script._on_plus_pressed()
	_assert(controller_script._players.size() == 2, "Plus should append a player")
	controller_script._on_minus_pressed()
	_assert(controller_script._players.size() == 1, "Minus should remove the tail player")

	controller_script._on_layout_selected(3)
	_assert(controller_script._board_size == 3, "Layout selection should update board size")

	controller_script._setup_word_set_options()
	_assert(controller_script._word_sets is Array, "Word-set list should be populated or remain empty safely")
```

- [ ] **Step 2: Run test to verify it fails**

Run: `godot --headless --path . -s res://scripts/tests/test_game_setting_scene.gd`
Expected: FAIL because plus, minus, layout, and refreshed setup behavior are not wired to the refactored scene yet.

- [ ] **Step 3: Write minimal implementation**

```gdscript
@onready var word_set_dropdown: CustomDropdown = _find_word_set_dropdown()
@onready var plus_button: BaseButton = _find_plus_button()
@onready var minus_button: BaseButton = _find_minus_button()
@onready var player_list: Container = _find_player_list_container()
@onready var layout_buttons := {
	3: _find_layout_button("Layout33"),
	4: _find_layout_button("Layout44"),
	5: _find_layout_button("Layout55"),
}

func _ready() -> void:
	_players = [_make_player(0)]
	_setup_file_dialog()
	_connect_signals()
	_setup_word_set_options()
	_select_layout(_board_size)
	_render_players()
	_update_start_state()

func _connect_signals() -> void:
	if plus_button != null:
		plus_button.pressed.connect(_on_plus_pressed)
	if minus_button != null:
		minus_button.pressed.connect(_on_minus_pressed)
	if word_set_dropdown != null:
		word_set_dropdown.item_selected.connect(_on_word_set_selected)
	if import_button != null:
		import_button.pressed.connect(_on_import_pressed)
	if back_button != null:
		back_button.pressed.connect(_on_back_pressed)
	if start_button != null:
		start_button.pressed.connect(_on_start_pressed)
	file_dialog.file_selected.connect(_on_file_selected)
	for board_size in layout_buttons.keys():
		var button: BaseButton = layout_buttons[board_size]
		if button != null:
			button.pressed.connect(_on_layout_selected.bind(board_size))

func _on_word_set_selected(index: int, item: Dictionary) -> void:
	if index < 0 or index >= _word_sets.size():
		_selected_word_set = {}
	elif item.has("meta"):
		_selected_word_set = Dictionary(item.get("meta", {})).duplicate(true)
	else:
		_selected_word_set = _word_sets[index]
	_update_start_state()

func _on_layout_selected(board_size: int) -> void:
	_board_size = board_size
	_select_layout(board_size)

func _on_plus_pressed() -> void:
	if _players.size() >= MAX_PLAYERS:
		return
	_players.append(_make_player(_players.size()))
	_render_players()

func _on_minus_pressed() -> void:
	if _players.size() <= MIN_PLAYERS:
		return
	_players.remove_at(_players.size() - 1)
	_reindex_players()
	_render_players()
```

- [ ] **Step 4: Run test to verify it passes**

Run: `godot --headless --path . -s res://scripts/tests/test_game_setting_scene.gd`
Expected: PASS with player add-remove behavior, layout selection updates, and safe word-set refresh behavior.

- [ ] **Step 5: Commit**

Workspace note: this workspace is not a git repo, so do not run a commit. Keep the checkpoint limited to `scripts/game_setting.gd` and the updated test file.

### Task 3: Add Explicit Startup Payload Support To WordPoison

**Files:**
- Modify: `scripts/word_poison_game.gd`
- Test: `scripts/tests/test_game_setting_scene.gd`

- [ ] **Step 1: Write the failing test**

```gdscript
	var game_scene := load("res://scenes/word_poison_game.tscn") as PackedScene
	var game_root = game_scene.instantiate()
	game_root.set_startup_config({
		"word_set": selected_word_set,
		"board_size": 4,
		"players": [{"id": 0, "name": "玩家1"}],
	})
	get_root().add_child(game_root)
	await process_frame

	var gameplay_panel := game_root.get_node("%GameplayPanel") as Control
	var word_source_panel := game_root.get_node("%WordSourcePanel") as Control
	_assert(gameplay_panel.visible, "Gameplay should be shown immediately when startup config exists")
	_assert(not word_source_panel.visible, "Word source panel should be skipped on direct entry")
```

- [ ] **Step 2: Run test to verify it fails**

Run: `godot --headless --path . -s res://scripts/tests/test_game_setting_scene.gd`
Expected: FAIL because `word_poison_game.gd` does not yet expose a startup-config API or direct gameplay initialization path.

- [ ] **Step 3: Write minimal implementation**

```gdscript
var _startup_config: Dictionary = {}

func set_startup_config(config: Dictionary) -> void:
	_startup_config = config.duplicate(true)

func _ready() -> void:
	randomize()
	file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	file_dialog.access = FileDialog.ACCESS_FILESYSTEM
	file_dialog.filters = PackedStringArray(["*.txt ; 文本词库", "*.csv ; CSV 词库", "*.tsv ; TSV 词库"])
	_gameplay_only_connections()
	if not _startup_config.is_empty():
		_start_from_config()
		return
	_show_missing_config_state()

func _start_from_config() -> void:
	_selected_word_set = Dictionary(_startup_config.get("word_set", {})).duplicate(true)
	_board_size = int(_startup_config.get("board_size", 4))
	_all_words = _store.parse_word_file(String(_selected_word_set.get("file_path", "")))
	_players.clear()
	for player_seed in _startup_config.get("players", []):
		_players.append(_build_player_state(player_seed))
	_generate_board_cells()
	_start_player_turn(0)
	_show_panel(gameplay_panel)

func _show_missing_config_state() -> void:
	word_source_panel.visible = false
	player_setup_panel.visible = false
	gameplay_panel.visible = false
	scoreboard_panel.visible = false
```

- [ ] **Step 4: Run test to verify it passes**

Run: `godot --headless --path . -s res://scripts/tests/test_game_setting_scene.gd`
Expected: PASS with `WordPoison` entering gameplay directly when startup config is supplied.

- [ ] **Step 5: Commit**

Workspace note: this workspace is not a git repo, so do not run a commit. Keep the checkpoint limited to `scripts/word_poison_game.gd` and the test file.

### Task 4: Wire Start Navigation From GameSetting Into WordPoison

**Files:**
- Modify: `scripts/game_setting.gd`
- Modify: `scripts/word_poison_game.gd`
- Test: `scripts/tests/test_game_setting_scene.gd`

- [ ] **Step 1: Write the failing test**

```gdscript
	var controller = root
	controller._selected_word_set = selected_word_set
	controller._players = [{"id": 0, "name": "玩家1"}, {"id": 1, "name": ""}]
	controller._board_size = 5
	controller._on_start_pressed()
	await process_frame

	var current_scene := root.get_tree().current_scene
	_assert(current_scene != null, "Starting should replace the scene")
	_assert(current_scene.scene_file_path == "res://scenes/word_poison_game.tscn", "Starting should navigate to WordPoison")
```

- [ ] **Step 2: Run test to verify it fails**

Run: `godot --headless --path . -s res://scripts/tests/test_game_setting_scene.gd`
Expected: FAIL because start currently does not build a payload or navigate into gameplay.

- [ ] **Step 3: Write minimal implementation**

```gdscript
const WORD_POISON_SCENE := preload("res://scenes/word_poison_game.tscn")

func _on_start_pressed() -> void:
	if _selected_word_set.is_empty():
		_update_start_state()
		return
	var words := _store.parse_word_file(String(_selected_word_set.get("file_path", "")))
	if words.is_empty():
		_selected_word_set = {}
		_update_start_state()
		return
	var next_scene := WORD_POISON_SCENE.instantiate()
	next_scene.set_startup_config({
		"word_set": _selected_word_set.duplicate(true),
		"board_size": _board_size,
		"players": _normalized_players(),
	})
	get_tree().root.add_child(next_scene)
	get_tree().current_scene = next_scene
	queue_free()

func _normalized_players() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for index in range(_players.size()):
		var name := String(_players[index].get("name", "")).strip_edges()
		if name.is_empty():
			name = _default_player_name(index)
		result.append({"id": index, "name": name})
	return result
```

- [ ] **Step 4: Run test to verify it passes**

Run: `godot --headless --path . -s res://scripts/tests/test_game_setting_scene.gd`
Expected: PASS with `GameSetting` transitioning into `WordPoison` and supplying normalized setup data.

- [ ] **Step 5: Commit**

Workspace note: this workspace is not a git repo, so do not run a commit. Keep the checkpoint limited to `scripts/game_setting.gd`, `scripts/word_poison_game.gd`, and the test file.

### Task 5: Remove Internal Setup Responsibilities From WordPoison Runtime Flow

**Files:**
- Modify: `scripts/word_poison_game.gd`
- Test: `scripts/tests/test_game_setting_scene.gd`

- [ ] **Step 1: Write the failing test**

```gdscript
	var replay_button := current_scene.get_node("%ReplayButton") as Button
	replay_button.pressed.emit()
	await process_frame

	var replay_scene := current_scene.get_tree().current_scene
	_assert(replay_scene.scene_file_path == "res://scenes/game_setting.tscn", "Replay should return to GameSetting")
```

- [ ] **Step 2: Run test to verify it fails**

Run: `godot --headless --path . -s res://scripts/tests/test_game_setting_scene.gd`
Expected: FAIL because replay currently resets internal setup flow instead of returning to `GameSetting`.

- [ ] **Step 3: Write minimal implementation**

```gdscript
func _on_replay_requested() -> void:
	get_tree().change_scene_to_file("res://scenes/game_setting.tscn")

func _show_missing_config_state() -> void:
	word_source_panel.visible = false
	player_setup_panel.visible = false
	gameplay_panel.visible = false
	scoreboard_panel.visible = true
	scoreboard_panel.show_results([])
```

- [ ] **Step 4: Run test to verify it passes**

Run: `godot --headless --path . -s res://scripts/tests/test_game_setting_scene.gd`
Expected: PASS with replay returning to `GameSetting` and normal runtime no longer depending on the internal setup panels.

- [ ] **Step 5: Commit**

Workspace note: this workspace is not a git repo, so do not run a commit. Keep the checkpoint limited to `scripts/word_poison_game.gd` and the test file.

### Task 6: Full Verification

**Files:**
- Verify: `scripts/game_setting.gd`
- Verify: `scripts/word_poison_game.gd`
- Verify: `scripts/tests/test_game_setting_scene.gd`

- [ ] **Step 1: Run the focused integration test**

Run: `godot --headless --path . -s res://scripts/tests/test_game_setting_scene.gd`
Expected: PASS with exit code `0`.

- [ ] **Step 2: Re-read the spec and verify each requirement maps to code**

Checklist:

```text
[ ] GameSetting owns word-set selection
[ ] GameSetting owns layout selection
[ ] GameSetting owns player editing
[ ] GameSetting owns import and start validation
[ ] WordPoison accepts explicit startup payload
[ ] WordPoison enters gameplay directly
[ ] Replay returns to GameSetting
```

- [ ] **Step 3: Record final state**

Report the verification evidence and list the exact modified files.
