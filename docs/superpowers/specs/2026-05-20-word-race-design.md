# Word Race（单词竞速）游戏设计文档

## 1. 概述

**游戏名称**：单词竞速（Word Race）
**游戏 ID**：`word_race`
**显示顺序**：3
**核心玩法**：两个玩家同屏对战，每回合展示一个英文单词和多个中文选项，先点击正确选项的玩家得分，答错则锁定 5 秒冷却。

## 2. 游戏规则

### 2.1 基本规则
- 固定两个玩家同屏对战
- 每回合展示 1 个英文单词 + N 个中文选项（N 可配置，默认 3）
- 两个玩家各自有独立的操作面板，看到相同的题目
- 先点击正确选项的玩家 +1 分，回合结束
- 点击错误选项的玩家操作面板锁定 5 秒（冷却时间可配置）
- 冷却期间对手仍可继续答题
- 若对手在冷却期间答对 → 对手得分，回合结束
- 若对手也答错 → 双方都进入冷却，先解除冷却并答对者得分

### 2.2 胜负判定
- 所有回合结束后，总分高者获胜
- 若总分相同，则为平局

## 3. 设置界面（SettingView）

### 3.1 可配置参数

| 参数 | 类型 | 默认值 | 范围 | 说明 |
|------|------|--------|------|------|
| 总回合数 | int | 10 | 1~50 | 游戏总回合数 |
| 选项数量 | int | 3 | 2~6 | 每个回合的中文选项数量 |
| 单词表 | WordSet | basic_words.txt | - | 从 WordSetStore 选择 |
| 玩家 A 名称 | string | "玩家A" | - | 固定两个玩家 |
| 玩家 B 名称 | string | "玩家B" | - | 固定两个玩家 |
| 答错冷却时间 | float | 5.0 | 1~10 | 秒数 |

### 3.2 界面布局
- 复用项目已有的 `word_source_panel` 组件进行单词表选择
- 玩家名称设置：固定两个输入框（玩家A、玩家B），不使用 `player_setup_panel`（该组件支持动态增减玩家，本游戏不需要）
- 增加"总回合数"和"选项数量"的滑块/输入框
- 增加"答错冷却时间"的输入框
- 底部"开始游戏"按钮

## 4. 游戏界面（GameplayView）

### 4.1 UI 布局（品字形）

```
┌─────────────────────────────────────┐
│           单词显示区域              │
│         "apple" (大字)              │
│       回合 3/10 · 答对得分          │
├──────────────────┬──────────────────┤
│   玩家A 操作面板  │   玩家B 操作面板  │
│                  │                  │
│  ┌────┐ ┌────┐  │  ┌────┐ ┌────┐  │
│  │ 苹果 │ │ 香蕉 │  │ │ 苹果 │ │ 香蕉 │  │
│  └────┘ └────┘  │  └────┘ └────┘  │
│  ┌────┐ ┌────┐  │  ┌────┐ ┌────┐  │
│  │ 橙子 │ │ 葡萄 │  │ │ 橙子 │ │ 葡萄 │  │
│  └────┘ └────┘  │  └────┘ └────┘  │
│                  │                  │
│  得分: 2         │  得分: 1         │
│  状态: 冷却 3s   │  状态: 正常       │
└──────────────────┴──────────────────┘
```

### 4.2 交互流程
1. 回合开始 → 单词区域显示英文单词，两个面板同时显示相同的 N 个中文选项
2. 玩家点击选项：
   - **正确** → 该玩家 +1 分，播放成功音效，回合结束
   - **错误** → 该玩家面板锁定 5 秒，显示冷却倒计时，播放错误音效
3. 回合结束 → 短暂延迟 1.5 秒后进入下一回合
4. 所有回合结束 → 跳转结果界面

### 4.3 状态管理（ViewModel）

```gdscript
# 核心状态变量
var _config: Dictionary = {}
var _selected_word_set: Dictionary = {}
var _all_words: Array = []
var _total_rounds: int = 10
var _option_count: int = 3
var _cooldown_duration: float = 5.0
var _current_round: int = 0
var _current_word: Dictionary = {}  # {"english": "apple", "chinese": "苹果"}
var _options: Array = []  # [{"text": "苹果", "is_correct": true}, ...]
var _players: Array = []  # 两个玩家的状态
var _round_finished: bool = false
var _game_finished: bool = false
```

### 4.4 计时器
- 冷却倒计时用 `Timer` 节点实现，每秒更新 UI
- 回合间过渡延迟 1.5 秒

## 5. 结果界面（ResultView）

### 5.1 UI 布局

```
┌─────────────────────────────────────┐
│            游戏结束                  │
│                                     │
│         ┌─────────────┐             │
│         │   胜利者     │             │
│         │   玩家A      │             │
│         │   得分: 7    │             │
│         └─────────────┘             │
│                                     │
│    玩家A: 7分  vs  玩家B: 3分       │
│                                     │
│    统计信息:                         │
│    - 总回合数: 10                    │
│    - 玩家A 正确率: 70%               │
│    - 玩家B 正确率: 30%               │
│                                     │
│    [再来一局]    [返回大厅]          │
└─────────────────────────────────────┘
```

### 5.2 数据传递
- 从 GameplayView 传入 `results` 字典：
  - `player_a_name` / `player_b_name`
  - `player_a_score` / `player_b_score`
  - `total_rounds`
  - `player_a_correct_count` / `player_b_correct_count`

### 5.3 按钮行为
- **再来一局** → `SceneRouter.goto_setting("word_race")` 返回设置页
- **返回大厅** → `SceneRouter.goto_hub()`

## 6. 文件结构

```
games/word_race/
├── race_def.gd              # GameDef 子类
├── race_config.gd           # 配置验证和构建
├── view_models/
│   ├── race_setting_vm.gd   # 设置页 ViewModel
│   ├── race_gameplay_vm.gd  # 游戏页 ViewModel
│   └── race_result_vm.gd    # 结果页 ViewModel
└── views/
    ├── setting_view.gd      # 设置页 View
    ├── setting_view.tscn    # 设置页场景
    ├── gameplay_view.gd     # 游戏页 View
    ├── gameplay_view.tscn   # 游戏页场景
    ├── result_view.gd       # 结果页 View
    └── result_view.tscn     # 结果页场景
```

## 7. 核心算法

### 7.1 选项生成
1. 从单词表中随机选择 1 个单词作为正确答案
2. 从剩余单词中随机选择 N-1 个作为干扰项
3. 将所有选项随机打乱顺序
4. 确保每个回合的选项顺序对两个玩家相同

### 7.2 冷却机制
1. 玩家点击错误选项时，记录冷却开始时间
2. 启动 Timer 节点，每秒更新剩余冷却时间
3. 冷却期间禁用该玩家的操作面板
4. 冷却结束后重新启用操作面板

### 7.3 回合结束判定
1. 有玩家答对 → 该玩家得分，回合结束
2. 所有玩家都处于冷却状态 → 等待最先冷却结束的玩家继续答题

## 8. 复用组件

- `WordSetStore`：单词表加载和解析
- `SceneRouter`：场景导航
- `GameView` / `ViewModel`：MVVM 基类
- `word_source_panel`：单词表选择组件
- `result_row`：结果行组件

## 9. 注册

在 `game_registry.gd` 的 `_register_builtin_games()` 中添加：

```gdscript
register_game(preload("res://games/word_race/race_def.gd").new())
```
