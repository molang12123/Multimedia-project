extends Control
## Temporary A-owned entry scene, intentionally independent of B/C/D.

func _ready() -> void:
	GameManager.call_deferred("open_menu")
