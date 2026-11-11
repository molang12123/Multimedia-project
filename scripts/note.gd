class_name Note
extends Node2D
## One falling note. It never moves by itself: the manager calls place() every frame
## with the current song time, so position always follows the music clock.

const WIDTH := 140.0
const HEIGHT := 30.0

var hit_time: float = 0.0   # seconds on the song timeline
var lane: int = 0
var missed: bool = false


func place(song_time: float, judge_y: float, speed: float) -> void:
	# Y = judge line - (time until hit) * fall speed
	position.y = judge_y - (hit_time - song_time) * speed


func mark_missed() -> void:
	missed = true
	modulate = Color(1, 1, 1, 0.35)


func _draw() -> void:
	draw_rect(Rect2(-WIDTH / 2.0, -HEIGHT / 2.0, WIDTH, HEIGHT), Color(0.35, 0.8, 1.0))
	draw_rect(Rect2(-WIDTH / 2.0, -HEIGHT / 2.0, WIDTH, HEIGHT), Color.WHITE, false, 3.0)
