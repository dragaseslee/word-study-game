# Word Poison Refactored Runtime Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the refactored `word_poison_game.tscn` work as the pure gameplay scene, render board cells with `word_panel.tscn`, and transition to a new result scene when the match ends.

**Architecture:** Keep setup in `GameSetting`, refactor `word_poison_game.gd` into a pure runtime controller bound to the new gameplay-only node tree, and push post-match UI into a new dedicated result scene. Update `gameplay_panel.gd` to become a thin renderer for the new labels, buttons, and board-card component.

**Tech Stack:** Godot 4.6, GDScript, PackedScene-based UI composition, headless scene tests

---

## File Map

- Modify: `scripts/word_poison_game.gd`
  Remove references to deleted setup nodes, bind runtime state to the new gameplay scene, and transition to results.
- Modify: `scripts/gameplay_panel.gd`
  Bind to renamed nodes and render board cells using `word_panel.tscn`.
- Create: `scenes/word_poison_result.tscn`
  Minimal result scene for replay and back navigation.
- Create: `scripts/word_poison_result.gd`
  Result-scene controller for rows and navigation signals.
- Modify: `scripts/tests/test_game_setting_scene.gd`
  Update integration expectations to the new `WordPoisonGame` node tree.
- Create: `scripts/tests/test_word_poison_runtime_scene.gd`
  Focused runtime test for `word_panel.tscn` board rendering and result-scene transition.

### Task 1: Update Runtime Tests For The Refactored WordPoison Scene

**Files:**
- Modify: `scripts/tests/test_game_setting_scene.gd`
- Create: `scripts/tests/test_word_poison_runtime_scene.gd`

- [ ] **Step 1: Write the failing test**

```gdscript
	var gameplay_panel := current_scene.get_node("%GameplayPanel") as Control
	_assert(gameplay_panel.visible, "WordPoison should show gameplay immediately when started from GameSetting")
	_assert(current_scene.has_node("GameplayPanel/GamePanel/BoardArea/CurrentPlayerName"), "Refactored current-player label missing")
	_assert(current_scene.has_node("GameplayPanel/GamePanel/BoardArea/MarginContainer/CurrentGameInfo"), "Refactored status label missing")
	_assert(current_scene.has_node("GameplayPanel/SidebarPanel/VBoxContainer/ActionButton/HBoxContainer/EndGameButton"), "EndGameButton missing")
```

```gdscript
extends SceneTree

const WORD_POISON_SCENE_PATH := "res://scenes/word_poison_game.tscn"
const RESULT_SCENE_PATH := "res://scenes/word_poison_result.tscn"

func _initialize() -> void:
	var scene := load(WORD_POISON_SCENE_PATH) as PackedScene
	var root = scene.instantiate()
	root.set_startup_config({
		"word_set": {"file_name": "basic_words.txt", "file_path": "res://sample_word_sets/basic_words.txt"},
		"board_size": 3,
		"players": [{"id": 0, "name": "玩家1"}],
	})
	get_root().add_child(root)
	await process_frame

	var board_grid := root.get_node("%BoardGrid") as GridContainer
	_assert(board_grid.get_child_count() == 9, "3x3 board should render 9 word cards")
	var first_card := board_grid.get_child(0) as Control
	_assert(first_card.name == "WordPanel" or first_card.scene_file_path == "res://scenes/components/word_panel.tscn", "Board should render word_panel instances")

	var end_game_button := root.get_node("%EndGameButton") as Button
	end_game_button.pressed.emit()
	await process_frame

	var result_scene := get_root().get_child(get_root().get_child_count() - 1)
	_assert(result_scene.scene_file_path == RESULT_SCENE_PATH, "EndGameButton should navigate to the result scene")
	quit(0)
```

- [ ] **Step 2: Run test to verify it fails**

Run: `& "D:\Program Files\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . -s res://scripts/tests/test_word_poison_runtime_scene.gd`
Expected: FAIL because the current runtime script still expects removed setup and scoreboard nodes, and `gameplay_panel.gd` still binds to the old node names.

- [ ] **Step 3: Write minimal implementation**

