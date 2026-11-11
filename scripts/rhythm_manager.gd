extends Node2D
## Core rhythm loop (member B): 4 lanes, spawn notes, move them from song time,
## judge taps per lane, score.
##
## Interfaces for the other members:
##   D -> SongClock (song time / audio backend) and the chart JSON (see README, format v2)
##   A -> start_game(difficulty)  and the `finished(result)` signal
##   C -> `judged(...)` signal  (the Hud node here is a placeholder UI)

signal judged(judgement: String, combo: int, score: int, delta_ms: float)
signal finished(result: Dictionary)

const NOTE_SCENE := preload("res://scenes/note.tscn")
const CHART_PATHS := [
	"res://charts/demo_local.json",
	"res://charts/monkey_dancing.json",
]

const LANES := 4
const LANE_AREA_X := 40.0
const LANE_W := 160.0
const KEYS := [KEY_D, KEY_F, KEY_J, KEY_K]   # desktop testing keys, lane 0..3

const SCREEN_W := 720.0
const SCREEN_H := 1280.0
const JUDGE_Y := 1040.0
const SPAWN_Y := -60.0
const START_TIME := -1.0          # song clock starts here (lead-in before first note)
const END_PADDING := 1.5          # seconds after the last note before results

const PERFECT_WINDOW := 0.050     # +-50 ms
const GOOD_WINDOW := 0.120        # +-120 ms, later than this = Miss
const GOOD_WEIGHT := 0.6          # Good counts as 60% of a Perfect for score

# fall speed in pixels per second
const SPEEDS := {"easy": 600.0, "normal": 800.0, "hard": 1000.0}

@onready var clock: Node = $SongClock
@onready var notes_root: Node2D = $Notes
@onready var hud: CanvasLayer = $Hud

## Shift judging by this many seconds to compensate for device/audio latency.
var input_offset := 0.0

var _charts: Array = []
var _song_index := 0
var _times: PackedFloat64Array = PackedFloat64Array()
var _lanes: PackedInt32Array = PackedInt32Array()
var _speed := 800.0
var _travel_time := 1.0
var _next_index := 0
var _active: Array = []           # Note nodes still on screen, ordered by hit_time
var _playing := false
var _difficulty := ""
var _end_time := 0.0
var _flash := PackedFloat32Array([0.0, 0.0, 0.0, 0.0])

var _counts := {"perfect": 0, "good": 0, "miss": 0}
var _combo := 0
var _max_combo := 0
var _score := 0
var _sfx: AudioStreamPlayer

# 新增的影片相關變數
var _video: VideoStreamPlayer
var _video_offset := 0.0
var _video_started := false


func _ready() -> void:
	var titles: Array = []
	for p in CHART_PATHS:
		var c := _load_chart(p)
		if not c.is_empty():
			_charts.append(c)
			titles.append(str(c.get("title", p)))
	_sfx = AudioStreamPlayer.new()
	_sfx.stream = _make_click()
	add_child(_sfx)
	
	# 新增背景影片播放器
	_video = VideoStreamPlayer.new()
	_video.position = Vector2.ZERO
	_video.size = Vector2(SCREEN_W, SCREEN_H)
	_video.expand = true
	_video.z_index = -10
	_video.volume_db = -80.0  # set video to mute
	add_child(_video)
	
	hud.set_songs(titles)
	hud.song_selected.connect(func(i): _song_index = i)
	hud.difficulty_selected.connect(start_game)
	hud.show_menu()


func start_game(difficulty: String) -> void:
	if _charts.is_empty():
		push_error("No charts loaded")
		return
	var chart: Dictionary = _charts[_song_index]
	var diffs: Dictionary = chart["difficulties"]
	if not diffs.has(difficulty):
		push_error("Chart has no difficulty '%s'" % difficulty)
		return
	for n in _active:
		n.queue_free()
	_active.clear()
	_difficulty = difficulty
	_parse_notes(diffs[difficulty])
	_speed = SPEEDS[difficulty]
	_travel_time = (JUDGE_Y - SPAWN_Y) / _speed
	_next_index = 0
	_counts = {"perfect": 0, "good": 0, "miss": 0}
	_combo = 0
	_max_combo = 0
	_score = 0
	_end_time = _times[_times.size() - 1] + END_PADDING
	hud.set_score(0)
	hud.set_combo(0)
	hud.hide_menu()
	_setup_media(chart)
	clock.start(START_TIME)
	_playing = true


