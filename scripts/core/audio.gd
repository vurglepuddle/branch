extends Node # audio.gd

signal music_display_changed(display_name: String)

@export var modern_beep_sound: AudioStream = preload("res://audio/modern/SFX_modern.wav")
@export var beep_sound: AudioStream = preload("res://audio/other/beep_sound.wav")
@export var switch_to_off_sfx: AudioStream
@export var star_appearance_sound: AudioStream = preload("res://audio/Star.wav")

@export var difficulty_music: Dictionary = {
	"baby": "res://audio/other/opening.mp3",
	"intern": "res://audio/other/opening.mp3",
	"profi": "res://audio/other/opening.mp3",
	"master": "res://audio/other/opening.mp3",
	"expert": "res://audio/other/opening.mp3",
	"torrero": "res://audio/other/BWV784 Courante.mp3"
}

@export var difficulty_music_modern: Dictionary = {
	"baby": "res://audio/modern/modernA.mp3",
	"intern": "res://audio/modern/modernB.mp3",
	"profi": "res://audio/modern/modernC.mp3",
	"master": "res://audio/modern/modernA.mp3",
	"expert": "res://audio/modern/modernB.mp3",
	"torrero": "res://audio/modern/modernC.mp3"
}

@export var classic_menu_theme: AudioStream
@export var modern_menu_theme: AudioStream

# --- Audio Players ---
var sfx_player: AudioStreamPlayer
var bg_player: AudioStreamPlayer
# var star_beep_player: AudioStreamPlayer 

# --- Audio State ---
var sfx_enabled: bool = true
var music_globally_muted: bool = false # For master music mute (e.g., M key)
var current_music_path: String = ""
var music_change_pending: bool = false # Flag to handle rapid changes

enum MusicStyle { CLASSIC, MODERN }
var current_music_style: MusicStyle = MusicStyle.CLASSIC
var is_menu_music_off: bool = false # To handle the "Off" state for menu music explicitly

# Constants for tweening
const MUSIC_TARGET_VOLUME_DB: float = -10.0
const MUSIC_MUTED_VOLUME_DB: float = -80.0 # Effectively silent
const MUSIC_FADE_DURATION: float = 1.0 # Default fade duration
const DEFAULT_SFX_VOLUME_DB: float = 0.0
const INITIAL_MUSIC_FADE_IN_DURATION: float = 1.5

func _ready():
	setup_audio_players()
	initialize_audio_settings()

func setup_audio_players():
	if not is_instance_valid(sfx_player):
		sfx_player = AudioStreamPlayer.new()
		sfx_player.name = "SFXPlayer"
		add_child(sfx_player)
	
	if not is_instance_valid(bg_player):
		bg_player = AudioStreamPlayer.new()
		bg_player.name = "BackgroundMusicPlayer"
		add_child(bg_player)
		bg_player.connect("finished", Callable(self, "_on_music_track_finished"))
	
	# separate star beep player if needed later:
	# if not is_instance_valid(star_beep_player):
	# 	star_beep_player = AudioStreamPlayer.new()
	# 	star_beep_player.name = "StarBeepPlayer"
	# 	add_child(star_beep_player)

func initialize_audio_settings():
	print("AudioManager initialize_audio_settings: START")
	sfx_player.volume_db = DEFAULT_SFX_VOLUME_DB if sfx_enabled else MUSIC_MUTED_VOLUME_DB

	_update_menu_music_on_state_change(true, INITIAL_MUSIC_FADE_IN_DURATION)
	
	var initial_display_name: String
	if is_menu_music_off:
		initial_display_name = "Off"
	elif current_music_style == MusicStyle.CLASSIC:
		initial_display_name = "Classic"
	else:
		initial_display_name = "Modern"
	
	emit_signal("music_display_changed", initial_display_name)


func _on_music_track_finished():
	if bg_player.has_meta("loop") and bg_player.get_meta("loop") == true and \
	   not music_globally_muted and not (is_menu_music_off and bg_player.stream in [classic_menu_theme, modern_menu_theme]): # Check relevant states
		if is_instance_valid(bg_player.stream):
			bg_player.play()
		else:
			print("AudioManager: Tried to loop, but stream is invalid.")
	else:
		print("AudioManager: Music track finished (not looping or conditions not met).")
		
# --- SFX Control ---
func toggle_sfx_enabled():
	sfx_enabled = !sfx_enabled
	sfx_player.volume_db = DEFAULT_SFX_VOLUME_DB if sfx_enabled else MUSIC_MUTED_VOLUME_DB
	print("AudioManager: SFX " + ("ENABLED" if sfx_enabled else "DISABLED"))
	if sfx_enabled:
		play_named_sfx("beep_sound")

