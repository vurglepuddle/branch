extends Node2D # audio.gd

@export var beep_sound: AudioStream = preload("res://audio/beep_sound.wav")
@export var difficulty_music: Dictionary = {
	"baby": "res://audio/opening.mp3",
	"intern": "res://audio/opening.mp3",
	"profi": "res://audio/opening.mp3",
	"master": "res://audio/opening.mp3",
	"expert": "res://audio/opening.mp3",
	"torrero": "res://audio/BWV784 Courante.mp3"
}
var sfx_player: AudioStreamPlayer
var bg_player: AudioStreamPlayer
var is_muted: bool = false
var all_audio_players: Array = []
var active_tweens: Dictionary = {}

func _ready():
	setup_audio()

func setup_audio():
	# Create the sound effect player
	sfx_player = AudioStreamPlayer.new()
	if beep_sound:
		sfx_player.stream = beep_sound
	add_child(sfx_player)
	all_audio_players.append(sfx_player)

	# Create the background music player
	bg_player = AudioStreamPlayer.new()
	add_child(bg_player)
	all_audio_players.append(bg_player)

func play_bg_music(stream: AudioStream):
	if stream:
		if stream is AudioStreamOggVorbis or stream is AudioStreamMP3:
			stream.loop = true  # Enable looping for supported stream types
		bg_player.stream = stream
		bg_player.volume_db = -40  # Start at low volume for fade-in
		bg_player.play()
		tween_volume(-10, 3)  # Fade in to the desired volume over 3 seconds
		#print("Background music started with fade-in and set to loop.")

func _on_music_finished():
	tween_volume(-40, 1, Callable(self, "_restart_music"))
	print("Music finished, fading out...")

func _restart_music():
	bg_player.volume_db = -80  # Reset volume for fade-in
	bg_player.play()
	tween_volume(-10, 3)  # Fade back in to the desired volume
	print("Music restarted with fade-in.")

func stop_bg_music():
	if bg_player:
		tween_volume(-40, 2, Callable(bg_player, "stop"))  # Fade out before stopping
		print("Background music fading out and stopping.")

func play_sfx():
	if sfx_player:
		sfx_player.play()
	else:
		print("SFX Player not initialized!")

func toggle_mute():
	is_muted = !is_muted  # Toggle the mute state

	# Stop all active tweens and adjust volumes immediately
	for player in all_audio_players:
		if player in active_tweens and active_tweens[player] != null:
			active_tweens[player].stop()  # Stop the active tween
			active_tweens[player] = null

		if is_muted:
			player.volume_db = -80  # Set to mute volume
		else:
			if player == sfx_player:
				player.volume_db = 0  # Restore SFX volume
			else:
				# Fade in background music when unmuting
				tween_volume(-10, 1)  # Adjust to desired fade duration

	print("Muted:", is_muted)

#func tween_volume(target_volume: float, duration: float, callback: Callable = Callable()):
	#if bg_player in active_tweens and active_tweens[bg_player] != null:
		#active_tweens[bg_player].stop()
		#active_tweens[bg_player].queue_free()
		#active_tweens[bg_player] = null
#
	#var tween = create_tween()
	#active_tweens[bg_player] = tween
#
	#tween.tween_property(bg_player, "volume_db", target_volume, duration)
	#if callback.is_valid():
		#tween.connect("finished", callback)
	##print("Tween created for volume: ", target_volume, ", duration: ", duration)


func tween_volume(target_volume, duration, callback = null):
	# If muted, skip tween and set volume directly
	if is_muted:
		bg_player.volume_db = -80  # Force mute volume
		return

	# Create or reuse a tween for the player
	if bg_player not in active_tweens or active_tweens[bg_player] == null:
		active_tweens[bg_player] = create_tween()
	else:
		# Stop any active tween for this player
		active_tweens[bg_player].stop()

	var tween = active_tweens[bg_player]
	tween.tween_property(bg_player, "volume_db", target_volume, duration)

	# Call the callback after the tween finishes, if provided
	if callback:
		tween.connect("finished", callback)
		
func load_and_play_music_by_difficulty(difficulty: String):
	if difficulty_music.has(difficulty):
		var music_path = difficulty_music[difficulty]
		var music_stream = load(music_path)  # Load the file into an AudioStream
		if music_stream:
			play_bg_music(music_stream)
		else:
			print("Error: Failed to load music from:", music_path)
	else:
		print("Error: No music found for difficulty:", difficulty)