```gdscript
	_assert(current_scene.has_node("GameplayPanel/GamePanel/BoardArea/CurrentPlayerName"), "Refactored current-player label missing")
	_assert(current_scene.has_node("GameplayPanel/GamePanel/BoardArea/MarginContainer/CurrentGameInfo"), "Refactored status label missing")
	_assert(current_scene.has_node("GameplayPanel/SidebarPanel/VBoxContainer/ActionButton/HBoxContainer/EndGameButton"), "EndGameButton missing")
```

```gdscript
var end_game_button := root.get_node("%EndGameButton") as Button
_assert(end_game_button != null, "EndGameButton should exist")
```

- [ ] **Step 4: Run test to verify it passes**

Run: `& "D:\Program Files\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . -s res://scripts/tests/test_word_poison_runtime_scene.gd`
Expected: PASS for the updated runtime-scene structure assertions and result-scene transition.

- [ ] **Step 5: Commit**

Workspace note: this workspace is not a git repo, so do not run a commit. Keep the checkpoint limited to the runtime-related test files.

### Task 2: Refactor gameplay_panel.gd To The New Node Tree And Word Cards

**Files:**
- Modify: `scripts/gameplay_panel.gd`
- Test: `scripts/tests/test_word_poison_runtime_scene.gd`

- [ ] **Step 1: Write the failing test**

```gdscript
	var board_grid := root.get_node("%BoardGrid") as GridContainer
	var card := board_grid.get_child(0) as Control
	var card_label := card.get_node("Label") as Label
	_assert(card_label.text.length() > 0, "Word card should display text")
	_assert(card.mouse_filter == Control.MOUSE_FILTER_STOP or card.get_child_count() > 0, "Word card should be interactive")
```

- [ ] **Step 2: Run test to verify it fails**

Run: `& "D:\Program Files\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . -s res://scripts/tests/test_word_poison_runtime_scene.gd`
Expected: FAIL because `gameplay_panel.gd` still creates plain `Button` cells and still looks for `CurrentPlayerLabel` and `GameplayStatusLabel`.

- [ ] **Step 3: Write minimal implementation**

```gdscript
extends HBoxContainer

signal cell_pressed(cell_index: int)
signal next_player_requested
signal end_game_requested

const WORD_PANEL_SCENE := preload("res://scenes/components/word_panel.tscn")

@onready var current_player_label: Label = %CurrentPlayerName
@onready var status_label: Label = %CurrentGameInfo
@onready var board_grid: GridContainer = %BoardGrid
@onready var next_player_button: Button = %NextPlayerButton
@onready var end_game_button: Button = %EndGameButton
@onready var word_set_label: Label = %GameplayWordSetLabel
@onready var board_size_label: Label = %GameplayBoardSizeLabel
@onready var best_score_label: Label = %BestScoreLabel
@onready var player_list: VBoxContainer = %GameplayPlayerList

func _ready() -> void:
	next_player_button.pressed.connect(func() -> void: next_player_requested.emit())
	end_game_button.pressed.connect(func() -> void: end_game_requested.emit())

func _render_board(cells: Array) -> void:
	for child in board_grid.get_children():
		child.queue_free()

	for cell_data in cells:
		var cell := cell_data as Dictionary
		var card := WORD_PANEL_SCENE.instantiate() as Control
		var label := card.get_node("Label") as Label
		label.text = String(cell.get("display_text", ""))
		card.mouse_filter = Control.MOUSE_FILTER_STOP
		card.gui_input.connect(_on_word_panel_input.bind(int(cell.get("cell_index", -1)), bool(cell.get("disabled", false))))
		board_grid.add_child(card)

func _on_word_panel_input(event: InputEvent, cell_index: int, disabled: bool) -> void:
	if disabled:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		cell_pressed.emit(cell_index)
```

- [ ] **Step 4: Run test to verify it passes**

Run: `& "D:\Program Files\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . -s res://scripts/tests/test_word_poison_runtime_scene.gd`
Expected: PASS with `word_panel.tscn` instances rendering into the board grid and runtime labels binding to the new node names.

- [ ] **Step 5: Commit**

Workspace note: this workspace is not a git repo, so do not run a commit. Keep the checkpoint limited to `scripts/gameplay_panel.gd` and the focused runtime test.

### Task 3: Refactor word_poison_game.gd To A Pure Runtime Controller

