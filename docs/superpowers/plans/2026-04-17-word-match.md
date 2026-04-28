# Word Match Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a dedicated `word match` setup, gameplay, and result flow with separate visuals, shared setup normalization, configurable mistake limits, and turn-based bilingual matching.

**Architecture:** Add a small shared setup helper for player normalization and startup payload construction, route `game_hub` into a new `word_match_setting` scene, and keep `word_match_game` as a pure runtime controller that consumes startup config and hands off to `word_match_result`. Reuse the project's existing `WordSetStore`, direct scene-instantiation flow, and headless `SceneTree` tests.

**Tech Stack:** Godot 4.6, GDScript, `.tscn` scenes, existing `WordSetStore`, headless scene tests run through `Godot_v4.6.1-stable_win64_console.exe`

---

## File Structure

- Create: `scripts/game_startup_config.gd`
  Shared data-only helper for player normalization, board-size normalization, `word match` startup payload construction, and runtime config validation.
- Modify: `scripts/game_hub.gd`
  Add `word match` navigation without changing the existing `word poison` card behavior.
- Modify: `scripts/game_setting.gd`
  Reuse the shared player-normalization helper so the new shared layer is actually exercised by both game setup flows.
- Create: `scenes/word_match_setting.tscn`
  Dedicated `word match` settings scene with its own layout, own controls, and no dependency on `word poison` node paths.
- Create: `scripts/word_match_setting.gd`
  `word match` settings controller: word set selection, layout selection, player editing, mistake-limit selection, start validation, and runtime handoff.
- Create: `scenes/word_match_game.tscn`
  Pure gameplay scene for `word match` with status labels, grid, and next-player action.
- Create: `scripts/word_match_game.gd`
  Runtime controller for board generation, selection logic, error counting, turn progression, and result handoff.
- Create: `scenes/word_match_result.tscn`
  Dedicated `word match` result scene with replay/back actions and a ranked results list.
- Create: `scripts/word_match_result.gd`
  Result controller that renders rows from supplied player results and handles replay/back navigation.
- Create: `scripts/tests/test_game_hub_scene.gd`
  Verifies the new `word match` card route from `game_hub`.
- Create: `scripts/tests/test_word_match_setting_scene.gd`
  Verifies the `word match` settings scene, validation, and startup payload handoff.
- Create: `scripts/tests/test_word_match_runtime_scene.gd`
  Verifies board generation, blank-cell handling, match resolution, error counting, failure threshold, and per-player isolation.
- Create: `scripts/tests/test_word_match_result_scene.gd`
  Verifies ranking order, row rendering, replay navigation, and back-to-hub navigation.

### Task 1: Shared Startup Helper And Hub Route

**Files:**
- Create: `scripts/game_startup_config.gd`
- Create: `scripts/tests/test_game_hub_scene.gd`
- Create: `scenes/word_match_setting.tscn`
- Create: `scripts/word_match_setting.gd`
- Modify: `scripts/game_hub.gd`

- [ ] **Step 1: Write the failing hub-route test**

Create `scripts/tests/test_game_hub_scene.gd` with this exact content:

```gdscript
extends SceneTree

const HUB_SCENE_PATH := "res://scenes/game_hub.tscn"
const WORD_MATCH_SETTING_SCENE_PATH := "res://scenes/word_match_setting.tscn"


func _initialize() -> void:
	var hub_scene := load(HUB_SCENE_PATH) as PackedScene
	_assert(hub_scene != null, "Game hub scene should load")

	var hub_root := hub_scene.instantiate() as Control
	_assert(hub_root != null, "Game hub scene should instantiate")
	get_root().add_child(hub_root)
	await process_frame

	var controller := hub_root
	_assert(controller.word_match_button != null, "Word match button should exist")
	_assert(controller.has_method("_on_word_match_panel_pressed"), "Word match card should have a press handler")

	controller._on_word_match_panel_pressed()
	await process_frame

	var current_scene := get_root().get_child(get_root().get_child_count() - 1)
	_assert(current_scene != null, "Word match card should navigate to a scene")
	_assert(current_scene.scene_file_path == WORD_MATCH_SETTING_SCENE_PATH, "Word match card should open the dedicated setting scene")
	current_scene.free()
	quit(0)


func _assert(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	quit(1)
```

- [ ] **Step 2: Run the hub-route test to verify it fails**

Run:
`& "D:\Program Files\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . -s res://scripts/tests/test_game_hub_scene.gd`

Expected: FAIL because `scripts/game_hub.gd` does not expose `_on_word_match_panel_pressed` yet and `scenes/word_match_setting.tscn` does not exist.

- [ ] **Step 3: Add the shared helper, a loadable setting-shell scene, and the hub route**

Create `scripts/game_startup_config.gd` with this exact content:

```gdscript
class_name GameStartupConfig
extends RefCounted


static func normalize_players(player_seeds: Array, default_prefix: String = "玩家") -> Array[Dictionary]:
	var normalized: Array[Dictionary] = []
	for index in range(player_seeds.size()):
		var player_seed := player_seeds[index] as Dictionary
		var name := String(player_seed.get("name", "")).strip_edges()
		if name.is_empty():
			name = "%s%d" % [default_prefix, index + 1]
		normalized.append({
			"id": index,
			"name": name,
		})
	return normalized


static func normalize_board_size(requested_size: int, allowed_sizes: Array[int], fallback: int) -> int:
	return requested_size if allowed_sizes.has(requested_size) else fallback


static func normalize_non_negative(value: int, fallback: int = 0) -> int:
	return value if value >= 0 else fallback


static func build_word_match_config(word_set: Dictionary, board_size: int, players: Array[Dictionary], max_errors: int) -> Dictionary:
	return {
		"game_type": "word_match",
		"word_set": word_set.duplicate(true),
		"board_size": board_size,
		"players": players.duplicate(true),
		"rules": {
			"max_errors": normalize_non_negative(max_errors, 0),
		},
	}


static func validate_word_match_config(config: Dictionary) -> Dictionary:
	var allowed_sizes: Array[int] = [3, 4, 5]
	var word_set := Dictionary(config.get("word_set", {})).duplicate(true)
	var players := normalize_players(config.get("players", []) as Array)
	var board_size := normalize_board_size(int(config.get("board_size", 4)), allowed_sizes, 4)
	var rules := Dictionary(config.get("rules", {})).duplicate(true)
	var max_errors := normalize_non_negative(int(rules.get("max_errors", 0)), 0)

	if String(config.get("game_type", "")).strip_edges() != "word_match":
		return {"ok": false, "message": "Missing word match game type"}
	if word_set.is_empty() or String(word_set.get("file_path", "")).strip_edges().is_empty():
		return {"ok": false, "message": "Missing word set file"}
	if players.is_empty():
		return {"ok": false, "message": "Missing players"}

	return {
		"ok": true,
		"config": {
			"game_type": "word_match",
			"word_set": word_set,
			"board_size": board_size,
			"players": players,
			"rules": {
				"max_errors": max_errors,
			},
		},
	}
```

Create `scripts/word_match_setting.gd` with this exact shell content:

```gdscript
extends Control
```

Create `scenes/word_match_setting.tscn` with this exact shell content:

```tscn
[gd_scene format=3]

[ext_resource type="Script" path="res://scripts/word_match_setting.gd" id="1_controller"]

[node name="WordMatchSetting" type="Control"]
layout_mode = 3
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
grow_horizontal = 2
grow_vertical = 2
script = ExtResource("1_controller")
```

Update `scripts/game_hub.gd` to this exact content:

