extends RhythmPort
## B's playfield (implements RhythmPort, see docs/interfaces.md and docs/rhythm_core.md).
## Landscape, two lanes (left / right), three note types: tap, hold, swipe up/down.
## Song time comes ONLY from AudioManager.get_song_time(); note positions are
## recomputed from it every frame.

const NOTE_SCENE := preload("res://scenes/rhythm/rhythm_note.tscn")

# ---- layout (1280x720 landscape) ---------------------------------------------------
const LANES := 2                                         # 0 = left, 1 = right
const SCREEN_W := 1280.0
const SCREEN_H := 720.0
const SPAWN := [Vector2(340, 110), Vector2(940, 110)]    # next to the MV, left / right
const JUDGE := [Vector2(100, 520), Vector2(1180, 520)]   # under the thumbs
const VIDEO_RECT := Rect2(320, 20, 640, 360)             # MV in the middle
const UI_RESERVED := Rect2(1150, 0, 130, 120)            # pause button: touches here are not hits

# ---- timing / scoring --------------------------------------------------------------
const PERFECT_WINDOW := 0.050     # +-50 ms
const GOOD_WINDOW := 0.120        # +-120 ms, later than this = Miss
const GOOD_WEIGHT := 0.6          # Good counts as 60% of a Perfect for score
const MAX_SCORE := 1000000
const HOLD_RELEASE_TOLERANCE := 0.15   # releasing a hold this early still completes it
const SWIPE_PX := 40.0            # vertical finger travel that counts as a swipe
const SWIPE_TIMEOUT := 0.35       # extra seconds a pressed swipe note waits for its swipe

## Base note speed in px/s along the lane; multiplied by GameSettings.note_speed.
const BASE_SPEEDS := {"easy": 330.0, "normal": 430.0, "challenge": 540.0}

# desktop keys -> lane
const KEY_TAP := {KEY_F: 0, KEY_J: 1}          # tap / hold (keep it down)
const KEY_SWIPE_UP := {KEY_E: 0, KEY_I: 1}
const KEY_SWIPE_DOWN := {KEY_D: 0, KEY_K: 1}

var _song_id := ""
var _difficulty := "normal"
var _notes: Array = []            # parsed chart notes: {t, lane, kind, len, dir}
var _lane_len := 1.0
var _travel_dirs: Array = []
var _next_index := 0
var _active: Array = []           # RhythmNote nodes on screen, ordered by hit_time
var _holds := {}                  # touch/key id -> note being held
var _swipes := {}                 # touch/key id -> swipe note waiting for its swipe
var _touch := {}                  # finger index -> {start, swiped}
var _running := false
var _paused := false
var _finished := false
var _flash := PackedFloat32Array([0.0, 0.0])

var _counts := {"perfect": 0, "good": 0, "miss": 0}
var _combo := 0
var _max_combo := 0
var _score := 0

var _video: VideoStreamPlayer
var _video_offset := 0.0
var _video_started := false
var _lane_view: RhythmLaneView
var _notes_root: Node2D


func _ready() -> void:
	GameSettings.load_settings()
	# draw order: background -> MV -> lanes -> notes
	var bg := ColorRect.new()
	bg.color = Color(0.05, 0.05, 0.09)
	bg.size = Vector2(SCREEN_W, SCREEN_H)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	_video = VideoStreamPlayer.new()
	_video.position = VIDEO_RECT.position
	_video.size = VIDEO_RECT.size
	_video.expand = true
	_video.volume_db = -80.0          # the MV is muted, the music comes from AudioManager
	_video.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_video)

	_lane_view = RhythmLaneView.new()
	add_child(_lane_view)
	_lane_view.setup(PackedVector2Array(SPAWN), PackedVector2Array(JUDGE))

	_notes_root = Node2D.new()
	add_child(_notes_root)

	for i in LANES:
		_travel_dirs.append((JUDGE[i] - SPAWN[i]).normalized())
	_lane_len = (JUDGE[0] - SPAWN[0]).length()


# ---- RhythmPort ----------------------------------------------------------------------

