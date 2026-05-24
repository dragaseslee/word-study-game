# WordComplete Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Create a new "补全单词" (WordComplete) two-player game where players fill in missing letters of English words.

**Architecture:** Follows the existing MVVM pattern: Config → GameDef → 3 ViewModels → 3 Views. Each player has their own letter grid inside their panel; inactive player is grayed out. Uses `WordSetStore` for word data and `themes/word_race.tres` for theming.

**Tech Stack:** Godot 4.6, GDScript, MVVM framework (`GameView`, `ViewModel`, `GameDef`)

---

## File Map

| Action | File | Purpose |
|--------|------|---------|
| Create | `games/word_complete/complete_config.gd` | Config constants, build, validate |
| Create | `games/word_complete/complete_def.gd` | GameDef subclass |
| Create | `games/word_complete/view_models/complete_setting_vm.gd` | Setting screen VM |
| Create | `games/word_complete/view_models/complete_gameplay_vm.gd` | Gameplay VM (core logic) |
| Create | `games/word_complete/view_models/complete_result_vm.gd` | Result screen VM |
| Create | `games/word_complete/views/setting_view.tscn` | Setting scene |
| Create | `games/word_complete/views/setting_view.gd` | Setting view script |
| Create | `games/word_complete/views/gameplay_view.tscn` | Gameplay scene |
| Create | `games/word_complete/views/gameplay_view.gd` | Gameplay view script |
| Create | `games/word_complete/views/result_view.tscn` | Result scene |
| Create | `games/word_complete/views/result_view.gd` | Result view script |
| Modify | `core/autoload/game_registry.gd` | Register game |
| Modify | `core/autoload/scene_router.gd` | Add 3 routes |
| Modify | `scripts/game_hub.gd` | Add hub button wiring |
| Modify | `scenes/game_hub.tscn` | Add hub button node |

---

### Task 1: Create CompleteConfig

**Files:**
- Create: `games/word_complete/complete_config.gd`

- [ ] **Step 1: Create directory structure**

```bash
mkdir -p games/word_complete/view_models games/word_complete/views
```

- [ ] **Step 2: Write complete_config.gd**

```gdscript
class_name CompleteConfig
extends RefCounted

const MIN_ROUND_COUNT := 1
const MAX_ROUND_COUNT := 50
const DEFAULT_ROUND_COUNT := 10
const DISTRACTOR_COUNT := 10


static func normalize_round_count(value: int) -> int:
    return clampi(value, MIN_ROUND_COUNT, MAX_ROUND_COUNT)


static func build_config(
    word_set: Dictionary,
    round_count: int,
    players: Array[Dictionary]
) -> Dictionary:
    return {
        "game_type": "word_complete",
        "word_set": word_set.duplicate(true),
        "round_count": normalize_round_count(round_count),
        "players": _normalize_players(players),
    }


static func validate_config(config: Dictionary) -> Dictionary:
    if String(config.get("game_type", "")) != "word_complete":
        return {}
    var word_set := Dictionary(config.get("word_set", {})).duplicate(true)
    if String(word_set.get("file_path", "")).strip_edges().is_empty():
        return {}
    var players := _normalize_players(config.get("players", []) as Array)
    if players.size() < 2:
        return {}
    return {
        "game_type": "word_complete",
        "word_set": word_set,
        "round_count": normalize_round_count(int(config.get("round_count", DEFAULT_ROUND_COUNT))),
        "players": players,
    }


static func _normalize_players(player_seeds: Array) -> Array[Dictionary]:
    var normalized: Array[Dictionary] = []
    for index in range(min(player_seeds.size(), 2)):
        var seed := player_seeds[index] as Dictionary
        var name := String(seed.get("name", "")).strip_edges() if seed != null else ""
        if name.is_empty():
            name = "玩家%d" % (index + 1)
        normalized.append({"id": index, "name": name})
    return normalized
```

- [ ] **Step 3: Validate with Godot headless**

```bash
"/home/dragaseslee/godot/Godot_v4.6.2-stable_linux.x86_64" --headless --path . --check-only --script res://games/word_complete/complete_config.gd
```

Expected: No errors (script is standalone, no scene dependencies).

- [ ] **Step 4: Commit**

```bash
git add games/word_complete/complete_config.gd
git commit -m "feat(word-complete): add config class"
```

---

### Task 2: Create CompleteDef

**Files:**
- Create: `games/word_complete/complete_def.gd`

- [ ] **Step 1: Write complete_def.gd**

```gdscript
extends GameDef


func _init() -> void:
    game_id = "word_complete"
    display_name = "补全单词"
    display_order = 4
    icon_path = "res://asserts/buttons/button_word_complete.png"
    setting_scene = "res://games/word_complete/views/setting_view.tscn"
    gameplay_scene = "res://games/word_complete/views/gameplay_view.tscn"
    result_scene = "res://games/word_complete/views/result_view.tscn"
    bgm_stream = null


func create_setting_vm() -> ViewModel:
    return CompleteSettingVM.new()


func create_gameplay_vm() -> ViewModel:
    return CompleteGameplayVM.new()


func create_result_vm() -> ViewModel:
    return CompleteResultVM.new()
```

- [ ] **Step 2: Validate**

```bash
"/home/dragaseslee/godot/Godot_v4.6.2-stable_linux.x86_64" --headless --path . --check-only --script res://games/word_complete/complete_def.gd
```

Expected: May warn about missing VM classes (not yet created). That's OK.

- [ ] **Step 3: Commit**

```bash
git add games/word_complete/complete_def.gd
git commit -m "feat(word-complete): add game definition"
```

---

### Task 3: Create CompleteSettingVM

**Files:**
- Create: `games/word_complete/view_models/complete_setting_vm.gd`

- [ ] **Step 1: Write complete_setting_vm.gd**

