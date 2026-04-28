# Game Setting Word Set Dropdown Simplification Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Simplify the game-setting word-set area so it uses the existing custom dropdown as the only selector UI and removes the extra preview/status block.

**Architecture:** Keep `scenes/components/custom_dropdown.tscn` as the single word-set selector in `scenes/game_setting.tscn`. Remove the preview labels from the scene, delete their controller logic from `scripts/game_setting.gd`, and keep selection, refresh, import, and start-button enablement flowing through `_selected_word_set`.

**Tech Stack:** Godot 4.6, GDScript, `.tscn` scenes

---

## File Structure

- Modify: `scenes/game_setting.tscn`
  - Remove the `WordSetPreview` node tree so only the title, dropdown shell, and action buttons remain in the word-set section.
- Modify: `scripts/game_setting.gd`
  - Remove preview-label references and preview-update logic while preserving dropdown population, selection, import, refresh, and status handling.
- Modify: `scripts/tests/test_game_setting_scene.gd`
  - Add assertions that the preview block is gone and that the simplified word-set section still uses the custom dropdown correctly.

## Verification

- Preferred: `godot --headless --path "." -s res://scripts/tests/test_game_setting_scene.gd`
- Current limitation: this workspace does not expose a callable `godot` CLI, so static review is the fallback until the binary path is provided.

### Task 1: Remove the Preview Block From the Scene

**Files:**
- Modify: `scenes/game_setting.tscn:171-188`
- Test: `scripts/tests/test_game_setting_scene.gd`

- [ ] **Step 1: Write the failing test**

Add this assertion after the existing custom dropdown assertions in `scripts/tests/test_game_setting_scene.gd`:

```gdscript
	_assert(not root.has_node("ScreenMargin/PanelCenter/MainPanelRoot/PanelContentMargin/PanelContent/ContentColumns/LeftColumn/WordSetSection/WordSetSectionContent/WordSetVBox/WordSetPreview"), "WordSetPreview should be removed")
```

- [ ] **Step 2: Run test to verify it fails**

Run: `godot --headless --path "." -s res://scripts/tests/test_game_setting_scene.gd`
Expected: FAIL with `WordSetPreview should be removed`

- [ ] **Step 3: Write minimal implementation**

Delete this node block from `scenes/game_setting.tscn`:

```tscn
[node name="WordSetPreview" type="VBoxContainer" parent="ScreenMargin/PanelCenter/MainPanelRoot/PanelContentMargin/PanelContent/ContentColumns/LeftColumn/WordSetSection/WordSetSectionContent/WordSetVBox" unique_id=1421648721]
layout_mode = 2
theme_override_constants/separation = 6

[node name="WordSetFileLabel" type="Label" parent="ScreenMargin/PanelCenter/MainPanelRoot/PanelContentMargin/PanelContent/ContentColumns/LeftColumn/WordSetSection/WordSetSectionContent/WordSetVBox/WordSetPreview" unique_id=1305310082]
unique_name_in_owner = true
layout_mode = 2
text = "文件: 未选择"

[node name="WordSetCountLabel" type="Label" parent="ScreenMargin/PanelCenter/MainPanelRoot/PanelContentMargin/PanelContent/ContentColumns/LeftColumn/WordSetSection/WordSetSectionContent/WordSetVBox/WordSetPreview" unique_id=1202357770]
unique_name_in_owner = true
layout_mode = 2
text = "词数: 0"

[node name="WordSetStatusLabel" type="Label" parent="ScreenMargin/PanelCenter/MainPanelRoot/PanelContentMargin/PanelContent/ContentColumns/LeftColumn/WordSetSection/WordSetSectionContent/WordSetVBox/WordSetPreview" unique_id=1225430733]
unique_name_in_owner = true
layout_mode = 2
text = "状态: 暂无可用词表"
```

- [ ] **Step 4: Run test to verify it passes**

Run: `godot --headless --path "." -s res://scripts/tests/test_game_setting_scene.gd`
Expected: the `WordSetPreview should be removed` assertion no longer fails

- [ ] **Step 5: Commit**

```bash
git add scenes/game_setting.tscn scripts/tests/test_game_setting_scene.gd
git commit -m "refactor: remove word set preview block"
```

### Task 2: Remove Preview Logic From the Controller

**Files:**
- Modify: `scripts/game_setting.gd:12-27`
- Modify: `scripts/game_setting.gd:30-49`
- Modify: `scripts/game_setting.gd:65-84`
- Modify: `scripts/game_setting.gd:100-108`
- Modify: `scripts/game_setting.gd:154-159`
- Modify: `scripts/game_setting.gd:238-247`
- Test: `scripts/tests/test_game_setting_scene.gd`