func start_rhythm(chart: Dictionary) -> bool:
	reset_rhythm()
	if not (chart.get("notes") is Array):
		push_error("Chart has no notes array")
		return false
	_song_id = str(chart.get("song_id", ""))
	_difficulty = str(chart.get("difficulty", "normal"))
	_parse_notes(chart["notes"])
	if _notes.is_empty():
		push_error("Chart has no playable notes")
		return false
	_setup_video(chart)
	_running = true
	return true


func reset_rhythm() -> void:
	_clear_notes()
	_notes = []
	_next_index = 0
	_running = false
	_paused = false
	_finished = false
	_counts = {"perfect": 0, "good": 0, "miss": 0}
	_combo = 0
	_max_combo = 0
	_score = 0
	if _video != null:
		_video.stop()
		_video.paused = false
		_video_started = false


func pause_rhythm() -> void:
	_paused = true
	if _video != null:
		_video.paused = true
	# Fingers may be lifted while paused, and that release is never delivered.
	# Forget who is holding what: holds in progress finish on their own at the tail,
	# swipe notes waiting for a swipe can be pressed again.
	_holds.clear()
	_swipes.clear()
	_touch.clear()
	for n in _active:
		n.swipe_pending = false


func resume_rhythm() -> void:
	_paused = false
	if _video != null:
		_video.paused = false


func try_hit(song_time: float) -> Dictionary:
	# Generic single-input hit (used by the mock HUD): earliest open note in either lane.
	if not _running or _paused:
		return {"judgement": "NONE"}
	var best: RhythmNote = null
	for lane in LANES:
		var n := _first_note(lane)
		if n != null and (best == null or n.hit_time < best.hit_time):
			best = n
	if best == null:
		return {"judgement": "NONE"}
	var delta: float = song_time - GameSettings.input_offset - best.hit_time
	if delta < -GOOD_WINDOW:
		return {"judgement": "NONE"}
	return _judge_note(best, delta)


func finalize_rhythm() -> void:
	if not _running or _finished:
		return
	# holds still pressed at the end count as completed; everything else left is a Miss
	for n in _active.duplicate():
		if n.holding:
			_judge_note(n, n.head_delta)
		elif not n.missed:
			_fail_note(n)
	while _next_index < _notes.size():
		_register("miss", 0.0, _notes[_next_index])
		_next_index += 1
	_finished = true
	_running = false
	_clear_notes()
	if _video != null:
		_video.stop()
	rhythm_finished.emit({
		"song_id": _song_id,
		"difficulty": _difficulty,
		"score": _score,
		"max_combo": _max_combo,
		"perfect": _counts["perfect"],
		"good": _counts["good"],
		"miss": _counts["miss"],
		"total_notes": _notes.size(),
		"completed": true,
	})


# ---- frame loop ----------------------------------------------------------------------

func _process(delta: float) -> void:
	for i in LANES:
		if _flash[i] > 0.0:
			_flash[i] = maxf(0.0, _flash[i] - delta)
			_lane_view.set_flash(i, _flash[i])

	if not _running or _paused:
		return
	var t: float = AudioManager.get_song_time()
	var speed := _speed()
	var travel_time := _lane_len / speed

	if not _video_started and _video.stream != null and t >= _video_offset:
		_video.play()
		_video_started = true

	# 1) spawn notes whose trip must begin now
	while _next_index < _notes.size() and t >= float(_notes[_next_index]["t"]) - travel_time:
		_spawn(_notes[_next_index])
		_next_index += 1

	# 2) position every note from song time, resolve holds / misses, clean up
	for n: RhythmNote in _active.duplicate():
		n.place(t, JUDGE[n.lane], speed, _lane_len)
		if n.holding and t >= n.tail_time():
			_judge_note(n, n.head_delta)               # held until the end
			continue
		if not n.missed:
			var late: float = t - GameSettings.input_offset - n.hit_time
			if n.swipe_pending:
				if late > GOOD_WINDOW + SWIPE_TIMEOUT:
					_fail_note(n)                      # finger never swiped
			elif not n.holding and late > GOOD_WINDOW:
				_fail_note(n)                          # never pressed in time
		if is_instance_valid(n) and not n.holding and t - n.tail_time() > 0.6:
			_active.erase(n)
			n.queue_free()


func _speed() -> float:
	var base: float = BASE_SPEEDS.get(_difficulty, BASE_SPEEDS["normal"])
	return base * clampf(GameSettings.note_speed, GameSettings.SPEED_MIN, GameSettings.SPEED_MAX)


