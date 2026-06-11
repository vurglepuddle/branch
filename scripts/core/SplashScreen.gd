# SplashScreen.gd
extends Node2D

@export var star_scene: PackedScene 

const MAX_STARS: int = 8 # Or your desired value
@export var min_star_spawn_time: float = 0.3
@export var max_star_spawn_time: float = 1.5

var spawn_area: Rect2 
var active_stars: int = 0
var transitioning: bool = false
var _initial_fade_complete: bool = false # New flag

@onready var star_spawn_timer: Timer = $StarSpawnTimer

func _ready():
	if not FadeOverlay:
		printerr("SplashScreen: FadeOverlay autoload not found!")
		get_tree().quit()
		return
	if not AudioManager:
		printerr("SplashScreen: AudioManager autoload not found!")
		get_tree().quit()
		return

	var viewport_rect = get_viewport_rect()
	spawn_area = Rect2(0, 0, viewport_rect.size.x, viewport_rect.size.y / 8.0)

	if GlobalSettings.graphics_old:
		$Bg.texture = load("res://sprites/BG_old.png")
	
	randomize()

	AudioManager._load_and_set_music_track_from_stream(null, false, false, 0.0)

	FadeOverlay.fade_finished.connect(_on_fade_finished)
	star_spawn_timer.timeout.connect(_on_star_spawn_timer_timeout)

	# --- MODIFICATION: Initially disable input processing for this node ---
	set_process_unhandled_input(false) 

	FadeOverlay.fade_rect.color = Color.BLACK 
	FadeOverlay.fade_rect.modulate.a = 1.0 
	FadeOverlay.visible = true

	# We will enable input in _on_fade_finished when type is "in"
	FadeOverlay.start_fade_in(1.0) 

	star_spawn_timer.wait_time = randf_range(min_star_spawn_time, max_star_spawn_time)
	star_spawn_timer.start()
	
	# Old input enabling removed from here


func _unhandled_input(event: InputEvent):
	# --- MODIFICATION: Check if initial fade is complete AND not already transitioning ---
	if not _initial_fade_complete or transitioning:
		return

	if event.is_pressed() and not event.is_echo():
		print_verbose("SplashScreen: Input detected, transitioning to main menu.")
		transitioning = true
		_initial_fade_complete = false # Prevent further input processing during transition
		set_process_unhandled_input(false) 
		
		SceneChanger.change_scene_with_fade("res://scenes/main_menu.tscn", 0.75)

func _on_star_spawn_timer_timeout():
	if active_stars < MAX_STARS and not transitioning:
		spawn_star()
	
	if not transitioning:
		star_spawn_timer.wait_time = randf_range(min_star_spawn_time, max_star_spawn_time)
		star_spawn_timer.start()

func spawn_star():
	if not star_scene:
		printerr("Star scene not set in SplashScreen inspector!")
		return

	var star_instance = star_scene.instantiate() as AnimatedSprite2D
	if not star_instance:
		printerr("Failed to instance star_scene or it's not an AnimatedSprite2D.")
		return

	star_instance.position.x = randf_range(spawn_area.position.x, spawn_area.end.x)
	star_instance.position.y = randf_range(spawn_area.position.y, spawn_area.end.y)
	
	add_child(star_instance)
	star_instance.connect("animation_cycle_finished", Callable(self, "_on_star_animation_cycle_finished"))
	
	active_stars += 1
	AudioManager.play_star_twinkle_sound(star_instance.position.y, get_viewport_rect().size.y)

func _on_star_animation_cycle_finished():
	active_stars = max(0, active_stars - 1)

func _on_fade_finished(type: String):
	if type == "in":
		print_verbose("SplashScreen: Fade in complete. Enabling input.")
		# --- MODIFICATION: Enable input processing only after fade-in is done ---
		_initial_fade_complete = true
		set_process_unhandled_input(true) 
	elif type == "out" and transitioning:
		print_verbose("SplashScreen: _on_fade_finished(out) - Transition managed by SceneChanger.")
		# SceneChanger handles the actual scene change.
		# We might not even need this 'elif' block anymore if SplashScreen doesn't do
		# specific cleanup *after* its own fade_out signal but *before* scene change.
		# For now, leaving it as a log.

func _exit_tree():
	if FadeOverlay and FadeOverlay.is_connected("fade_finished", Callable(self, "_on_fade_finished")):
		FadeOverlay.fade_finished.disconnect(Callable(self, "_on_fade_finished"))
	if star_spawn_timer and star_spawn_timer.is_connected("timeout", Callable(self, "_on_star_spawn_timer_timeout")):
		star_spawn_timer.timeout.disconnect(Callable(self, "_on_star_spawn_timer_timeout"))
