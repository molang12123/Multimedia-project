## 操作
| 點擊、長按 | 手機端按住畫面左半 / 右半 | 電腦端滑鼠按左半 / 右半，或 F / J |
| 上滑 / 下滑音符 | 按下後手指上移 / 下移 40px | 滑鼠按住後往上 / 下拖曳；或 E / I（上滑）、D / K（下滑） |
| 暫停 | 右上角 II 按鈕、返回鍵 | ESC 或點右上角 II |
| 暫停中繼續 | 「繼續」或返回鍵 | ESC 或「繼續」 |

右上角暫停按鈕的區域（`UI_RESERVED`）不算軌道點擊。

## 判定
- 點擊：±50 ms Perfect、±120 ms Good，超過算 Miss。
- 長按：按下時判定時間，按到尾端算完成；提早超過 150ms 放開算 Miss。
- 滑動：按下時判定時間，手指上下移動 40px 確認方向（不看距離、角度）。方向錯、沒滑就放開、逾時沒滑都算 Miss。
- 暫停時正在按的長按，恢復後會在尾端自動完成（暫停中放開手指的事件收不到）。
- 分數滿分 1,000,000，Good 算 60%。

## 暫停頁與設定
暫停頁有：繼續、重新開始、返回主選單、音樂音量、打擊音效音量、音符速度（0.5x–2.0x）。
- 設定存在 `user://settings.cfg`（`scripts/shared/game_settings.gd` 的 `GameSettings`，靜態類別，不需要 autoload）。
- 音量立即透過 `AudioManager.set_music_volume / set_sfx_volume` 生效；音符速度在繼續後生效。
- 之後做正式設定頁時，讀寫 `GameSettings` 的欄位再 `GameSettings.save_settings()` 。

## 版面（1280×720 橫向）
`scripts/rhythm/rhythm_playfield.gd` 最上方：`SPAWN`（音符出現點，MV 兩側）、`JUDGE`（判定點，拇指處）、`VIDEO_RECT`（MV 位置）、`BASE_SPEEDS`（各難度基礎速度，px/秒）。

## 譜面格式（schema_version 2，一首歌一個檔）
```json
{
  "schema_version": 2,
  "song_id": "monkey_dancing",
  "title": "Monkey Dancing (Driftveil City)",
  "bpm": 135.5,
  "duration_sec": 41.785,
  "audio": {"path": "res://audio/monkey_dancing.mp3", "offset": 0.0},
  "video": {"path": "res://video/monkey_dancing.ogv", "offset": 0.0},
  "difficulties": {
    "easy": [
      {"time_sec": 3.319, "lane": 0},
      {"time_sec": 5.07, "lane": 1, "type": "hold", "duration_sec": 0.812},
      {"time_sec": 10.406, "lane": 0, "type": "swipe", "direction": "up"}
    ],
    "normal": [],
    "challenge": []
  }
}
```
- `lane`：0 左、1 右；省略 `type` = 點擊。`video` 可省略。
- `AudioManager.load_chart(song_id, difficulty)` 回傳給 A / B 的格式與 interfaces.md 的 v1 相同（`schema_version`、`song_id`、`difficulty`、`duration_sec`、`notes`），只是每個音符多了 `lane` / `type` / `duration_sec` / `direction`，另附 `video`。
- 新增歌曲：放音檔 → 用工具產生譜面 → 把檔案加進 `scripts/audio/audio_manager.gd` 的 `SONG_FILES`。

### 自動產生譜面
```
pip install librosa numpy
python tools/make_chart.py audio/xxx.mp3 --id xxx --title "曲名" \
    --audio-res res://audio/xxx.mp3 [--video res://video/xxx.ogv] -o charts/xxx.json
```
依拍點排音符；challenge 另外加入有明顯起拍的八分音符。偵測不到拍子的音檔可用 `--grid 120:2.0`（BPM:第一拍秒數）。產生的只是起點，需要玩過後手動修。

## 對外介面（照 docs/interfaces.md）
- `scenes/rhythm/rhythm_playfield.tscn` 實作 `RhythmPort`。`note_judged` 的 result 除了 v1 的 4 個鍵，另附 `combo`、`lane`、`note_type`（給 UI 用）。`try_hit()` 判定兩軌中最早的音符。
- 時間：只用 `AudioManager.get_song_time()`；歌曲從 -1 秒開始（前奏留白），音樂在 `audio.offset` 開始播放。

---

### 新增
- `scripts/rhythm/*`、`scenes/rhythm/*`、`charts/*.json`（新格式）、`tools/make_chart.py`、`tests/rhythm/*`、`docs/rhythm_core.md`

### 需要功能版 UI（改外觀或換掉）
- `scenes/ui/rhythm_hud.tscn`：分數、歌名、Combo、判定文字、右上角暫停鈕、ESC / 返回鍵暫停。根節點與文字必須保持 `mouse_filter = Ignore`，否則觸控會被吃掉，打不到音符。
- `scenes/ui/pause_menu.tscn`：暫停頁（Process Mode = Always）。
- 兩者都只用 UIPort 的 signal / 方法，換掉時保持相同的 signal 就好。

### 可用的 AudioManager
`scripts/audio/audio_manager.gd`（實作 `AudioPort`）：播放本地 mp3 / wav、音訊時鐘平滑、暫停凍結時間、自然結束時只發一次 `song_finished`、音量、打擊音效。D 可以接手或重寫，只要維持 AudioPort。

### 改了原先的檔案（可能需要review?）
1. **`scripts/core/game_manager.gd`（修 bug）**：Godot 4.7 的 `SceneTree.scene_changed` 沒有參數，原本的 `_on_scene_changed(scene)` 每次都呼叫失敗，`_changing_scene` 卡在 true，**第一次換場景後所有導覽都會失效**。改成無參數，從 `get_tree().current_scene` 取得場景。
2. **`scenes/core/rhythm_game.tscn`**：三個子場景換成 B / C 的正式版；根節點 `mouse_filter = Ignore`。Godot 的 GUI 也會處理觸控事件，原本全螢幕的 Control（預設 Stop）會把所有點擊、觸控吃掉。
3. **`project.godot`**：橫向 1280×720、`orientation = sensor_landscape`、`AudioManager` autoload 改指向 `scripts/audio/audio_manager.gd`、`emulate_touch_from_mouse = true`（電腦用滑鼠測觸控）、`quit_on_go_back = false`（Android 返回鍵改成暫停，不會直接關閉遊戲）。
4. **`scenes/menus/main_menu.gd`**：舊原型場景已刪除，這個舊選單改成跳回 bootstrap。
5. 刪除舊的 4 軌原型：`scenes/main.tscn`、`scenes/note.tscn`、`scripts/rhythm_manager.gd`、`hud.gd`、`note.gd`、`song_clock.gd`。

## Android 測試
1. 匯出前在 Android 匯出設定的 **Resources → Filters to export non-resource files** 加上 `*.json`，確保譜面被打包（若已自動包含，加了也無妨）。
2. 實機要確認：觸控雙押、長按、上下滑手感；右上角暫停鈕；返回鍵 = 暫停 / 繼續；MV（.ogv）是否播放；切到背景再回來時遊戲應自動暫停（GameManager 已處理）。
3. 若每次點擊都偏早或偏晚：看判定文字下方的 ms 數，之後可以把 `GameSettings.input_offset` 做成設定項。
