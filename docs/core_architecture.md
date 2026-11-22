# Silver Rhythm — A 核心架构（Mock 第一版）

本分支仅开发 A 的核心架构、模块协议与 Mock。**未修改**原有 `scenes/main.tscn`、`scripts/rhythm_manager.gd`、`scripts/song_clock.gd`、`scripts/hud.gd` 或歌曲/视频文件。

## 启动与全局结构

- `project.godot` → `scenes/core/bootstrap.tscn` → GameManager → Mock 主菜单
- Autoload 按顺序注册：`GameState`、`AudioManager`（Mock）、`GameManager`
- `GameState`：选择信息、状态转换、成绩；不执行场景切换。
- `GameManager`：唯一场景导航入口，管理开始/暂停/继续/重开/返回/结算。
- `RhythmGameController`：组合 B 的 Playfield、C 的 HUD 和 Overlay、D 的 AudioManager；不计算音符或歌曲时间。

## 场景与文件所有权

| 路径 | 负责人 |
| --- | --- |
| scenes/core, scripts/core | A |
| scenes/mocks, scripts/mocks | A（仅测试替身） |
| scripts/interfaces, docs/interfaces.md | A（修改前与 B/C/D 确认） |
| scenes/rhythm, scripts/rhythm | B |
| scenes/ui, scripts/ui | C |
| scenes/audio, scripts/audio, charts | D |
| tests/android | E |

目前项目已有的 `scenes/main.tscn` 是旧节奏原型，暂时不迁移或删除。PR 合并前，Mock 将成为项目默认入口。需要查看旧原型，可在 Godot 编辑器直接打开 `scenes/main.tscn` 并运行当前场景（F6）。

## 流程

启动 → 主菜单 → 选歌/难度 → RhythmGameController → 结算 → 重开/选歌/主菜单。

主菜单还可进入教学、设置、自由演奏**占位场景**，均能返回主菜单。

暂停画面是节奏场景的子场景，Process Mode=Always。A 统一通过 `SceneTree.paused` 控制暂停；Mock 音乐时间只在 _process(delta) 增长，因此暂停不跳时。真实 D 必须另行正确处理自己的音频时钟。

## 替换 Mock 的位置

1. B 实现 `RhythmPort` 并提供 Node2D 场景：替换 `scenes/core/rhythm_game.tscn` 下的 `RhythmPlayfield` 实例。
2. C 实现 `UIPort`：分别替换 `RhythmHUD` 与 `PauseOverlay` 实例；更新 GameManager 的其他 UI 场景路径。
3. D 实现 `AudioPort`：只将 `project.godot` 的 `AudioManager` Autoload 路径改为 D 的实现。
4. A 负责以上整合，不让 B/C/D 同时编辑 `scenes/core/rhythm_game.tscn`。

所有跨模块方法与 Signal 见 `docs/interfaces.md`。

## 暂未改变的项目设置

当前 `project.godot` 原本是 720×1280 直屏，现阶段**刻意保留**，以免影响组员现有四轨原型；横屏（如 1280×800）、单轨玩法和 Android 真机导出应由团队定稿后再分别实施。本 PR 只验证 A 的架构，不宣称已达成 Android 横屏验收。

## 手动 Smoke Test

1. 启动 Godot 项目（F5），应进入「银龄节奏 · A 组 Mock」。
2. 开始游戏 → 选择歌曲与难度 → 开始；HUD 显示选择，模拟成绩逐渐变化。
3. 点击暂停；等待几秒，恢复后应从原先音乐时间继续。
4. 暂停状态下重开或返回主菜单，不应卡在暂停。
5. 等待约 15 秒，进入成绩页；重开、重新选歌、返回主菜单都应有效。
6. 快速连续点击任意导航按钮，不应重复切换或产生多份场景。
7. 命令行单元 Smoke Test：`godot --headless --path . --script res://tests/core/core_state_test.gd`。

**验证限制：** 当前仅已提交结构与源码，尚未在实际 Godot 4.7 编辑器和 Android 设备执行验证。请在本地运行上述测试后再合并 PR。
