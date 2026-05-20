# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## 项目概览

WorldWar Fourth Place Edition — 经典 WEGO 回合制策略战棋游戏，基于 Godot 4.6 引擎。视图层与逻辑层完全分离，通过 EventBus 信号 + GameSim API 双向通信。

## 常用命令

### Godot Headless 校验

修改 `.gd` 脚本后使用 Linux 版 Godot 做语法检查：

```bash
# 资源导入校验（优先执行）
"/home/dragaseslee/godot/Godot_v4.6.2-stable_linux.x86_64" --headless --path . --import

# 单文件语法检查
"/home/dragaseslee/godot/Godot_v4.6.2-stable_linux.x86_64" --headless --path . --check-only --script res://scripts/xxx.gd
```

注意：`--check-only --script` 只能检查脚本解析和加载问题，依赖场景节点、Autoload 或运行时树的脚本无法完整验证。

## 架构核心

### Autoload 单例

- **`EventBus`** (`scripts/autoload/event_bus.gd`) — 全局发布/订阅信号总线，内建事件录制与回放。逻辑层只发信号，视图层只收信号。
- **`GameSim`** (`scripts/autoload/game_sim.gd`) — 游戏模拟核心，管理战役生命周期（init → planning → resolution → game_over），持有所有数据（units, buildings, factions），协调子系统。

### 三层架构

```
视图层 (scripts/game/, scripts/rendering/)  →  调用 GameSim API，订阅 EventBus 信号
逻辑层 (scripts/systems/)                    →  纯工具类 System，通过 TurnContext 注入
数据层 (scripts/resources/)                  →  Unit, BattleMap, Order 等 Resource 类型
```

### 回合流程

1. **Planning**: 玩家/AI 提交命令 → 各方确认 → 进入 Resolution
2. **Resolution**: 构建优先队列 → 逐单位调用 `UnitAI.decide()` → `unit.execute_action()` → `_apply_effects()` → 事件发送
3. **Post-resolution**: 口粮消耗 → 士气结算 → 信使推进 → 视野更新 → 胜利检查

### 关键设计模式

- **TurnContext** — 参数对象，聚合所有 System 引用和回合状态，避免函数参数爆炸。Unit 和 AI 通过 context 访问 System，不直接依赖。
- **Effect 引擎** — Unit 执行动作返回 `Array[Dictionary]`（effect 列表），GameSim 的 `_apply_effects()` 统一应用到游戏状态并发送事件。
- **优先队列结算** — 按优先级排序的循环队列，每轮消耗 1 AP，AP 耗尽退出。
- **AI** — GOAP 架构（`AISystem` + `ActionPlanner` + `WorldStateEvaluator`），单位级决策由 `UnitAI` 根据命令和姿态决定。

### 子系统

| System | 职责 |
|--------|------|
| `VisionSystem` | BFS 扩散计算视野，地形阻挡 |
| `MovementSystem` | A* 寻路（四向网格），查找最近空位 |
| `CombatSystem` | 伤害计算、士气逃跑、击退 |
| `MoraleSystem` | 单位消灭影响周围士气 |
| `RationSystem` | 口粮消耗与饥饿状态 |
| `MessengerSystem` | 信使传递命令/报告 |
| `VictorySystem` | 占领/歼灭/存活/限时胜利判定 |

### 数据资源类型

- `BattleMap` — 地图（grid_size, grids, buildings, factions, victory_conditions）
- `MapGrid` — 单格（terrain_type, move_cost_override, passable_override, cover_bonus, vision_block）
- `Unit` — 部队（grid_pos, hp, ap, morale, troop_type, formation, pending_orders）
- `Order` — 命令（order_type, target_id/pos, sender_id, expire_turn, stance）
- `Faction` — 阵营（faction_id, is_player, initial_units）

## 工作规范

- 默认使用中文交流，代码注释使用中文
- 修改 `.gd` 文件时注意 `.tscn`、`.tres`、Autoload、输入映射和资源路径是否受影响
- 优先沿用项目已有结构和命名，不为小问题引入过度抽象
- 修改后必须运行 Godot headless 校验
- 不规范的经验教训补充到 `godot编码规范.md` 的 "常见陷阱与规避" 章节（如果该文件存在）
- **Edit 工具注意事项**：项目 `.gd` 文件使用 4 空格缩进（非 tab）。`Edit` 工具的 `old_string` 必须与文件内容逐字符精确匹配，缩进不匹配是最常见的失败原因。大块替换优先用 `Write` 覆盖整个文件。`Edit` 失败时用 `cat -A` 检查实际缩进字符。
