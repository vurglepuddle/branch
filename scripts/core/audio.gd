extends Node # audio.gd

signal music_display_changed(display_name: String)

@export var modern_beep_sound: AudioStream = preload("res://audio/modern/SFX_modern.wav")
@export var beep_sound: AudioStream = preload("res://audio//other/beep_sound.wav")
@export var switch_to_off_sfx: AudioStream

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

# --- New Exports ---
@export var classic_menu_theme: AudioStream
@export var modern_menu_theme: AudioStream
#@export var style_switch_sfx_stream: AudioStream # SFX for when music style changes

# --- Audio Players ---
var sfx_player: AudioStreamPlayer
var bg_player: AudioStreamPlayer

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
	#print("--- AudioManager: _ready() START ---")
	setup_audio_players()
	#print("--- AudioManager: After setup_audio_players ---")
	initialize_audio_settings()
	#print("--- AudioManager: After initialize_audio_settings ---")
	#print("--- AudioManager: _ready() COMPLETED --- (Engine will emit 'ready' signal now)")


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

func initialize_audio_settings():
	print("AudioManager initialize_audio_settings: START")
	sfx_player.volume_db = DEFAULT_SFX_VOLUME_DB if sfx_enabled else MUSIC_MUTED_VOLUME_DB
	# print("AudioManager initialize_audio_settings: SFX volume set.")

	# Call _update_menu_music_on_state_change with fade_in = true for the initial load
	_update_menu_music_on_state_change(true, INITIAL_MUSIC_FADE_IN_DURATION) # Use new duration parameter
	# print("AudioManager initialize_audio_settings: After _update_menu_music_on_state_change.")
	
	var initial_display_name: String
	if is_menu_music_off:
		initial_display_name = "Off"
	elif current_music_style == MusicStyle.CLASSIC:
		initial_display_name = "Classic"
	else:
		initial_display_name = "Modern"
	
	# print("AudioManager initialize_audio_settings: Determined initial_display_name: ", initial_display_name)
	emit_signal("music_display_changed", initial_display_name)
	# print("AudioManager initialize_audio_settings: Signal 'music_display_changed' emitted.")
	# print("AudioManager initialize_audio_settings: END")

func _on_music_track_finished():
	# Handle looping for music if not natively supported by stream's import settings
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
			# This is for general UI beeps (difficulty, start, sfx toggle etc.)
			if is_menu_music_off: 
				# If music is "Off" via the cycle, use the neutral 'switch_to_off_sfx' for all general beeps
				stream_to_play = switch_to_off_sfx 
			elif current_music_style == MusicStyle.CLASSIC:
				stream_to_play = beep_sound # Classic beep
			else: # current_music_style == MusicStyle.MODERN (and not is_menu_music_off)
				stream_to_play = modern_beep_sound # Modern beep
		
		"switch_to_off_sfx": 
			stream_to_play = switch_to_off_sfx

		
		_: # Fallback for unknown keys
			printerr("AudioManager: Unknown SFX key: ", sfx_key)
			# Fallback logic: if key is unknown, what should it play?
			# Option 1: Play the current style-aware beep (classic/modern/neutral if off)
			if is_menu_music_off:
				stream_to_play = switch_to_off_sfx
			elif current_music_style == MusicStyle.CLASSIC:
				stream_to_play = beep_sound
			else: # MODERN
				stream_to_play = modern_beep_sound
			if not stream_to_play:
				printerr("AudioManager: No fallback beep sound available for unknown key.")
				return
	   
	if stream_to_play:
		sfx_player.stream = stream_to_play
		sfx_player.volume_db = volume_db 
		sfx_player.play()
	else:
		# Refined error message to be more specific about which stream is null for the "beep_sound" key
		var problem_stream_name = ""
		if sfx_key == "beep_sound":
			if is_menu_music_off:
				problem_stream_name = "'switch_to_off_sfx' (for when music is Off)"
			elif current_music_style == MusicStyle.CLASSIC:
				problem_stream_name = "classic 'beep_sound'"
			else: # MODERN
				problem_stream_name = "'modern_beep_sound'"
		elif sfx_key == "switch_to_off_sfx":
			problem_stream_name = "'switch_to_off_sfx'"
		else: # Unknown key
			problem_stream_name = "a valid stream for key '%s' (or its fallback)" % sfx_key

		printerr("AudioManager: SFX stream for %s is null. Please assign it in the Inspector." % problem_stream_name)

# Kept for compatibility if you used play_sfx() elsewhere for default beep
func play_sfx(sfx_name: String = "beep_sound", volume_db: float = DEFAULT_SFX_VOLUME_DB):
	play_named_sfx(sfx_name, volume_db)