- [ ] **Step 1: Write the failing test**

Add this assertion after the existing `WordSetDropdown` checks in `scripts/tests/test_game_setting_scene.gd`:

```gdscript
	_assert(not root.has_node("%WordSetFileLabel"), "WordSetFileLabel should be removed")
	_assert(not root.has_node("%WordSetCountLabel"), "WordSetCountLabel should be removed")
	_assert(not root.has_node("%WordSetStatusLabel"), "WordSetStatusLabel should be removed")
```

- [ ] **Step 2: Run test to verify it fails**

Run: `godot --headless --path "." -s res://scripts/tests/test_game_setting_scene.gd`
Expected: FAIL because those named nodes still exist or the scene/script still depends on them

- [ ] **Step 3: Write minimal implementation**

Make these exact controller edits in `scripts/game_setting.gd`:

1. Remove these `@onready` lines:

```gdscript
@onready var word_set_file_label: Label = %WordSetFileLabel
@onready var word_set_count_label: Label = %WordSetCountLabel
@onready var word_set_status_label: Label = %WordSetStatusLabel
```

2. Remove `_update_word_set_preview()` calls from `_ready()`, `_setup_word_set_options()`, and `_on_word_set_selected()`.

3. On import failure, replace:

```gdscript
		word_set_status_label.text = "状态: %s" % String(result.get("message", "导入失败"))
		_update_status()
		return
```

with:

```gdscript
		status_label.text = String(result.get("message", "导入失败"))
		start_button.disabled = _selected_word_set.is_empty()
		return
```

4. Delete the whole preview function:

```gdscript
func _update_word_set_preview() -> void:
	if _selected_word_set.is_empty():
		word_set_file_label.text = "文件: 未选择"
		word_set_count_label.text = "词数: 0"
		word_set_status_label.text = "状态: 暂无可用词表" if _word_sets.is_empty() else "状态: 请选择词表"
		return

	word_set_file_label.text = "文件: %s" % String(_selected_word_set.get("file_name", ""))
	word_set_count_label.text = "词数: %d" % int(_selected_word_set.get("word_count", 0))
	word_set_status_label.text = "状态: 可用于开始游戏"
```

- [ ] **Step 4: Run test to verify it passes**

Run: `godot --headless --path "." -s res://scripts/tests/test_game_setting_scene.gd`
Expected: scene loads without missing-node errors, and the removed-label assertions pass

- [ ] **Step 5: Commit**

```bash
git add scripts/game_setting.gd scripts/tests/test_game_setting_scene.gd
git commit -m "refactor: drop redundant word set preview logic"
```

### Task 3: Tighten the Regression Test Around the Simplified Section

**Files:**
- Modify: `scripts/tests/test_game_setting_scene.gd:27-44`
- Test: `scripts/tests/test_game_setting_scene.gd`

- [ ] **Step 1: Write the failing test**

Add this assertion near the existing word-set section checks:

```gdscript
	_assert(root.has_node("ScreenMargin/PanelCenter/MainPanelRoot/PanelContentMargin/PanelContent/ContentColumns/LeftColumn/WordSetSection/WordSetSectionContent/WordSetVBox/WordSetActions"), "Word set action row should remain after simplification")
```

- [ ] **Step 2: Run test to verify it fails**

Run: `godot --headless --path "." -s res://scripts/tests/test_game_setting_scene.gd`
Expected: FAIL if the scene cleanup accidentally removed the action row or left the section in an invalid structure

- [ ] **Step 3: Write minimal implementation**

Keep the word-set section structure equivalent to this shape in `scenes/game_setting.tscn`:

```tscn
[node name="WordSetVBox" type="VBoxContainer" ...]
[node name="WordSetTitle" type="Label" ...]
[node name="WordSetDropdownShell" type="Control" ...]
[node name="WordSetDropdown" ... instance=ExtResource("6_custom_dropdown")]
[node name="WordSetActions" type="HBoxContainer" ...]
[node name="RefreshButton" type="TextureButton" parent=".../WordSetActions" ...]
[node name="ImportButton" type="TextureButton" parent=".../WordSetActions" ...]
```

- [ ] **Step 4: Run test to verify it passes**

Run: `godot --headless --path "." -s res://scripts/tests/test_game_setting_scene.gd`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add scenes/game_setting.tscn scripts/tests/test_game_setting_scene.gd
git commit -m "test: cover simplified word set section"
```
