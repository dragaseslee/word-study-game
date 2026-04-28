# Game Setting Panel Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Upgrade `scenes/game_setting.tscn` into a single-page custom settings scene with image attachment points for the main panel, dropdown shells, buttons, and player rows.

**Architecture:** Keep the scene Godot-native: one upgraded `Control` scene, one focused controller script for runtime state, and one lightweight headless verification script that asserts the expected scene structure and interactive behavior. Decorative image nodes stay separate from real controls so the user can replace textures without changing script paths.

**Tech Stack:** Godot 4.6, GDScript, `.tscn` scenes, existing `WordSetStore` parsing/import logic

---

## File Structure

- Modify: `scenes/game_setting.tscn`
  - Replace the current proof-of-concept panel crop with a complete two-column settings scene.
- Create: `scripts/game_setting.gd`
  - Own the new settings page state: word-set list, selected layout, player count, player rows, status text, button state.
- Modify: `scripts/game_hub.gd`
  - Route the witch's potion entry card to `res://scenes/game_setting.tscn` instead of directly opening gameplay.
- Create: `scripts/tests/test_game_setting_scene.gd`
  - Headless verification script that loads the scene and asserts the required named nodes and basic runtime behavior.
- Reuse: `scripts/word_set_store.gd`
  - No code change required in the first pass; the new controller should instantiate and call it directly.

## Verification Commands

- Scene structure verification:
  - `godot --headless --path "." -s res://scripts/tests/test_game_setting_scene.gd`
- Project smoke test:
  - `godot --headless --path "." --quit-after 1`

If the local Godot executable is named differently, substitute the project's installed Godot 4 binary while keeping the same arguments.

### Task 1: Add a Headless Verification Script

**Files:**
- Create: `scripts/tests/test_game_setting_scene.gd`
- Test: `scripts/tests/test_game_setting_scene.gd`

- [ ] **Step 1: Write the failing verification script**

```gdscript
extends SceneTree

const SCENE_PATH := "res://scenes/game_setting.tscn"


func _initialize() -> void:
	var packed_scene := load(SCENE_PATH) as PackedScene
	_assert(packed_scene != null, "Game setting scene should load")

	var root := packed_scene.instantiate()
	_assert(root != null, "Game setting scene should instantiate")

	_assert(root.has_node("BackgroundLayer"), "BackgroundLayer node missing")
	_assert(root.has_node("ScreenMargin/PanelCenter/MainPanelRoot/MainPanelBg"), "Main panel background missing")
	_assert(root.has_node("ScreenMargin/PanelCenter/MainPanelRoot/PanelContentMargin/ContentColumns/LeftColumn/WordSetSection"), "Word set section missing")
	_assert(root.has_node("ScreenMargin/PanelCenter/MainPanelRoot/PanelContentMargin/ContentColumns/LeftColumn/LayoutSection"), "Layout section missing")
	_assert(root.has_node("ScreenMargin/PanelCenter/MainPanelRoot/PanelContentMargin/ContentColumns/RightColumn/PlayerCountSection"), "Player count section missing")
	_assert(root.has_node("ScreenMargin/PanelCenter/MainPanelRoot/PanelContentMargin/ContentColumns/RightColumn/PlayerListSection"), "Player list section missing")
	_assert(root.has_node("ScreenMargin/PanelCenter/MainPanelRoot/PanelContentMargin/ContentColumns/RightColumn/ActionSection"), "Action section missing")

	var script := root.get_script()
	_assert(script != null, "Game setting controller script missing")

	root.free()
	quit(0)


func _assert(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	quit(1)
```

- [ ] **Step 2: Run the verifier and confirm it fails**

Run: `godot --headless --path "." -s res://scripts/tests/test_game_setting_scene.gd`
Expected: FAIL because the current `game_setting.tscn` only contains a single texture crop and does not yet expose the required node tree or controller script.

- [ ] **Step 3: Commit the failing test scaffold**

```bash
git add scripts/tests/test_game_setting_scene.gd
git commit -m "test: add game setting scene verifier"
```

### Task 2: Replace the Proof-of-Concept Scene With the Full Panel Skeleton

**Files:**
- Modify: `scenes/game_setting.tscn`
- Test: `scripts/tests/test_game_setting_scene.gd`

- [ ] **Step 1: Replace the current scene header and add the controller script resource**