```gdscript
class_name CompleteSettingVM
extends ViewModel

var _word_sets: Array[Dictionary] = []
var _selected_word_set: Dictionary = {}
var _round_count := 10
var _players: Array[Dictionary] = []


func _on_initialize(_config: Dictionary) -> void:
    _players = [{"name": "玩家A"}, {"name": "玩家B"}]
    _refresh_word_sets()


func select_word_set(index: int) -> void:
    if index < 0 or index >= _word_sets.size():
        _selected_word_set = {}
    else:
        _selected_word_set = _word_sets[index].duplicate(true)
    notify_view()


func set_round_count(value: int) -> void:
    _round_count = CompleteConfig.normalize_round_count(value)
    notify_view()


func set_player_name(index: int, name: String) -> void:
    if index < 0 or index >= _players.size():
        return
    _players[index]["name"] = name
    notify_view()


func import_word_set(source_path: String) -> Dictionary:
    var result := WordSetStore.import_word_set(source_path)
    if bool(result.get("ok", false)):
        _selected_word_set = {
            "file_name": result.get("file_name", ""),
            "file_path": result.get("file_path", ""),
            "word_count": int(result.get("word_count", 0)),
        }
        _refresh_word_sets()
    return result


func can_start() -> bool:
    if _word_sets.is_empty():
        return false
    if _selected_word_set.is_empty():
        return false
    if int(_selected_word_set.get("word_count", 0)) < 2:
        return false
    return true


func status_text() -> String:
    if _word_sets.is_empty():
        return "暂无可用词表，请先导入词表"
    if _selected_word_set.is_empty():
        return "请先选择词表"
    if int(_selected_word_set.get("word_count", 0)) < 2:
        return "词表单词不足，至少需要 2 个单词"
    return "已选择 %s，可开始游戏" % String(_selected_word_set.get("file_name", ""))


func start_game() -> Dictionary:
    if not can_start():
        return {}
    return CompleteConfig.build_config(
        _selected_word_set,
        _round_count,
        _players,
    )


func _refresh_word_sets() -> void:
    _word_sets = WordSetStore.list_word_sets()
    if _selected_word_set.is_empty() and not _word_sets.is_empty():
        _selected_word_set = _word_sets[0].duplicate(true)


func build_view_data() -> Dictionary:
    return {
        "word_sets": _word_sets,
        "selected_word_set": _selected_word_set,
        "round_count": _round_count,
        "players": _players,
        "can_start": can_start(),
        "status_text": status_text(),
    }
```

- [ ] **Step 2: Validate**

```bash
"/home/dragaseslee/godot/Godot_v4.6.2-stable_linux.x86_64" --headless --path . --check-only --script res://games/word_complete/view_models/complete_setting_vm.gd
```

- [ ] **Step 3: Commit**

```bash
git add games/word_complete/view_models/complete_setting_vm.gd
git commit -m "feat(word-complete): add setting view model"
```

---

### Task 4: Create CompleteGameplayVM

**Files:**
- Create: `games/word_complete/view_models/complete_gameplay_vm.gd`

This is the core logic file. Key differences from RaceGameplayVM:
- No cooldown system (turn-based, not real-time)
- Tracks `active_player_index` instead of per-player cooldown
- `select_letter(letter)` replaces `on_option_pressed(player_index, option_index)`
- Generates masked word with one missing letter
- Generates distractor letters

- [ ] **Step 1: Write complete_gameplay_vm.gd**

```gdscript
class_name CompleteGameplayVM
extends ViewModel

signal game_finished

var _config: Dictionary = {}
var _selected_word_set: Dictionary = {}
var _all_words: Array[Dictionary] = []
var _total_rounds: int = 10
var _current_round: int = 0
var _current_word: Dictionary = {}
var _missing_index: int = -1
var _correct_letter: String = ""
var _letters: Array[String] = []
var _players: Array[Dictionary] = []
var _active_player_index: int = 0
var _game_finished: bool = false
var _used_word_indices: Array[int] = []


func _on_initialize(config: Dictionary) -> void:
    var validated_config := CompleteConfig.validate_config(config)
    if validated_config.is_empty():
        return
    _config = validated_config
    _selected_word_set = Dictionary(_config.get("word_set", {})).duplicate(true)
    _all_words = WordSetStore.parse_word_file(String(_selected_word_set.get("file_path", "")))
    _total_rounds = int(_config.get("round_count", 10))

    if _all_words.size() < 2:
        return

    _init_players()
    _start_new_round()


func is_initialized() -> bool:
    return not _players.is_empty()


func select_letter(letter: String) -> void:
    if _game_finished:
        return

    var player := _players[_active_player_index]
    if player.get("is_waiting", false):
        return

    if letter.to_upper() == _correct_letter.to_upper():
        # 答对
        player["score"] = int(player.get("score", 0)) + 1
        player["correct_count"] = int(player.get("correct_count", 0)) + 1
        _players[_active_player_index] = player
        _current_round += 1
        if _current_round >= _total_rounds:
            _game_finished = true
            game_finished.emit()
            notify_view()
        else:
            _start_new_round()
    else:
        # 答错，切换活跃玩家
        player["error_count"] = int(player.get("error_count", 0)) + 1
        _players[_active_player_index] = player
        _active_player_index = (_active_player_index + 1) % _players.size()
        notify_view()


func request_end_game() -> void:
    _open_result_scene()


func get_sorted_results() -> Array[Dictionary]:
    var results: Array[Dictionary] = []
    for player in _players:
        results.append(player.duplicate(true))
    results.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
        var score_a := int(a.get("score", 0))
        var score_b := int(b.get("score", 0))
        return score_a > score_b
    )
    return results


func _init_players() -> void:
    _players.clear()
    var player_seeds := _config.get("players", []) as Array
    for index in range(player_seeds.size()):
        var seed := player_seeds[index] as Dictionary
        var player_name := String(seed.get("name", "")).strip_edges()
        if player_name.is_empty():
            player_name = "玩家%d" % (index + 1)
        _players.append({
            "id": index,
            "name": player_name,
            "score": 0,
            "correct_count": 0,
            "error_count": 0,
        })
    _active_player_index = 0


func _start_new_round() -> void:
    _current_word = _pick_random_word()
    var english := String(_current_word.get("english", ""))
    _missing_index = randi() % english.length()
    _correct_letter = english[_missing_index]
    _letters = _generate_letters(_correct_letter)
    notify_view()


func _pick_random_word() -> Dictionary:
    var available_indices: Array[int] = []
    for i in range(_all_words.size()):
        if not _used_word_indices.has(i):
            available_indices.append(i)

    if available_indices.is_empty():
        _used_word_indices.clear()
        for i in range(_all_words.size()):
            available_indices.append(i)

    var chosen_index := available_indices[randi() % available_indices.size()]
    _used_word_indices.append(chosen_index)
    return _all_words[chosen_index]


func _generate_letters(correct_letter: String) -> Array[String]:
    var all_letters := "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
    var result: Array[String] = [correct_letter.to_upper()]

    # 从剩余字母中随机选取干扰字母
    var pool: Array[String] = []
    for c in all_letters:
        if c.to_upper() != correct_letter.to_upper():
            pool.append(c)
    pool.shuffle()

    for i in range(CompleteConfig.DISTRACTOR_COUNT):
        result.append(pool[i])
    result.shuffle()
    return result


func _open_result_scene() -> void:
    var results := get_sorted_results()
    SceneRouter.goto_result("word_complete", results)


func build_view_data() -> Dictionary:
    var english := String(_current_word.get("english", ""))
    var chinese := String(_current_word.get("chinese", ""))

    # 构建带下划线的单词显示
    var masked_word := ""
    for i in range(english.length()):
        if i == _missing_index:
            masked_word += "_"
        else:
            masked_word += english[i]

    var players_view_data: Array[Dictionary] = []
    for i in range(_players.size()):
        var player := _players[i]
        players_view_data.append({
            "name": String(player.get("name", "")),
            "score": int(player.get("score", 0)),
            "is_active": i == _active_player_index,
        })

    return {
        "current_round": _current_round + 1,
        "total_rounds": _total_rounds,
        "meaning": chinese,
        "masked_word": masked_word,
        "players": players_view_data,
        "active_player_index": _active_player_index,
        "letters": _letters,
        "game_finished": _game_finished,
    }
```

