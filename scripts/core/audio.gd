extends Node # audio.gd

@export var beep_sound: AudioStream = preload("res://audio//other/beep_sound.wav")
@export var difficulty_music: Dictionary = {
	"baby": "res://audio/other/opening.mp3",
	"intern": "res://audio/other/opening.mp3",
	"profi": "res://audio/other/opening.mp3",
	"master": "res://audio/other/opening.mp3",
	"expert": "res://audio/other/opening.mp3",
	"torrero": "res://audio/other/BWV784 Courante.mp3"
}

# --- Audio Players ---
var sfx_player: AudioStreamPlayer
var bg_player: AudioStreamPlayer

# --- Audio State ---
var sfx_enabled: bool = true
var music_globally_muted: bool = false # For master music mute (e.g., M key)
var current_music_path: String = ""
var music_change_pending: bool = false # Flag to handle rapid changes

var menu_music_tracks: Array[Dictionary] = [
	{"name": "Original", "path": "res://audio/other/opening.mp3"},
	{"name": "Courante", "path": "res://audio/other/BWV784 Courante.mp3"},
	{"name": "Off", "path": null} # An option to turn music off by cycling
]

var current_menu_music_idx: int = 0
#var is_muted: bool = false
#var all_audio_players: Array = []
#var active_tweens: Dictionary = {}


# Constants for tweening
const MUSIC_TARGET_VOLUME_DB: float = -10.0
const MUSIC_MUTED_VOLUME_DB: float = -80.0 # Effectively silent
const MUSIC_FADE_DURATION: float = 1.0 # Default fade duration
const DEFAULT_SFX_VOLUME_DB: float = 0.0

func _ready():
	setup_audio_players()
	initialize_audio_settings()
	print("AudioManager ready.")


func setup_audio_players():
	if not is_instance_valid(sfx_player):
		sfx_player = AudioStreamPlayer.new()
		sfx_player.name = "SFXPlayer"
		if beep_sound: # Default beep sound
			sfx_player.stream = beep_sound
		add_child(sfx_player)
	
	if not is_instance_valid(bg_player):
		bg_player = AudioStreamPlayer.new()
		bg_player.name = "BackgroundMusicPlayer"
		add_child(bg_player)
		bg_player.connect("finished", Callable(self, "_on_music_track_finished"))

func initialize_audio_settings():
	# Initialize SFX player volume based on sfx_enabled state
	sfx_player.volume_db = DEFAULT_SFX_VOLUME_DB if sfx_enabled else MUSIC_MUTED_VOLUME_DB

	# Load and play initial menu music track if not globally muted
	if not menu_music_tracks.is_empty():
		var initial_track_info = menu_music_tracks[current_menu_music_idx]
		_load_and_set_music_track(initial_track_info.path, false) # false for no fade on initial load


func _on_music_track_finished():
	# This is called when a non-looping track ends.
	# For looped tracks, this won't be hit unless loop is manually turned off.
	print("AudioManager: Music track finished signal received (may indicate non-looping track ended).")
	# If you want continuous play even for non-looped tracks, you could re-trigger play here
	# or cycle to the next track, depending on desired behavior.
	# For now, if it was looped, it continues. If not, it stops.

# --- SFX Control ---

func toggle_sfx_enabled():
	sfx_enabled = !sfx_enabled
	sfx_player.volume_db = DEFAULT_SFX_VOLUME_DB if sfx_enabled else MUSIC_MUTED_VOLUME_DB
	print("AudioManager: SFX " + ("ENABLED" if sfx_enabled else "DISABLED"))
	# Optionally play a sound to indicate change, if SFX are now on
	if sfx_enabled:
		play_sfx("beep_sound") # Assuming you have a beep for UI feedback

func play_sfx(sfx_name: String = "beep_sound", volume_db: float = DEFAULT_SFX_VOLUME_DB):
	if not sfx_enabled or not is_instance_valid(sfx_player):
		return

	# This is a placeholder for a more robust SFX management system
	# For now, it just plays the default beep_sound or a named one if you extend this
	if sfx_name == "beep_sound" and beep_sound:
		sfx_player.stream = beep_sound
		sfx_player.volume_db = volume_db if sfx_enabled else MUSIC_MUTED_VOLUME_DB
		sfx_player.play()
	# else if sfx_name == "other_sound":
	#    sfx_player.stream = preload("res://path_to_other_sound.wav")
	#    sfx_player.play()
	else:
		# Fallback to default beep if specific sound not found or implemented
		if beep_sound:
			sfx_player.stream = beep_sound
			sfx_player.volume_db = volume_db if sfx_enabled else MUSIC_MUTED_VOLUME_DB
			sfx_player.play()


# --- Music Control ---

# res://audio.gd

# ... (other properties) ...
# var music_globally_muted: bool = false # Already exists

