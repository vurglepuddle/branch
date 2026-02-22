extends Node2D # PreClock.gd

const DISPLAY_DURATION: float = 1.0

@onready var clock_sprite: AnimatedSprite2D = $Clock

func _ready():
	AudioManager._load_and_set_music_track_from_stream(null, false, false, 0.0)

	FadeOverlay.fade_rect.color = Color.BLACK
	FadeOverlay.fade_rect.modulate.a = 1.0
	FadeOverlay.visible = true
	FadeOverlay.start_fade_in(0.4)

	clock_sprite.play("clock")

	var timer = get_tree().create_timer(DISPLAY_DURATION)
	timer.timeout.connect(_go_to_splash)

func _go_to_splash():
	SceneChanger.change_scene_with_fade("res://scenes/SplashScreen.tscn", 0.4)