- [ ] **Step 2: Validate**

```bash
"/home/dragaseslee/godot/Godot_v4.6.2-stable_linux.x86_64" --headless --path . --check-only --script res://games/word_complete/view_models/complete_gameplay_vm.gd
```

- [ ] **Step 3: Commit**

```bash
git add games/word_complete/view_models/complete_gameplay_vm.gd
git commit -m "feat(word-complete): add gameplay view model"
```

---

### Task 5: Create CompleteResultVM

**Files:**
- Create: `games/word_complete/view_models/complete_result_vm.gd`

- [ ] **Step 1: Write complete_result_vm.gd**

```gdscript
class_name CompleteResultVM
extends ViewModel

var _results: Array[Dictionary] = []


func _on_initialize(config: Dictionary) -> void:
    var results := config.get("results", []) as Array
    for result in results:
        _results.append((result as Dictionary).duplicate(true))


func replay() -> void:
    SceneRouter.goto_game_setting("word_complete")


func back_to_hub() -> void:
    SceneRouter.goto_hub()


func build_view_data() -> Dictionary:
    return {
        "results": _results,
    }
```

- [ ] **Step 2: Commit**

```bash
git add games/word_complete/view_models/complete_result_vm.gd
git commit -m "feat(word-complete): add result view model"
```

---

### Task 6: Create Setting View

**Files:**
- Create: `games/word_complete/views/setting_view.tscn`
- Create: `games/word_complete/views/setting_view.gd`

- [ ] **Step 1: Write setting_view.gd**

```gdscript
extends GameView

var _vm: CompleteSettingVM

@onready var _status_label: Label = %StatusLabel
@onready var _word_set_option: OptionButton = %WordSetOption
@onready var _import_button: TextureButton = %ImportButton
@onready var _round_count_spin_box: SpinBox = %RoundCountSpinBox
@onready var _player_a_name_edit: LineEdit = %PlayerANameEdit
@onready var _player_b_name_edit: LineEdit = %PlayerBNameEdit
@onready var _back_button: TextureButton = $ActionSection/ActionButtons/BackButton
@onready var _start_button: TextureButton = $ActionSection/ActionButtons/StartButton
@onready var _upload_file_dialog: FileDialog = %UploadFileDialog


func _ready() -> void:
    _vm = CompleteSettingVM.new()
    bind(_vm)

    _setup_file_dialog()
    _connect_signals()

    var params := SceneRouter.get_params()
    _vm.initialize(params)


func _setup_file_dialog() -> void:
    _upload_file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
    _upload_file_dialog.access = FileDialog.ACCESS_FILESYSTEM
    _upload_file_dialog.filters = PackedStringArray(["*.txt ; Text Word Set", "*.csv ; CSV Word Set", "*.tsv ; TSV Word Set"])


func _connect_signals() -> void:
    _word_set_option.item_selected.connect(_on_word_set_selected)
    _import_button.pressed.connect(_on_import_pressed)
    _round_count_spin_box.value_changed.connect(func(value: float) -> void: _vm.set_round_count(int(value)))
    _player_a_name_edit.text_changed.connect(_vm.set_player_name.bind(0))
    _player_b_name_edit.text_changed.connect(_vm.set_player_name.bind(1))
    _back_button.pressed.connect(_on_back_pressed)
    _start_button.pressed.connect(_on_start_pressed)
    _upload_file_dialog.file_selected.connect(_on_file_selected)


func render(view_data: Dictionary) -> void:
    _render_word_set_option(view_data)
    _round_count_spin_box.value = int(view_data.get("round_count", 10))

    var players: Array = view_data.get("players", [])
    if players.size() >= 1:
        _player_a_name_edit.text = String(players[0].get("name", "玩家A"))
    if players.size() >= 2:
        _player_b_name_edit.text = String(players[1].get("name", "玩家B"))

    _status_label.text = String(view_data.get("status_text", ""))
    _start_button.disabled = not bool(view_data.get("can_start", false))


func _render_word_set_option(view_data: Dictionary) -> void:
    var word_sets: Array = view_data.get("word_sets", [])
    var selected: Dictionary = view_data.get("selected_word_set", {})

    _word_set_option.clear()
    for word_set in word_sets:
        _word_set_option.add_item("%s (%d 词)" % [word_set.get("file_name", ""), int(word_set.get("word_count", 0))])

    var selected_path := String(selected.get("file_path", ""))
    var found := false
    for index in range(word_sets.size()):
        if String(word_sets[index].get("file_path", "")) == selected_path:
            _word_set_option.select(index)
            found = true
            break
    if not found and not word_sets.is_empty():
        _word_set_option.select(0)

    if word_sets.is_empty():
        _word_set_option.add_item("暂无可用词表")
        _word_set_option.select(0)
    _word_set_option.disabled = word_sets.is_empty()


func _on_word_set_selected(index: int) -> void:
    _vm.select_word_set(index)


func _on_import_pressed() -> void:
    _upload_file_dialog.popup_centered_ratio(0.7)


func _on_file_selected(path: String) -> void:
    _vm.import_word_set(path)


func _on_back_pressed() -> void:
    SceneRouter.goto_hub()


func _on_start_pressed() -> void:
    var config := _vm.start_game()
    if config.is_empty():
        return
    SceneRouter.goto_gameplay("word_complete", config)
```

- [ ] **Step 2: Write setting_view.tscn**

This scene mirrors `word_race/views/setting_view.tscn` but removes the option count SpinBox (not needed for WordComplete) and changes the title.