func cycle_menu_music_track():
	if menu_music_tracks.is_empty():
		return
	current_menu_music_idx = (current_menu_music_idx + 1) % menu_music_tracks.size()
	var new_track_info = menu_music_tracks[current_menu_music_idx]

	if new_track_info.path == null: # This is the "Off" track
		print("AudioManager: 'Off' track selected in menu. Engaging global music mute.")
		music_globally_muted = true
		# We still call _load_and_set_music_track with null to ensure current track fades out.
		_load_and_set_music_track(new_track_info.path, true) 
	else:
		# If a real track is selected, and we are only globally muted because "Off" was selected,
		# we can consider unmuting. However, this might conflict with a manual global mute (e.g. M key).
		# For simplicity, let's assume cycling to a real track means the user wants music IF global mute wasn't set by other means.
		# A more robust solution might involve separate flags or states.
		if music_globally_muted and get_current_menu_music_track_name() != "Off": # Check if it was previously "Off"
			# This logic can get tricky. For now, let's just say selecting a track un-mutes only if
			# the MUTE was specifically from choosing "Off".
			# The toggle_global_music_mute should be the primary way to unmute if M-key was pressed.
			# To keep it simple: if user selects a new track, we assume they want music unless M-key mute is active.
			# For now, let's just allow _load_and_set_music_track to decide based on the current music_globally_muted state.
			# If music_globally_muted was set by M-key, it will remain true.
			# If it was set by "Off", and now a new track is selected, we might want to set it to false.
			# Let's make `toggle_global_music_mute` the main control for this flag.
			# Selecting "Off" just means "play no track now".
			pass # Let _load_and_set_music_track handle based on existing music_globally_muted state.
			# The current logic in _finalize_music_change already checks `music_globally_muted`.
			# So if "Off" set it to true, new music won't play unless `toggle_global_music_mute` is called.
			# This feels more consistent. So the change above (`music_globally_muted = true`) is the key for "Off".
		_load_and_set_music_track(new_track_info.path, true)
	
	print("AudioManager: Cycled to menu music track: " + new_track_info.name)
	# MainMenu will update its display based on get_current_menu_music_track_name()

func get_current_menu_music_track_name() -> String:
	if not menu_music_tracks.is_empty():
		return menu_music_tracks[current_menu_music_idx].name
	return "N/A"

func _load_and_set_music_track(new_path_variant: Variant, fade: bool):
	var new_path: String
	if new_path_variant is String:
		new_path = new_path_variant
	elif new_path_variant == null:
		new_path = "" # Convert null to empty string, signifying no track
	else:
		printerr("AudioManager: _load_and_set_music_track received unexpected type for path: ", typeof(new_path_variant), ". Defaulting to no track.")
		new_path = "" # Default to no track for unexpected types

	# --- The rest of the function uses 'new_path' which is now guaranteed to be a String ---

	if music_change_pending and new_path == current_music_path:
		# If a change to this exact path is already pending, do nothing.
		# This also covers the case where new_path is "" and current_music_path is also "".
		print("AudioManager: Music change to '%s' already pending or track is the same and change in progress." % new_path)
		return
	
	# If the same music is already playing (and not "" which means "off"),
	# and not globally muted, ensure it's at target volume (e.g. if a previous fade was interrupted)
	if !new_path.is_empty() and new_path == current_music_path and bg_player.playing and not music_globally_muted:
		if bg_player.volume_db < MUSIC_TARGET_VOLUME_DB:
			_start_volume_tween(bg_player, MUSIC_TARGET_VOLUME_DB, MUSIC_FADE_DURATION)
		# print("AudioManager: Music '%s' is already playing at correct state." % new_path)
		return
	# If new_path is "" and current track is already "" (or not playing), also effectively no change needed.
	if new_path.is_empty() and current_music_path.is_empty() and not bg_player.playing:
		# print("AudioManager: Music is already off or set to no track.")
		return

	music_change_pending = true
	
	var music_stream: AudioStream = null
	if !new_path.is_empty(): # Only attempt to load if new_path is a non-empty string
		music_stream = load(new_path)
		if not music_stream:
			printerr("AudioManager: Failed to load music from: '%s'" % new_path)
			music_change_pending = false # Reset pending flag as this attempt failed
			# Fade out current music (if any), then finalize with no new stream (empty path)
			if fade and (bg_player.playing or bg_player.volume_db > MUSIC_MUTED_VOLUME_DB + 5) and bg_player.stream != null :
				_start_volume_tween(bg_player, MUSIC_MUTED_VOLUME_DB, MUSIC_FADE_DURATION, 
									Callable(self, "_finalize_music_change").bind(null, "")) # Target stream=null, path=""
			else:
				_finalize_music_change(null, "") # Target stream=null, path=""
			return
		
		# Ensure looping for background music
		if music_stream is AudioStreamOggVorbis or music_stream is AudioStreamMP3:
			music_stream.loop = true
	# If new_path is empty, music_stream remains null, which is correct for stopping music.

	# Fade out current music if it's playing and fade is requested,
	# and if the new music is different or if current music needs to stop.
	# The check `bg_player.stream != null` ensures we only fade if there's something to fade.
	if fade and (bg_player.playing or bg_player.volume_db > MUSIC_MUTED_VOLUME_DB + 5) and bg_player.stream != null :
		# print("AudioManager: Fading out current music to switch to '%s'..." % new_path)
		_start_volume_tween(bg_player, MUSIC_MUTED_VOLUME_DB, MUSIC_FADE_DURATION, 
							Callable(self, "_finalize_music_change").bind(music_stream, new_path))
	else:
		# No current music playing, or no fade requested, or same track being re-set.
		# Directly finalize the change.
		_finalize_music_change(music_stream, new_path)