# ---- input ---------------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if not _running or _paused:
		return
	if event is InputEventScreenTouch:
		# one event per finger -> real multi-touch; desktop mouse is emulated as touch
		if event.pressed:
			if UI_RESERVED.has_point(event.position):
				return
			var lane := 0 if event.position.x < SCREEN_W * 0.5 else 1
			_touch[event.index] = {"start": event.position, "swiped": false}
			_press(event.index, lane, AudioManager.get_song_time())
		elif _touch.has(event.index):
			_release(event.index, AudioManager.get_song_time())
			_touch.erase(event.index)
	elif event is InputEventScreenDrag:
		var st: Variant = _touch.get(event.index)
		if st != null and not st["swiped"]:
			var dy: float = event.position.y - st["start"].y
			if absf(dy) >= SWIPE_PX:
				st["swiped"] = true
				_swipe(event.index, "down" if dy > 0.0 else "up")
	elif event is InputEventKey and not event.echo:
		var key: int = event.physical_keycode
		if KEY_TAP.has(key):
			var lane: int = KEY_TAP[key]
			if event.pressed:
				_press(-100 - lane, lane, AudioManager.get_song_time())
			else:
				_release(-100 - lane, AudioManager.get_song_time())
		elif event.pressed and KEY_SWIPE_UP.has(key):
			_swipe_key(KEY_SWIPE_UP[key], "up", AudioManager.get_song_time())
		elif event.pressed and KEY_SWIPE_DOWN.has(key):
			_swipe_key(KEY_SWIPE_DOWN[key], "down", AudioManager.get_song_time())


func _flash_lane(lane: int) -> void:
	_flash[lane] = 0.12
	_lane_view.set_flash(lane, 0.12)


## A finger (or F/J) went down in `lane`.
func _press(id: int, lane: int, t: float) -> void:
	_flash_lane(lane)
	var n := _first_note(lane)
	if n == null:
		return
	var delta: float = t - GameSettings.input_offset - n.hit_time
	if delta < -GOOD_WINDOW:
		return                        # nearest note in this lane is still too far away
	match n.kind:
		"tap":
			_judge_note(n, delta)
		"hold":
			n.holding = true          # judged when the hold ends
			n.head_delta = delta
			_holds[id] = n
			AudioManager.play_sfx("hit")
		"swipe":
			n.swipe_pending = true    # timing is taken now, direction is checked on the swipe
			n.head_delta = delta
			_swipes[id] = n


## The finger/key that was pressed with `id` went up.
func _release(id: int, t: float) -> void:
	if _holds.has(id):
		var n: RhythmNote = _holds[id]
		_holds.erase(id)
		if t - GameSettings.input_offset >= n.tail_time() - HOLD_RELEASE_TOLERANCE:
			_judge_note(n, n.head_delta)
		else:
			_fail_note(n)             # let go too early
	if _swipes.has(id):
		var s: RhythmNote = _swipes[id]
		_swipes.erase(id)
		_fail_note(s)                 # lifted without swiping


## Touch: the finger that is down moved far enough up or down.
func _swipe(id: int, dir: String) -> void:
	var n: RhythmNote = _swipes.get(id)
	if n == null:
		return
	_swipes.erase(id)
	if dir == n.swipe_dir:
		_judge_note(n, n.head_delta)
	else:
		_fail_note(n)                 # wrong direction


## Keyboard: E/I (up) and D/K (down) act as press + swipe in one key.
func _swipe_key(lane: int, dir: String, t: float) -> void:
	_flash_lane(lane)
	var n := _first_note(lane)
	if n == null or n.kind != "swipe":
		return
	var delta: float = t - GameSettings.input_offset - n.hit_time
	if delta < -GOOD_WINDOW:
		return
	if dir == n.swipe_dir:
		_judge_note(n, delta)
	else:
		_fail_note(n)


## Earliest note in `lane` that nobody is touching and that has not been missed.
func _first_note(lane: int) -> RhythmNote:
	for n: RhythmNote in _active:
		if n.lane == lane and not n.missed and not n.holding and not n.swipe_pending:
			return n
	return null


# ---- judging / scoring ---------------------------------------------------------------