```tscn
[gd_scene format=3]

[ext_resource type="Script" path="res://games/word_complete/views/setting_view.gd" id="1_setting"]
[ext_resource type="Theme" uid="uid://bplyip1c2qc4t" path="res://themes/word_race.tres" id="1_w45wa"]
[ext_resource type="Texture2D" uid="uid://b7775wlgpbtij" path="res://asserts/background/background.png" id="3_rgh6a"]
[ext_resource type="Theme" uid="uid://ivxxbefsd1km" path="res://themes/witch's_potion.tres" id="4_p0o7o"]
[ext_resource type="Texture2D" uid="uid://b3fus55lnqgef" path="res://asserts/buttons/upload_files.png" id="6_uc3wp"]
[ext_resource type="Texture2D" uid="uid://ctakfxeqjilpo" path="res://asserts/someUI.png" id="7_rb8h2"]

[sub_resource type="AtlasTexture" id="AtlasTexture_v8aqu"]
atlas = ExtResource("7_rb8h2")
region = Rect2(348, 732, 270, 107)

[sub_resource type="AtlasTexture" id="AtlasTexture_4k7dv"]
atlas = ExtResource("7_rb8h2")
region = Rect2(656, 732, 269, 107)

[node name="WordCompleteSetting" type="Control"]
layout_mode = 3
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
grow_horizontal = 2
grow_vertical = 2
theme = ExtResource("1_w45wa")
script = ExtResource("1_setting")

[node name="BackgroundLayer" type="TextureRect" parent="."]
layout_mode = 1
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
grow_horizontal = 2
grow_vertical = 2
texture = ExtResource("3_rgh6a")
expand_mode = 1
stretch_mode = 6

[node name="MarginContainer" type="MarginContainer" parent="."]
layout_mode = 1
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
grow_horizontal = 2
grow_vertical = 2
theme_override_constants/margin_left = 24
theme_override_constants/margin_top = 24
theme_override_constants/margin_right = 24
theme_override_constants/margin_bottom = 24

[node name="PanelContainer" type="MarginContainer" parent="MarginContainer"]
custom_minimum_size = Vector2(1000, 800)
layout_mode = 2
size_flags_horizontal = 4
size_flags_vertical = 4

[node name="VBoxContainer" type="VBoxContainer" parent="MarginContainer/PanelContainer"]
layout_mode = 2
theme_override_constants/separation = 16

[node name="TitleLabel" type="Label" parent="MarginContainer/PanelContainer/VBoxContainer"]
layout_mode = 2
theme_type_variation = &"PanelTitle"
text = "补全单词 - 设置"
horizontal_alignment = 1

[node name="WordSetRow" type="HBoxContainer" parent="MarginContainer/PanelContainer/VBoxContainer"]
layout_mode = 2
size_flags_vertical = 3
theme_override_constants/separation = 12

[node name="Label" type="Label" parent="MarginContainer/PanelContainer/VBoxContainer/WordSetRow"]
layout_mode = 2
size_flags_horizontal = 3
theme_type_variation = &"section_title"
text = "选择词表"

[node name="VBoxContainer" type="VBoxContainer" parent="MarginContainer/PanelContainer/VBoxContainer/WordSetRow"]
layout_mode = 2
size_flags_horizontal = 3
size_flags_stretch_ratio = 3.0
theme_override_constants/separation = 1

[node name="HBoxContainer" type="HBoxContainer" parent="MarginContainer/PanelContainer/VBoxContainer/WordSetRow/VBoxContainer"]
layout_mode = 2
size_flags_vertical = 3

[node name="AspectRatioContainer" type="AspectRatioContainer" parent="MarginContainer/PanelContainer/VBoxContainer/WordSetRow/VBoxContainer/HBoxContainer"]
layout_mode = 2
size_flags_horizontal = 3
ratio = 3.5

[node name="WordSetOption" type="OptionButton" parent="MarginContainer/PanelContainer/VBoxContainer/WordSetRow/VBoxContainer/HBoxContainer/AspectRatioContainer"]
unique_name_in_owner = true
layout_mode = 2

[node name="ImportButton" type="TextureButton" parent="MarginContainer/PanelContainer/VBoxContainer/WordSetRow/VBoxContainer/HBoxContainer"]
unique_name_in_owner = true
custom_minimum_size = Vector2(150, 0)
layout_mode = 2
size_flags_horizontal = 3
size_flags_stretch_ratio = 0.4
texture_normal = ExtResource("6_uc3wp")
ignore_texture_size = true
stretch_mode = 5

[node name="MarginContainer" type="MarginContainer" parent="MarginContainer/PanelContainer/VBoxContainer/WordSetRow/VBoxContainer"]
layout_mode = 2

[node name="StatusLabel" type="Label" parent="MarginContainer/PanelContainer/VBoxContainer/WordSetRow/VBoxContainer/MarginContainer"]
unique_name_in_owner = true
custom_minimum_size = Vector2(100, 0)
layout_mode = 2
theme_type_variation = &"section_title"
theme_override_font_sizes/font_size = 16
horizontal_alignment = 2
autowrap_mode = 3

[node name="RoundCountRow" type="HBoxContainer" parent="MarginContainer/PanelContainer/VBoxContainer"]
layout_mode = 2
size_flags_vertical = 3
theme_override_constants/separation = 12

[node name="RoundCountLabel" type="Label" parent="MarginContainer/PanelContainer/VBoxContainer/RoundCountRow"]
layout_mode = 2
size_flags_horizontal = 3
theme_type_variation = &"section_title"
text = "总题数"

[node name="RoundCountSpinBox" type="SpinBox" parent="MarginContainer/PanelContainer/VBoxContainer/RoundCountRow"]
unique_name_in_owner = true
layout_mode = 2
size_flags_horizontal = 3
size_flags_vertical = 4
min_value = 1.0
max_value = 50.0
value = 10.0

[node name="PlayerARow" type="HBoxContainer" parent="MarginContainer/PanelContainer/VBoxContainer"]
layout_mode = 2
size_flags_vertical = 3
theme_override_constants/separation = 12

[node name="Label" type="Label" parent="MarginContainer/PanelContainer/VBoxContainer/PlayerARow"]
layout_mode = 2
size_flags_horizontal = 3
theme_type_variation = &"section_title"
text = "玩家名称"

[node name="PlayerANameEdit" type="LineEdit" parent="MarginContainer/PanelContainer/VBoxContainer/PlayerARow"]
unique_name_in_owner = true
layout_mode = 2
size_flags_horizontal = 3
size_flags_vertical = 4
placeholder_text = "玩家A"
alignment = 1

[node name="Label2" type="Label" parent="MarginContainer/PanelContainer/VBoxContainer/PlayerARow"]
layout_mode = 2
size_flags_horizontal = 3
theme_type_variation = &"section_title"
text = " VS "
horizontal_alignment = 1

[node name="PlayerBNameEdit" type="LineEdit" parent="MarginContainer/PanelContainer/VBoxContainer/PlayerARow"]
unique_name_in_owner = true
layout_mode = 2
size_flags_horizontal = 3
size_flags_vertical = 4
placeholder_text = "玩家B"
alignment = 1

[node name="ActionSection" type="MarginContainer" parent="."]
custom_minimum_size = Vector2(0, 170)
layout_mode = 1
anchors_preset = 7
anchor_left = 0.5
anchor_top = 1.0
anchor_right = 0.5
anchor_bottom = 1.0
offset_left = -275.5
offset_top = -170.0
offset_right = 275.5
grow_horizontal = 2
grow_vertical = 0

[node name="ActionButtons" type="HBoxContainer" parent="ActionSection"]
layout_mode = 2
theme_override_constants/separation = 12

[node name="BackButton" type="TextureButton" parent="ActionSection/ActionButtons"]
layout_mode = 2
size_flags_horizontal = 3
texture_normal = SubResource("AtlasTexture_v8aqu")
ignore_texture_size = true
stretch_mode = 5

[node name="Label" type="Label" parent="ActionSection/ActionButtons/BackButton"]
layout_mode = 1
anchors_preset = 8
anchor_left = 0.5
anchor_top = 0.5
anchor_right = 0.5
anchor_bottom = 0.5
offset_left = -20.0
offset_top = -11.5
offset_right = 20.0
offset_bottom = 11.5
grow_horizontal = 2
grow_vertical = 2
theme = ExtResource("4_p0o7o")
theme_type_variation = &"layout_label"
text = "返回"
horizontal_alignment = 1
vertical_alignment = 1

[node name="StartButton" type="TextureButton" parent="ActionSection/ActionButtons"]
layout_mode = 2
size_flags_horizontal = 3
texture_normal = SubResource("AtlasTexture_4k7dv")
ignore_texture_size = true
stretch_mode = 5

[node name="Label" type="Label" parent="ActionSection/ActionButtons/StartButton"]
layout_mode = 1
anchors_preset = 8
anchor_left = 0.5
anchor_top = 0.5
anchor_right = 0.5
anchor_bottom = 0.5
offset_left = -20.0
offset_top = -11.5
offset_right = 20.0
offset_bottom = 11.5
grow_horizontal = 2
grow_vertical = 2
theme = ExtResource("4_p0o7o")
theme_type_variation = &"layout_label"
text = "开始"
horizontal_alignment = 1
vertical_alignment = 1

[node name="UploadFileDialog" type="FileDialog" parent="."]
unique_name_in_owner = true
title = "导入词表"
```