**Files:**
- Modify: `scripts/word_poison_game.gd`
- Modify: `scripts/tests/test_game_setting_scene.gd`
- Test: `scripts/tests/test_word_poison_runtime_scene.gd`

- [ ] **Step 1: Write the failing test**

```gdscript
	var gameplay_panel := root.get_node("%GameplayPanel")
	_assert(gameplay_panel.visible, "Gameplay panel should remain the only visible phase")
	_assert(root.get("_players").size() == 1, "Runtime should normalize startup players")
	_assert(int(root.get("_board_size")) == 3, "Runtime should preserve requested board size")
```

- [ ] **Step 2: Run test to verify it fails**

Run: `& "D:\Program Files\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . -s res://scripts/tests/test_word_poison_runtime_scene.gd`
Expected: FAIL because the current controller still references `%WordSourcePanel`, `%PlayerSetupPanel`, `%ScoreboardPanel`, and `%UploadFileDialog` during `_ready()`.

- [ ] **Step 3: Write minimal implementation**

```gdscript
extends Control

const BOARD_DIMENSIONS := {3: 9, 4: 16, 5: 25}
const RESULT_SCENE := preload("res://scenes/word_poison_result.tscn")

var _store := WordSetStore.new()
var _selected_word_set: Dictionary = {}
var _all_words: Array[Dictionary] = []
var _board_size := 4
var _board_cells: Array[Dictionary] = []
var _players: Array[Dictionary] = []
var _current_player_index := -1
var _finished_player_count := 0
var _finish_counter := 0
var _turn_is_waiting := false
var _startup_config: Dictionary = {}

@onready var gameplay_panel: Control = %GameplayPanel

func _ready() -> void:
	randomize()
	gameplay_panel.cell_pressed.connect(_on_cell_pressed)
	gameplay_panel.next_player_requested.connect(_on_next_player_requested)
	gameplay_panel.end_game_requested.connect(_on_end_game_requested)
	if not _startup_config.is_empty() and _initialize_from_config():
		return
	get_tree().change_scene_to_file("res://scenes/game_setting.tscn")

func _show_panel(target: Control) -> void:
	gameplay_panel.visible = gameplay_panel == target
```

- [ ] **Step 4: Run test to verify it passes**

Run: `& "D:\Program Files\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . -s res://scripts/tests/test_word_poison_runtime_scene.gd`
Expected: PASS with the controller starting directly from startup data and no longer requiring removed setup nodes.

- [ ] **Step 5: Commit**

Workspace note: this workspace is not a git repo, so do not run a commit. Keep the checkpoint limited to `scripts/word_poison_game.gd` and the updated tests.

### Task 4: Add A Dedicated Result Scene

**Files:**
- Create: `scenes/word_poison_result.tscn`
- Create: `scripts/word_poison_result.gd`
- Test: `scripts/tests/test_word_poison_runtime_scene.gd`

- [ ] **Step 1: Write the failing test**

```gdscript
	var result_scene := get_root().get_child(get_root().get_child_count() - 1)
	_assert(result_scene.has_method("set_results"), "Result scene controller should expose a set_results entry point")
	var replay_button := result_scene.get_node("%ReplayButton") as Button
	var back_button := result_scene.get_node("%BackToHubButton") as Button
	_assert(replay_button != null, "ReplayButton missing from result scene")
	_assert(back_button != null, "BackToHubButton missing from result scene")
```

- [ ] **Step 2: Run test to verify it fails**

Run: `& "D:\Program Files\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . -s res://scripts/tests/test_word_poison_runtime_scene.gd`
Expected: FAIL because the result scene does not yet exist.

- [ ] **Step 3: Write minimal implementation**

```gdscript
extends Control

signal replay_requested
signal back_to_hub_requested

@onready var results_list: VBoxContainer = %ResultsList
@onready var replay_button: Button = %ReplayButton
@onready var back_button: Button = %BackToHubButton

func _ready() -> void:
	replay_button.pressed.connect(func() -> void: get_tree().change_scene_to_file("res://scenes/game_setting.tscn"))
	back_button.pressed.connect(func() -> void: get_tree().change_scene_to_file("res://scenes/game_hub.tscn"))

func set_results(results: Array[Dictionary]) -> void:
	for child in results_list.get_children():
		child.queue_free()
	for index in range(results.size()):
		var player := results[index]
		var label := Label.new()
		label.text = "#%d %s | 点击 %d" % [index + 1, player.get("name", ""), int(player.get("safe_click_count", 0))]
		results_list.add_child(label)
```

