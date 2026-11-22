# 银龄节奏（Silver Rhythm）

Godot 4.x 音乐游戏团队项目。现有 B 节奏原型保存在 `scenes/main.tscn`，A 的独立核心架构及 Mock 入口保存在 `scenes/core/`。

## 本分支：A 的架构与 Mock

- 用 Godot 打开根目录的 `project.godot`，按 **F5** 可从 A 的 Mock 主菜单开始。
- 单独运行原有节奏原型：在编辑器打开 `scenes/main.tscn`，按 **F6**。
- 全局 Autoload：GameState、AudioManager（Mock）、GameManager。
- Mock 可测试选歌、难度、假成绩、暂停/继续、重开、结算和返回菜单。
- 正式 B/C/D 模块尚未接入，现有旧原型保持原样。

## 文档

- [核心架构与测试步骤](docs/core_architecture.md)
- [B/C/D 统一接口](docs/interfaces.md)

## 核心状态单元测试

在 Godot 可执行文件加入 PATH 的环境中，运行：

```bash
godot --headless --path . --script res://tests/core/core_state_test.gd
```

目前未在 Godot 编辑器或 Android 设备验证。测试通过后再合并分支。