- [ ] **Step 3: Validate**

```bash
"/home/dragaseslee/godot/Godot_v4.6.2-stable_linux.x86_64" --headless --path . --import 2>&1 | tail -5
```

- [ ] **Step 4: Commit**

```bash
git add games/word_complete/views/setting_view.gd games/word_complete/views/setting_view.tscn
git commit -m "feat(word-complete): add setting view"
```

---

### Task 7: Create Gameplay View

**Files:**
- Create: `games/word_complete/views/gameplay_view.tscn`
- Create: `games/word_complete/views/gameplay_view.gd`

- [ ] **Step 1: Write gameplay_view.gd**

```gdscript
extends GameView

var _vm: CompleteGameplayVM

@onready var _round_label: Label = %RoundLabel
@onready var _meaning_label: Label = %MeaningLabel
@onready var _word_label: Label = %WordLabel
@onready var _player_a_panel: Panel = %PlayerAPanel
@onready var _player_b_panel: Panel = %PlayerBPanel
@onready var _player_a_name_label: Label = %PlayerANameLabel
@onready var _player_b_name_label: Label = %PlayerBNameLabel
@onready var _player_a_score_label: Label = %PlayerAScoreLabel
@onready var _player_b_score_label: Label = %PlayerBScoreLabel
@onready var _player_a_status_label: Label = %PlayerAStatusLabel
@onready var _player_b_status_label: Label = %PlayerBStatusLabel
@onready var _player_a_letters_container: GridContainer = %PlayerALettersContainer
@onready var _player_b_letters_container: GridContainer = %PlayerBLettersContainer
@onready var _end_game_button: Button = %EndGameButton

var _round_transition_timer: Timer


func _ready() -> void:
    var params := SceneRouter.get_params()
    var config: Dictionary = params.get("config", {})

    _vm = CompleteGameplayVM.new()
    bind(_vm)
    _vm.initialize(config)

    if not _vm.is_initialized():
        SceneRouter.goto_game_setting("word_complete")
        return

    _setup_timers()
    _connect_signals()


func _setup_timers() -> void:
    _round_transition_timer = Timer.new()
    _round_transition_timer.one_shot = true
    _round_transition_timer.wait_time = 1.0
    _round_transition_timer.timeout.connect(_on_round_transition)
    add_child(_round_transition_timer)


func _connect_signals() -> void:
    _end_game_button.pressed.connect(_vm.request_end_game)
    _vm.game_finished.connect(_on_game_finished)


func render(view_data: Dictionary) -> void:
    _round_label.text = "第 %d/%d 题" % [
        int(view_data.get("current_round", 1)),
        int(view_data.get("total_rounds", 10))
    ]
    _meaning_label.text = "中文意思：%s" % String(view_data.get("meaning", ""))
    _word_label.text = String(view_data.get("masked_word", ""))

    var players: Array = view_data.get("players", [])
    var letters: Array = view_data.get("letters", [])
    var active_index := int(view_data.get("active_player_index", 0))
    var is_game_finished := bool(view_data.get("game_finished", false))

    if players.size() >= 2:
        _render_player_panel(0, players[0], letters, active_index, is_game_finished,
            _player_a_panel, _player_a_name_label, _player_a_score_label,
            _player_a_status_label, _player_a_letters_container)
        _render_player_panel(1, players[1], letters, active_index, is_game_finished,
            _player_b_panel, _player_b_name_label, _player_b_score_label,
            _player_b_status_label, _player_b_letters_container)

    _end_game_button.visible = is_game_finished


func _render_player_panel(
    player_index: int,
    player_data: Dictionary,
    letters: Array,
    active_index: int,
    is_game_finished: bool,
    panel: Panel,
    name_label: Label,
    score_label: Label,
    status_label: Label,
    letters_container: GridContainer
) -> void:
    var is_active := player_index == active_index

    name_label.text = String(player_data.get("name", ""))
    score_label.text = "得分: %d" % int(player_data.get("score", 0))

    if is_game_finished:
        status_label.text = "游戏结束"
        panel.modulate = Color(0.5, 0.5, 0.5, 1.0)
    elif is_active:
        status_label.text = "回答中"
        panel.modulate = Color(1.0, 1.0, 1.0, 1.0)
    else:
        status_label.text = "等待"
        panel.modulate = Color(0.5, 0.5, 0.5, 1.0)

    _render_letters(letters_container, player_index, letters, not is_active or is_game_finished)


func _render_letters(container: GridContainer, player_index: int, letters: Array, is_disabled: bool) -> void:
    for child in container.get_children():
        child.queue_free()

    for i in range(letters.size()):
        var letter: String = letters[i]
        var button := Button.new()
        button.text = letter
        button.disabled = is_disabled
        button.custom_minimum_size = Vector2(60, 60)
        button.pressed.connect(_on_letter_pressed.bind(letter))
        container.add_child(button)


func _on_letter_pressed(letter: String) -> void:
    _vm.select_letter(letter)


func _on_game_finished() -> void:
    _round_transition_timer.stop()
    # 延迟跳转到结果页
    var timer := Timer.new()
    timer.one_shot = true
    timer.wait_time = 1.5
    timer.timeout.connect(func() -> void:
        var results := _vm.get_sorted_results()
        SceneRouter.goto_result("word_complete", results)
    )
    add_child(timer)
    timer.start()


func _on_round_transition() -> void:
    pass  # 由 VM 直接处理题目切换
```

