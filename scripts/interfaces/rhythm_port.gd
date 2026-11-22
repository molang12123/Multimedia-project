class_name RhythmPort
extends Node2D
## Interface contract for B's playfield and A's MockRhythmManager.
signal rhythm_finished(result: Dictionary)
signal score_changed(score: int)
signal note_judged(result: Dictionary)

func start_rhythm(_chart: Dictionary) -> bool:
	return false

func pause_rhythm() -> void:
	pass

func resume_rhythm() -> void:
	pass

func reset_rhythm() -> void:
	pass

func try_hit(_song_time: float) -> Dictionary:
	return {"judgement": "NONE"}

func finalize_rhythm() -> void:
	pass