```gdscript
extends Control

const PoisonMusic = preload("res://scripts/poison_music.gd")
const WORD_POISON_SCENE := "res://scenes/game_setting.tscn"
const WORD_MATCH_SETTING_SCENE := "res://scenes/word_match_setting.tscn"

const CARD_NORMAL_SCALE := Vector2.ONE
const CARD_HOVER_SCALE := Vector2(1.04, 1.04)
const CARD_PRESSED_SCALE := Vector2(0.97, 0.97)
const CARD_NORMAL_MODULATE := Color(1.0, 1.0, 1.0, 1.0)
const CARD_HOVER_MODULATE := Color(1.08, 1.08, 1.08, 1.0)
const CARD_PRESSED_MODULATE := Color(0.96, 0.96, 0.96, 1.0)
const HOVER_DURATION := 0.14
const PRESS_DURATION := 0.08

@onready var witchs_potion_panel: Control = $"MarginContainer/VBoxContainer/GamesPanel/GridContainer/WitchsPotionPanel"
@onready var witchs_potion_button: TextureButton = $"MarginContainer/VBoxContainer/GamesPanel/GridContainer/WitchsPotionPanel/AspectRatioContainer/TextureButton"
@onready var word_match_panel: Control = $"MarginContainer/VBoxContainer/GamesPanel/GridContainer/WordMatchPanel"
@onready var word_match_button: TextureButton = $"MarginContainer/VBoxContainer/GamesPanel/GridContainer/WordMatchPanel/AspectRatioContainer/TextureButton"

var _card_tweens: Dictionary = {}


func _ready() -> void:
	PoisonMusic.stop(get_tree())
	_setup_game_card(witchs_potion_panel, witchs_potion_button)
	_setup_game_card(word_match_panel, word_match_button)
	witchs_potion_panel.gui_input.connect(_on_witchs_potion_panel_input)
	witchs_potion_button.pressed.connect(_on_witchs_potion_panel_pressed)
	word_match_panel.gui_input.connect(_on_word_match_panel_input)
	word_match_button.pressed.connect(_on_word_match_panel_pressed)


func _on_witchs_potion_panel_pressed() -> void:
	get_tree().change_scene_to_file(WORD_POISON_SCENE)


func _on_word_match_panel_pressed() -> void:
	get_tree().change_scene_to_file(WORD_MATCH_SETTING_SCENE)


func _on_witchs_potion_panel_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if _is_mouse_over(witchs_potion_button):
			return
		_on_witchs_potion_panel_pressed()


func _on_word_match_panel_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if _is_mouse_over(word_match_button):
			return
		_on_word_match_panel_pressed()


func _setup_game_card(panel: Control, button: BaseButton) -> void:
	panel.pivot_offset = panel.size / 2.0
	panel.resized.connect(_on_card_resized.bind(panel))
	button.mouse_entered.connect(_on_card_mouse_entered.bind(panel, button))
	button.mouse_exited.connect(_on_card_mouse_exited.bind(panel, button))
	button.button_down.connect(_on_card_button_down.bind(panel))
	button.button_up.connect(_on_card_button_up.bind(panel, button))
	_animate_card_to(panel, CARD_NORMAL_SCALE, CARD_NORMAL_MODULATE, 0.0)


func _on_card_resized(panel: Control) -> void:
	panel.pivot_offset = panel.size / 2.0


func _on_card_mouse_entered(panel: Control, _button: BaseButton) -> void:
	_animate_card_to(panel, CARD_HOVER_SCALE, CARD_HOVER_MODULATE, HOVER_DURATION)


func _on_card_mouse_exited(panel: Control, button: BaseButton) -> void:
	if _is_mouse_over(button):
		return
	_animate_card_to(panel, CARD_NORMAL_SCALE, CARD_NORMAL_MODULATE, HOVER_DURATION)


func _on_card_button_down(panel: Control) -> void:
	_animate_card_to(panel, CARD_PRESSED_SCALE, CARD_PRESSED_MODULATE, PRESS_DURATION)


func _on_card_button_up(panel: Control, button: BaseButton) -> void:
	if _is_mouse_over(button):
		_animate_card_to(panel, CARD_HOVER_SCALE, CARD_HOVER_MODULATE, HOVER_DURATION)
		return

	_animate_card_to(panel, CARD_NORMAL_SCALE, CARD_NORMAL_MODULATE, HOVER_DURATION)


func _animate_card_to(panel: Control, target_scale: Vector2, target_modulate: Color, duration: float) -> void:
	var existing_tween: Tween = _card_tweens.get(panel)
	if existing_tween != null and existing_tween.is_valid():
		existing_tween.kill()

	if duration <= 0.0:
		panel.scale = target_scale
		panel.modulate = target_modulate
		_card_tweens.erase(panel)
		return

	var tween := create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(panel, "scale", target_scale, duration)
	tween.parallel().tween_property(panel, "modulate", target_modulate, duration)
	_card_tweens[panel] = tween


func _is_mouse_over(control: Control) -> bool:
	return control.get_global_rect().has_point(control.get_global_mouse_position())
```

- [ ] **Step 4: Run the hub-route test to verify it passes**

Run:
`& "D:\Program Files\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . -s res://scripts/tests/test_game_hub_scene.gd`

Expected: PASS with exit code `0`.

- [ ] **Step 5: Checkpoint without git**

Workspace note: this workspace is not a git repo, so do not run a commit. Keep the checkpoint limited to:

- `scripts/game_startup_config.gd`
- `scripts/game_hub.gd`
- `scenes/word_match_setting.tscn`
- `scripts/word_match_setting.gd`
- `scripts/tests/test_game_hub_scene.gd`

### Task 2: Build The Word Match Setting Scene

**Files:**
- Modify: `scenes/word_match_setting.tscn`
- Modify: `scripts/word_match_setting.gd`
- Modify: `scripts/game_setting.gd`
- Create: `scenes/word_match_game.tscn`
- Create: `scripts/word_match_game.gd`
- Create: `scripts/tests/test_word_match_setting_scene.gd`
- Verify: `scripts/tests/test_game_setting_scene.gd`

- [ ] **Step 1: Write the failing word-match-setting integration test**

Create `scripts/tests/test_word_match_setting_scene.gd` with this exact content:

```gdscript
extends SceneTree

const WORD_MATCH_SETTING_SCENE_PATH := "res://scenes/word_match_setting.tscn"
const WORD_MATCH_GAME_SCENE_PATH := "res://scenes/word_match_game.tscn"


func _initialize() -> void:
	var scene := load(WORD_MATCH_SETTING_SCENE_PATH) as PackedScene
	_assert(scene != null, "Word match setting scene should load")

	var root := scene.instantiate() as Control
	_assert(root != null, "Word match setting scene should instantiate")
	get_root().add_child(root)
	await process_frame

	var controller := root
	var start_button := root.get_node("%StartButton") as BaseButton
	var max_errors_spin_box := root.get_node("%MaxErrorsSpinBox") as SpinBox
	var player_list := root.get_node("%PlayerList") as VBoxContainer

	_assert(controller._players.size() == 1, "Word match should seed one default player")
	_assert(player_list.get_child_count() == 1, "Player list should render the seeded player row")
	_assert(int(max_errors_spin_box.value) == 3, "Allowed mistakes should default to 3")
	_assert(start_button.disabled, "Start should stay disabled when no word set is selected")

	var store := WordSetStore.new()
	var import_result := store.import_word_set(ProjectSettings.globalize_path("res://sample_word_sets/basic_words.txt"))
	_assert(bool(import_result.get("ok", false)), "Sample word set should import for the setting test")

	controller._setup_word_set_options()
	var selected_index := controller._find_word_set_index(String(import_result.get("file_path", "")))
	_assert(selected_index >= 0, "Imported word set should appear in the selector")

	controller._on_word_set_selected(selected_index)
	controller._on_layout_selected(5)
	controller._on_add_player_pressed()
	controller._on_player_name_changed("   ", 1)
	max_errors_spin_box.value = 2
	controller._update_start_state()
	_assert(not start_button.disabled, "Start should enable for a valid configuration")

	controller._on_start_pressed()
	await process_frame

	var current_scene := get_root().get_child(get_root().get_child_count() - 1)
	_assert(current_scene != null, "Start should navigate to a gameplay scene")
	_assert(current_scene.scene_file_path == WORD_MATCH_GAME_SCENE_PATH, "Start should open the word match gameplay scene")

	var startup_config := current_scene.get("_startup_config") as Dictionary
	_assert(String(startup_config.get("game_type", "")) == "word_match", "Startup config should carry the word match game type")
	_assert(int(startup_config.get("board_size", 0)) == 5, "Selected layout should be passed to gameplay")
	var players := startup_config.get("players", []) as Array
	_assert(players.size() == 2, "All configured players should be passed to gameplay")
	_assert(String((players[1] as Dictionary).get("name", "")) == "玩家2", "Blank player names should normalize before handoff")
	var rules := startup_config.get("rules", {}) as Dictionary
	_assert(int(rules.get("max_errors", -1)) == 2, "Allowed mistakes should be stored in startup rules")

	current_scene.free()
	quit(0)


func _assert(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	quit(1)
```

