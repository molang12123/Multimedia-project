class_name RhythmLaneView
extends Node2D
## Draws the two lanes (spawn point -> judge point, widening towards the player),
## the judge rings and the MV frame. Pure view: the playfield gives it the geometry.

const WIDTH_SPAWN := 40.0
const WIDTH_JUDGE := 130.0
const EXTEND := 100.0              # lane keeps going a little past the judge point
const RING_R := 54.0

var spawn: PackedVector2Array = PackedVector2Array()
var judge: PackedVector2Array = PackedVector2Array()
var frame: Rect2 = Rect2()          # outline of the MV area (empty = none)
var _flash: PackedFloat32Array = PackedFloat32Array()


func setup(spawn_points: PackedVector2Array, judge_points: PackedVector2Array) -> void:
	spawn = spawn_points
	judge = judge_points
	_flash.resize(spawn.size())
	queue_redraw()


func set_frame(rect: Rect2) -> void:
	frame = rect
	queue_redraw()


func set_flash(i: int, value: float) -> void:
	_flash[i] = value
	queue_redraw()


func _draw() -> void:
	if frame.size != Vector2.ZERO:
		draw_rect(frame.grow(2.0), Color(1, 1, 1, 0.35), false, 2.0)
	for i in spawn.size():
		var s := spawn[i]
		var j := judge[i]
		var length := (j - s).length()
		var dir := (j - s) / length
		var perp := Vector2(-dir.y, dir.x)
		var end := j + dir * EXTEND
		var w_end := lerpf(WIDTH_SPAWN, WIDTH_JUDGE, (length + EXTEND) / length)
		var a := s + perp * WIDTH_SPAWN * 0.5
		var b := s - perp * WIDTH_SPAWN * 0.5
		var c := end - perp * w_end * 0.5
		var d := end + perp * w_end * 0.5
		draw_colored_polygon(PackedVector2Array([a, b, c, d]), Color(0.15, 0.2, 0.4, 0.40))
		draw_line(a, d, Color(1, 1, 1, 0.25), 2.0, true)
		draw_line(b, c, Color(1, 1, 1, 0.25), 2.0, true)
		var f := _flash[i] / 0.12
		draw_circle(j, RING_R, Color(1, 1, 1, 0.10 + 0.40 * f))
		draw_arc(j, RING_R, 0.0, TAU, 48, Color(1, 1, 1, 0.9), 5.0, true)
