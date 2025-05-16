

#func _on_branch_clicked(x: int, y: int):
	## Existing rotation logic
	#clicked_branch.cycle_rotation()
	#
	## Simplified validation
	#reset_connection_flags()
	#source_tile.propagate_connection(grid_width, grid_height, branches)
	#update_tile_states()
#
#func reset_connection_flags():
	#for row in branches:
		#for branch in row:
			#branch.connected_to_source = false
#
#func update_tile_states():
	#for row in branches:
		#for branch in row:
			#branch.set_state("alive" if branch.connected_to_source else "dead")







	# Load music for the selected difficulty dynamically
	#if difficulty_music.has(difficulty):
		#bg_music = load(difficulty_music[difficulty])  # Use `load()` for dynamic paths
	#else:
		#print("Error: No music path found for difficulty '%s'" % difficulty)



#func propagate_connection(grid_width: int, grid_height: int, branches: Array):
	#if state != "alive" or not connected_to_source:
		#return
#
	#var directions = [[0, -1], [1, 0], [0, 1], [-1, 0]]  # UP, RIGHT, DOWN, LEFT
	#for i in range(4):
		#var dx = directions[i][0]
		#var dy = directions[i][1]
		#var neighbor_x = grid_x + dx
		#var neighbor_y = grid_y + dy
#
		## Bounds check
		#if neighbor_x < 0 or neighbor_x >= grid_width or neighbor_y < 0 or neighbor_y >= grid_height:
			#continue
#
		#var neighbor = branches[neighbor_x][neighbor_y]
#
		## Check for a valid connection
		#if get_connections()[i] == 1 and neighbor.get_connections()[(i + 2) % 4] == 1:
			#if neighbor.connected_to_source == false:  # Only propagate once
				#neighbor.connected_to_source = true
				#neighbor.set_state("alive")  # Ensure visual state matches
				#neighbor.propagate_connection(grid_width, grid_height, branches)
				

#setup_audio()  # Setup audio nodes

#func setup_audio():
	## Create the sound effect player
	#sfx_player = AudioStreamPlayer.new()
	#if beep_sound:
		#sfx_player.stream = beep_sound
		#print("Beep sound loaded successfully.")
	#else:
		#print("Beep sound is not set! Please check beep_sound assignment.")
	#add_child(sfx_player)
	#all_audio_players.append(sfx_player)  # Add to audio player list
#
	## Create the background music player
	#bg_player = AudioStreamPlayer.new()
	#if bg_music:
		#bg_player.stream = bg_music
		#print("Background music loaded successfully for difficulty level.")
	#else:
		#print("Background music is not set! Please check bg_music assignment.")
	#bg_player.volume_db = -10  # Set to 50% loudness
	#add_child(bg_player)
	#all_audio_players.append(bg_player)  # Add to audio player list
#
	## Start the background music with a fade-in
	#play_bg_music()
#
#func play_bg_music():
	#if bg_player:
		#bg_player.volume_db = -40  # Start silent
		#bg_player.play()
		#tween_volume(-10, 3)  # Fade in to 50% loudness over 3 seconds
#
#func stop_bg_music():
	#if bg_player:
		#tween_volume(-40, 2, Callable(bg_player, "stop"))  # Fade out to silent over 2 seconds
#
#func tween_volume(target_volume, duration, callback = null):
	## If muted, ensure the target volume is always -80 dB
	#if is_muted:
		#target_volume = -80
#
	## Create or reuse tween for the player
	#if bg_player not in active_tweens or active_tweens[bg_player] == null:
		#active_tweens[bg_player] = create_tween()
#
	#var tween = active_tweens[bg_player]
	#tween.tween_property(bg_player, "volume_db", target_volume, duration)
#
	## Call the callback after the tween finishes, if provided
	#if callback:
		#tween.connect("finished", callback)
#
#func toggle_mute():
	#is_muted = !is_muted  # Toggle the mute state
#
	## Adjust volume for all audio players
	#for player in all_audio_players:
		## Stop any active tween affecting this player
		#if player in active_tweens and active_tweens[player] != null:
			#active_tweens[player].stop()  # Stop the tween
			#active_tweens[player] = null  # Remove from active tweens
#
		#if is_muted:
			## Mute the player immediately
			#player.volume_db = -80
		#else:
			#if player == sfx_player:
				## Restore SFX volume immediately
				#player.volume_db = 0
			#else:
				## Always fade in background music
				#var target_volume = -10  # Default unmuted volume
				#var duration = 1.0  # Fade-in duration
				#tween_volume(target_volume, duration)
#
	#print("Muted:", is_muted)