- [ ] **Step 2: Write gameplay_view.tscn**

```tscn
[gd_scene format=3]

[ext_resource type="Theme" uid="uid://bplyip1c2qc4t" path="res://themes/word_race.tres" id="1_theme"]
[ext_resource type="Script" path="res://games/word_complete/views/gameplay_view.gd" id="1_view"]
[ext_resource type="Texture2D" uid="uid://d1shywtks7n26" path="res://asserts/panels/word_race_word_panel.png" id="3_panel"]

[sub_resource type="AtlasTexture" id="AtlasTexture_panel"]
atlas = ExtResource("3_panel")

[node name="WordCompleteGameplay" type="Control"]
layout_mode = 3
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
grow_horizontal = 2
grow_vertical = 2
theme = ExtResource("1_theme")
script = ExtResource("1_view")

[node name="VBoxContainer" type="VBoxContainer" parent="."]
layout_mode = 1
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
grow_horizontal = 2
grow_vertical = 2
theme_override_constants/separation = 8

[node name="RoundLabel" type="Label" parent="VBoxContainer"]
unique_name_in_owner = true
layout_mode = 2
theme_type_variation = &"layout_label"
text = "第 1/10 题"
horizontal_alignment = 1

[node name="MeaningLabel" type="Label" parent="VBoxContainer"]
unique_name_in_owner = true
layout_mode = 2
theme_type_variation = &"section_title"
text = "中文意思："
horizontal_alignment = 1

[node name="WordPanel" type="Panel" parent="VBoxContainer"]
layout_mode = 2
size_flags_vertical = 3

[node name="TextureRect" type="TextureRect" parent="VBoxContainer/WordPanel"]
layout_mode = 1
anchors_preset = 8
anchor_left = 0.5
anchor_top = 0.5
anchor_right = 0.5
anchor_bottom = 0.5
offset_left = -367.0
offset_top = -153.0
offset_right = 410.0
offset_bottom = 112.0
grow_horizontal = 2
grow_vertical = 2
texture = SubResource("AtlasTexture_panel")
expand_mode = 1
stretch_mode = 5

[node name="WordLabel" type="Label" parent="VBoxContainer/WordPanel"]
unique_name_in_owner = true
layout_mode = 0
offset_top = 12.0
offset_right = 1920.0
offset_bottom = 92.0
theme_type_variation = &"PanelTitle"
text = "等待开始..."
horizontal_alignment = 1

[node name="HBoxContainer" type="HBoxContainer" parent="VBoxContainer"]
layout_mode = 2
size_flags_vertical = 3
size_flags_stretch_ratio = 5.0
theme_override_constants/separation = 12

[node name="MarginContainerA" type="MarginContainer" parent="VBoxContainer/HBoxContainer"]
layout_mode = 2
size_flags_horizontal = 3
theme_override_constants/margin_left = 16
theme_override_constants/margin_top = 16
theme_override_constants/margin_right = 16
theme_override_constants/margin_bottom = 16

[node name="PlayerAPanel" type="Panel" parent="VBoxContainer/HBoxContainer/MarginContainerA"]
unique_name_in_owner = true
layout_mode = 2
size_flags_horizontal = 3
theme_type_variation = &"PlayerPanel"

[node name="PlayerAVBox" type="VBoxContainer" parent="VBoxContainer/HBoxContainer/MarginContainerA/PlayerAPanel"]
layout_mode = 1
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
grow_horizontal = 2
grow_vertical = 2
theme_override_constants/separation = 8

[node name="InfoHBox" type="HBoxContainer" parent="VBoxContainer/HBoxContainer/MarginContainerA/PlayerAPanel/PlayerAVBox"]
layout_mode = 2
size_flags_vertical = 3
size_flags_stretch_ratio = 0.2

[node name="PlayerANameLabel" type="Label" parent="VBoxContainer/HBoxContainer/MarginContainerA/PlayerAPanel/PlayerAVBox/InfoHBox"]
unique_name_in_owner = true
layout_mode = 2
size_flags_horizontal = 10
theme_type_variation = &"section_title"
text = "玩家A"
horizontal_alignment = 1

[node name="PlayerAScoreLabel" type="Label" parent="VBoxContainer/HBoxContainer/MarginContainerA/PlayerAPanel/PlayerAVBox/InfoHBox"]
unique_name_in_owner = true
layout_mode = 2
size_flags_horizontal = 2
theme_type_variation = &"section_title"
text = "得分: 0"
horizontal_alignment = 1

[node name="PlayerAStatusLabel" type="Label" parent="VBoxContainer/HBoxContainer/MarginContainerA/PlayerAPanel/PlayerAVBox"]
unique_name_in_owner = true
layout_mode = 2
theme_type_variation = &"section_title"
theme_override_font_sizes/font_size = 20
text = "回答中"
horizontal_alignment = 1

[node name="LettersMargin" type="MarginContainer" parent="VBoxContainer/HBoxContainer/MarginContainerA/PlayerAPanel/PlayerAVBox"]
layout_mode = 2
size_flags_vertical = 3
theme_override_constants/margin_left = 32
theme_override_constants/margin_top = 16
theme_override_constants/margin_right = 32
theme_override_constants/margin_bottom = 16

[node name="PlayerALettersContainer" type="GridContainer" parent="VBoxContainer/HBoxContainer/MarginContainerA/PlayerAPanel/PlayerAVBox/LettersMargin"]
unique_name_in_owner = true
layout_mode = 2
columns = 4

[node name="MarginContainerB" type="MarginContainer" parent="VBoxContainer/HBoxContainer"]
layout_mode = 2
size_flags_horizontal = 3
theme_override_constants/margin_left = 16
theme_override_constants/margin_top = 16
theme_override_constants/margin_right = 16
theme_override_constants/margin_bottom = 16

[node name="PlayerBPanel" type="Panel" parent="VBoxContainer/HBoxContainer/MarginContainerB"]
unique_name_in_owner = true
layout_mode = 2
size_flags_horizontal = 3
theme_type_variation = &"PlayerPanel"

[node name="PlayerBVBox" type="VBoxContainer" parent="VBoxContainer/HBoxContainer/MarginContainerB/PlayerBPanel"]
layout_mode = 1
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
grow_horizontal = 2
grow_vertical = 2
theme_override_constants/separation = 8

[node name="InfoHBox" type="HBoxContainer" parent="VBoxContainer/HBoxContainer/MarginContainerB/PlayerBPanel/PlayerBVBox"]
layout_mode = 2
size_flags_vertical = 3
size_flags_stretch_ratio = 0.2

[node name="PlayerBNameLabel" type="Label" parent="VBoxContainer/HBoxContainer/MarginContainerB/PlayerBPanel/PlayerBVBox/InfoHBox"]
unique_name_in_owner = true
layout_mode = 2
size_flags_horizontal = 10
theme_type_variation = &"section_title"
text = "玩家B"
horizontal_alignment = 1

[node name="PlayerBScoreLabel" type="Label" parent="VBoxContainer/HBoxContainer/MarginContainerB/PlayerBPanel/PlayerBVBox/InfoHBox"]
unique_name_in_owner = true
layout_mode = 2
size_flags_horizontal = 2
theme_type_variation = &"section_title"
text = "得分: 0"
horizontal_alignment = 1

[node name="PlayerBStatusLabel" type="Label" parent="VBoxContainer/HBoxContainer/MarginContainerB/PlayerBPanel/PlayerBVBox"]
unique_name_in_owner = true
layout_mode = 2
theme_type_variation = &"section_title"
theme_override_font_sizes/font_size = 20
text = "等待"
horizontal_alignment = 1

[node name="LettersMargin" type="MarginContainer" parent="VBoxContainer/HBoxContainer/MarginContainerB/PlayerBPanel/PlayerBVBox"]
layout_mode = 2
size_flags_vertical = 3
theme_override_constants/margin_left = 32
theme_override_constants/margin_top = 16
theme_override_constants/margin_right = 32
theme_override_constants/margin_bottom = 16

[node name="PlayerBLettersContainer" type="GridContainer" parent="VBoxContainer/HBoxContainer/MarginContainerB/PlayerBPanel/PlayerBVBox/LettersMargin"]
unique_name_in_owner = true
layout_mode = 2
columns = 4

[node name="ButtonContainer" type="HBoxContainer" parent="VBoxContainer"]
layout_mode = 2
theme_override_constants/separation = 12
alignment = 1

[node name="EndGameButton" type="Button" parent="VBoxContainer/ButtonContainer"]
unique_name_in_owner = true
layout_mode = 2
text = "查看结果"
```