- [ ] **Step 2: Run the setting integration test to verify it fails**

Run:
`& "D:\Program Files\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . -s res://scripts/tests/test_word_match_setting_scene.gd`

Expected: FAIL because the setting shell scene does not contain the required nodes, does not manage player state yet, and `res://scenes/word_match_game.tscn` does not exist.

- [ ] **Step 3: Implement the full word-match setting scene and a gameplay receiver shell**

Replace `scenes/word_match_setting.tscn` with this exact content:

```tscn
[gd_scene format=3]

[ext_resource type="Script" path="res://scripts/word_match_setting.gd" id="1_controller"]

[node name="WordMatchSetting" type="Control"]
layout_mode = 3
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
grow_horizontal = 2
grow_vertical = 2
script = ExtResource("1_controller")

[node name="Background" type="ColorRect" parent="."]
layout_mode = 1
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
grow_horizontal = 2
grow_vertical = 2
color = Color(0.07, 0.1, 0.18, 1)

[node name="Margin" type="MarginContainer" parent="."]
layout_mode = 1
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
grow_horizontal = 2
grow_vertical = 2
theme_override_constants/margin_left = 80
theme_override_constants/margin_top = 60
theme_override_constants/margin_right = 80
theme_override_constants/margin_bottom = 60

[node name="RootVBox" type="VBoxContainer" parent="Margin"]
layout_mode = 2
theme_override_constants/separation = 18

[node name="TitleLabel" type="Label" parent="Margin/RootVBox"]
layout_mode = 2
text = "Word Match 设置"
horizontal_alignment = 1

[node name="StatusLabel" type="Label" parent="Margin/RootVBox"]
unique_name_in_owner = true
layout_mode = 2
text = "请选择词库并配置玩家"

[node name="WordRow" type="HBoxContainer" parent="Margin/RootVBox"]
layout_mode = 2
theme_override_constants/separation = 12

[node name="WordSetOption" type="OptionButton" parent="Margin/RootVBox/WordRow"]
unique_name_in_owner = true
layout_mode = 2
size_flags_horizontal = 3

[node name="ImportButton" type="Button" parent="Margin/RootVBox/WordRow"]
unique_name_in_owner = true
layout_mode = 2
text = "导入词库"

[node name="LayoutRow" type="HBoxContainer" parent="Margin/RootVBox"]
layout_mode = 2
theme_override_constants/separation = 12

[node name="Layout3Button" type="Button" parent="Margin/RootVBox/LayoutRow"]
unique_name_in_owner = true
layout_mode = 2
toggle_mode = true
text = "3 x 3"

[node name="Layout4Button" type="Button" parent="Margin/RootVBox/LayoutRow"]
unique_name_in_owner = true
layout_mode = 2
toggle_mode = true
text = "4 x 4"

[node name="Layout5Button" type="Button" parent="Margin/RootVBox/LayoutRow"]
unique_name_in_owner = true
layout_mode = 2
toggle_mode = true
text = "5 x 5"

[node name="MistakeRow" type="HBoxContainer" parent="Margin/RootVBox"]
layout_mode = 2
theme_override_constants/separation = 12

[node name="MistakeLabel" type="Label" parent="Margin/RootVBox/MistakeRow"]
layout_mode = 2
text = "允许失败次数"

[node name="MaxErrorsSpinBox" type="SpinBox" parent="Margin/RootVBox/MistakeRow"]
unique_name_in_owner = true
layout_mode = 2
min_value = 0.0
max_value = 9.0
step = 1.0
value = 3.0

[node name="PlayerHeader" type="HBoxContainer" parent="Margin/RootVBox"]
layout_mode = 2
theme_override_constants/separation = 12

[node name="PlayerTitle" type="Label" parent="Margin/RootVBox/PlayerHeader"]
layout_mode = 2
size_flags_horizontal = 3
text = "玩家设置"

[node name="AddPlayerButton" type="Button" parent="Margin/RootVBox/PlayerHeader"]
unique_name_in_owner = true
layout_mode = 2
text = "添加玩家"

[node name="PlayerScroll" type="ScrollContainer" parent="Margin/RootVBox"]
layout_mode = 2
size_flags_vertical = 3

[node name="PlayerList" type="VBoxContainer" parent="Margin/RootVBox/PlayerScroll"]
unique_name_in_owner = true
layout_mode = 2
size_flags_horizontal = 3
theme_override_constants/separation = 10

[node name="ActionRow" type="HBoxContainer" parent="Margin/RootVBox"]
layout_mode = 2
theme_override_constants/separation = 12

[node name="BackButton" type="Button" parent="Margin/RootVBox/ActionRow"]
unique_name_in_owner = true
layout_mode = 2
size_flags_horizontal = 3
text = "返回"

[node name="StartButton" type="Button" parent="Margin/RootVBox/ActionRow"]
unique_name_in_owner = true
layout_mode = 2
size_flags_horizontal = 3
text = "开始"

[node name="UploadFileDialog" type="FileDialog" parent="."]
unique_name_in_owner = true
title = "导入词库"
size = Vector2i(900, 540)
```

Replace `scripts/word_match_setting.gd` with this exact content:

```gdscript
extends Control

const MIN_PLAYERS := 1
const MAX_PLAYERS := 10
const BOARD_SIZES: Array[int] = [3, 4, 5]
const WORD_MATCH_SCENE := preload("res://scenes/word_match_game.tscn")

var _store := WordSetStore.new()
var _word_sets: Array[Dictionary] = []
var _selected_word_set: Dictionary = {}
var _board_size := 4
var _players: Array[Dictionary] = []
var _max_errors := 3

@onready var status_label: Label = %StatusLabel
@onready var word_set_option: OptionButton = %WordSetOption
@onready var import_button: Button = %ImportButton
@onready var layout_3_button: Button = %Layout3Button
@onready var layout_4_button: Button = %Layout4Button
@onready var layout_5_button: Button = %Layout5Button
@onready var max_errors_spin_box: SpinBox = %MaxErrorsSpinBox
@onready var add_player_button: Button = %AddPlayerButton
@onready var player_list: VBoxContainer = %PlayerList
@onready var back_button: Button = %BackButton
@onready var start_button: Button = %StartButton
@onready var file_dialog: FileDialog = %UploadFileDialog


func _ready() -> void:
	_players = [{"id": 0, "name": _default_player_name(0)}]
	_setup_file_dialog()
	_connect_signals()
	_setup_word_set_options()
	_select_layout(_board_size)
	_render_players()
	_update_start_state()


func _setup_file_dialog() -> void:
	file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	file_dialog.access = FileDialog.ACCESS_FILESYSTEM
	file_dialog.filters = PackedStringArray(["*.txt ; 文本词库", "*.csv ; CSV 词库", "*.tsv ; TSV 词库"])


func _connect_signals() -> void:
	word_set_option.item_selected.connect(_on_word_set_selected)
	import_button.pressed.connect(_on_import_pressed)
	layout_3_button.pressed.connect(_on_layout_selected.bind(3))
	layout_4_button.pressed.connect(_on_layout_selected.bind(4))
	layout_5_button.pressed.connect(_on_layout_selected.bind(5))
	max_errors_spin_box.value_changed.connect(_on_max_errors_changed)
	add_player_button.pressed.connect(_on_add_player_pressed)
	back_button.pressed.connect(_on_back_pressed)
	start_button.pressed.connect(_on_start_pressed)
	file_dialog.file_selected.connect(_on_file_selected)


func _setup_word_set_options() -> void:
	var previous_path := String(_selected_word_set.get("file_path", ""))
	_word_sets = _store.list_word_sets()
	word_set_option.clear()
	if _word_sets.is_empty():
		_selected_word_set = {}
		word_set_option.disabled = true
		word_set_option.add_item("暂无可用词表", -1)
		word_set_option.select(0)
		_update_start_state()
		return

	word_set_option.disabled = false
	for index in range(_word_sets.size()):
		var item := _word_sets[index]
		word_set_option.add_item("%s (%d 词)" % [item.get("file_name", ""), int(item.get("word_count", 0))], index)

	var selected_index := _find_word_set_index(previous_path)
	if selected_index < 0:
		selected_index = 0
	_selected_word_set = _word_sets[selected_index].duplicate(true)
	word_set_option.select(selected_index)
	_update_start_state()


func _find_word_set_index(file_path: String) -> int:
	for index in range(_word_sets.size()):
		if String(_word_sets[index].get("file_path", "")) == file_path:
			return index
	return -1


func _on_word_set_selected(index: int) -> void:
	if index < 0 or index >= _word_sets.size():
		_selected_word_set = {}
	else:
		_selected_word_set = _word_sets[index].duplicate(true)
	_update_start_state()


func _on_layout_selected(board_size: int) -> void:
	_board_size = GameStartupConfig.normalize_board_size(board_size, BOARD_SIZES, 4)
	_select_layout(_board_size)
	_update_start_state()


func _on_max_errors_changed(value: float) -> void:
	_max_errors = GameStartupConfig.normalize_non_negative(int(value), 0)
	max_errors_spin_box.value = float(_max_errors)
	_update_start_state()


func _on_add_player_pressed() -> void:
	if _players.size() >= MAX_PLAYERS:
		return
	_players.append({"id": _players.size(), "name": _default_player_name(_players.size())})
	_render_players()
	_update_start_state()


func _on_remove_player_pressed(index: int) -> void:
	if _players.size() <= MIN_PLAYERS:
		return
	if index < 0 or index >= _players.size():
		return
	_players.remove_at(index)
	_players = GameStartupConfig.normalize_players(_players)
	_render_players()
	_update_start_state()


func _on_player_name_changed(new_text: String, index: int) -> void:
	if index < 0 or index >= _players.size():
		return
	_players[index]["name"] = new_text


func _on_import_pressed() -> void:
	file_dialog.popup_centered_ratio(0.7)


func _on_file_selected(path: String) -> void:
	var result := _store.import_word_set(path)
	if not bool(result.get("ok", false)):
		status_label.text = String(result.get("message", "导入失败"))
		_update_start_state()
		return

	_selected_word_set = {
		"file_name": result.get("file_name", ""),
		"file_path": result.get("file_path", ""),
		"word_count": int(result.get("word_count", 0)),
	}
	status_label.text = "词库导入成功"
	_setup_word_set_options()


func _render_players() -> void:
	for child in player_list.get_children():
		child.queue_free()

	for index in range(_players.size()):
		var row := HBoxContainer.new()
		row.name = "PlayerRow%d" % index
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL

		var name_edit := LineEdit.new()
		name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_edit.placeholder_text = _default_player_name(index)
		name_edit.text = String(_players[index].get("name", _default_player_name(index)))
		name_edit.text_changed.connect(_on_player_name_changed.bind(index))

		var remove_button := Button.new()
		remove_button.text = "移除"
		remove_button.disabled = _players.size() <= MIN_PLAYERS
		remove_button.pressed.connect(_on_remove_player_pressed.bind(index), CONNECT_DEFERRED)

		row.add_child(name_edit)
		row.add_child(remove_button)
		player_list.add_child(row)

	add_player_button.disabled = _players.size() >= MAX_PLAYERS


func _select_layout(board_size: int) -> void:
	layout_3_button.button_pressed = board_size == 3
	layout_4_button.button_pressed = board_size == 4
	layout_5_button.button_pressed = board_size == 5


func _required_pair_count() -> int:
	return int(floor(float(_board_size * _board_size) / 2.0))


func _default_player_name(index: int) -> String:
	return "玩家%d" % (index + 1)


func _update_start_state() -> void:
	if _selected_word_set.is_empty():
		start_button.disabled = true
		status_label.text = "请选择词库并配置玩家"
		return

	var word_count := int(_selected_word_set.get("word_count", 0))
	var required_pairs := _required_pair_count()
	if word_count < required_pairs:
		start_button.disabled = true
		status_label.text = "当前布局至少需要 %d 对词" % required_pairs
		return

	start_button.disabled = false
	status_label.text = "已选择 %s，布局 %dx%d，允许失败 %d 次" % [
		_selected_word_set.get("file_name", ""),
		_board_size,
		_board_size,
		_max_errors,
	]


func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/game_hub.tscn")


func _on_start_pressed() -> void:
	if start_button.disabled:
		_update_start_state()
		return

	var words := _store.parse_word_file(String(_selected_word_set.get("file_path", "")))
	if words.size() < _required_pair_count():
		status_label.text = "词库词对不足，无法开始当前布局"
		start_button.disabled = true
		return

	var normalized_players := GameStartupConfig.normalize_players(_players)
	var next_scene := WORD_MATCH_SCENE.instantiate()
	next_scene.set_startup_config(GameStartupConfig.build_word_match_config(
		_selected_word_set,
		_board_size,
		normalized_players,
		_max_errors
	))
	get_tree().root.add_child(next_scene)
	get_tree().current_scene = next_scene
	queue_free()
```

Create `scripts/word_match_game.gd` with this exact receiver shell content:

```gdscript
extends Control

var _startup_config: Dictionary = {}


func set_startup_config(config: Dictionary) -> void:
	_startup_config = config.duplicate(true)
```

Create `scenes/word_match_game.tscn` with this exact receiver shell content:

```tscn
[gd_scene format=3]

[ext_resource type="Script" path="res://scripts/word_match_game.gd" id="1_controller"]

[node name="WordMatchGame" type="Control"]
layout_mode = 3
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
grow_horizontal = 2
grow_vertical = 2
script = ExtResource("1_controller")
```

In `scripts/game_setting.gd`, replace the whole `_normalized_players()` function with this exact code so the shared helper is used by both setup flows:

```gdscript
func _normalized_players() -> Array[Dictionary]:
	return GameStartupConfig.normalize_players(_players)
```

- [ ] **Step 4: Run the new setting test and the existing poison setting test**

Run:
`& "D:\Program Files\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . -s res://scripts/tests/test_word_match_setting_scene.gd`

Expected: PASS with exit code `0`.