```tscn
[gd_scene format=3 uid="uid://dliv6jfeaicib"]

[ext_resource type="Script" path="res://scripts/game_setting.gd" id="1_controller"]
[ext_resource type="Texture2D" uid="uid://b7775wlgpbtij" path="res://asserts/background.png" id="2_background"]
[ext_resource type="Texture2D" uid="uid://gq8iy32fvp1f" path="res://asserts/panel_design.png" id="3_panel"]
[ext_resource type="Texture2D" path="res://asserts/layout_choose.png" id="4_dropdown"]
[ext_resource type="Texture2D" path="res://asserts/button_general.png" id="5_button"]
```

- [ ] **Step 2: Build the top-level scene shell with named image attachment points**

```tscn
[node name="GameSetting" type="Control"]
layout_mode = 3
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
grow_horizontal = 2
grow_vertical = 2
script = ExtResource("1_controller")

[node name="BackgroundLayer" type="TextureRect" parent="."]
layout_mode = 1
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
grow_horizontal = 2
grow_vertical = 2
texture = ExtResource("2_background")
expand_mode = 1
stretch_mode = 6

[node name="ScreenMargin" type="MarginContainer" parent="."]
layout_mode = 1
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
grow_horizontal = 2
grow_vertical = 2
theme_override_constants/margin_left = 48
theme_override_constants/margin_top = 48
theme_override_constants/margin_right = 48
theme_override_constants/margin_bottom = 48

[node name="PanelCenter" type="CenterContainer" parent="ScreenMargin"]
layout_mode = 2

[node name="MainPanelRoot" type="Control" parent="ScreenMargin/PanelCenter"]
custom_minimum_size = Vector2(1280, 760)
layout_mode = 2

[node name="MainPanelBg" type="TextureRect" parent="ScreenMargin/PanelCenter/MainPanelRoot"]
layout_mode = 1
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
grow_horizontal = 2
grow_vertical = 2
texture = ExtResource("3_panel")
expand_mode = 1
stretch_mode = 5

[node name="PanelContentMargin" type="MarginContainer" parent="ScreenMargin/PanelCenter/MainPanelRoot"]
layout_mode = 1
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
grow_horizontal = 2
grow_vertical = 2
theme_override_constants/margin_left = 72
theme_override_constants/margin_top = 72
theme_override_constants/margin_right = 72
theme_override_constants/margin_bottom = 60

[node name="ContentColumns" type="HBoxContainer" parent="ScreenMargin/PanelCenter/MainPanelRoot/PanelContentMargin"]
layout_mode = 2
theme_override_constants/separation = 32
```

- [ ] **Step 3: Add the left column sections and real interactive controls**

```tscn
[node name="LeftColumn" type="VBoxContainer" parent="ScreenMargin/PanelCenter/MainPanelRoot/PanelContentMargin/ContentColumns"]
layout_mode = 2
size_flags_horizontal = 3
theme_override_constants/separation = 24

[node name="WordSetSection" type="PanelContainer" parent="ScreenMargin/PanelCenter/MainPanelRoot/PanelContentMargin/ContentColumns/LeftColumn"]
layout_mode = 2
size_flags_vertical = 3

[node name="WordSetSectionContent" type="MarginContainer" parent="ScreenMargin/PanelCenter/MainPanelRoot/PanelContentMargin/ContentColumns/LeftColumn/WordSetSection"]
layout_mode = 2

[node name="WordSetVBox" type="VBoxContainer" parent="ScreenMargin/PanelCenter/MainPanelRoot/PanelContentMargin/ContentColumns/LeftColumn/WordSetSection/WordSetSectionContent"]
layout_mode = 2

[node name="WordSetDropdownShell" type="Control" parent="ScreenMargin/PanelCenter/MainPanelRoot/PanelContentMargin/ContentColumns/LeftColumn/WordSetSection/WordSetSectionContent/WordSetVBox"]
custom_minimum_size = Vector2(0, 72)

[node name="WordSetDropdownBg" type="TextureRect" parent="ScreenMargin/PanelCenter/MainPanelRoot/PanelContentMargin/ContentColumns/LeftColumn/WordSetSection/WordSetSectionContent/WordSetVBox/WordSetDropdownShell"]
layout_mode = 1
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
texture = ExtResource("4_dropdown")
expand_mode = 1
stretch_mode = 5

[node name="WordSetOption" type="OptionButton" parent="ScreenMargin/PanelCenter/MainPanelRoot/PanelContentMargin/ContentColumns/LeftColumn/WordSetSection/WordSetSectionContent/WordSetVBox/WordSetDropdownShell"]
unique_name_in_owner = true
layout_mode = 1
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0

[node name="LayoutSection" type="PanelContainer" parent="ScreenMargin/PanelCenter/MainPanelRoot/PanelContentMargin/ContentColumns/LeftColumn"]
layout_mode = 2
size_flags_vertical = 3

[node name="LayoutDropdownShell" type="Control" parent="ScreenMargin/PanelCenter/MainPanelRoot/PanelContentMargin/ContentColumns/LeftColumn/LayoutSection"]
custom_minimum_size = Vector2(0, 72)

[node name="LayoutDropdownBg" type="TextureRect" parent="ScreenMargin/PanelCenter/MainPanelRoot/PanelContentMargin/ContentColumns/LeftColumn/LayoutSection/LayoutDropdownShell"]
layout_mode = 1
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
texture = ExtResource("4_dropdown")

[node name="LayoutOption" type="OptionButton" parent="ScreenMargin/PanelCenter/MainPanelRoot/PanelContentMargin/ContentColumns/LeftColumn/LayoutSection/LayoutDropdownShell"]
unique_name_in_owner = true
layout_mode = 1
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
```