func play_named_sfx(sfx_key: String, volume_db: float = DEFAULT_SFX_VOLUME_DB):
	if not sfx_enabled or not is_instance_valid(sfx_player):
		return

	var stream_to_play: AudioStream
	match sfx_key:
		"beep_sound": 
			if is_menu_music_off: 
				stream_to_play = switch_to_off_sfx 
			elif current_music_style == MusicStyle.CLASSIC:
				stream_to_play = beep_sound
			else: 
				stream_to_play = modern_beep_sound
		
		"switch_to_off_sfx": 
			stream_to_play = switch_to_off_sfx
		
		# You could add a "star_beep" case here if you want to call it via play_named_sfx
		# "star_beep":
		# 	stream_to_play = star_appearance_sound
		
		_: 
			printerr("AudioManager: Unknown SFX key: ", sfx_key)
			if is_menu_music_off:
				stream_to_play = switch_to_off_sfx
			elif current_music_style == MusicStyle.CLASSIC:
				stream_to_play = beep_sound
			else: 
				stream_to_play = modern_beep_sound
			if not stream_to_play:
				printerr("AudioManager: No fallback beep sound available for unknown key.")
				return
	   
	if stream_to_play:
		sfx_player.stream = stream_to_play
		sfx_player.volume_db = volume_db 
		sfx_player.play()
	else:
		var problem_stream_name = ""
		if sfx_key == "beep_sound":
			if is_menu_music_off:
				problem_stream_name = "'switch_to_off_sfx' (for when music is Off)"
			elif current_music_style == MusicStyle.CLASSIC:
				problem_stream_name = "classic 'beep_sound'"
			else: 
				problem_stream_name = "'modern_beep_sound'"
		elif sfx_key == "switch_to_off_sfx":
			problem_stream_name = "'switch_to_off_sfx'"
		else: 
			problem_stream_name = "a valid stream for key '%s' (or its fallback)" % sfx_key

		printerr("AudioManager: SFX stream for %s is null. Please assign it in the Inspector." % problem_stream_name)

# Function specifically for the star appearance sound
func play_star_sound():
	# If you want this sound to ignore the sfx_enabled toggle, remove "not sfx_enabled or"
	if not sfx_enabled or not is_instance_valid(sfx_player):
		return

	if star_appearance_sound:
		# Using the main sfx_player. If you created star_beep_player, use that instead.
		sfx_player.stream = star_appearance_sound 
		sfx_player.volume_db = DEFAULT_SFX_VOLUME_DB # Or a custom volume for this sound
		sfx_player.play()
	else:
		printerr("AudioManager: Star appearance sound (star_appearance_sound) is not assigned in the Inspector!")


# Kept for compatibility if you used play_sfx() elsewhere for default beep
func play_sfx(sfx_name: String = "beep_sound", volume_db: float = DEFAULT_SFX_VOLUME_DB):
	play_named_sfx(sfx_name, volume_db)

func toggle_music_style_and_state():
	var display_name: String
	var sfx_key_for_this_action: String = "beep_sound"

	if not is_menu_music_off:
		if current_music_style == MusicStyle.CLASSIC:
			current_music_style = MusicStyle.MODERN
			display_name = "Modern"
		elif current_music_style == MusicStyle.MODERN:
			is_menu_music_off = true
			display_name = "Off"
			sfx_key_for_this_action = "switch_to_off_sfx"
	else: 
		is_menu_music_off = false
		current_music_style = MusicStyle.CLASSIC 
		display_name = "Classic"

	emit_signal("music_display_changed", display_name)
	play_named_sfx(sfx_key_for_this_action) 
	_update_menu_music_on_state_change() 

func _update_menu_music_on_state_change(fade_in: bool = true, duration: float = MUSIC_FADE_DURATION):
	if music_globally_muted:
		_load_and_set_music_track_from_stream(null, false, false, duration) 
		current_music_path = ""
		return

	var new_track_stream: AudioStream = null
	if not is_menu_music_off:
		if current_music_style == MusicStyle.CLASSIC:
			new_track_stream = classic_menu_theme
		else: 
			new_track_stream = modern_menu_theme
	_load_and_set_music_track_from_stream(new_track_stream, fade_in, true, duration) 


func play_difficulty_music(difficulty_key: String, loop: bool = true, fade: bool = true, duration: float = MUSIC_FADE_DURATION):
	if is_menu_music_off or music_globally_muted:
		_load_and_set_music_track_from_path("", false, loop, duration) 
		return

	var music_lib: Dictionary
	if current_music_style == MusicStyle.CLASSIC:
		music_lib = difficulty_music
	else: 
		music_lib = difficulty_music_modern
	
	if not music_lib.has(difficulty_key):
		printerr("AudioManager: Difficulty key '%s' not found in selected music library." % difficulty_key)
		_load_and_set_music_track_from_path("", fade, loop, duration) 
		return

	var music_path_to_load: String = music_lib[difficulty_key]
	_load_and_set_music_track_from_path(music_path_to_load, fade, loop, duration)

func _load_and_set_music_track_from_stream(track_stream: AudioStream, fade_in: bool = true, loop: bool = true, duration: float = MUSIC_FADE_DURATION):
	if music_change_pending and fade_in:
		return

	if not is_instance_valid(bg_player):
		printerr("AudioManager: BackgroundMusicPlayer not valid for _load_and_set_music_track_from_stream.")
		return

	if bg_player.playing and bg_player.stream != track_stream and fade_in:
		music_change_pending = true
		var tween = create_tween()
		tween.tween_property(bg_player, "volume_db", MUSIC_MUTED_VOLUME_DB, duration / 2.0) 
		tween.tween_callback(Callable(self, "_play_new_music_stream").bind(track_stream, loop, true, duration)) 
	else:
		_play_new_music_stream(track_stream, loop, fade_in and bg_player.stream != track_stream, duration)