Run:
`& "D:\Program Files\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . -s res://scripts/tests/test_game_setting_scene.gd`

Expected: PASS with exit code `0`, proving the new shared helper did not break the existing `word poison` setting flow.

- [ ] **Step 5: Checkpoint without git**

Workspace note: this workspace is not a git repo, so do not run a commit. Keep the checkpoint limited to:

- `scenes/word_match_setting.tscn`
- `scripts/word_match_setting.gd`
- `scripts/game_setting.gd`
- `scenes/word_match_game.tscn`
- `scripts/word_match_game.gd`
- `scripts/tests/test_word_match_setting_scene.gd`

### Task 3: Implement Word Match Runtime Logic

**Files:**
- Modify: `scenes/word_match_game.tscn`
- Modify: `scripts/word_match_game.gd`
- Create: `scripts/tests/test_word_match_runtime_scene.gd`

- [ ] **Step 1: Write the failing runtime test**

Create `scripts/tests/test_word_match_runtime_scene.gd` with this exact content:

```gdscript
extends SceneTree

const WORD_MATCH_GAME_SCENE_PATH := "res://scenes/word_match_game.tscn"


func _initialize() -> void:
	var scene := load(WORD_MATCH_GAME_SCENE_PATH) as PackedScene
	_assert(scene != null, "Word match gameplay scene should load")

	var invalid_root := scene.instantiate()
	_assert(invalid_root != null, "Word match gameplay scene should instantiate for the invalid-entry check")
	get_root().add_child(invalid_root)
	await process_frame

	var fallback_scene := get_root().get_child(get_root().get_child_count() - 1)
	_assert(fallback_scene.scene_file_path == "res://scenes/word_match_setting.tscn", "Opening gameplay without startup config should return to settings")
	fallback_scene.free()

	var root := scene.instantiate()
	_assert(root != null, "Word match gameplay scene should instantiate")
	root.set_startup_config({
		"game_type": "word_match",
		"word_set": {"file_name": "basic_words.txt", "file_path": "res://sample_word_sets/basic_words.txt", "word_count": 20},
		"board_size": 3,
		"players": [{"id": 0, "name": "玩家1"}, {"id": 1, "name": "玩家2"}],
		"rules": {"max_errors": 1},
	})
	get_root().add_child(root)
	await process_frame

	var board_grid := root.get_node("%BoardGrid") as GridContainer
	_assert(board_grid != null, "Gameplay scene should expose a board grid")
	_assert(root._board_cells.size() == 9, "3x3 should build nine cells")
	_assert(_count_blank_cells(root._board_cells) == 1, "3x3 should include one blank cell")

	root._board_size = 4
	root._generate_board_cells()
	_assert(root._board_cells.size() == 16, "4x4 should build sixteen cells")
	_assert(_count_blank_cells(root._board_cells) == 0, "4x4 should not include a blank cell")

	root._board_size = 3
	root._board_cells = _build_test_board()
	root._players = [
		root._build_player_state({"id": 0, "name": "玩家1"}),
		root._build_player_state({"id": 1, "name": "玩家2"}),
	]
	root._current_player_index = 0
	root._selected_cell_indices = []
	root._finished_player_count = 0
	root._finish_counter = 0
	root._turn_is_waiting = false
	root._status_text = "测试中"
	root._refresh_view()

	root._on_cell_pressed(0)
	root._on_cell_pressed(1)
	var player_one := root._players[0] as Dictionary
	_assert(int(player_one.get("matched_pair_count", 0)) == 1, "A correct English-Chinese pair should count as one match")
	_assert((player_one.get("matched_cell_indices", []) as Array).has(0), "A correct match should record the first cell index")
	_assert((player_one.get("matched_cell_indices", []) as Array).has(1), "A correct match should record the second cell index")

	root._on_cell_pressed(2)
	root._on_cell_pressed(5)
	player_one = root._players[0] as Dictionary
	_assert(int(player_one.get("error_count", 0)) == 1, "A wrong pair should increment the mistake count")
	_assert(not bool(player_one.get("is_failed", false)), "The player should still continue while mistakes stay within the limit")

	root._on_cell_pressed(2)
	root._on_cell_pressed(7)
	player_one = root._players[0] as Dictionary
	_assert(bool(player_one.get("is_failed", false)), "The player should fail on the max_errors + 1 mistake")
	_assert(root._turn_is_waiting, "A failed turn should wait for the next-player action")

	root._on_next_player_requested()
	await process_frame
	_assert(int(root._current_player_index) == 1, "Next-player action should start the following player's turn")
	var player_two := root._players[1] as Dictionary
	_assert(int(player_two.get("matched_pair_count", 0)) == 0, "The next player should start with independent progress")

	root._on_cell_pressed(0)
	root._on_cell_pressed(1)
	player_two = root._players[1] as Dictionary
	_assert(int(player_two.get("matched_pair_count", 0)) == 1, "The next player should be able to match the same board pair independently")

	quit(0)


func _build_test_board() -> Array[Dictionary]:
	return [
		{"cell_index": 0, "kind": "word", "pair_id": 0, "text": "apple", "language": "english"},
		{"cell_index": 1, "kind": "word", "pair_id": 0, "text": "苹果", "language": "chinese"},
		{"cell_index": 2, "kind": "word", "pair_id": 1, "text": "pear", "language": "english"},
		{"cell_index": 3, "kind": "word", "pair_id": 1, "text": "梨", "language": "chinese"},
		{"cell_index": 4, "kind": "word", "pair_id": 2, "text": "dog", "language": "english"},
		{"cell_index": 5, "kind": "word", "pair_id": 2, "text": "狗", "language": "chinese"},
		{"cell_index": 6, "kind": "word", "pair_id": 3, "text": "book", "language": "english"},
		{"cell_index": 7, "kind": "word", "pair_id": 3, "text": "书", "language": "chinese"},
		{"cell_index": 8, "kind": "blank", "pair_id": -1, "text": "", "language": ""},
	]


func _count_blank_cells(cells: Array) -> int:
	var count := 0
	for cell_data in cells:
		var cell := cell_data as Dictionary
		if String(cell.get("kind", "")) == "blank":
			count += 1
	return count


func _assert(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	quit(1)
```

- [ ] **Step 2: Run the runtime test to verify it fails**

Run:
`& "D:\Program Files\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . -s res://scripts/tests/test_word_match_runtime_scene.gd`

Expected: FAIL because the gameplay shell does not expose `%BoardGrid`, does not initialize startup config, and does not implement any board or turn logic.

- [ ] **Step 3: Replace the gameplay shell with the full runtime controller and scene**

Replace `scenes/word_match_game.tscn` with this exact content:

```tscn
[gd_scene format=3]

[ext_resource type="Script" path="res://scripts/word_match_game.gd" id="1_controller"]

[node name="WordMatchGame" type="Control"]
layout_mode = 3
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
grow_horizontal = 2
grow_vertical = 2
script = ExtResource("1_controller")

[node name="Background" type="ColorRect" parent="."]
layout_mode = 1
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
grow_horizontal = 2
grow_vertical = 2
color = Color(0.06, 0.08, 0.12, 1)

[node name="Margin" type="MarginContainer" parent="."]
layout_mode = 1
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
grow_horizontal = 2
grow_vertical = 2
theme_override_constants/margin_left = 80
theme_override_constants/margin_top = 60
theme_override_constants/margin_right = 80
theme_override_constants/margin_bottom = 60

[node name="RootVBox" type="VBoxContainer" parent="Margin"]
layout_mode = 2
theme_override_constants/separation = 16

[node name="HeaderRow" type="HBoxContainer" parent="Margin/RootVBox"]
layout_mode = 2
theme_override_constants/separation = 12

[node name="CurrentPlayerLabel" type="Label" parent="Margin/RootVBox/HeaderRow"]
unique_name_in_owner = true
layout_mode = 2
size_flags_horizontal = 3
text = "当前玩家"

[node name="ProgressLabel" type="Label" parent="Margin/RootVBox/HeaderRow"]
unique_name_in_owner = true
layout_mode = 2
text = "进度"

[node name="MistakeLabel" type="Label" parent="Margin/RootVBox/HeaderRow"]
unique_name_in_owner = true
layout_mode = 2
text = "错误"

[node name="StatusLabel" type="Label" parent="Margin/RootVBox"]
unique_name_in_owner = true
layout_mode = 2
text = "准备中"

[node name="BoardGrid" type="GridContainer" parent="Margin/RootVBox"]
unique_name_in_owner = true
layout_mode = 2
size_flags_horizontal = 3
size_flags_vertical = 3
theme_override_constants/h_separation = 10
theme_override_constants/v_separation = 10
columns = 3

[node name="NextPlayerButton" type="Button" parent="Margin/RootVBox"]
unique_name_in_owner = true
layout_mode = 2
text = "下一位玩家"
visible = false
```