func _judge_note(n: RhythmNote, delta: float) -> Dictionary:
	_forget(n)
	_active.erase(n)
	n.queue_free()
	AudioManager.play_sfx("hit")
	var judgement := "perfect" if absf(delta) <= PERFECT_WINDOW else "good"
	return _register(judgement, delta, _note_info(n))


func _fail_note(n: RhythmNote) -> void:
	_forget(n)
	var was_holding := n.holding
	n.mark_missed()
	_register("miss", 0.0, _note_info(n))
	if was_holding:                   # a broken hold disappears right away
		_active.erase(n)
		n.queue_free()


func _forget(n: RhythmNote) -> void:
	for id in _holds.keys():
		if _holds[id] == n:
			_holds.erase(id)
	for id in _swipes.keys():
		if _swipes[id] == n:
			_swipes.erase(id)


func _note_info(n: RhythmNote) -> Dictionary:
	return {"t": n.hit_time, "lane": n.lane, "kind": n.kind}


func _register(judgement: String, delta: float, note: Dictionary) -> Dictionary:
	_counts[judgement] += 1
	if judgement == "miss":
		_combo = 0
	else:
		_combo += 1
		_max_combo = maxi(_max_combo, _combo)
	var total := maxi(_notes.size(), 1)
	var raw: float = _counts["perfect"] + _counts["good"] * GOOD_WEIGHT
	var new_score := roundi(MAX_SCORE * raw / total)
	var score_delta := new_score - _score
	_score = new_score

	var result := {
		"judgement": judgement.to_upper(),       # PERFECT / GOOD / MISS
		"time_sec": float(note["t"]),
		"delta_sec": delta,
		"score_delta": score_delta,
		# extensions beyond interface v1 (UI may use them):
		"combo": _combo,
		"lane": int(note["lane"]),
		"note_type": str(note["kind"]),
	}
	score_changed.emit(_score)
	note_judged.emit(result)
	return result


# ---- notes / chart -------------------------------------------------------------------

func _clear_notes() -> void:
	for n in _active:
		if is_instance_valid(n):
			n.queue_free()
	_active.clear()
	_holds.clear()
	_swipes.clear()
	_touch.clear()


func _spawn(data: Dictionary) -> void:
	var n: RhythmNote = NOTE_SCENE.instantiate()
	n.hit_time = data["t"]
	n.lane = data["lane"]
	n.kind = data["kind"]
	n.hold_len = data["len"]
	n.swipe_dir = data["dir"]
	n.travel_dir = _travel_dirs[n.lane]
	n.position = SPAWN[n.lane]
	n.visible = false
	_notes_root.add_child(n)
	_active.append(n)


## Accepts chart schema v1 ({"time_sec"} only, lanes alternate) and v2
## ({"time_sec", "lane", "type", "duration_sec", "direction"}). See docs/rhythm_core.md.
func _parse_notes(raw: Array) -> void:
	_notes = []
	var alt := 0
	for e in raw:
		if not (e is Dictionary) or not e.has("time_sec"):
			continue
		var lane := alt
		if e.has("lane"):
			lane = clampi(int(e["lane"]), 0, LANES - 1)
		else:
			alt = 1 - alt
		var n := {"t": float(e["time_sec"]), "lane": lane, "kind": "tap", "len": 0.0, "dir": "up"}
		match str(e.get("type", "tap")):
			"hold":
				n["kind"] = "hold"
				n["len"] = maxf(float(e.get("duration_sec", 0.5)), 0.1)
			"swipe":
				n["kind"] = "swipe"
				n["dir"] = "down" if str(e.get("direction", "up")) == "down" else "up"
		_notes.append(n)
	_notes.sort_custom(func(a, b): return a["t"] < b["t"])


func _setup_video(chart: Dictionary) -> void:
	_video.stop()
	_video.stream = null
	_video_started = false
	var v: Variant = chart.get("video")
	if v is Dictionary and v.has("path"):
		var path := str(v["path"])
		if ResourceLoader.exists(path):
			_video.stream = load(path)
			_video_offset = float(v.get("offset", 0.0))
		else:
			push_warning("Video not found: " + path)
	_lane_view.set_frame(VIDEO_RECT if _video.stream != null else Rect2())