func _load_and_set_music_track_from_path(track_path: String, fade_in: bool = true, loop: bool = true, duration: float = MUSIC_FADE_DURATION):
	var new_stream: AudioStream = null
	if not track_path.is_empty():
		new_stream = load(track_path) as AudioStream
		if not is_instance_valid(new_stream):
			printerr("AudioManager: Failed to load music track from path: ", track_path)
			_load_and_set_music_track_from_stream(null, false, loop, duration) 
			return
	
	_load_and_set_music_track_from_stream(new_stream, fade_in, loop, duration)


func _play_new_music_stream(track_stream: AudioStream, loop: bool, should_fade_in_new_track: bool, fade_duration: float = MUSIC_FADE_DURATION):
	music_change_pending = false
	if not is_instance_valid(bg_player): return

	if bg_player.stream == track_stream and bg_player.playing and not should_fade_in_new_track:
		bg_player.stream_paused = music_globally_muted 
		if not music_globally_muted and not (is_menu_music_off and bg_player.stream in [classic_menu_theme, modern_menu_theme]):
			if bg_player.volume_db < MUSIC_TARGET_VOLUME_DB - 1.0: 
				bg_player.volume_db = MUSIC_TARGET_VOLUME_DB
		return

	bg_player.stop() 

	if is_instance_valid(track_stream):
		bg_player.stream = track_stream
		if should_fade_in_new_track and not music_globally_muted:
			bg_player.volume_db = MUSIC_MUTED_VOLUME_DB 
		elif music_globally_muted:
			bg_player.volume_db = MUSIC_MUTED_VOLUME_DB
		else: 
			bg_player.volume_db = MUSIC_TARGET_VOLUME_DB
		
		bg_player.play()
		bg_player.stream_paused = music_globally_muted 
		
		current_music_path = track_stream.resource_path if track_stream else ""

		if should_fade_in_new_track and not music_globally_muted:
			var tween = create_tween().set_trans(Tween.TRANS_SINE) 
			tween.tween_property(bg_player, "volume_db", MUSIC_TARGET_VOLUME_DB, fade_duration)
		elif not music_globally_muted and not should_fade_in_new_track:
			bg_player.volume_db = MUSIC_TARGET_VOLUME_DB

	else: 
		current_music_path = ""
		bg_player.stream = null 
		bg_player.volume_db = MUSIC_MUTED_VOLUME_DB 

	bg_player.set_meta("loop", loop) 

func _fade_music_out(duration: float = MUSIC_FADE_DURATION):
	if is_instance_valid(bg_player) and bg_player.playing:
		var tween = create_tween()
		tween.tween_property(bg_player, "volume_db", MUSIC_MUTED_VOLUME_DB, duration)
		tween.tween_callback(Callable(bg_player, "stop"))

func toggle_global_music_mute():
	music_globally_muted = !music_globally_muted
	if is_instance_valid(bg_player):
		if music_globally_muted:
			bg_player.stream_paused = true
			print("AudioManager: Music GLOBALLY MUTED")
		else:
			bg_player.stream_paused = false
			if not (is_menu_music_off and bg_player.stream in [classic_menu_theme, modern_menu_theme]):
				if bg_player.playing and bg_player.stream != null: 
					bg_player.volume_db = MUSIC_TARGET_VOLUME_DB
			print("AudioManager: Music GLOBALLY UNMUTED")
	if not music_globally_muted:
		_update_menu_music_on_state_change(false)

func _start_volume_tween(player: AudioStreamPlayer, target_volume_db: float, duration: float, on_finished_callback: Callable = Callable()):
	if not is_instance_valid(player):
		return

	_kill_player_tween(player) 

	var tween = create_tween()
	player.set_meta("active_volume_tween", tween)
	
	tween.tween_property(player, "volume_db", target_volume_db, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	
	if on_finished_callback.is_valid():
		tween.tween_callback(on_finished_callback)

	tween.connect("finished", Callable(self, "_on_tween_cleanup").bind(player), CONNECT_ONE_SHOT)

func _kill_player_tween(player: AudioStreamPlayer):
	if is_instance_valid(player) and player.has_meta("active_volume_tween"):
		var existing_tween = player.get_meta("active_volume_tween")
		if is_instance_valid(existing_tween) and existing_tween.is_running():
			existing_tween.kill()
		player.remove_meta("active_volume_tween")

func _on_tween_cleanup(player: AudioStreamPlayer):
	if is_instance_valid(player) and player.has_meta("active_volume_tween"):
		var tween_ref = player.get_meta("active_volume_tween")
		if tween_ref == null or (is_instance_valid(tween_ref) and not tween_ref.is_running()):
			player.remove_meta("active_volume_tween")

func _unhandled_input(event: InputEvent):
	if event.is_action_pressed("ui_mute"):
		toggle_global_music_mute()
		get_viewport().set_input_as_handled()