func load_and_play_music_by_difficulty(difficulty_key: String):
	if not difficulty_music.has(difficulty_key):
		printerr("AudioManager: No music found for difficulty key: %s" % difficulty_key)
		_load_and_set_music_track(null, true) # Pass null; _load_and_set_music_track will handle it
		return

	var new_music_path = difficulty_music[difficulty_key] # This could be null if defined so in the dictionary
	_load_and_set_music_track(new_music_path, true) # Pass the path (which might be null or a string)

func _finalize_music_change(new_stream: AudioStream, new_path: String):
	music_change_pending = false # Processing finished or about to
	
	if not is_instance_valid(bg_player): return

	bg_player.stop() # Stop before changing stream or volume drastically

	current_music_path = new_path # Update path before potential play
	bg_player.stream = new_stream

	if new_stream != null:
		if not music_globally_muted:
			bg_player.volume_db = MUSIC_MUTED_VOLUME_DB # Start silent for fade-in
			bg_player.play()
			_start_volume_tween(bg_player, MUSIC_TARGET_VOLUME_DB, MUSIC_FADE_DURATION)
			print("AudioManager: Playing new music '%s' with fade-in." % new_path)
		else:
			# Music is globally muted. Stream is loaded, path updated, but remains silent.
			bg_player.volume_db = MUSIC_MUTED_VOLUME_DB
			print("AudioManager: New music '%s' loaded but currently globally muted." % new_path)
	else:
		# No new stream means stop music (or it was already faded out)
		bg_player.volume_db = MUSIC_MUTED_VOLUME_DB # Ensure it's silent
		print("AudioManager: Music stopped (no new stream provided or 'Off' selected).")


# --- Global Music Mute (e.g., for an 'M' key shortcut) ---
# Ensure toggle_global_music_mute correctly updates UI if needed and handles playing/stopping
func toggle_global_music_mute():
	music_globally_muted = !music_globally_muted
	print("AudioManager: Global music mute toggled to %s" % music_globally_muted)

	if not is_instance_valid(bg_player):
		return

	_kill_player_tween(bg_player) # Stop any ongoing fade

	if music_globally_muted:
		# If "Off" track is selected in menu, its path is null.
		# We want to mute regardless of current track.
		if bg_player.playing: 
			_start_volume_tween(bg_player, MUSIC_MUTED_VOLUME_DB, MUSIC_FADE_DURATION)
		else: 
			bg_player.volume_db = MUSIC_MUTED_VOLUME_DB
		# If "Off" is selected in menu, update current_menu_music_idx to reflect this,
		# so the UI shows "Off" if global mute is activated.
		# This makes the M-key sync with the menu's "Off" state.
		var off_idx = -1
		for i in menu_music_tracks.size():
			if menu_music_tracks[i].path == null:
				off_idx = i
				break
		if off_idx != -1:
			current_menu_music_idx = off_idx
			# You'll need a way for main_menu to refresh its display if it's visible.
			# e.g., emit a signal: emit_signal("music_settings_changed")

	else: # Unmuting globally
		# If unmuting, and current menu track is "Off", cycle to the first actual music track.
		# Or, simply play current_music_path if it's not null.
		if current_music_path != null and !current_music_path.is_empty() and bg_player.stream != null:
			bg_player.play() 
			_start_volume_tween(bg_player, MUSIC_TARGET_VOLUME_DB, MUSIC_FADE_DURATION)
		elif current_music_path != null and !current_music_path.is_empty() and bg_player.stream == null:
			# Stream was probably set to null because of "Off" or previous mute. Try to reload.
			_load_and_set_music_track(current_music_path, true) # true to fade in
		else:
			# No current_music_path (was "Off" and nothing else loaded).
			# Optionally, play the default menu music.
			if not menu_music_tracks.is_empty():
				var first_track_idx = 0
				if menu_music_tracks[first_track_idx].path == null and menu_music_tracks.size() > 1:
					first_track_idx = 1 # Try second track if first is "Off"
				
				if menu_music_tracks[first_track_idx].path != null:
					current_menu_music_idx = first_track_idx
					_load_and_set_music_track(menu_music_tracks[current_menu_music_idx].path, true)
				else: # Still no valid track, stay silent
					bg_player.volume_db = MUSIC_MUTED_VOLUME_DB


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
