extends Node

var current_difficulty: String = "baby"
var last_menu_difficulty_index: int = 0

var music_style: String = "classic"   # "classic" | "modern" | "off"
var sfx_enabled: bool = true
var graphics_old: bool = false
var language: String = "en"           # "en" | "ru"

const SETTINGS_PATH := "user://settings.cfg"

func _ready() -> void:
	load_settings()

func save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("game", "difficulty_index", last_menu_difficulty_index)
	cfg.set_value("audio", "music_style", music_style)
	cfg.set_value("audio", "sfx_enabled", sfx_enabled)
	cfg.set_value("graphics", "old", graphics_old)
	cfg.set_value("ui", "language", language)
	cfg.save(SETTINGS_PATH)

func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) != OK:
		return
	last_menu_difficulty_index = cfg.get_value("game", "difficulty_index", 0)
	current_difficulty = ["baby", "intern", "profi", "master", "expert", "torrero"][last_menu_difficulty_index]
	music_style = cfg.get_value("audio", "music_style", "classic")
	sfx_enabled = cfg.get_value("audio", "sfx_enabled", true)
	graphics_old = cfg.get_value("graphics", "old", false)
	language = cfg.get_value("ui", "language", "en")