- [ ] **Step 4: Add the right column sections, stepper, player list, and actions**

```tscn
[node name="RightColumn" type="VBoxContainer" parent="ScreenMargin/PanelCenter/MainPanelRoot/PanelContentMargin/ContentColumns"]
layout_mode = 2
custom_minimum_size = Vector2(420, 0)
theme_override_constants/separation = 24

[node name="PlayerCountSection" type="PanelContainer" parent="ScreenMargin/PanelCenter/MainPanelRoot/PanelContentMargin/ContentColumns/RightColumn"]
layout_mode = 2

[node name="MinusButton" type="Button" parent="ScreenMargin/PanelCenter/MainPanelRoot/PanelContentMargin/ContentColumns/RightColumn/PlayerCountSection"]
unique_name_in_owner = true
text = "-"

[node name="PlayerCountValue" type="Label" parent="ScreenMargin/PanelCenter/MainPanelRoot/PanelContentMargin/ContentColumns/RightColumn/PlayerCountSection"]
unique_name_in_owner = true
text = "1"

[node name="PlusButton" type="Button" parent="ScreenMargin/PanelCenter/MainPanelRoot/PanelContentMargin/ContentColumns/RightColumn/PlayerCountSection"]
unique_name_in_owner = true
text = "+"

[node name="PlayerListSection" type="PanelContainer" parent="ScreenMargin/PanelCenter/MainPanelRoot/PanelContentMargin/ContentColumns/RightColumn"]
layout_mode = 2
size_flags_vertical = 3

[node name="PlayerListScroll" type="ScrollContainer" parent="ScreenMargin/PanelCenter/MainPanelRoot/PanelContentMargin/ContentColumns/RightColumn/PlayerListSection"]
layout_mode = 2
size_flags_vertical = 3

[node name="PlayerList" type="VBoxContainer" parent="ScreenMargin/PanelCenter/MainPanelRoot/PanelContentMargin/ContentColumns/RightColumn/PlayerListSection/PlayerListScroll"]
unique_name_in_owner = true
layout_mode = 2

[node name="ActionSection" type="PanelContainer" parent="ScreenMargin/PanelCenter/MainPanelRoot/PanelContentMargin/ContentColumns/RightColumn"]
layout_mode = 2

[node name="StatusLabel" type="Label" parent="ScreenMargin/PanelCenter/MainPanelRoot/PanelContentMargin/ContentColumns/RightColumn/ActionSection"]
unique_name_in_owner = true
text = "请选择词表、布局和玩家数量"

[node name="BackButton" type="Button" parent="ScreenMargin/PanelCenter/MainPanelRoot/PanelContentMargin/ContentColumns/RightColumn/ActionSection"]
unique_name_in_owner = true
text = "返回"

[node name="StartButton" type="Button" parent="ScreenMargin/PanelCenter/MainPanelRoot/PanelContentMargin/ContentColumns/RightColumn/ActionSection"]
unique_name_in_owner = true
text = "开始游戏"
```

- [ ] **Step 5: Run the verifier again and confirm the scene still fails only because the script is missing**

Run: `godot --headless --path "." -s res://scripts/tests/test_game_setting_scene.gd`
Expected: FAIL with a controller-script-related assertion instead of node-missing assertions.

- [ ] **Step 6: Commit the scene skeleton**

```bash
git add scenes/game_setting.tscn
git commit -m "feat: add custom game setting panel skeleton"
```

### Task 3: Implement the Settings Controller and Runtime Rows

**Files:**
- Create: `scripts/game_setting.gd`
- Modify: `scripts/tests/test_game_setting_scene.gd`
- Test: `scripts/tests/test_game_setting_scene.gd`

- [ ] **Step 1: Extend the verifier to assert runtime defaults and player row rendering**