- [ ] **Step 3: Validate**

```bash
"/home/dragaseslee/godot/Godot_v4.6.2-stable_linux.x86_64" --headless --path . --import 2>&1 | tail -5
```

- [ ] **Step 4: Commit**

```bash
git add games/word_complete/views/gameplay_view.gd games/word_complete/views/gameplay_view.tscn
git commit -m "feat(word-complete): add gameplay view"
```

---

### Task 8: Create Result View

**Files:**
- Create: `games/word_complete/views/result_view.tscn`
- Create: `games/word_complete/views/result_view.gd`

- [ ] **Step 1: Write result_view.gd**

```gdscript
extends GameView

const RESULT_ROW_SCENE := preload("res://scenes/components/result_row.tscn")

var _vm: CompleteResultVM

@onready var _winner_label: Label = %WinnerLabel
@onready var _results_list: VBoxContainer = %ResultsList
@onready var _replay_button: Button = %ReplayButton
@onready var _back_to_hub_button: Button = %BackToHubButton


func _ready() -> void:
    var params := SceneRouter.get_params()
    var results: Array = params.get("results", [])

    _vm = CompleteResultVM.new()
    bind(_vm)
    _vm.initialize({"results": results})

    _replay_button.pressed.connect(_vm.replay)
    _back_to_hub_button.pressed.connect(_vm.back_to_hub)

    if results.is_empty():
        SceneRouter.goto_game_setting("word_complete")
        return


func render(view_data: Dictionary) -> void:
    var results: Array = view_data.get("results", [])

    if results.size() >= 2:
        var winner_name := String(results[0].get("name", ""))
        var winner_score := int(results[0].get("score", 0))
        var loser_score := int(results[1].get("score", 0))
        if winner_score > loser_score:
            _winner_label.text = "胜利者: %s (得分: %d)" % [winner_name, winner_score]
        else:
            _winner_label.text = "平局！双方得分: %d" % winner_score
    else:
        _winner_label.text = "游戏结束"

    for child in _results_list.get_children():
        child.free()

    for index in range(results.size()):
        var result: Dictionary = results[index]
        var row := RESULT_ROW_SCENE.instantiate()
        row.setup(
            index + 1,
            String(result.get("name", "玩家")),
            _build_status_text(result)
        )
        _results_list.add_child(row)


func _build_status_text(result: Dictionary) -> String:
    return "得分: %d | 正确: %d | 错误: %d" % [
        int(result.get("score", 0)),
        int(result.get("correct_count", 0)),
        int(result.get("error_count", 0)),
    ]
```

- [ ] **Step 2: Write result_view.tscn**

