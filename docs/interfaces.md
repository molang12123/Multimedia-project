# Silver Rhythm — A/B/C/D 接口 v1（待组员确认）

## 总则

- A 只处理流程与整合，B 的判定、C 的正式 UI、D 的音乐读取属于各自成员。
- 公共接口脚本：`scripts/interfaces/rhythm_port.gd`、`audio_port.gd`、`ui_port.gd`。
- Mock 与正式场景均须遵守同一契约；正式场景可扩展，但不得破坏这些基础方法。
- 歌曲时间单位一律为 **float 秒**；难度只能是 `easy` / `normal` / `challenge`。
- **当前旧原型**使用四轨、`hard` 与谱面 v2，这不属于本 PR 的修改。B/D 接入时需要协调转换，不要将旧接口直接当成 v1。

## B 节奏系统（RhythmPort）

- `start_rhythm(chart: Dictionary) -> bool`：初始化并启动一局
- `pause_rhythm() -> void`；`resume_rhythm() -> void`
- `reset_rhythm() -> void`：清空旧音符/成绩
- `try_hit(song_time: float) -> Dictionary`：返回一次点击判定
- `finalize_rhythm() -> void`：歌曲自然结束时将剩余音符结算，仅发出一次最终结果
- `score_changed(score: int)` Signal
- `note_judged(result: Dictionary)` Signal；result 的键：`judgement`（PERFECT/GOOD/MISS/NONE）、`time_sec`、`delta_sec`、`score_delta`
- `rhythm_finished(result: Dictionary)` Signal；result 的键：`song_id`、`difficulty`、`score`、`max_combo`、`perfect`、`good`、`miss`、`total_notes`、`completed`
- `NONE` 表示未判定，不需要发出 note_judged。

B 必须通过 `AudioManager.get_song_time()` 取得音乐时间，不得另外使用墙钟判定。当前 Mock 内建自动 Perfect/Good/Miss **只为测试**。

## C UI（UIPort）

提供 Signal：`start_pressed()`、`song_selected(song_id: String, difficulty: String)`、`pause_requested()`、`resume_requested()`、`restart_requested()`、`menu_requested()`、`song_select_requested()`、`tutorial_requested()`、`settings_requested()`、`free_play_requested()`。

A 向需要的 UI 场景调用：`set_song_info(song_id, difficulty)`、`set_score(score)`、`show_judgement(result)`、`set_paused(bool)`、`set_result(result)`。

C 只 emit Signal，不直接修改 GameState.current_state，也不直接调用 B 的评分逻辑。**Mock 专用** tap_requested 让试玩者手动触发点击，正式 C 可不用。

暂停 Overlay 必须 Process Mode=Always。

## D AudioManager（AudioPort）

全局 Autoload 名称固定为 `AudioManager`；仅创建一个实例。

- `play_song(song_id: String) -> bool`
- `stop_music() -> void`
- `pause_music() -> void`
- `resume_music() -> void`
- `get_song_time() -> float`
- `load_chart(song_id: String, difficulty: String) -> Dictionary`
- `get_song_catalog() -> Array`，每首歌至少有 `id`、`title`
- `set_music_volume(value: float) -> void`；`set_sfx_volume(value: float) -> void`（范围 0.0–1.0）
- `play_sfx(sound_id: String) -> void`
- `song_finished()` Signal：仅自然播放结束才触发，不因 stop_music 触发

暂停时歌曲时间必须冻结，恢复后从原位置继续；不允许突然归零或重复发 song_finished。

## 谱面 v1 示例

```json
{
  "schema_version": 1,
  "song_id": "song_01",
  "difficulty": "easy",
  "duration_sec": 15.0,
  "notes": [{"time_sec": 2.0}, {"time_sec": 3.5}]
}
```

D 返回上面的 Dictionary 给 A，A 原样传给 B。音符时间为目标点击时间，顺序递增。真实的谱面结构如需支持多轨，请由 B/D 共同确认版本，A 可加适配层。

## 音乐结束约定

D 发 song_finished → A 调 B.finalize_rhythm() → B 处理遗漏音符并发 rhythm_finished(result) → A 保存结果进入结算；不得在 D 结束时直接丢弃尚未处理的 B 音符。
