extends Node2D # audio.gd

@export var beep_sound: AudioStream = preload("res://audio//other/beep_sound.wav")
@export var difficulty_music: Dictionary = {
	"baby": "res://audio/other/opening.mp3",
	"intern": "res://audio/other/opening.mp3",
	"profi": "res://audio/other/opening.mp3",
	"master": "res://audio/other/opening.mp3",
	"expert": "res://audio/other/opening.mp3",
	"torrero": "res://audio/other/BWV784 Courante.mp3"
}
var sfx_player: AudioStreamPlayer
var bg_player: AudioStreamPlayer
var is_muted: bool = false
var all_audio_players: Array = []
var active_tweens: Dictionary = {}
var current_music_path: String = ""
var music_change_pending: bool = false # Flag to handle rapid changes

# Constants for tweening
const MUSIC_TARGET_VOLUME_DB: float = -10.0
const MUSIC_MUTED_VOLUME_DB: float = -80.0 # Effectively silent
const MUSIC_FADE_DURATION: float = 1.0 # Default fade duration

func _ready():
	setup_audio()

func setup_audio():
	if not is_instance_valid(sfx_player):
		sfx_player = AudioStreamPlayer.new()
		sfx_player.name = "SFXPlayer"
		if beep_sound:
			sfx_player.stream = beep_sound
		add_child(sfx_player)
	
	if not is_instance_valid(bg_player):
		bg_player = AudioStreamPlayer.new()
		bg_player.name = "BackgroundMusicPlayer"
		add_child(bg_player)
		# Connect finished signal for looping/restarting if desired
		bg_player.connect("finished", Callable(self, "_on_music_track_finished"))
	## Create the sound effect player
	#sfx_player = AudioStreamPlayer.new()
	#if beep_sound:
		#sfx_player.stream = beep_sound
	#add_child(sfx_player)
	#all_audio_players.append(sfx_player)
#
	## Create the background music player
	#bg_player = AudioStreamPlayer.new()
	#add_child(bg_player)
	#all_audio_players.append(bg_player)
	
func _on_music_track_finished():
	# This is for when a non-looping track ends, or for custom looping logic
	print("Music track finished signal received.")
	# If you want continuous looping for all music, set stream.loop = true
	# and this signal might not be strictly needed unless you do something special.
	# For now, let's assume streams are set to loop. If not, you'd restart here:
	# if bg_player.stream != null and not is_muted:
	#     bg_player.play()


func load_and_play_music_by_difficulty(difficulty: String):
	if not difficulty_music.has(difficulty):
		printerr("AudioManager: No music found for difficulty: %s" % difficulty)
		# Optionally play a default or stop music
		_play_new_music_stream(null) # Attempt to stop/fade out current
		return

	var new_music_path = difficulty_music[difficulty]
	if new_music_path == current_music_path and bg_player.playing and not music_change_pending:
		# If the same music is already playing and no change is pending, do nothing
		# (or ensure it's at the correct volume if a previous fade was interrupted)
		if not is_muted and bg_player.volume_db < MUSIC_TARGET_VOLUME_DB:
			_start_volume_tween(bg_player, MUSIC_TARGET_VOLUME_DB, MUSIC_FADE_DURATION)
		# print("AudioManager: Music for '%s' is already set or playing." % difficulty)
		return

	if music_change_pending and new_music_path == current_music_path:
		# A change to this same music was already in progress, let it finish
		# print("AudioManager: Music change to '%s' already pending." % new_music_path)
		return

	print("AudioManager: Request to play music for '%s' (Path: %s)" % [difficulty, new_music_path])
	music_change_pending = true # Signal that a change is in progress
	
	# Load the stream first to ensure it's valid
	var music_stream = load(new_music_path)
	if not music_stream:
		printerr("AudioManager: Failed to load music from: %s" % new_music_path)
		music_change_pending = false
		_play_new_music_stream(null) # Attempt to stop/fade out current
		return
		
	if music_stream is AudioStreamOggVorbis or music_stream is AudioStreamMP3:
		music_stream.loop = true

	# Fade out current music (if any is playing), then play new one
	if bg_player.playing or bg_player.volume_db > MUSIC_MUTED_VOLUME_DB + 5: # If it's audible
		print("AudioManager: Fading out current music...")
		# The callback will handle playing the new stream
		_start_volume_tween(bg_player, MUSIC_MUTED_VOLUME_DB, MUSIC_FADE_DURATION, 
							Callable(self, "_play_new_music_stream").bind(music_stream, new_music_path))
	else:
		# No music playing or already silent, just play the new one directly
		_play_new_music_stream(music_stream, new_music_path)