func _process(delta: float) -> void:
	if _video != null and is_instance_valid(_video):
		_video.size = get_viewport_rect().size

	var flashing := false
	for i in LANES:
		if _flash[i] > 0.0:
			_flash[i] = maxf(0.0, _flash[i] - delta)
			flashing = true
	if flashing:
		queue_redraw()

	if not _playing:
		return
	var t: float = clock.get_time()
	
	# 觸發背景影片播放
	if not _video_started and _video.stream != null and t >= _video_offset:
		_video.play()
		_video_started = true

	# 1) spawn notes whose fall must begin now
	while _next_index < _times.size() and t >= _times[_next_index] - _travel_time:
		_spawn(_times[_next_index], _lanes[_next_index])
		_next_index += 1

	# 2) position every note from song time, detect misses, clean up
	for n in _active.duplicate():
		n.place(t, JUDGE_Y, _speed)
		if not n.missed and t - input_offset - n.hit_time > GOOD_WINDOW:
			n.mark_missed()
			_register("miss", 0.0)
		if n.position.y > SCREEN_H + 60.0:
			_active.erase(n)
			n.queue_free()

	# 3) song over?
	if t > _end_time:
		_finish()


func _unhandled_input(event: InputEvent) -> void:
	if not _playing:
		return
	if event is InputEventScreenTouch and event.pressed:
		# one event per finger -> real multi-touch; desktop mouse is emulated as touch
		var lane := clampi(int(floor((event.position.x - LANE_AREA_X) / LANE_W)), 0, LANES - 1)
		_on_tap_lane(lane, clock.get_time())
	elif event is InputEventKey and event.pressed and not event.echo:
		var lane: int = KEYS.find(event.physical_keycode)
		if lane >= 0:
			_on_tap_lane(lane, clock.get_time())


func _on_tap_lane(lane: int, t: float) -> void:
	_flash[lane] = 0.12
	queue_redraw()
	# judge against the earliest note in this lane that has not been hit or missed yet
	for n in _active:
		if n.lane != lane or n.missed:
			continue
		var delta: float = t - input_offset - n.hit_time
		if delta < -GOOD_WINDOW:
			return  # nearest note in this lane is still too far away: ignore this tap
		var judgement := "perfect" if absf(delta) <= PERFECT_WINDOW else "good"
		_active.erase(n)
		n.queue_free()
		_sfx.play()
		_register(judgement, delta * 1000.0)
		return


func _register(judgement: String, delta_ms: float) -> void:
	_counts[judgement] += 1
	if judgement == "miss":
		_combo = 0
	else:
		_combo += 1
		_max_combo = maxi(_max_combo, _combo)
	var total := maxi(_times.size(), 1)
	var raw: float = _counts["perfect"] + _counts["good"] * GOOD_WEIGHT
	_score = roundi(1000000.0 * raw / total)

	hud.set_score(_score)
	hud.set_combo(_combo)
	var text := judgement.to_upper()
	if judgement != "miss":
		text += "\n%+d ms" % roundi(delta_ms)
	var colors := {"perfect": Color(1, 0.9, 0.3), "good": Color(0.5, 1, 0.6), "miss": Color(1, 0.4, 0.4)}
	hud.flash_judgement(text, colors[judgement])
	judged.emit(judgement, _combo, _score, delta_ms)


func _finish() -> void:
	_playing = false
	clock.stop()
	_video.stop()
	for n in _active:
		n.queue_free()
	_active.clear()
	var result := {
		"song": str(_charts[_song_index].get("title", "")),
		"difficulty": _difficulty,
		"score": _score,
		"max_combo": _max_combo,
		"perfect": _counts["perfect"],
		"good": _counts["good"],
		"miss": _counts["miss"],
		"total": _times.size(),
	}
	finished.emit(result)
	hud.show_menu("%s\n%s\nScore %d\nMax combo %d\nPerfect %d  Good %d  Miss %d" % [
		result["song"], _difficulty.to_upper(), _score, _max_combo,
		result["perfect"], result["good"], result["miss"]])


