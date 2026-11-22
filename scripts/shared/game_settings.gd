class_name GameSettings
extends RefCounted
## Player settings shared by B (note speed), C (pause / settings screens) and D (volumes).
## Stored in user://settings.cfg so they survive restarts. No autoload needed:
##   GameSettings.load_settings()      # once, before reading
##   GameSettings.music_volume = 0.5; GameSettings.save_settings()

const PATH := "user://settings.cfg"

static var music_volume: float = 0.8     ## 0.0 - 1.0
static var sfx_volume: float = 0.8       ## 0.0 - 1.0, hit feedback sound
static var note_speed: float = 1.0       ## multiplier on the difficulty's base speed
static var input_offset: float = 0.0     ## seconds, positive = player hits late

static var _loaded := false

const SPEED_MIN := 0.5
const SPEED_MAX := 2.0


static func load_settings() -> void:
	if _loaded:
		return
	_loaded = true
	var cfg := ConfigFile.new()
	if cfg.load(PATH) != OK:
		return
	music_volume = clampf(float(cfg.get_value("audio", "music_volume", music_volume)), 0.0, 1.0)
	sfx_volume = clampf(float(cfg.get_value("audio", "sfx_volume", sfx_volume)), 0.0, 1.0)
	note_speed = clampf(float(cfg.get_value("gameplay", "note_speed", note_speed)), SPEED_MIN, SPEED_MAX)
	input_offset = clampf(float(cfg.get_value("gameplay", "input_offset", input_offset)), -0.3, 0.3)


static func save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("audio", "music_volume", music_volume)
	cfg.set_value("audio", "sfx_volume", sfx_volume)
	cfg.set_value("gameplay", "note_speed", note_speed)
	cfg.set_value("gameplay", "input_offset", input_offset)
	cfg.save(PATH)
