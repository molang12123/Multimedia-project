extends RhythmPort
## A-only fake rhythm: generates deterministic Perfect/Good/Miss events,
## also accepts optional manual taps for flow testing.

var _chart: Dictionary = {}
var _notes: Array = []
var _handled: Array = []
var _running := false
var _paused := false
var _finished := false
var _score := 0
var _combo := 0
var _max_combo := 0
var _perfect := 0
var _good := 0
var _miss := 0


func start_rhythm(chart: Dictionary) -> bool:
	reset_rhythm()
	if not chart.has("notes") or not (chart["notes"] is Array):
		return false
	_chart = chart.duplicate(true)
	_notes = chart["notes"].duplicate(true)
	for _note in _notes:
		_handled.append(false)
	_running = true
	return true


func reset_rhythm() -> void:
	_chart.clear()
	_notes.clear()
	_handled.clear()
	_running = false
	_paused = false
	_finished = false
	_score = 0
	_combo = 0
	_max_combo = 0
	_perfect = 0
	_good = 0
	_miss = 0
	queue_redraw()


func pause_rhythm() -> void:
	_paused = true


func resume_rhythm() -> void:
	_paused = false


func _process(_delta: float) -> void:
	if not _running or _paused:
		return
	var t := AudioManager.get_song_time()
	for i in range(_notes.size()):
		if _handled[i]:
			continue
		var target: float = float(_notes[i]["time_sec"])
		# Deterministic automatic judgements provide score even without input.
		if i % 3 == 0 and t >= target + 0.06:
			_record(i, "PERFECT", 0.06)
		elif i % 3 == 1 and t >= target + 0.23:
			_record(i, "GOOD", 0.23)
		elif i % 3 == 2 and t >= target + 0.55:
			_record(i, "MISS", 0.55)
	queue_redraw()


func try_hit(song_time: float) -> Dictionary:
	if not _running or _paused:
		return {"judgement": "NONE"}
	for i in range(_notes.size()):
		if _handled[i]:
			continue
		var delta: float = song_time - float(_notes[i]["time_sec"])
		if absf(delta) <= 0.45:
			var judgement := "PERFECT" if absf(delta) <= 0.18 else "GOOD"
			return _record(i, judgement, delta)
	return {"judgement": "NONE"}


func _record(index: int, judgement: String, delta: float) -> Dictionary:
	_handled[index] = true
	if judgement == "PERFECT":
		_perfect += 1
		_score += 100
		_combo += 1
	elif judgement == "GOOD":
		_good += 1
		_score += 60
		_combo += 1
	else:
		_miss += 1
		_combo = 0
	_max_combo = maxi(_max_combo, _combo)
	var result := {
		"judgement": judgement,
		"time_sec": float(_notes[index]["time_sec"]),
		"delta_sec": delta,
		"score_delta": 100 if judgement == "PERFECT" else (60 if judgement == "GOOD" else 0)
	}
	score_changed.emit(_score)
	note_judged.emit(result)
	return result


func finalize_rhythm() -> void:
	if not _running or _finished:
		return
	for i in range(_notes.size()):
		if not _handled[i]:
			_record(i, "MISS", 0.0)
	_finished = true
	_running = false
	rhythm_finished.emit({
		"song_id": str(_chart.get("song_id", "")),
		"difficulty": str(_chart.get("difficulty", "")),
		"score": _score,
		"max_combo": _max_combo,
		"perfect": _perfect,
		"good": _good,
		"miss": _miss,
		"total_notes": _notes.size(),
		"completed": true
	})


func _draw() -> void:
	var view := get_viewport_rect().size
	draw_rect(Rect2(Vector2.ZERO, view), Color(0.08, 0.12, 0.2))
	draw_line(Vector2(view.x * 0.20, view.y * 0.72),
		Vector2(view.x * 0.80, view.y * 0.72), Color(0.7, 0.85, 1.0), 6.0)
	if _running:
		var pct := fposmod(AudioManager.get_song_time(), 1.6) / 1.6
		draw_circle(Vector2(view.x * 0.5, lerpf(view.y * 0.15, view.y * 0.72, pct)),
			25.0, Color(0.35, 0.88, 0.84))