Replace `scripts/word_match_game.gd` with this exact content:

```gdscript
extends Control

const BOARD_SIZES: Array[int] = [3, 4, 5]
const WORD_MATCH_SETTING_SCENE_PATH := "res://scenes/word_match_setting.tscn"
const WORD_MATCH_RESULT_SCENE_PATH := "res://scenes/word_match_result.tscn"

var _store := WordSetStore.new()
var _startup_config: Dictionary = {}
var _selected_word_set: Dictionary = {}
var _all_words: Array[Dictionary] = []
var _board_size := 4
var _board_cells: Array[Dictionary] = []
var _players: Array[Dictionary] = []
var _current_player_index := -1
var _selected_cell_indices: Array[int] = []
var _finished_player_count := 0
var _finish_counter := 0
var _turn_is_waiting := false
var _max_errors := 0
var _status_text := "准备中"

@onready var current_player_label: Label = %CurrentPlayerLabel
@onready var progress_label: Label = %ProgressLabel
@onready var mistake_label: Label = %MistakeLabel
@onready var status_label: Label = %StatusLabel
@onready var board_grid: GridContainer = %BoardGrid
@onready var next_player_button: Button = %NextPlayerButton


func set_startup_config(config: Dictionary) -> void:
	_startup_config = config.duplicate(true)


func _ready() -> void:
	randomize()
	next_player_button.pressed.connect(_on_next_player_requested)
	if _initialize_from_config():
		return
	get_tree().change_scene_to_file(WORD_MATCH_SETTING_SCENE_PATH)


func _initialize_from_config() -> bool:
	var validation := GameStartupConfig.validate_word_match_config(_startup_config)
	if not bool(validation.get("ok", false)):
		return false

	var config := validation.get("config", {}) as Dictionary
	_selected_word_set = Dictionary(config.get("word_set", {})).duplicate(true)
	_board_size = GameStartupConfig.normalize_board_size(int(config.get("board_size", 4)), BOARD_SIZES, 4)
	_all_words = _store.parse_word_file(String(_selected_word_set.get("file_path", "")))
	if _all_words.size() < _required_pair_count():
		return false

	var rules := config.get("rules", {}) as Dictionary
	_max_errors = GameStartupConfig.normalize_non_negative(int(rules.get("max_errors", 0)), 0)
	_players.clear()
	for player_seed in config.get("players", []) as Array:
		_players.append(_build_player_state(player_seed as Dictionary))
	if _players.is_empty():
		return false

	_finished_player_count = 0
	_finish_counter = 0
	_generate_board_cells()
	_start_player_turn(0)
	return true


func _required_pair_count() -> int:
	return int(floor(float(_board_size * _board_size) / 2.0))


func _generate_board_cells() -> void:
	_board_cells.clear()
	var pair_count := _required_pair_count()
	var pool := _all_words.duplicate(true)
	pool.shuffle()

	var raw_cells: Array[Dictionary] = []
	for index in range(pair_count):
		var entry := pool[index] as Dictionary
		raw_cells.append({"kind": "word", "pair_id": index, "text": entry.get("english", ""), "language": "english"})
		raw_cells.append({"kind": "word", "pair_id": index, "text": entry.get("chinese", ""), "language": "chinese"})

	if (_board_size * _board_size) % 2 == 1:
		raw_cells.append({"kind": "blank", "pair_id": -1, "text": "", "language": ""})

	raw_cells.shuffle()
	for cell_index in range(raw_cells.size()):
		var cell := raw_cells[cell_index].duplicate(true)
		cell["cell_index"] = cell_index
		_board_cells.append(cell)


func _build_player_state(seed: Dictionary) -> Dictionary:
	var name := String(seed.get("name", "")).strip_edges()
	if name.is_empty():
		name = "玩家%d" % (int(seed.get("id", 0)) + 1)
	return {
		"id": int(seed.get("id", 0)),
		"name": name,
		"matched_pair_count": 0,
		"error_count": 0,
		"matched_cell_indices": [],
		"is_cleared": false,
		"is_failed": false,
		"finish_order": 9999,
	}


func _start_player_turn(player_index: int) -> void:
	_current_player_index = player_index
	_selected_cell_indices.clear()
	_turn_is_waiting = false
	_status_text = "请选择两个卡片进行配对"
	_refresh_view()


func _on_cell_pressed(cell_index: int) -> void:
	if _turn_is_waiting or _current_player_index < 0:
		return

	var cell := _board_cells[cell_index] as Dictionary
	if String(cell.get("kind", "")) == "blank":
		return
	if _current_player_matches().has(cell_index):
		return
	if _selected_cell_indices.has(cell_index):
		return

	_selected_cell_indices.append(cell_index)
	if _selected_cell_indices.size() < 2:
		_status_text = "已选择 1 张卡片，再选 1 张"
		_refresh_view()
		return

	_evaluate_selection()


func _evaluate_selection() -> void:
	var first_cell := _board_cells[_selected_cell_indices[0]] as Dictionary
	var second_cell := _board_cells[_selected_cell_indices[1]] as Dictionary
	var is_valid_pair := int(first_cell.get("pair_id", -1)) == int(second_cell.get("pair_id", -1))
	is_valid_pair = is_valid_pair and String(first_cell.get("language", "")) != String(second_cell.get("language", ""))

	if is_valid_pair:
		var matched_indices: Array = _players[_current_player_index]["matched_cell_indices"]
		matched_indices.append(_selected_cell_indices[0])
		matched_indices.append(_selected_cell_indices[1])
		_players[_current_player_index]["matched_cell_indices"] = matched_indices
		_players[_current_player_index]["matched_pair_count"] = int(_players[_current_player_index].get("matched_pair_count", 0)) + 1
		_selected_cell_indices.clear()
		if int(_players[_current_player_index].get("matched_pair_count", 0)) >= _required_pair_count():
			_finish_current_player(true, "%s 已完成所有配对" % _players[_current_player_index].get("name", "玩家"))
			return
		_status_text = "匹配成功，继续选择"
		_refresh_view()
		return

	_players[_current_player_index]["error_count"] = int(_players[_current_player_index].get("error_count", 0)) + 1
	_selected_cell_indices.clear()
	if int(_players[_current_player_index].get("error_count", 0)) > _max_errors:
		_finish_current_player(false, "%s 超过允许失败次数" % _players[_current_player_index].get("name", "玩家"))
		return
	_status_text = "匹配错误，可以继续尝试"
	_refresh_view()


func _finish_current_player(is_cleared: bool, status_text: String) -> void:
	_players[_current_player_index]["is_cleared"] = is_cleared
	_players[_current_player_index]["is_failed"] = not is_cleared
	_players[_current_player_index]["finish_order"] = _finish_counter
	_finish_counter += 1
	_finished_player_count += 1
	_turn_is_waiting = true
	_selected_cell_indices.clear()
	_status_text = status_text
	_refresh_view()


func _on_next_player_requested() -> void:
	if not _turn_is_waiting:
		return
	if _finished_player_count >= _players.size():
		_open_result_scene(_build_sorted_results())
		return
	_start_player_turn(_current_player_index + 1)


func _current_player_matches() -> Array:
	if _current_player_index < 0 or _current_player_index >= _players.size():
		return []
	return _players[_current_player_index].get("matched_cell_indices", [])


func _refresh_view() -> void:
	board_grid.columns = _board_size
	status_label.text = _status_text
	next_player_button.visible = _turn_is_waiting
	next_player_button.text = "查看结算" if _finished_player_count >= _players.size() else "下一位玩家"

	if _current_player_index >= 0 and _current_player_index < _players.size():
		var player := _players[_current_player_index] as Dictionary
		current_player_label.text = "当前玩家：%s" % player.get("name", "")
		progress_label.text = "进度：%d / %d" % [int(player.get("matched_pair_count", 0)), _required_pair_count()]
		mistake_label.text = "错误：%d / %d" % [int(player.get("error_count", 0)), _max_errors]
	else:
		current_player_label.text = "当前玩家："
		progress_label.text = "进度：0 / 0"
		mistake_label.text = "错误：0 / 0"

	for child in board_grid.get_children():
		child.queue_free()

	var matched_lookup := _current_player_matches()
	for cell_data in _board_cells:
		var cell := cell_data as Dictionary
		var cell_index := int(cell.get("cell_index", -1))
		var cell_button := Button.new()
		cell_button.name = "Cell%d" % cell_index
		cell_button.custom_minimum_size = Vector2(150, 90)
		cell_button.text = String(cell.get("text", ""))
		var is_blank := String(cell.get("kind", "")) == "blank"
		var is_matched := matched_lookup.has(cell_index)
		cell_button.disabled = is_blank or is_matched or _turn_is_waiting
		if is_blank:
			cell_button.text = ""
			cell_button.modulate = Color(0.22, 0.24, 0.3, 1)
		elif _selected_cell_indices.has(cell_index):
			cell_button.modulate = Color(1.0, 0.9, 0.55, 1)
		elif is_matched:
			cell_button.modulate = Color(0.45, 0.45, 0.45, 1)
		else:
			cell_button.modulate = Color(1, 1, 1, 1)
		cell_button.pressed.connect(_on_cell_pressed.bind(cell_index))
		board_grid.add_child(cell_button)


func _build_sorted_results() -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	for player_data in _players:
		results.append((player_data as Dictionary).duplicate(true))
	results.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var cleared_a := bool(a.get("is_cleared", false))
		var cleared_b := bool(b.get("is_cleared", false))
		if cleared_a != cleared_b:
			return cleared_a
		var matched_a := int(a.get("matched_pair_count", 0))
		var matched_b := int(b.get("matched_pair_count", 0))
		if matched_a != matched_b:
			return matched_a > matched_b
		var errors_a := int(a.get("error_count", 0))
		var errors_b := int(b.get("error_count", 0))
		if errors_a != errors_b:
			return errors_a < errors_b
		return int(a.get("finish_order", 9999)) < int(b.get("finish_order", 9999))
	)
	return results


func _open_result_scene(results: Array[Dictionary]) -> void:
	var result_scene_pack := load(WORD_MATCH_RESULT_SCENE_PATH) as PackedScene
	if result_scene_pack == null:
		get_tree().change_scene_to_file(WORD_MATCH_SETTING_SCENE_PATH)
		return
	var result_scene := result_scene_pack.instantiate()
	result_scene.set_results(results)
	get_tree().root.add_child(result_scene)
	get_tree().current_scene = result_scene
	queue_free()
```