func _spawn(hit_time: float, lane: int) -> void:
	var n: Note = NOTE_SCENE.instantiate()
	n.hit_time = hit_time
	n.lane = lane
	n.position = Vector2(LANE_AREA_X + LANE_W * (lane + 0.5), SPAWN_Y)
	notes_root.add_child(n)
	_active.append(n)


# ---- chart handling (format v2, see README) -------------------------------------

func _load_chart(path: String) -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not (parsed is Dictionary) or not parsed.has("difficulties"):
		push_error("Could not parse chart: " + path)
		return {}
	if int(parsed.get("version", 0)) != 2:
		push_error("Unsupported chart version in " + path)
		return {}
	return parsed


func _parse_notes(raw: Array) -> void:
	# each entry is [time_seconds, lane]; sort by time so spawning/judging stay ordered
	var notes: Array = []
	for e in raw:
		if e is Array and e.size() >= 2:
			notes.append([float(e[0]), clampi(int(e[1]), 0, LANES - 1)])
	notes.sort_custom(func(a, b): return a[0] < b[0])
	_times = PackedFloat64Array()
	_lanes = PackedInt32Array()
	for n in notes:
		_times.append(n[0])
		_lanes.append(n[1])


func _setup_media(chart: Dictionary) -> void:
	var notice := ""
	
	# 處理音樂
	var a: Dictionary = chart.get("audio", {"type": "none"})
	var stream: AudioStream = null
	if a.get("type", "none") == "local":
		var path := str(a.get("path", ""))
		if ResourceLoader.exists(path):
			stream = load(path)
		else:
			notice = "Audio not found: " + path

	# 處理背景影片
	var v: Dictionary = chart.get("video", {"type": "none"})
	_video.stop()
	_video.stream = null
	_video_started = false
	
	if v.get("type", "none") == "local":
		var v_path := str(v.get("path", ""))
		if ResourceLoader.exists(v_path):
			_video.stream = load(v_path)
			_video_offset = float(v.get("offset", 0.0))
		else:
			if notice != "": notice += "\n"
			notice += "Video not found: " + v_path

	hud.set_notice(notice)
	clock.setup(stream, float(a.get("offset", 0.0)))
	queue_redraw()


# ---- drawing / helpers -----------------------------------------------------------

func _make_click() -> AudioStreamWAV:
	var rate := 44100
	var n := int(rate * 0.04)
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in n:
		var v := sin(TAU * 1200.0 * i / rate) * (1.0 - float(i) / n) * 0.6
		data.encode_s16(i * 2, int(v * 32767.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = rate
	w.data = data
	return w


func _draw() -> void:
	# 取得目前的視窗大小，避免放大視窗後軌道背景畫布不夠大
	var view_size = get_viewport_rect().size
	
	if _video.stream != null:
		# 半透明的背景遮罩 (透明度 0.25)，讓影片稍微變暗以凸顯音符
		draw_rect(Rect2(Vector2.ZERO, view_size), Color(0.06, 0.06, 0.1, 0.25))
	else:
		draw_rect(Rect2(Vector2.ZERO, view_size), Color(0.06, 0.06, 0.1))
		
	for i in LANES:
		var x := LANE_AREA_X + LANE_W * i
		# 重點！軌道底色加上透明度 (alpha = 0.35) 讓底下影片透出來
		var shade := Color(0.12, 0.12, 0.2, 0.35) if i % 2 == 0 else Color(0.10, 0.10, 0.17, 0.35)
		draw_rect(Rect2(x, 0, LANE_W, view_size.y), shade)
		
		if _flash[i] > 0.0:
			draw_rect(Rect2(x, 0, LANE_W, view_size.y), Color(1, 1, 1, 0.18 * _flash[i] / 0.12))
		draw_line(Vector2(x, 0), Vector2(x, view_size.y), Color(1, 1, 1, 0.15), 2.0)
		
	var xr := LANE_AREA_X + LANE_W * LANES
	draw_line(Vector2(xr, 0), Vector2(xr, view_size.y), Color(1, 1, 1, 0.15), 2.0)
	draw_line(Vector2(LANE_AREA_X, JUDGE_Y), Vector2(xr, JUDGE_Y), Color(1, 1, 1, 0.8), 6.0)