```gdscript
	root._ready()

	var player_count_label := root.get_node("%PlayerCountValue") as Label
	_assert(player_count_label.text == "1", "Default player count should be 1")

	var player_list := root.get_node("%PlayerList") as VBoxContainer
	_assert(player_list.get_child_count() == 1, "Default player row should be rendered")

	var start_button := root.get_node("%StartButton") as Button
	_assert(start_button.disabled, "Start button should be disabled before selecting a word set")
```

- [ ] **Step 2: Run the verifier and confirm it fails because the controller behavior is missing**

Run: `godot --headless --path "." -s res://scripts/tests/test_game_setting_scene.gd`
Expected: FAIL because `_ready()` does not yet populate the dropdowns, player count label, list rows, or button state.

- [ ] **Step 3: Create the controller with focused state and bindings**

```gdscript
extends Control

const MIN_PLAYERS := 1
const MAX_PLAYERS := 10

var _store := WordSetStore.new()
var _word_sets: Array[Dictionary] = []
var _selected_word_set: Dictionary = {}
var _board_size := 4
var _players: Array[Dictionary] = []

@onready var word_set_option: OptionButton = %WordSetOption
@onready var layout_option: OptionButton = %LayoutOption
@onready var player_count_value: Label = %PlayerCountValue
@onready var player_list: VBoxContainer = %PlayerList
@onready var status_label: Label = %StatusLabel
@onready var start_button: Button = %StartButton
@onready var back_button: Button = %BackButton
@onready var plus_button: Button = %PlusButton
@onready var minus_button: Button = %MinusButton


func _ready() -> void:
	randomize()
	_players = [_make_player(0)]
	_setup_layout_options()
	_setup_word_set_options()
	plus_button.pressed.connect(_on_plus_pressed)
	minus_button.pressed.connect(_on_minus_pressed)
	word_set_option.item_selected.connect(_on_word_set_selected)
	layout_option.item_selected.connect(_on_layout_selected)
	back_button.pressed.connect(_on_back_pressed)
	start_button.pressed.connect(_on_start_pressed)
	_render_players()
	_update_status()
```

- [ ] **Step 4: Implement the dropdown setup, player stepper, and player row rendering**

```gdscript
func _setup_layout_options() -> void:
	layout_option.clear()
	layout_option.add_item("3 x 3", 3)
	layout_option.add_item("4 x 4", 4)
	layout_option.add_item("5 x 5", 5)
	_select_layout(_board_size)


func _setup_word_set_options() -> void:
	_word_sets = _store.list_word_sets()
	word_set_option.clear()
	if _word_sets.is_empty():
		word_set_option.add_item("暂无可用词表", -1)
		word_set_option.disabled = true
		_selected_word_set = {}
		return

	word_set_option.disabled = false
	for index in range(_word_sets.size()):
		var item := _word_sets[index]
		word_set_option.add_item(String(item.get("file_name", "")), index)
	_selected_word_set = _word_sets[0]
	word_set_option.select(0)


func _on_plus_pressed() -> void:
	if _players.size() >= MAX_PLAYERS:
		return
	_players.append(_make_player(_players.size()))
	_render_players()
	_update_status()


func _on_minus_pressed() -> void:
	if _players.size() <= MIN_PLAYERS:
		return
	_players.remove_at(_players.size() - 1)
	_reindex_players()
	_render_players()
	_update_status()


func _render_players() -> void:
	for child in player_list.get_children():
		child.queue_free()

	for index in range(_players.size()):
		var row := HBoxContainer.new()
		row.name = "PlayerRow%d" % index

		var slot_bg := ColorRect.new()
		slot_bg.name = "PlayerRowBg"
		slot_bg.color = Color(0.16, 0.12, 0.20, 0.55)
		slot_bg.custom_minimum_size = Vector2(0, 56)

		var name_edit := LineEdit.new()
		name_edit.text = String(_players[index].get("name", ""))
		name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_edit.text_changed.connect(_on_player_name_changed.bind(index))

		var remove_button := Button.new()
		remove_button.text = "删除"
		remove_button.disabled = _players.size() <= MIN_PLAYERS
		remove_button.pressed.connect(_on_remove_player_pressed.bind(index))

		row.add_child(slot_bg)
		row.add_child(name_edit)
		row.add_child(remove_button)
		player_list.add_child(row)

	player_count_value.text = str(_players.size())
	minus_button.disabled = _players.size() <= MIN_PLAYERS
	plus_button.disabled = _players.size() >= MAX_PLAYERS
```

- [ ] **Step 5: Implement selection updates, row deletion, and status text**