```tscn
[gd_scene format=3]

[ext_resource type="Script" path="res://games/word_complete/views/result_view.gd" id="1_result"]
[ext_resource type="Theme" uid="uid://bplyip1c2qc4t" path="res://themes/word_race.tres" id="1_theme"]

[node name="WordCompleteResult" type="Control"]
layout_mode = 3
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
grow_horizontal = 2
grow_vertical = 2
theme = ExtResource("1_theme")
script = ExtResource("1_result")

[node name="MarginContainer" type="MarginContainer" parent="."]
layout_mode = 1
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
grow_horizontal = 2
grow_vertical = 2
theme_override_constants/margin_left = 24
theme_override_constants/margin_top = 24
theme_override_constants/margin_right = 24
theme_override_constants/margin_bottom = 24

[node name="VBoxContainer" type="VBoxContainer" parent="MarginContainer"]
layout_mode = 2
theme_override_constants/separation = 10

[node name="TitleLabel" type="Label" parent="MarginContainer/VBoxContainer"]
layout_mode = 2
theme_type_variation = &"PanelTitle"
text = "游戏结束"
horizontal_alignment = 1

[node name="WinnerLabel" type="Label" parent="MarginContainer/VBoxContainer"]
unique_name_in_owner = true
layout_mode = 2
theme_type_variation = &"section_title"
text = ""
horizontal_alignment = 1

[node name="ResultsList" type="VBoxContainer" parent="MarginContainer/VBoxContainer"]
unique_name_in_owner = true
layout_mode = 2
size_flags_vertical = 3
theme_override_constants/separation = 8

[node name="ActionRow" type="HBoxContainer" parent="MarginContainer/VBoxContainer"]
layout_mode = 2
alignment = 1
theme_override_constants/separation = 12

[node name="ReplayButton" type="Button" parent="MarginContainer/VBoxContainer/ActionRow"]
unique_name_in_owner = true
layout_mode = 2
size_flags_horizontal = 3
text = "再来一局"

[node name="BackToHubButton" type="Button" parent="MarginContainer/VBoxContainer/ActionRow"]
unique_name_in_owner = true
layout_mode = 2
size_flags_horizontal = 3
text = "返回大厅"
```

- [ ] **Step 3: Validate**

```bash
"/home/dragaseslee/godot/Godot_v4.6.2-stable_linux.x86_64" --headless --path . --import 2>&1 | tail -5
```

- [ ] **Step 4: Commit**

```bash
git add games/word_complete/views/result_view.gd games/word_complete/views/result_view.tscn
git commit -m "feat(word-complete): add result view"
```

---

### Task 9: Register Game and Add Routes

**Files:**
- Modify: `core/autoload/game_registry.gd`
- Modify: `core/autoload/scene_router.gd`

- [ ] **Step 1: Add to GameRegistry**

Add this line at the end of `_register_builtin_games()` in `core/autoload/game_registry.gd`:

```gdscript
register_game(preload("res://games/word_complete/complete_def.gd").new())
```

- [ ] **Step 2: Add routes to SceneRouter**

Add these three entries to the `mapping` dictionary in `_resolve_scene_path()` in `core/autoload/scene_router.gd`:

```gdscript
"setting_word_complete": "res://games/word_complete/views/setting_view.tscn",
"gameplay_word_complete": "res://games/word_complete/views/gameplay_view.tscn",
"result_word_complete": "res://games/word_complete/views/result_view.tscn",
```

- [ ] **Step 3: Validate**

```bash
"/home/dragaseslee/godot/Godot_v4.6.2-stable_linux.x86_64" --headless --path . --import 2>&1 | tail -5
```

- [ ] **Step 4: Commit**

```bash
git add core/autoload/game_registry.gd core/autoload/scene_router.gd
git commit -m "feat(word-complete): register game and add routes"
```

---

### Task 10: Add Hub Button

**Files:**
- Modify: `scripts/game_hub.gd`
- Modify: `scenes/game_hub.tscn`

- [ ] **Step 1: Add hub wiring to game_hub.gd**

Add to the `@onready` block at the top:

```gdscript
@onready var word_complete_panel: Control = $"MarginContainer/VBoxContainer/GamesPanel/GridContainer/WordCompletePanel"
@onready var word_complete_button: TextureButton = $"MarginContainer/VBoxContainer/GamesPanel/GridContainer/WordCompletePanel/AspectRatioContainer/TextureButton"
```

Add to `_ready()`:

```gdscript
_setup_game_card(word_complete_panel, word_complete_button)
word_complete_panel.gui_input.connect(func(event: InputEvent) -> void:
    if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
        if _is_mouse_over(word_complete_button):
            return
        _on_word_complete_panel_pressed()
)
word_complete_button.pressed.connect(_on_word_complete_panel_pressed)
```

Add the handler function:

```gdscript
func _on_word_complete_panel_pressed() -> void:
    SceneRouter.goto_game_setting("word_complete")
```

- [ ] **Step 2: Add panel node to game_hub.tscn**

Add a `WordCompletePanel` node under `GridContainer` in `game_hub.tscn`, following the same pattern as `WordRacePanel`:

```
[node name="WordCompletePanel" type="Control" parent="MarginContainer/VBoxContainer/GamesPanel/GridContainer"]
layout_mode = 2
size_flags_horizontal = 3
size_flags_vertical = 3

[node name="AspectRatioContainer" type="AspectRatioContainer" parent="MarginContainer/VBoxContainer/GamesPanel/GridContainer/WordCompletePanel"]
layout_mode = 1
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
grow_horizontal = 2
grow_vertical = 2
size_flags_horizontal = 3
size_flags_vertical = 3
ratio = 1.6

[node name="TextureButton" type="TextureButton" parent="MarginContainer/VBoxContainer/GamesPanel/GridContainer/WordCompletePanel/AspectRatioContainer"]
layout_mode = 2
ignore_texture_size = true
stretch_mode = 5
```

Note: The `texture_normal` for the button needs a game icon image. Use a placeholder or reuse an existing icon temporarily. The `columns` in GridContainer should be updated to `3` to accommodate 4 games (currently `2`).

- [ ] **Step 3: Validate full import**

```bash
"/home/dragaseslee/godot/Godot_v4.6.2-stable_linux.x86_64" --headless --path . --import 2>&1 | tail -10
```

- [ ] **Step 4: Commit**

```bash
git add scripts/game_hub.gd scenes/game_hub.tscn
git commit -m "feat(word-complete): add hub entry button"
```

---

### Task 11: Full Validation

- [ ] **Step 1: Run full import check**

```bash
"/home/dragaseslee/godot/Godot_v4.6.2-stable_linux.x86_64" --headless --path . --import
```

Expected: No errors related to `word_complete`.

- [ ] **Step 2: Verify all files exist**

```bash
ls -la games/word_complete/ games/word_complete/view_models/ games/word_complete/views/
```

Expected: All 11 files present (config, def, 3 vms, 3 view scripts, 3 tscn files).

- [ ] **Step 3: Final commit if any fixes needed**

```bash
git add -A
git commit -m "fix(word-complete): address validation issues"
```
