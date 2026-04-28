# Poison Game Team Name Display Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Remove hardcoded "玩家1：" and "玩家2：" prefixes from player name labels in poison game, showing only custom names set in game settings.

**Architecture:** Simple string modification in gameplay_panel.gd to directly display player names without prefixes. No changes needed to scene files or other scripts.

**Tech Stack:** Godot 4.x, GDScript

---

### Task 1: Modify Player Name Display in GameplayPanel

**Files:**
- Modify: `scripts/gameplay_panel.gd:47-50`

- [ ] **Step 1: Read current implementation**

Read the `update_view` function in `scripts/gameplay_panel.gd` to understand current name display logic.

- [ ] **Step 2: Modify player label text assignment**

Change the hardcoded prefix format to direct name display:

```gdscript
# 更新玩家标签
if players.size() > 0:
    player1_label.text = players[0].get("name", "")
if players.size() > 1:
    player2_label.text = players[1].get("name", "")
```

Replace the current code (lines 47-50):
```gdscript
# 更新玩家标签
if players.size() > 0:
    player1_label.text = "玩家1：%s" % players[0].get("name", "")
if players.size() > 1:
    player2_label.text = "玩家2：%s" % players[1].get("name", "")
```

- [ ] **Step 3: Verify no other hardcoded prefixes exist**

Search for other occurrences of "玩家1：" or "玩家2：" in the codebase to ensure complete fix.

Run: `grep -r "玩家[12]：" scripts/`
Expected: No output (or only in comments/documentation)

- [ ] **Step 4: Test manually**

1. Open Godot editor
2. Run the project
3. Go to game settings, set custom player names (e.g., "张三", "李四")
4. Start poison game
5. Verify player labels show only "张三" and "李四" without prefixes
6. Check that scoreboard also displays names correctly

- [ ] **Step 5: Commit changes**

```bash
git add scripts/gameplay_panel.gd
git commit -m "fix: show custom player names without hardcoded prefixes in poison game"
```

---

## Self-Review

**1. Spec coverage:**
- ✅ Remove hardcoded prefixes from player1_label and player2_label - Task 1, Step 2
- ✅ Display only custom names - Task 1, Step 2
- ✅ No changes needed to other files - verified in Architecture section

**2. Placeholder scan:**
- ✅ No TBD/TODO placeholders
- ✅ All steps contain actual commands/code
- ✅ File paths are exact

**3. Type consistency:**
- ✅ Using same `players[].get("name", "")` pattern as original code
- ✅ Consistent with scoreboard_panel.gd implementation

---

Plan complete and saved to `docs/superpowers/plans/2026-04-28-poison-game-team-name-display-plan.md`. Two execution options:

**1. Subagent-Driven (recommended)** - I dispatch a fresh subagent per task, review between tasks, fast iteration

**2. Inline Execution** - Execute tasks in this session using executing-plans, batch execution with checkpoints

Which approach?