class_name RhythmNote
extends Node2D
## One note: tap, hold or swipe. It never moves by itself: the playfield calls place()
## every frame with the current song time, so position always follows the music.

const HEAD_R := 38.0
const COL_TAP := Color(0.35, 0.8, 1.0)
const COL_HOLD := Color(0.35, 0.9, 0.5)
const COL_SWIPE := Color(1.0, 0.65, 0.25)

var hit_time: float = 0.0          ## seconds on the song timeline
var lane: int = 0                  ## 0 = left, 1 = right
var kind: String = "tap"           ## "tap" | "hold" | "swipe"
var hold_len: float = 0.0          ## seconds (hold only)
var swipe_dir: String = "up"       ## "up" | "down" (swipe only)
var travel_dir: Vector2 = Vector2.DOWN   ## unit vector spawn -> judge point

var missed: bool = false
var holding: bool = false          ## head was hit, finger is still down
var swipe_pending: bool = false    ## finger is down on a swipe note, waiting for the swipe
var head_delta: float = 0.0        ## timing error (s) of the press that started this note

var _body_px: float = 0.0


func tail_time() -> float:
	return hit_time + hold_len


func place(song_time: float, judge: Vector2, speed: float, lane_len: float) -> void:
	# distance (px) still to travel to the judge point = (time until hit) * speed
	var d := (hit_time - song_time) * speed
	if holding:
		d = 0.0                      # a held head sticks to the judge point
	visible = d <= lane_len + 1.0    # not drawn before it reaches the spawn point
	position = judge - travel_dir * d
	var p := clampf(1.0 - d / lane_len, 0.0, 1.0)
	scale = Vector2.ONE * lerpf(0.45, 1.0, p)   # small at the spawn point, full size at the judge point
	if kind == "hold":
		var remain := hold_len
		if holding:
			remain = maxf(0.0, tail_time() - song_time)
		_body_px = clampf(remain * speed, 0.0, maxf(lane_len - d, 0.0))  # tail never leaves the lane
		queue_redraw()


func mark_missed() -> void:
	missed = true
	holding = false
	swipe_pending = false
	modulate = Color(1, 1, 1, 0.35)


func _draw() -> void:
	var col := COL_TAP
	if kind == "hold":
		col = COL_HOLD
		if _body_px > 1.0:
			var back := -travel_dir * (_body_px / maxf(scale.x, 0.01))
			draw_line(Vector2.ZERO, back, Color(COL_HOLD, 0.55), HEAD_R * 1.5, true)
	elif kind == "swipe":
		col = COL_SWIPE
	draw_circle(Vector2.ZERO, HEAD_R, col)
	draw_arc(Vector2.ZERO, HEAD_R, 0.0, TAU, 40, Color.WHITE, 4.0, true)
	if kind == "swipe":
		var k := 1.0 if swipe_dir == "up" else -1.0
		draw_colored_polygon(PackedVector2Array([
			Vector2(0, -20.0 * k), Vector2(-17, 9.0 * k), Vector2(17, 9.0 * k)]), Color(0.25, 0.12, 0.0))
