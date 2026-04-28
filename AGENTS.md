# AGENTS.md

本文件是 Codex 在本项目中的工作规范。执行代码解释、修改、验证时应优先遵守这里的规则。

## 常见报错与排查经验总结

### 1. 节点引用为空导致属性/方法访问失败
**报错特征**：`Invalid access to property or key '...' on a base object of type 'null instance'.` 或 `Attempt to call function '...' in base 'null instance' on a null instance.`
**发生场景**：
- 在 `.gd` 脚本中使用了 `@onready var my_node = $NodePath` 或 `%UniqueNodeName`。
- 后续由于重构、UI 布局修改，在 `.tscn` 场景文件中**删除、重命名或移动了**该节点。
- 脚本依然在 `_ready()` 或其他函数中尝试访问 `my_node.pressed.connect(...)` 或 `my_node.text = ...`。由于此时 `my_node` 为 `null`，引发报错。
**解决经验**：
1. **核对 `.tscn` 和 `.gd` 的同步情况**：每次进行 UI 重构（特别是删减功能如“下一位玩家”、“结束游戏”按钮时），必须同步检查附加脚本中的 `@onready` 节点路径是否依然有效。
2. **全局搜索遗留节点**：如果一个节点在 UI 中被删去，务必全局搜索它对应的 `%UniqueName` 或变量名，将它的声明和调用（尤其是 `_ready()` 里的信号连接）一同移除，或加入 `if my_node:` 防御性判断（如果是可选节点）。
