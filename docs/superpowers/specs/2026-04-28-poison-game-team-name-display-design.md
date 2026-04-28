# Poison Game Team Name Display Optimization

## Date
2026-04-28

## Problem Description
Currently in the poison game interface, player names are displayed with hardcoded prefixes "玩家1：" and "玩家2：" (e.g., "玩家1：张三", "玩家2：李四"). The user wants to display only the custom names set in the game settings (e.g., "张三", "李四").

## Current Implementation
In `scripts/gameplay_panel.gd`, lines 47-50:
```gdscript
# 更新玩家标签
if players.size() > 0:
    player1_label.text = "玩家1：%s" % players[0].get("name", "")
if players.size() > 1:
    player2_label.text = "玩家2：%s" % players[1].get("name", "")
```

The player names are correctly passed from `word_poison_game.gd` through the `update_view()` function, but the display adds unnecessary hardcoded prefixes.

## Solution
Modify `scripts/gameplay_panel.gd` to remove the hardcoded prefixes:

**Change from:**
```gdscript
if players.size() > 0:
    player1_label.text = "玩家1：%s" % players[0].get("name", "")
if players.size() > 1:
    player2_label.text = "玩家2：%s" % players[1].get("name", "")
```

**Change to:**
```gdscript
if players.size() > 0:
    player1_label.text = players[0].get("name", "")
if players.size() > 1:
    player2_label.text = players[1].get("name", "")
```

## Scope
- **Files to modify:** `scripts/gameplay_panel.gd` (lines 48-50)
- **Files NOT affected:**
  - `scripts/word_poison_game.gd` - already correctly passes player names
  - `scripts/scoreboard_panel.gd` - already displays names without prefixes
  - `scenes/word_poison_game.tscn` - no changes needed to scene file

## Verification
1. Set custom player names in game setting scene
2. Start poison game
3. Verify player labels show only custom names (e.g., "张三" instead of "玩家1：张三")
4. Check that scoreboard also displays names correctly (already working)

## Risk Assessment
- **Low risk**: Simple string change, no logic modifications
- **Backward compatible**: If player name is empty, `.get("name", "")` returns empty string, which is acceptable
- **No breaking changes**: Other parts of code already handle player names correctly