- [ ] **Step 4: Run the runtime test to verify it passes**

Run:
`& "D:\Program Files\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . -s res://scripts/tests/test_word_match_runtime_scene.gd`

Expected: PASS with exit code `0`.

- [ ] **Step 5: Checkpoint without git**

Workspace note: this workspace is not a git repo, so do not run a commit. Keep the checkpoint limited to:

- `scenes/word_match_game.tscn`
- `scripts/word_match_game.gd`
- `scripts/tests/test_word_match_runtime_scene.gd`

### Task 4: Add Result Scene And Complete The End-To-End Flow

**Files:**
- Create: `scenes/word_match_result.tscn`
- Create: `scripts/word_match_result.gd`
- Modify: `scripts/tests/test_word_match_runtime_scene.gd`
- Create: `scripts/tests/test_word_match_result_scene.gd`

- [ ] **Step 1: Write the failing result-scene test and extend the runtime test to cover result handoff**

Create `scripts/tests/test_word_match_result_scene.gd` with this exact content:

```gdscript
extends SceneTree

const WORD_MATCH_RESULT_SCENE_PATH := "res://scenes/word_match_result.tscn"
const WORD_MATCH_SETTING_SCENE_PATH := "res://scenes/word_match_setting.tscn"
const GAME_HUB_SCENE_PATH := "res://scenes/game_hub.tscn"


func _initialize() -> void:
	var result_scene := load(WORD_MATCH_RESULT_SCENE_PATH) as PackedScene
	_assert(result_scene != null, "Word match result scene should load")

	var result_root := result_scene.instantiate()
	result_root.set_results([
		{"id": 1, "name": "玩家2", "matched_pair_count": 4, "error_count": 1, "is_cleared": true, "is_failed": false, "finish_order": 1},
		{"id": 0, "name": "玩家1", "matched_pair_count": 3, "error_count": 0, "is_cleared": true, "is_failed": false, "finish_order": 0},
		{"id": 2, "name": "玩家3", "matched_pair_count": 2, "error_count": 0, "is_cleared": false, "is_failed": true, "finish_order": 2},
	])
	get_root().add_child(result_root)
	await process_frame

	var results_list := result_root.get_node("%ResultsList") as VBoxContainer
	_assert(results_list.get_child_count() == 3, "Result scene should render one row per player")
	var first_row := results_list.get_child(0) as HBoxContainer
	var second_row := results_list.get_child(1) as HBoxContainer
	var third_row := results_list.get_child(2) as HBoxContainer
	_assert((first_row.get_node("NameLabel") as Label).text == "玩家2", "Highest-ranked cleared player should appear first")
	_assert((second_row.get_node("NameLabel") as Label).text == "玩家1", "Second cleared player should appear next")
	_assert((third_row.get_node("StatusLabel") as Label).text == "失败", "Failed players should render their failed status")

	var back_button := result_root.get_node("%BackToHubButton") as Button
	back_button.pressed.emit()
	await process_frame

	var hub_scene := get_root().get_child(get_root().get_child_count() - 1)
	_assert(hub_scene.scene_file_path == GAME_HUB_SCENE_PATH, "Back button should return to the game hub")
	hub_scene.free()

	var replay_root := result_scene.instantiate()
	replay_root.set_results([
		{"id": 0, "name": "玩家1", "matched_pair_count": 1, "error_count": 0, "is_cleared": true, "is_failed": false, "finish_order": 0},
	])
	get_root().add_child(replay_root)
	await process_frame
	var replay_button := replay_root.get_node("%ReplayButton") as Button
	replay_button.pressed.emit()
	await process_frame

	var setting_scene := get_root().get_child(get_root().get_child_count() - 1)
	_assert(setting_scene.scene_file_path == WORD_MATCH_SETTING_SCENE_PATH, "Replay button should return to the word match setting scene")
	setting_scene.free()

	var invalid_root := result_scene.instantiate()
	get_root().add_child(invalid_root)
	await process_frame
	var invalid_fallback_scene := get_root().get_child(get_root().get_child_count() - 1)
	_assert(invalid_fallback_scene.scene_file_path == WORD_MATCH_SETTING_SCENE_PATH, "Opening result without data should return to the word match setting scene")
	invalid_fallback_scene.free()
	quit(0)


func _assert(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	quit(1)
```