```gdscript
func _on_word_set_selected(index: int) -> void:
	if index < 0 or index >= _word_sets.size():
		_selected_word_set = {}
	else:
		_selected_word_set = _word_sets[index]
	_update_status()


func _on_layout_selected(index: int) -> void:
	_board_size = layout_option.get_item_id(index)
	_update_status()


func _on_player_name_changed(new_text: String, index: int) -> void:
	if index >= 0 and index < _players.size():
		_players[index]["name"] = new_text
	_update_status()


func _on_remove_player_pressed(index: int) -> void:
	if _players.size() <= MIN_PLAYERS:
		return
	_players.remove_at(index)
	_reindex_players()
	_render_players()
	_update_status()


func _update_status() -> void:
	var word_set_name := "未选择词表"
	if not _selected_word_set.is_empty():
		word_set_name = String(_selected_word_set.get("file_name", ""))
	status_label.text = "%s | %d x %d | %d 人" % [word_set_name, _board_size, _board_size, _players.size()]
	start_button.disabled = _selected_word_set.is_empty()
```

- [ ] **Step 6: Add helper methods and navigation behavior**

```gdscript
func _make_player(index: int) -> Dictionary:
	return {
		"id": index,
		"name": "玩家%d" % (index + 1),
	}


func _reindex_players() -> void:
	for index in range(_players.size()):
		_players[index]["id"] = index
		if String(_players[index].get("name", "")).strip_edges().is_empty():
			_players[index]["name"] = "玩家%d" % (index + 1)


func _select_layout(board_size: int) -> void:
	for index in range(layout_option.item_count):
		if layout_option.get_item_id(index) == board_size:
			layout_option.select(index)
			return


func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/game_hub.tscn")


func _on_start_pressed() -> void:
	_update_status()
```

- [ ] **Step 7: Run the verifier and confirm it passes**

Run: `godot --headless --path "." -s res://scripts/tests/test_game_setting_scene.gd`
Expected: PASS with exit code `0` and no `push_error` output.

- [ ] **Step 8: Commit the controller work**

```bash
git add scripts/game_setting.gd scripts/tests/test_game_setting_scene.gd
git commit -m "feat: add interactive game setting controller"
```

### Task 4: Wire the Entry Point and Run Smoke Verification

**Files:**
- Modify: `scripts/game_hub.gd`
- Test: `scripts/tests/test_game_setting_scene.gd`

- [ ] **Step 1: Change the entry scene constant to open the settings page**

```gdscript
const WORD_POISON_SCENE := "res://scenes/game_setting.tscn"
```

- [ ] **Step 2: Run the scene verifier one more time**

Run: `godot --headless --path "." -s res://scripts/tests/test_game_setting_scene.gd`
Expected: PASS.

- [ ] **Step 3: Run a full project smoke test**

Run: `godot --headless --path "." --quit-after 1`
Expected: PASS with no parse errors so the upgraded scene and new script both load cleanly at project start.

- [ ] **Step 4: Commit the route update**

```bash
git add scripts/game_hub.gd
git commit -m "feat: route hub entry to custom settings panel"
```

## Asset Hookup Checklist

After implementation, the user should be able to bind or replace art on these nodes without changing logic paths:

- `BackgroundLayer`: full-screen backdrop
- `MainPanelBg`: large central panel image
- `WordSetDropdownBg`: word-set dropdown shell image
- `LayoutDropdownBg`: layout dropdown shell image
- `WordSetSection`: left-top module frame styling
- `LayoutSection`: left-bottom module frame styling
- `PlayerCountSection`: right-top module frame styling
- `PlayerListSection`: player-list frame styling
- `ActionSection`: bottom action frame styling
- `BackButton` and `StartButton`: main action button textures or styleboxes
- runtime `PlayerRowBg` nodes inside `PlayerList`: per-player slot styling

## Self-Review

- Spec coverage check:
  - single-page upgraded `game_setting.tscn`: covered in Task 2
  - left/right split panel: covered in Task 2
  - word-set dropdown plus preview-capable section: covered in Task 2 and Task 3
  - layout dropdown section: covered in Task 2 and Task 3
  - player stepper plus removable player rows: covered in Task 3
  - explicit asset binding points: covered in Task 2 and Asset Hookup Checklist
  - hub access for previewing the scene in-project: covered in Task 4
- Placeholder scan:
  - removed vague “implement later” language; all file paths, commands, and code targets are named directly
- Type consistency:
  - the plan consistently uses `WordSetOption`, `LayoutOption`, `PlayerList`, `PlayerCountValue`, `StartButton`, and `game_setting.gd`