- [ ] **Step 4: Run test to verify it passes**

Run: `& "D:\Program Files\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . -s res://scripts/tests/test_word_poison_runtime_scene.gd`
Expected: PASS with the result scene available and navigable.

- [ ] **Step 5: Commit**

Workspace note: this workspace is not a git repo, so do not run a commit. Keep the checkpoint limited to the new result-scene files and runtime test.

### Task 5: Wire Endgame Result Navigation From Runtime

**Files:**
- Modify: `scripts/word_poison_game.gd`
- Modify: `scripts/tests/test_game_setting_scene.gd`
- Modify: `scripts/tests/test_word_poison_runtime_scene.gd`

- [ ] **Step 1: Write the failing test**

```gdscript
	var end_game_button := root.get_node("%EndGameButton") as Button
	end_game_button.pressed.emit()
	await process_frame
	var result_scene := get_root().get_child(get_root().get_child_count() - 1)
	var results_list := result_scene.get_node("%ResultsList") as VBoxContainer
	_assert(results_list.get_child_count() >= 1, "Result scene should receive at least one ranked row")
```

- [ ] **Step 2: Run test to verify it fails**

Run: `& "D:\Program Files\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . -s res://scripts/tests/test_word_poison_runtime_scene.gd`
Expected: FAIL because the runtime controller does not yet instantiate the result scene and pass rankings.

- [ ] **Step 3: Write minimal implementation**

```gdscript
func _on_end_game_requested() -> void:
	_open_result_scene(_build_sorted_results())

func _show_scoreboard() -> void:
	_open_result_scene(_build_sorted_results())

func _build_sorted_results() -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	for player in _players:
		results.append(player.duplicate(true))
	results.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var score_a := int(a.get("safe_click_count", 0))
		var score_b := int(b.get("safe_click_count", 0))
		if score_a == score_b:
			return int(a.get("finish_order", 9999)) < int(b.get("finish_order", 9999))
		return score_a > score_b
	)
	return results

func _open_result_scene(results: Array[Dictionary]) -> void:
	var result_scene := RESULT_SCENE.instantiate()
	result_scene.set_results(results)
	get_tree().root.add_child(result_scene)
	get_tree().current_scene = result_scene
	queue_free()
```

- [ ] **Step 4: Run test to verify it passes**

Run: `& "D:\Program Files\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . -s res://scripts/tests/test_word_poison_runtime_scene.gd`
Expected: PASS with both manual end and all-finished flow reaching the result scene with ranked rows.

- [ ] **Step 5: Commit**

Workspace note: this workspace is not a git repo, so do not run a commit. Keep the checkpoint limited to `scripts/word_poison_game.gd` and the related tests.

### Task 6: Full Verification

**Files:**
- Verify: `scripts/word_poison_game.gd`
- Verify: `scripts/gameplay_panel.gd`
- Verify: `scripts/word_poison_result.gd`
- Verify: `scripts/tests/test_game_setting_scene.gd`
- Verify: `scripts/tests/test_word_poison_runtime_scene.gd`

- [ ] **Step 1: Run the updated GameSetting integration test**

Run: `& "D:\Program Files\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . -s res://scripts/tests/test_game_setting_scene.gd`
Expected: PASS with the refactored WordPoison node tree.

- [ ] **Step 2: Run the focused runtime test**

Run: `& "D:\Program Files\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . -s res://scripts/tests/test_word_poison_runtime_scene.gd`
Expected: PASS with exit code `0`.

- [ ] **Step 3: Re-read the spec and verify each requirement maps to code**

Checklist:

```text
[ ] WordPoison uses the new gameplay-only node tree
[ ] gameplay_panel.gd binds to renamed nodes
[ ] BoardGrid renders word_panel instances
[ ] EndGameButton transitions to result scene
[ ] All-finished flow transitions to result scene
[ ] Result scene supports replay and back-to-hub
```

- [ ] **Step 4: Record final state**

Report the verification evidence and list the exact modified files.