Append these exact lines near the end of `scripts/tests/test_word_match_runtime_scene.gd`, just before the final `quit(0)`:

```gdscript
	root._players[1]["matched_pair_count"] = root._required_pair_count()
	root._players[1]["is_cleared"] = true
	root._players[1]["finish_order"] = 1
	root._finished_player_count = root._players.size()
	root._turn_is_waiting = true
	root._on_next_player_requested()
	await process_frame

	var result_scene := get_root().get_child(get_root().get_child_count() - 1)
	_assert(result_scene != null, "Finishing all players should navigate to a result scene")
	_assert(result_scene.scene_file_path == "res://scenes/word_match_result.tscn", "Finishing all players should open the word match result scene")
	result_scene.free()
```

- [ ] **Step 2: Run the result and runtime tests to verify they fail**

Run:
`& "D:\Program Files\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . -s res://scripts/tests/test_word_match_result_scene.gd`

Expected: FAIL because `scenes/word_match_result.tscn` and `scripts/word_match_result.gd` do not exist yet.

Run:
`& "D:\Program Files\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . -s res://scripts/tests/test_word_match_runtime_scene.gd`

Expected: FAIL because the runtime controller cannot yet open the missing result scene.

- [ ] **Step 3: Implement the result scene and complete runtime handoff**

Create `scenes/word_match_result.tscn` with this exact content:

```tscn
[gd_scene format=3]

[ext_resource type="Script" path="res://scripts/word_match_result.gd" id="1_controller"]

[node name="WordMatchResult" type="Control"]
layout_mode = 3
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
grow_horizontal = 2
grow_vertical = 2
script = ExtResource("1_controller")

[node name="Background" type="ColorRect" parent="."]
layout_mode = 1
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
grow_horizontal = 2
grow_vertical = 2
color = Color(0.08, 0.1, 0.14, 1)

[node name="Margin" type="MarginContainer" parent="."]
layout_mode = 1
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
grow_horizontal = 2
grow_vertical = 2
theme_override_constants/margin_left = 100
theme_override_constants/margin_top = 80
theme_override_constants/margin_right = 100
theme_override_constants/margin_bottom = 80

[node name="RootVBox" type="VBoxContainer" parent="Margin"]
layout_mode = 2
theme_override_constants/separation = 16

[node name="TitleLabel" type="Label" parent="Margin/RootVBox"]
layout_mode = 2
text = "Word Match 结算"
horizontal_alignment = 1

[node name="ResultsList" type="VBoxContainer" parent="Margin/RootVBox"]
unique_name_in_owner = true
layout_mode = 2
size_flags_vertical = 3
theme_override_constants/separation = 10

[node name="ActionRow" type="HBoxContainer" parent="Margin/RootVBox"]
layout_mode = 2
theme_override_constants/separation = 12

[node name="ReplayButton" type="Button" parent="Margin/RootVBox/ActionRow"]
unique_name_in_owner = true
layout_mode = 2
size_flags_horizontal = 3
text = "再玩一次"

[node name="BackToHubButton" type="Button" parent="Margin/RootVBox/ActionRow"]
unique_name_in_owner = true
layout_mode = 2
size_flags_horizontal = 3
text = "返回游戏选择"
```

Create `scripts/word_match_result.gd` with this exact content:

```gdscript
extends Control

const WORD_MATCH_SETTING_SCENE_PATH := "res://scenes/word_match_setting.tscn"
const GAME_HUB_SCENE_PATH := "res://scenes/game_hub.tscn"

var _pending_results: Array[Dictionary] = []

@onready var results_list: VBoxContainer = %ResultsList
@onready var replay_button: Button = %ReplayButton
@onready var back_button: Button = %BackToHubButton


func _ready() -> void:
	replay_button.pressed.connect(func() -> void: get_tree().change_scene_to_file(WORD_MATCH_SETTING_SCENE_PATH))
	back_button.pressed.connect(func() -> void: get_tree().change_scene_to_file(GAME_HUB_SCENE_PATH))
	if _pending_results.is_empty():
		get_tree().change_scene_to_file(WORD_MATCH_SETTING_SCENE_PATH)
		return
	_render_results(_pending_results)


func set_results(results: Array[Dictionary]) -> void:
	_pending_results = results.duplicate(true)
	if is_node_ready() and not _pending_results.is_empty():
		_render_results(_pending_results)


func _render_results(results: Array[Dictionary]) -> void:
	for child in results_list.get_children():
		child.queue_free()

	for index in range(results.size()):
		var player := results[index] as Dictionary
		var row := HBoxContainer.new()
		row.name = "ResultRow%d" % index
		row.theme_override_constants.separation = 12

		var rank_label := Label.new()
		rank_label.name = "RankLabel"
		rank_label.text = "#%d" % (index + 1)
		rank_label.custom_minimum_size = Vector2(60, 0)

		var name_label := Label.new()
		name_label.name = "NameLabel"
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_label.text = String(player.get("name", ""))

		var pairs_label := Label.new()
		pairs_label.name = "PairsLabel"
		pairs_label.text = "匹配 %d" % int(player.get("matched_pair_count", 0))

		var errors_label := Label.new()
		errors_label.name = "ErrorsLabel"
		errors_label.text = "错误 %d" % int(player.get("error_count", 0))

		var status_label := Label.new()
		status_label.name = "StatusLabel"
		status_label.text = "通关" if bool(player.get("is_cleared", false)) else "失败"

		row.add_child(rank_label)
		row.add_child(name_label)
		row.add_child(pairs_label)
		row.add_child(errors_label)
		row.add_child(status_label)
		results_list.add_child(row)
```

Do not change `scripts/word_match_game.gd` beyond keeping `_open_result_scene()` exactly as written in Task 3. It already instantiates `set_results(results)` on the target scene once the scene file exists.

- [ ] **Step 4: Run the runtime test, result test, and full poison regression**

Run:
`& "D:\Program Files\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . -s res://scripts/tests/test_word_match_runtime_scene.gd`

Expected: PASS with exit code `0`, including the final handoff into `word_match_result.tscn`.

Run:
`& "D:\Program Files\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . -s res://scripts/tests/test_word_match_result_scene.gd`

Expected: PASS with exit code `0`.

Run:
`& "D:\Program Files\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . -s res://scripts/tests/test_game_hub_scene.gd`

Expected: PASS with exit code `0`.

Run:
`& "D:\Program Files\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . -s res://scripts/tests/test_word_match_setting_scene.gd`

Expected: PASS with exit code `0`.

Run:
`& "D:\Program Files\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . -s res://scripts/tests/test_game_setting_scene.gd`

Expected: PASS with exit code `0`.

Run:
`& "D:\Program Files\Godot\Godot_v4.6.1-stable_win64_console.exe" --headless --path . -s res://scripts/tests/test_word_poison_runtime_scene.gd`

Expected: PASS with exit code `0`.

- [ ] **Step 5: Checkpoint without git**

Workspace note: this workspace is not a git repo, so do not run a commit. Keep the checkpoint limited to:

- `scenes/word_match_result.tscn`
- `scripts/word_match_result.gd`
- `scripts/tests/test_word_match_result_scene.gd`
- `scripts/tests/test_word_match_runtime_scene.gd`
- all files from Tasks 1-3 that are still part of the final diff