# --- Music Control ---

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
	_update_menu_music_on_state_change() # Uses default fade duration for changes

func _update_menu_music_on_state_change(fade_in: bool = true, duration: float = MUSIC_FADE_DURATION):
	# print("AudioManager _update_menu_music_on_state_change: START. Fade: ", fade_in, " Duration: ", duration)
	if music_globally_muted:
		# print("AudioManager _update_menu_music_on_state_change: Music globally muted, loading null.")
		_load_and_set_music_track_from_stream(null, false, false, duration) # Pass duration
		current_music_path = ""
		# print("AudioManager _update_menu_music_on_state_change: END (globally muted)")
		return

	var new_track_stream: AudioStream = null
	if not is_menu_music_off:
		if current_music_style == MusicStyle.CLASSIC:
			# print("AudioManager _update_menu_music_on_state_change: Style is CLASSIC.")
			new_track_stream = classic_menu_theme
			# if not is_instance_valid(new_track_stream):
				# printerr("AudioManager _update_menu_music_on_state_change: classic_menu_theme IS NULL!")
		else: # MODERN
			# print("AudioManager _update_menu_music_on_state_change: Style is MODERN.")
			new_track_stream = modern_menu_theme
			# if not is_instance_valid(new_track_stream):
				# printerr("AudioManager _update_menu_music_on_state_change: modern_menu_theme IS NULL!")
	# else:
		# print("AudioManager _update_menu_music_on_state_change: Menu music is OFF.")
	
	# print("AudioManager _update_menu_music_on_state_change: Calling _load_and_set_music_track_from_stream.")
	_load_and_set_music_track_from_stream(new_track_stream, fade_in, true, duration) # true for loop, pass duration


func play_difficulty_music(difficulty_key: String, loop: bool = true, fade: bool = true, duration: float = MUSIC_FADE_DURATION):
	if is_menu_music_off or music_globally_muted:
		# print("AudioManager: Difficulty music not playing because menu music is set to Off or globally muted.")
		_load_and_set_music_track_from_path("", false, loop, duration) # Play nothing
		return

	var music_lib: Dictionary
	if current_music_style == MusicStyle.CLASSIC:
		music_lib = difficulty_music
	else: # MODERN
		music_lib = difficulty_music_modern
	
	if not music_lib.has(difficulty_key):
		printerr("AudioManager: Difficulty key '%s' not found in selected music library." % difficulty_key)
		_load_and_set_music_track_from_path("", fade, loop, duration) # Play nothing
		return

	var music_path_to_load: String = music_lib[difficulty_key]
	_load_and_set_music_track_from_path(music_path_to_load, fade, loop, duration)

# --- Core Music Loading and Playing ---

func _load_and_set_music_track_from_stream(track_stream: AudioStream, fade_in: bool = true, loop: bool = true, duration: float = MUSIC_FADE_DURATION):
	# print("AudioManager _load_and_set_music_track_from_stream: START. Stream valid: ", is_instance_valid(track_stream), " Fade: ", fade_in, " Loop: ", loop, " Duration: ", duration)
	if music_change_pending and fade_in:
		# print("AudioManager: Music change already pending.")
		return

	if not is_instance_valid(bg_player):
		printerr("AudioManager: BackgroundMusicPlayer not valid for _load_and_set_music_track_from_stream.")
		return

	# If already playing, different track, and fade_in is true, then fade out current
	if bg_player.playing and bg_player.stream != track_stream and fade_in:
		music_change_pending = true
		var tween = create_tween()
		# Fade out current track over half the duration (or a fixed short duration)
		tween.tween_property(bg_player, "volume_db", MUSIC_MUTED_VOLUME_DB, duration / 2.0) 
		tween.tween_callback(Callable(self, "_play_new_music_stream").bind(track_stream, loop, true, duration)) # Pass true for fade_in and duration
	else:
		# Play new track (or replay same track if loop is false and it finished, or if no fade_in was requested)
		# If it's the same track or no fade_in, the fade_in flag to _play_new_music_stream will be false.
		_play_new_music_stream(track_stream, loop, fade_in and bg_player.stream != track_stream, duration)


# Plays music from a resource path (good for dynamic loading like difficulty music)
func _load_and_set_music_track_from_path(track_path: String, fade_in: bool = true, loop: bool = true, duration: float = MUSIC_FADE_DURATION):

	var new_stream: AudioStream = null
	if not track_path.is_empty():
		new_stream = load(track_path) as AudioStream
		if not is_instance_valid(new_stream):
			printerr("AudioManager: Failed to load music track from path: ", track_path)
			_load_and_set_music_track_from_stream(null, false, loop, duration) # Play nothing
			return
	
	_load_and_set_music_track_from_stream(new_stream, fade_in, loop, duration)




