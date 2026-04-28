# Custom Dropdown Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a reusable custom dropdown scene with styled popup items and wire it into the word-set selector in `game_setting.tscn`.

**Architecture:** Introduce two small reusable UI units: one dropdown root scene and one dropdown item scene. Keep data-loading in `scripts/game_setting.gd`; the dropdown only renders items, manages open/close state, and emits selection signals.

**Tech Stack:** Godot 4.6, GDScript, `.tscn` scenes

---

## File Structure

- Create: `scenes/components/custom_dropdown.tscn`
- Create: `scenes/components/custom_dropdown_item.tscn`
- Create: `scripts/custom_dropdown.gd`
- Create: `scripts/custom_dropdown_item.gd`
- Modify: `scenes/game_setting.tscn`
- Modify: `scripts/game_setting.gd`
- Modify: `scripts/tests/test_game_setting_scene.gd`

## Verification

- Preferred: `godot --headless --path "." -s res://scripts/tests/test_game_setting_scene.gd`
- Current limitation: this workspace does not expose a callable `godot` CLI, so static review is the fallback until the binary path is provided.