func _play_new_music_stream(stream: AudioStream, new_path: String = ""):
	# This function is called after fade-out or directly if no music was playing
	music_change_pending = false # Mark change as no longer pending (or about to complete)

	if is_instance_valid(bg_player): # Ensure bg_player still exists
		bg_player.stop() # Ensure it's fully stopped before changing stream

		if stream != null:
			bg_player.stream = stream
			current_music_path = new_path # Update the current path
			if not is_muted:
				bg_player.volume_db = MUSIC_MUTED_VOLUME_DB # Start from silent for fade-in
				bg_player.play()
				_start_volume_tween(bg_player, MUSIC_TARGET_VOLUME_DB, MUSIC_FADE_DURATION)
				print("AudioManager: Playing new music '%s' with fade-in." % new_path)
			else:
				# Music is loaded, but we are muted. Set volume to muted state.
				bg_player.volume_db = MUSIC_MUTED_VOLUME_DB
				current_music_path = new_path # Still update path so unmute knows what to play
				print("AudioManager: New music '%s' loaded but currently muted." % new_path)
		else:
			# No new stream means stop music
			bg_player.stream = null
			current_music_path = ""
			print("AudioManager: Music stopped (no new stream provided).")

func _start_volume_tween(player: AudioStreamPlayer, target_volume_db: float, duration: float, on_finished_callback: Callable = Callable()):
	if not is_instance_valid(player):
		return

	# Kill any existing tween on this player to prevent conflicts
	if player.get_meta("active_volume_tween", null) != null:
		var existing_tween = player.get_meta("active_volume_tween")
		if is_instance_valid(existing_tween) and existing_tween.is_running():
			existing_tween.kill() # Use kill() to stop and free immediately

	var tween = create_tween()
	player.set_meta("active_volume_tween", tween) # Store reference to the new tween
	
	tween.tween_property(player, "volume_db", target_volume_db, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	
	if on_finished_callback.is_valid():
		tween.tween_callback(on_finished_callback) # Use tween_callback for reliability

	# When tween is done (completed or killed), clear its meta reference
	tween.connect("finished", Callable(self, "_on_tween_cleanup").bind(player), CONNECT_ONE_SHOT)


func _on_tween_cleanup(player: AudioStreamPlayer):
	if is_instance_valid(player) and player.has_meta("active_volume_tween"):
		if player.get_meta("active_volume_tween") != null and not player.get_meta("active_volume_tween").is_running():
			player.remove_meta("active_volume_tween")


func toggle_mute():
	is_muted = !is_muted
	print("AudioManager: Mute toggled to %s" % is_muted)

	# SFX Player Mute
	if is_instance_valid(sfx_player):
		sfx_player.volume_db = MUSIC_MUTED_VOLUME_DB if is_muted else 0 # Or your preferred SFX volume

	# Background Music Player Mute
	if not is_instance_valid(bg_player):
		return

	# Kill any active volume tween on bg_player
	if bg_player.get_meta("active_volume_tween", null) != null:
		var existing_tween = bg_player.get_meta("active_volume_tween")
		if is_instance_valid(existing_tween) and existing_tween.is_running():
			existing_tween.kill()
		bg_player.remove_meta("active_volume_tween") # Clean meta

	if is_muted:
		bg_player.volume_db = MUSIC_MUTED_VOLUME_DB
		# We don't stop the stream, just silence it, so it can resume if unmuted.
		# If bg_player was playing, it continues playing silently.
	else:
		# Unmuting
		if bg_player.stream != null: # If there's a track loaded
			bg_player.play() # Ensure it's playing (might have been stopped or never started if muted from beginning)
			_start_volume_tween(bg_player, MUSIC_TARGET_VOLUME_DB, MUSIC_FADE_DURATION)
		else:
			# No stream loaded, nothing to unmute to. Volume remains at muted.
			bg_player.volume_db = MUSIC_MUTED_VOLUME_DB


func play_sfx(): # Renamed to avoid conflict if you make it a general sfx player
	if is_instance_valid(sfx_player) and not is_muted: # Check mute for sfx too
		sfx_player.play()
