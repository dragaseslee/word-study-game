# WordComplete（补全单词）游戏设计

## 概述

双人对战单词补全游戏。显示英文单词（随机缺少 1 个字母）和中文意思，两个玩家轮流在各自的字母网格中点击缺少的字母。点击正确得分并继续，点击错误换对方。

## 核心玩法

- 每题显示一个英文单词，随机隐藏 1 个字母（用 `_` 替代），同时显示中文意思
- 两个玩家轮流操作，非活跃方整个面板（含字母网格）灰色禁用
- 活跃玩家在自己的字母网格中点击缺少的字母：
  - **正确**：得分 +1，刷新下一题（字母网格重新生成），同一玩家继续活跃
  - **错误**：切换活跃方，当前题不变，对方在自己的网格中选择
- 固定题数，答完显示结果

## 字母网格

- 每个玩家面板内各有一套字母网格
- 网格包含正确字母 + 10 个干扰字母（随机大写字母，不重复），共 11 个按钮
- 字母统一显示为大写，匹配时忽略大小写（word 中的 `a` 匹配按钮 `A`）
- 按钮排列为 3 行（4-4-3），随机打乱顺序
- 复用 `option_card.tscn` 按钮风格

## 布局（从上到下）

```
┌───────────────────────────────┐
│         第 3/10 题             │  ← RoundLabel
│                               │
│        中文意思：苹果          │  ← MeaningLabel
│        a p _ l e              │  ← WordLabel（缺失字母高亮为下划线）
│                               │
│  ┌──────────┐  ┌──────────┐  │
│  │  玩家A    │  │  玩家B    │  │
│  │  得分: 2  │  │  得分: 1  │  │
│  │  回答中   │  │  等待     │  │
│  │          │  │          │  │
│  │ [Q][W][R]│  │ [Q][W][R]│  │  ← 各自的字母网格
│  │ [T][Y][U]│  │ [T][Y][U]│  │    非活跃方灰色禁用
│  │ [I][P][A]│  │ [I][P][A]│  │
│  └──────────┘  └──────────┘  │
└───────────────────────────────┘
```

## 设置页

| 设置项 | 类型 | 默认值 | 说明 |
|--------|------|--------|------|
| 词库选择 | OptionButton + 导入按钮 | 第一个可用词库 | 复用 WordSetStore |
| 总题数 | SpinBox（1-50） | 10 | 答完结束 |
| 玩家A名字 | LineEdit | "玩家A" | |
| 玩家B名字 | LineEdit | "玩家B" | |

## 结果页

显示双方最终得分和胜负判定，提供"再来一局"（回设置页）和"返回主页"按钮。

## 技术实现

### 文件结构

```
games/word_complete/
  complete_config.gd          # 配置构建与校验
  complete_def.gd             # GameDef 子类
  view_models/
    complete_setting_vm.gd     # 设置页 ViewModel
    complete_gameplay_vm.gd    # 游戏页 ViewModel
    complete_result_vm.gd      # 结果页 ViewModel
  views/
    setting_view.tscn + .gd    # 设置页
    gameplay_view.tscn + .gd   # 游戏页
    result_view.tscn + .gd     # 结果页
```

### 需修改的文件

| 文件 | 修改内容 |
|------|---------|
| `core/autoload/game_registry.gd` | 添加 `register_game(preload("res://games/word_complete/complete_def.gd").new())` |
| `core/autoload/scene_router.gd` | 添加 3 条路由：`setting_word_complete`、`gameplay_word_complete`、`result_word_complete` |
| `scripts/game_hub.gd` | 添加入口按钮的 `@onready` 引用和按下事件处理 |
| `scenes/game_hub.tscn` | 添加入口面板和按钮节点 |

### 复用

| 组件 | 来源 |
|------|------|
| 主题 | `themes/word_race.tres` |
| 词库 | `WordSetStore` autoload |
| 按钮风格 | `scenes/components/option_card.tscn` |
| MVVM 框架 | `core/mvvm/game_view.gd`、`core/mvvm/view_model.gd`、`core/mvvm/game_def.gd` |

### ViewModel 数据流

**SettingVM**
- 输入：词库列表、设置项
- 输出：config dict（`file_path`、`total_rounds`、`player_a_name`、`player_b_name`）

**GameplayVM**
- 输入：config dict
- 状态：当前题目索引、当前单词、缺失字母位置、活跃玩家索引、双方得分、字母列表
- 核心方法：`select_letter(letter)` → 判断正误、更新状态、切换玩家
- 输出：view_data dict（`current_round`、`total_rounds`、`meaning`、`masked_word`、`players`、`active_player_index`、`letters`、`game_finished`）

**ResultVM**
- 输入：results array
- 输出：view_data dict（`players`、`winner_name`）

### 场景节点结构

**gameplay_view.tscn**
```
WordCompleteGameplay (Control, full-rect, themed)
  VBoxContainer
    RoundLabel (Label)
    MeaningLabel (Label)
    WordLabel (Label, bbcode/rich text for underscore highlight)
    HBoxContainer
      PlayerAPanel (Panel, PlayerPanel style)
        VBoxContainer
          PlayerANameLabel
          PlayerAScoreLabel
          PlayerAStatusLabel
          GridContainer (3 columns)
            [动态创建的字母按钮]
      PlayerBPanel (Panel, PlayerPanel style)
        VBoxContainer
          PlayerBNameLabel
          PlayerBScoreLabel
          PlayerBStatusLabel
          GridContainer (3 columns)
            [动态创建的字母按钮]
```

### 游戏状态机

```
IDLE → PLAYER_A_TURN → PLAYER_B_TURN → GAME_OVER
         ↑       |         ↑       |
         └─正确──┘         └─正确──┘
         错误→切换          错误→切换
```

- 每次 `select_letter()` 调用时：
  1. 检查是否为正确字母
  2. 正确：当前玩家得分 +1，如果还有下一题则刷新题目和字母网格（同一玩家继续），否则进入 GAME_OVER
  3. 错误：切换活跃玩家，当前题和字母网格不变（双方交替尝试直到有人答对）

### 干扰字母生成

```gdscript
func _generate_distractors(correct_letter: String, count: int = 10) -> Array[String]:
    var all_letters = "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
    var pool = all_letters.replace(correct_letter, "")
    pool = pool.substr(0, count)  # 取前 count 个
    # 或者随机采样
    var result: Array[String] = [correct_letter]
    var shuffled = pool.split("")
    shuffled.shuffle()
    for i in range(count):
        result.append(shuffled[i])
    result.shuffle()
    return result
```