func _play_new_music_stream(track_stream: AudioStream, loop: bool, should_fade_in_new_track: bool, fade_duration: float = MUSIC_FADE_DURATION):
	music_change_pending = false
	if not is_instance_valid(bg_player): return

	# If it's the same stream, it's already playing, and no fade was requested (e.g. from finished signal for looping)
	# or if global mute changed state.
	if bg_player.stream == track_stream and bg_player.playing and not should_fade_in_new_track:
		bg_player.stream_paused = music_globally_muted # Just ensure global mute state is applied
		# Ensure volume is correct if unmuting
		if not music_globally_muted and not (is_menu_music_off and bg_player.stream in [classic_menu_theme, modern_menu_theme]):
			if bg_player.volume_db < MUSIC_TARGET_VOLUME_DB - 1.0: # If it was muted
				bg_player.volume_db = MUSIC_TARGET_VOLUME_DB
		return

	bg_player.stop() # Stop current playback before changing stream or parameters

	if is_instance_valid(track_stream):
		bg_player.stream = track_stream
		# Set initial volume based on whether we're fading or globally muted
		if should_fade_in_new_track and not music_globally_muted:
			bg_player.volume_db = MUSIC_MUTED_VOLUME_DB # Start silent for fade-in
		elif music_globally_muted:
			bg_player.volume_db = MUSIC_MUTED_VOLUME_DB
		else: # Play immediately at target volume
			bg_player.volume_db = MUSIC_TARGET_VOLUME_DB
		
		bg_player.play()
		bg_player.stream_paused = music_globally_muted # Apply global mute immediately
		
		current_music_path = track_stream.resource_path if track_stream else ""

		if should_fade_in_new_track and not music_globally_muted:
			var tween = create_tween().set_trans(Tween.TRANS_SINE) # Smooth fade
			tween.tween_property(bg_player, "volume_db", MUSIC_TARGET_VOLUME_DB, fade_duration)
		# If not fading in and not globally muted, ensure volume is at target
		elif not music_globally_muted and not should_fade_in_new_track:
			bg_player.volume_db = MUSIC_TARGET_VOLUME_DB

	else: # track_stream is null (e.g., music turned "Off")
		current_music_path = ""
		bg_player.stream = null 
		bg_player.volume_db = MUSIC_MUTED_VOLUME_DB # Ensure it's silent

	bg_player.set_meta("loop", loop) # For manual looping in _on_music_track_finished

func _fade_music_out(duration: float = MUSIC_FADE_DURATION):
	if is_instance_valid(bg_player) and bg_player.playing:
		var tween = create_tween()
		tween.tween_property(bg_player, "volume_db", MUSIC_MUTED_VOLUME_DB, duration)
		tween.tween_callback(Callable(bg_player, "stop"))


# --- Global Mute (Example - you might have this elsewhere) ---
func toggle_global_music_mute():
	music_globally_muted = !music_globally_muted
	if is_instance_valid(bg_player):
		if music_globally_muted:
			#bg_player.volume_db = MUSIC_MUTED_VOLUME_DB # Or use stream_paused
			bg_player.stream_paused = true
			print("AudioManager: Music GLOBALLY MUTED")
		else:
			#bg_player.volume_db = MUSIC_TARGET_VOLUME_DB # Or use stream_paused
			bg_player.stream_paused = false
			# If music was off due to style choice, global unmute shouldn't turn it on unless style changes
			if not (is_menu_music_off and bg_player.stream in [classic_menu_theme, modern_menu_theme]):
				if bg_player.playing and bg_player.stream != null: # ensure it was playing something
					bg_player.volume_db = MUSIC_TARGET_VOLUME_DB
			print("AudioManager: Music GLOBALLY UNMUTED")
	# Potentially re-evaluate current music if it was "off" due to global mute
	if not music_globally_muted:
		_update_menu_music_on_state_change(false) # Refresh current menu music state without fade


# --- Tweening Logic ---
func _start_volume_tween(player: AudioStreamPlayer, target_volume_db: float, duration: float, on_finished_callback: Callable = Callable()):
	if not is_instance_valid(player):
		return

	_kill_player_tween(player) # Kill any existing tween on this player

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
		# Check if the meta still points to a valid tween that is no longer running
		if tween_ref == null or (is_instance_valid(tween_ref) and not tween_ref.is_running()):
			player.remove_meta("active_volume_tween")

# Example of how you might handle the M key for global music mute
# This would typically be in a global input handler script or your main game node
#func _unhandled_input(event: InputEvent):
	#if event.is_action_pressed("ui_mute")
		#toggle_global_music_mute()
		#get_viewport().set_input_as_handled()
