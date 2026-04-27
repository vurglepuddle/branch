extends Node2D # this is grid.gd #

const BranchType = preload("res://scripts/core/branch_types.gd").BranchType
const PuzzleGenerator = preload("res://scripts/core/puzzle_generator.gd")
var generator = PuzzleGenerator.new()
# Reference to the Branch scene
@export var BranchScene: PackedScene
#@onready var audio_manager: Node = $AudioManager

var level_won_waiting_for_exit_input: bool = false
var is_level_complete_animation_playing: bool = false # Prevent re-triggering

# The size of the grid
var difficulty_levels = {
	# "size": [width, height]
	# "prim_initial_density_factor": Target density for Prim's algorithm (0.0 to 1.0)
	# "prim_min_tiles": Absolute minimum tiles for Prim's target, useful for small grids
	# "final_target_density_factor": Desired density AFTER pruning (0.0 to 1.0)
	# "final_density_variation_factor": +/- variation on final_target_density (0.0 to 1.0 of the target)
	"baby":   {"size": [6, 17], "prim_initial_density_factor": 0.1, "prim_min_tiles": 4, "final_target_density_factor": 0.1, "final_density_variation_factor": 0.1, "max_gen_attempts": 5},
	"intern": {"size": [6, 17], "prim_initial_density_factor": 0.3, "prim_min_tiles": 8, "final_target_density_factor": 0.3, "final_density_variation_factor": 0.1, "max_gen_attempts": 10},
	"profi":  {"size": [6, 17], "prim_initial_density_factor": 0.5, "prim_min_tiles": 20, "final_target_density_factor": 0.5, "final_density_variation_factor": 0.1, "max_gen_attempts": 10},
	"master": {"size": [6, 17], "prim_initial_density_factor": 0.7, "prim_min_tiles": 38, "final_target_density_factor": 0.7, "final_density_variation_factor": 0.1, "max_gen_attempts": 10},
	"expert": {"size": [6, 17], "prim_initial_density_factor": 1.0, "prim_min_tiles": 85, "final_target_density_factor": 0.75, "final_density_variation_factor": 0.05, "max_gen_attempts": 15},
	"torrero":{"size": [6, 17], "prim_initial_density_factor": 1.0, "prim_min_tiles": 85, "final_target_density_factor": 0.86, "final_density_variation_factor": 0.05, "max_gen_attempts": 15}
}

var difficulty_key_map = {
	KEY_1: "baby",
	KEY_2: "intern",
	KEY_3: "profi",
	KEY_4: "master",
	KEY_5: "expert",
	KEY_6: "torrero"
}

var current_difficulty_str: String 
var is_toroidal_grid: bool = false # Flag for toroidal mode

# The size of the grid
var grid_width  # Horizontal grid size
var grid_height  # Vertical grid size
var branches = []
var source_tile = null  # Holds a reference to the source tile
# Backgrounds
var bg1
var all_connected = false # class-level variable for win condition

var _game_hud: CanvasLayer

func _ready():
	randomize()
	_game_hud = preload("res://scenes/GameHUD.tscn").instantiate()
	add_child(_game_hud)
	_game_hud.give_up_requested.connect(_on_give_up_requested)
	if GlobalSettings: # Check if the Autoload script exists
		current_difficulty_str = GlobalSettings.current_difficulty
		print("Grid: Loaded difficulty from GlobalSettings: " + current_difficulty_str)
	else:
		# Fallback if GlobalSettings is not found (e.g., running grid.tscn directly for testing)
		current_difficulty_str = "torrero" # Your previous default value
		printerr("Grid: GlobalSettings Autoload not found! Using default difficulty: " + current_difficulty_str)
	load_level_for_current_difficulty()
	if FadeOverlay:
		FadeOverlay.fade_rect.color = Color.BLACK
		FadeOverlay.fade_rect.modulate.a = 1.0 
		FadeOverlay.visible = true
		FadeOverlay.start_fade_in(0.5)
		print("Grid: Fade-in initiated.")
	else:
		printerr("Grid: FadeOverlay Autoload not found! Scene will appear abruptly.")

func load_level_for_current_difficulty():
	print("--- load_level_for_current_difficulty START for: %s ---" % self.current_difficulty_str)

	if not difficulty_levels.has(self.current_difficulty_str):
		printerr("Error: Difficulty level '%s' not found!" % self.current_difficulty_str)
		var difficulty_keys = difficulty_levels.keys()
		if difficulty_keys.size() > 0:
			self.current_difficulty_str = difficulty_keys[0]
			print("Fell back to difficulty: %s" % self.current_difficulty_str)
		else:
			printerr("FATAL: No difficulty levels defined!")
			return

	var current_difficulty_settings = difficulty_levels[self.current_difficulty_str]
	
	grid_width = current_difficulty_settings.size[0]
	grid_height = current_difficulty_settings.size[1]
	self.is_toroidal_grid = (self.current_difficulty_str == "torrero")
	print("Grid settings: WxH=%sx%s, Toroidal=%s" % [grid_width, grid_height, self.is_toroidal_grid])
	
	var prim_density_factor = current_difficulty_settings.prim_initial_density_factor
	var prim_min_tiles = current_difficulty_settings.prim_min_tiles
	var final_target_density = current_difficulty_settings.final_target_density_factor
	var final_variation = current_difficulty_settings.final_density_variation_factor
	var max_gen_attempts_for_level = current_difficulty_settings.max_gen_attempts

	print("Clearing old branches...")
	var children_to_remove = []
	for child in get_children():
		if child is BranchNode: # Assumes branch.gd has class_name BranchNode
			children_to_remove.append(child)
			
	if children_to_remove.size() > 0:
		print("Found %s BranchNode children to remove." % children_to_remove.size())
	else:
		print("No existing BranchNode children found to remove (this is normal on first load).")
		
	for child_to_remove in children_to_remove:
		if is_instance_valid(child_to_remove):
			child_to_remove.queue_free()
	
	branches.clear() # Clear the internal array
	source_tile = null # Reset source tile
	self.all_connected = false
	is_level_complete_animation_playing = false
	print("Old branches cleared and state reset.")

	var valid_cells: Dictionary = DifficultyLayouts.get_valid_cells(self.current_difficulty_str)
	print("Calling init_branches...")
	init_branches(grid_width, grid_height, BranchScene,
				  prim_density_factor, prim_min_tiles,
				  final_target_density, final_variation, self.is_toroidal_grid, max_gen_attempts_for_level,
				  valid_cells)
	print("init_branches call finished. Current branch count in array: %s" % branches.size())
	
	var actual_branch_children_count = 0
	for child in get_children():
		if child is BranchNode:
			actual_branch_children_count += 1
	print("Actual BranchNode children in scene tree after init_branches: %s" % actual_branch_children_count)

	if actual_branch_children_count > 0:
		print("Calling center_grid...")
		center_grid()
		print("center_grid call finished.")
	else:
		print("Skipping center_grid as no branches were added to the scene tree.")

	if AudioManager: # Ensure AudioManager is capitalized correctly if that's its autoload name
		AudioManager.play_difficulty_music(self.current_difficulty_str)
		print("AudioManager instructed to play music for %s" % self.current_difficulty_str)
	else:
		printerr("AudioManager not found when trying to play music in load_level.")
		
	print("--- load_level_for_current_difficulty END for: %s ---" % self.current_difficulty_str)



func _input(event: InputEvent):
	if level_won_waiting_for_exit_input:
			var should_return_to_menu = false
			if event is InputEventKey and event.is_pressed() and not event.is_echo():
				print("Grid: Key pressed after win. Returning to menu.")
				should_return_to_menu = true
			elif event is InputEventMouseButton and event.is_pressed():
				print("Grid: Mouse button pressed after win. Returning to menu.")
				should_return_to_menu = true
			elif event is InputEventScreenTouch and event.is_pressed(): # For touch devices
				print("Grid: Screen touched after win. Returning to menu.")
				should_return_to_menu = true

			if should_return_to_menu:
				# Consume the input BEFORE changing the scene
				get_viewport().set_input_as_handled() 
				_return_to_main_menu()
				# No 'return' needed here if _return_to_main_menu changes scene, 
				# as this node will likely be gone before further _input processing.
				# However, to be absolutely safe and prevent further code in _input from running for this event:
				return 
	
	if is_level_complete_animation_playing:
		return

	var difficulty_changed_by_hotkey = false
	var new_selected_difficulty = ""

	if event is InputEventKey and event.is_pressed() and not event.is_echo():
		var pressed_key = event.keycode 
		if difficulty_key_map.has(pressed_key):
			new_selected_difficulty = difficulty_key_map[pressed_key]
			if new_selected_difficulty != current_difficulty_str:
				current_difficulty_str = new_selected_difficulty
				difficulty_changed_by_hotkey = true
				print("Grid: Difficulty changed by hotkey to: " + current_difficulty_str)
				get_viewport().set_input_as_handled() 

	if difficulty_changed_by_hotkey:
		level_won_waiting_for_exit_input = false # Reset if they change difficulty (reloads level)
		load_level_for_current_difficulty() 
		if AudioManager: 
			AudioManager.play_difficulty_music(current_difficulty_str)
		return branches

func center_grid():
	var screen_size = get_viewport_rect().size
	var grid_size = Vector2(grid_width * 84, grid_height * 68)
	position = (screen_size - grid_size) / 2

	var bg_texture1 = preload("res://sprites/branches/grid2.png")
	if bg1 and is_instance_valid(bg1): # Remove old bg1 if it exists
				bg1.queue_free()

	bg1 = Sprite2D.new()
	bg1.texture = bg_texture1
	bg1.centered = false # Keep top-left as origin
	bg1.z_index = -8
	add_child(bg1)
	#bg1.position = Vector2(0, 0)


func _process(_delta):
	#if Input.is_action_just_pressed("ui_mute"):  # "ui_mute" in Input Map
		#audio_manager.toggle_global_music_mute()
		#get_viewport().set_input_as_handled()
		
	if Input.is_action_just_pressed("ui_accepted"):
		print("Test triggered for difficulty: %s" % self.current_difficulty_str)
		#run_batch_generation_test(self.current_difficulty_str, 200)

func init_branches(g_width: int, g_height: int, b_scene: PackedScene,
				   initial_prim_density: float, min_prim_abs_tiles: int,
				   target_final_density: float, final_density_variation: float,
				   p_is_toroidal: bool, p_max_generation_attempts: int,
				   p_valid_cells: Dictionary = {}) -> void:

	var puzzle_data = null
	var actual_final_active_tile_count = 0
	var num_total_cells_on_grid: int = p_valid_cells.size() if not p_valid_cells.is_empty() else g_width * g_height

	# Calculate the desired *range* for the final number of active tiles
	var base_desired_final_tiles = floor(num_total_cells_on_grid * target_final_density)
	var variation_amount = floor(base_desired_final_tiles * final_density_variation)
	
	var min_acceptable_final_tiles = max(1, base_desired_final_tiles - variation_amount)
	var max_acceptable_final_tiles = base_desired_final_tiles + variation_amount 
	min_acceptable_final_tiles = min(min_acceptable_final_tiles, num_total_cells_on_grid) 
	max_acceptable_final_tiles = min(max_acceptable_final_tiles, num_total_cells_on_grid) 
	min_acceptable_final_tiles = min(min_acceptable_final_tiles, max_acceptable_final_tiles)

	print("Targeting final active tiles: approx %s (min: %s, max: %s)" % [base_desired_final_tiles, min_acceptable_final_tiles, max_acceptable_final_tiles])
	# Removed the next print line as it's now better placed inside the loop or before calling the generator.

	var attempts = 0
	#var max_generation_attempts = 35 

	while attempts < p_max_generation_attempts:
		attempts += 1
		print("Generation attempt #%s (Prim's target: density_factor=%s, min_tiles=%s)..." % [attempts, initial_prim_density, min_prim_abs_tiles])
		puzzle_data = generator.generate_solvable_puzzle(g_width, g_height, b_scene,
														 initial_prim_density, min_prim_abs_tiles,
														 p_is_toroidal, p_valid_cells)
		
		actual_final_active_tile_count = 0 
		if puzzle_data and puzzle_data.has("branches"):
			for x_col in puzzle_data.branches:
				for branch_node in x_col:
					if branch_node and branch_node.branch_type != BranchType.EMPTY:
						actual_final_active_tile_count += 1
		else:
			printerr("Puzzle generation failed to return valid branches structure on attempt %s." % attempts)
			if attempts < p_max_generation_attempts:
				continue 
			else:
				break 

		print("Generated puzzle with %s active tiles." % actual_final_active_tile_count)

		if actual_final_active_tile_count >= min_acceptable_final_tiles:
			print("Acceptable density achieved.")
			break 
		
		if attempts < p_max_generation_attempts:
			print("Too sparse (min desired: %s). Retrying..." % min_acceptable_final_tiles)

	if actual_final_active_tile_count < min_acceptable_final_tiles:
		print("Warning: Could not achieve desired minimum density (%s) after %s attempts. Proceeding with %s active tiles." % [min_acceptable_final_tiles, p_max_generation_attempts, actual_final_active_tile_count])

	if not puzzle_data or not puzzle_data.has("branches") or not puzzle_data.has("source_x"):
		printerr("FATAL: Puzzle data is invalid after all generation attempts!")
		var dummy_branch = b_scene.instantiate()
		dummy_branch.branch_type = BranchType.TERMINAL
		dummy_branch.connections = [1,0,0,0]; dummy_branch.rotation_index = 0
		dummy_branch.state = "alive"; dummy_branch.connected_to_source = true
		dummy_branch.update_texture()
		
		# Clear previous children before adding dummy (important if this is a retry scenario within _ready)
		var children_to_remove_fallback = []
		for child in get_children():
			if child.name == "AudioManager" or child.name == "bg1": # Keep essentials
				continue
			if child is BranchNode: # USE class_name CHECK
				children_to_remove_fallback.append(child)
		for child_to_remove in children_to_remove_fallback:
			child_to_remove.queue_free()

		branches = [[dummy_branch]]
		# Update global grid_width and grid_height if using this fallback and they are used elsewhere
		# self.grid_width = 1 
		# self.grid_height = 1
		source_tile = branches[0][0]
		dummy_branch.position = Vector2(0 * 84 + 42, 0 * 68 + 34)
		add_child(dummy_branch)
		print("Fallback: Created a 1x1 dummy puzzle.")
		# defer_propagation(source_tile) # Might not be needed or could error if grid size changed drastically
		return 

	branches = puzzle_data.branches
	var source_x = puzzle_data.source_x
	var source_y = puzzle_data.source_y

	if source_x < 0 or source_x >= g_width or source_y < 0 or source_y >= g_height or \
	   branches.size() <= source_x or branches[source_x].size() <= source_y or \
	   branches[source_x][source_y] == null:
		printerr("Invalid source tile coordinates (%s, %s) or source tile is null!" % [source_x, source_y])
		return
		
	source_tile = branches[source_x][source_y]
	print("Source Tile is at: (", source_x, ", ", source_y, ")")
	
	# Clear previous children (Branches) before adding new ones
	var children_to_remove_init = []
	for child in get_children():
		if child.name == "AudioManager" or child.name == "bg1": # Keep essentials
			continue
		if child is BranchNode: # USE class_name CHECK
			children_to_remove_init.append(child)
	for child_to_remove in children_to_remove_init:
		child_to_remove.queue_free()

	for x in range(g_width):
		for y in range(g_height):
			if x >= branches.size() or y >= branches[x].size(): 
				printerr("Attempting to access branches[%s][%s] out of bounds during scene setup." % [x,y])
				continue

			var branch_instance = branches[x][y]
			if branch_instance == null:
				printerr("Found null branch instance at %s, %s during scene setup" % [x,y])
				branch_instance = b_scene.instantiate()
				branch_instance.branch_type = BranchType.EMPTY
				branch_instance.connections = [0,0,0,0]; branch_instance.state = "dead"
				branch_instance.update_texture()
				branches[x][y] = branch_instance
				
			branch_instance.position = Vector2(x * 84 + 42, y * 68 + 34)
			
			# Ensure signals are not connected multiple times
			if not branch_instance.is_connected("branch_clicked", Callable(self, "_on_branch_clicked")):
				branch_instance.connect("branch_clicked", Callable(self, "_on_branch_clicked"))

			if not branch_instance.is_connected("branch_right_clicked", Callable(self, "_on_branch_right_clicked")):
				branch_instance.connect("branch_right_clicked", Callable(self, "_on_branch_right_clicked"))
			
			add_child(branch_instance) 
	
	# Make sure source_tile is valid before calling defer_propagation
	if source_tile and is_instance_valid(source_tile):
		defer_propagation(source_tile, p_is_toroidal)
	else:
		printerr("Source tile is null or invalid before defer_propagation.")


func _on_branch_clicked(x: int, y: int):
	if all_connected or is_level_complete_animation_playing or level_won_waiting_for_exit_input:
		return
	if is_instance_valid(_game_hud) and _game_hud.panel_is_open:
		return
	# Play the beep sound
	if AudioManager:
		AudioManager.play_beep_pitched(y, grid_height)

	var clicked_branch = branches[x][y]

	clicked_branch.cycle_rotation()
	
	var flags_reset_count = 0
	for r_idx in range(branches.size()): # Iterate by index for clarity
		for c_idx in range(branches[r_idx].size()):
			var bn = branches[r_idx][c_idx]
			if bn.connected_to_source == true: # Only print if it was true
				# print("GRID: Resetting flag for (%s,%s) from %s to false" % [bn.grid_x, bn.grid_y, bn.connected_to_source])
				flags_reset_count +=1
			bn.connected_to_source = false
			
	if source_tile: # Ensure source_tile is valid
		source_tile.connected_to_source = true
		source_tile.propagate_connection(grid_width, grid_height, branches, self.is_toroidal_grid)

	var turned_dead_count = 0
	var kept_alive_count = 0
	for r_idx in range(branches.size()):
		for c_idx in range(branches[r_idx].size()):
			var bn = branches[r_idx][c_idx]
			if bn.branch_type != BranchType.EMPTY: # Only consider non-empty tiles
				if bn.state == "alive" and not bn.connected_to_source:
					bn.set_state("dead")
					turned_dead_count +=1
				elif bn.state == "dead" and bn.connected_to_source: # Should not happen if logic is correct
					bn.set_state("alive") # This might be an overcorrection, but highlights an issue
				elif bn.state == "alive" and bn.connected_to_source:
					kept_alive_count +=1
	for row in branches:
		for branch_node_in_row in row: # Renamed 'branch' to avoid conflict
			if branch_node_in_row.state == "alive" and not branch_node_in_row.connected_to_source:
				branch_node_in_row.set_state("dead")

	source_tile.connected_to_source = true
	source_tile.propagate_connection(grid_width, grid_height, branches, self.is_toroidal_grid)

	for row in branches:
		for branch in row:
			if branch.state == "alive" and not branch.connected_to_source:
				branch.set_state("dead")
				
	# Step 5: Check if the puzzle is solved
	check_win_condition()

func _on_branch_right_clicked(x: int, y: int):
	var clicked_branch = branches[x][y]
	print("--- Debug Info for Tile at (", x, ", ", y, ") ---")
	print("Connections (UP, RIGHT, DOWN, LEFT): ", clicked_branch.get_connections())
	print("Rotation Index: ", clicked_branch.rotation_index)
	print("State: ", clicked_branch.state)
	print("Connected to Source: ", clicked_branch.connected_to_source)
	print("Is Toroidal Grid: ", self.is_toroidal_grid)
	print("--------------------------------------------")


func defer_propagation(source_tile, p_is_toroidal: bool):
	call_deferred("run_propagation", source_tile, p_is_toroidal)

func run_propagation(source_tile, p_is_toroidal: bool):
	source_tile.propagate_connection(grid_width, grid_height, branches, p_is_toroidal)
	
func validate_initial_connections():
	# Start propagation from the source tile
	if source_tile and is_instance_valid(source_tile): # Added validity check
		source_tile.propagate_connection(grid_width, grid_height, branches, self.is_toroidal_grid)
	#source_tile.propagate_connection(grid_width, grid_height, branches, self.is_toroidal_grid)
	
	# Force cleanup for disconnected tiles
	for row in branches:
		for branch in row:
			if not branch.connected_to_source and branch.state == "alive":
				branch.set_state("dead")

func check_win_condition():
	# Assume all are connected initially, then prove otherwise.
	self.all_connected = true # Use 'self' to be explicit or just 'all_connected'
	
	for x_idx in range(grid_width):
		for y_idx in range(grid_height):
			var branch = branches[x_idx][y_idx]
			# Skip empty tiles
			if branch.branch_type == BranchType.EMPTY:
				continue
				
			# If any non-empty tile is dead, puzzle is not solved
			if branch.state != "alive":
				self.all_connected = false # Set the class-level variable
				break # Exit the inner loop
		
		if not self.all_connected: # Check class-level variable
			break # Exit the outer loop
	
	if self.all_connected: # Check class-level variable
		is_level_complete_animation_playing = true # Set flag
		print("🎉 CONGRATULATIONS! 🎉")
		call_deferred("start_leaf_spawn_sequence")
		call_deferred("start_blossom_sequence")

func start_blossom_sequence():
	var alive_terminal_branches = []
	for x in range(grid_width):
		for y in range(grid_height):
			var branch = branches[x][y]
			if branch.branch_type == BranchType.TERMINAL and branch.state == "alive":
				alive_terminal_branches.append(branch)

	if alive_terminal_branches.size() == 0:
		print("No alive terminal branches found to animate.")
		# Proceed to next level or level complete screen logic here
		# For example: show_level_complete_screen_after_delay(2.0)
		is_level_complete_animation_playing = false # Reset flag
		return
	# Shuffle the list to make the order random beyond the first few
	alive_terminal_branches.shuffle()

	var overall_animation_delay_accumulator: float = 0.0
	var max_initial_delay: float = 4.0 # Max N seconds (was 5, reduced to make total time reasonable)
	var max_subsequent_delay: float = 1.5 # Max Y seconds (was 3, reduced)

	for i in range(alive_terminal_branches.size()):
		var branch_to_animate: BranchNode = alive_terminal_branches[i]
		var current_delay: float = 0.0

		if i == 0: # First terminal branch
			current_delay = randf_range(0.1, max_initial_delay) # Random delay between 0.1 and N
		elif i == 1: # Second terminal branch

			current_delay = randf_range(0.05, max_subsequent_delay) # Random delay between 0.05 and Y
																  # (0.05 to avoid exact same time)
		else: # Subsequent branches
			# Shorter, more rapid, slightly overlapping delays
			current_delay = randf_range(0.05, 0.5) # e.g., 0.05 to 0.5 seconds

		var actual_start_delay = overall_animation_delay_accumulator + current_delay
		
		var individual_timer = Timer.new()
		individual_timer.wait_time = actual_start_delay
		individual_timer.one_shot = true

		individual_timer.connect("timeout", Callable(self, "_play_single_blossom").bind(branch_to_animate, individual_timer))
		add_child(individual_timer) # Timer needs to be in the scene tree to process
		individual_timer.start()
		
		# Accumulate delay for the *start* of the next potential animation trigger
		# This creates a cascading effect.
		overall_animation_delay_accumulator += current_delay 
		# If you want them more overlapped, make overall_animation_delay_accumulator increase by less,
		# e.g., overall_animation_delay_accumulator += current_delay * 0.3

	var cleanup_delay = overall_animation_delay_accumulator + 2.0 # 2 seconds for last animation to play out
	var final_timer = Timer.new()
	final_timer.wait_time = cleanup_delay
	final_timer.one_shot = true
	final_timer.connect("timeout", Callable(self, "_finish_level_complete_sequence").bind(final_timer))
	add_child(final_timer)
	final_timer.start()
	#print("Blossom sequence initiated. Total estimated duration: ~%s seconds" % cleanup_delay)

func _play_single_blossom(branch: BranchNode, timer_node: Timer):
	if is_instance_valid(branch):
		#print("Playing blossom for branch at: (%s, %s)" % [branch.grid_x, branch.grid_y])
		branch.play_terminal_blossom() # Call the animation player on the branch
	if is_instance_valid(timer_node):
		timer_node.queue_free() # Clean up the timer

func _finish_level_complete_sequence(timer_node: Timer):
	print("Level complete animation sequence finished.")
	is_level_complete_animation_playing = false # Reset this flag as animations are done
	
	level_won_waiting_for_exit_input = true
	print("Grid: Now waiting for input to return to menu.")

	if is_instance_valid(timer_node):
		timer_node.queue_free()

func start_leaf_spawn_sequence():
	var eligible_leaf_branches = []
	for x in range(grid_width):
		for y in range(grid_height):
			var branch: BranchNode = branches[x][y]
			if (branch.branch_type == BranchType.STRAIGHT or branch.branch_type == BranchType.THREE) \
			   and branch.state == "alive":
				eligible_leaf_branches.append(branch)

	if eligible_leaf_branches.is_empty():
		print("No eligible branches found for leaf spawning.")
		return

	eligible_leaf_branches.shuffle()

	var leaf_delay_accumulator: float = 0.5
	var base_leaf_delay: float = 0.15 # Approx 4 frames at 60fps (1/60 * 4)
									 # Or 0.05 for 3 frames at 60fps

	for i in range(eligible_leaf_branches.size()):
		var branch_to_leaf: BranchNode = eligible_leaf_branches[i]
		
		# Stagger the leaf spawning slightly
		var current_leaf_spawn_delay = leaf_delay_accumulator + randf_range(base_leaf_delay * 0.5, base_leaf_delay * 1.5)

		var leaf_timer = Timer.new()
		leaf_timer.wait_time = current_leaf_spawn_delay
		leaf_timer.one_shot = true
		leaf_timer.connect("timeout", Callable(self, "_spawn_single_leaf").bind(branch_to_leaf, leaf_timer))
		add_child(leaf_timer)
		leaf_timer.start()

		# Increment accumulator for next leaf, ensuring some cascade
		leaf_delay_accumulator += base_leaf_delay * randf_range(0.2, 0.5) # Smaller increment for more overlap
		
		# Cap total leaf sequence duration roughly if needed, though shuffling helps
		if leaf_delay_accumulator > 5.0: # e.g., don't let leaf sequence drag on too long
			pass # Or break, or stop incrementing leaf_delay_accumulator

	print("Leaf spawn sequence initiated for %s branches." % eligible_leaf_branches.size())


func _spawn_single_leaf(branch: BranchNode, timer_node: Timer):
	if is_instance_valid(branch):
		branch.spawn_leaf_animation() # Call the method on the BranchNode
	if is_instance_valid(timer_node):
		timer_node.queue_free()


func _on_give_up_requested() -> void:
	if not GlobalSettings.give_up_animation:
		_return_to_main_menu()
		return
	_game_hud.hide_panel()
	_game_hud.locked = true
	is_level_complete_animation_playing = true
	level_won_waiting_for_exit_input = false
	await get_tree().create_timer(0.28).timeout  # wait for panel to slide down
	_run_solve_animation()

func _get_solve_order() -> Array:
	var result: Array = []
	var visited: Dictionary = {}
	var queue: Array = []
	var src := Vector2i(-1, -1)
	for x in range(grid_width):
		for y in range(grid_height):
			if branches[x][y] == source_tile:
				src = Vector2i(x, y)
				break
		if src.x >= 0:
			break
	if src.x < 0:
		return result
	queue.append(src)
	visited[src] = true
	while not queue.is_empty():
		var pos: Vector2i = queue.pop_front()
		if branches[pos.x][pos.y].branch_type != BranchType.EMPTY:
			result.append(pos)
		for dir in [Vector2i(0,-1), Vector2i(1,0), Vector2i(0,1), Vector2i(-1,0)]:
			var nx: int = pos.x + dir.x
			var ny: int = pos.y + dir.y
			if is_toroidal_grid:
				nx = ((nx % grid_width) + grid_width) % grid_width
				ny = ((ny % grid_height) + grid_height) % grid_height
			elif nx < 0 or nx >= grid_width or ny < 0 or ny >= grid_height:
				continue
			var next := Vector2i(nx, ny)
			if not visited.has(next) and branches[nx][ny].branch_type != BranchType.EMPTY:
				visited[next] = true
				queue.append(next)
	return result

func _propagate_after_solve() -> void:
	for row in branches:
		for b in row:
			b.connected_to_source = false
	source_tile.connected_to_source = true
	source_tile.propagate_connection(grid_width, grid_height, branches, is_toroidal_grid)
	for row in branches:
		for b in row:
			if b.branch_type != BranchType.EMPTY and b.state == "alive" and not b.connected_to_source:
				b.set_state("dead")

func _run_solve_animation() -> void:
	for pos in _get_solve_order():
		await get_tree().create_timer(0.07).timeout
		branches[pos.x][pos.y].solve_rotation()
		_propagate_after_solve()
		if AudioManager:
			AudioManager.play_beep_pitched(pos.y, grid_height)
	is_level_complete_animation_playing = false
	level_won_waiting_for_exit_input = true
	await get_tree().create_timer(3.0).timeout
	if level_won_waiting_for_exit_input:
		_return_to_main_menu()

func _return_to_main_menu():
	level_won_waiting_for_exit_input = false # Reset the flag

	if AudioManager:
		# AudioManager._load_and_set_music_track_from_stream(null, false, false, 0.1) # Stop music quickly
		pass

	SceneChanger.change_scene_with_fade("res://scenes/main_menu.tscn", 0.2)


#func run_batch_generation_test(difficulty_to_test: String, num_runs: int = 100):
	#if not difficulty_levels.has(difficulty_to_test):
		#printerr("Test Error: Difficulty '%s' not found." % difficulty_to_test)
		#return
		#
	#print("\n--- Starting Batch Generation Test ---")
	#print("Difficulty: %s, Runs: %s" % [difficulty_to_test, num_runs])
	#var current_difficulty_settings = difficulty_levels[difficulty_to_test]
	#
	#var g_width = current_difficulty_settings.size[0]
	#var g_height = current_difficulty_settings.size[1]
	#var b_scene = BranchScene # Assuming BranchScene is loaded and valid
#
	#var prim_density = current_difficulty_settings.prim_initial_density_factor
	#var prim_min = current_difficulty_settings.prim_min_tiles
	#var final_target_density = current_difficulty_settings.final_target_density_factor
	#var final_variation = current_difficulty_settings.final_density_variation_factor
	#
	## DETERMINE if this test is for a toroidal grid
	#var is_toroidal_for_test: bool = (difficulty_to_test == "torrero") # Or however you determine this
#
	## GET max_gen_attempts from difficulty settings (assuming you added it as per Option 1 previously)
	#var max_gen_attempts_per_run: int
	#if current_difficulty_settings.has("max_gen_attempts"):
		#max_gen_attempts_per_run = current_difficulty_settings.max_gen_attempts
	#else:
		#printerr("Test Warning: 'max_gen_attempts' not defined for difficulty '%s'. Defaulting to 35." % difficulty_to_test)
		#max_gen_attempts_per_run = 35 # Fallback, but you should define it
#
	#var num_total_cells = g_width * g_height
	#var base_desired_final = floor(num_total_cells * final_target_density)
	#var variation_abs = floor(base_desired_final * final_variation)
	#var min_acceptable_final = max(1, base_desired_final - variation_abs)
	## Clamp min_acceptable_final: it cannot be more than total cells, and not more than prim_min_tiles (if prim_min_tiles is an absolute floor from Prim's generation)
	#min_acceptable_final = min(min_acceptable_final, num_total_cells)
	## Consider if min_acceptable_final should also be min(min_acceptable_final, prim_min) if prim_min is a hard floor
	## For now, let's assume prim_min is just for the Prim's stage, and final density is the true target.
#
	#var successes = 0
	#var total_attempts_for_successes = 0
	#var failed_to_meet_density_count = 0 # Renamed for clarity
	#var active_tile_counts_successful_runs = [] # Renamed for clarity
#
	#for i in range(num_runs):
		#var current_run_inner_attempts = 0 # Renamed for clarity
		#var achieved_density_this_run = false # Renamed for clarity
		#var last_active_count_this_run = 0
#
		## This inner while loop simulates the loop in your grid.gd's init_branches
		#while current_run_inner_attempts < max_gen_attempts_per_run:
			#current_run_inner_attempts += 1
			#
			## CRITICAL UPDATE: Pass the is_toroidal_for_test flag
			#var puzzle_data = generator.generate_solvable_puzzle(
									#g_width, g_height, b_scene, 
									#prim_density, prim_min,
									#is_toroidal_for_test # Pass the toroidal flag
								#) 
			#
			#var active_count = 0
			#if puzzle_data and puzzle_data.has("branches"):
				#for x_col in puzzle_data.branches:
					#for branch_node in x_col:
						#if branch_node and branch_node.branch_type != BranchType.EMPTY:
							#active_count += 1
			#last_active_count_this_run = active_count
#
			#if active_count >= min_acceptable_final:
				#successes += 1
				#total_attempts_for_successes += current_run_inner_attempts
				#active_tile_counts_successful_runs.append(active_count)
				#achieved_density_this_run = true
				#break # Success for this run (this puzzle generation met criteria)
		#
		#if not achieved_density_this_run:
			#failed_to_meet_density_count += 1
			## Optionally log details of failed runs:
			## print("Run %s/%s FAILED density requirement. Got %s tiles. (Target min: %s, Max attempts: %s)" % [i+1, num_runs, last_active_count_this_run, min_acceptable_final, max_gen_attempts_per_run])
#
	#print("\n--- Batch Test Results ---")
	#print("Difficulty Tested: %s (Toroidal: %s)" % [difficulty_to_test, is_toroidal_for_test])
	#print("Target Min Acceptable Final Tiles: %s" % min_acceptable_final)
	#print("Max Generation Attempts Per Run: %s" % max_gen_attempts_per_run)
	#print("Total Test Runs: %s" % num_runs)
	#print("Successful Generations (met density): %s (%s%%)" % [successes, float(successes)/num_runs * 100.0 if num_runs > 0 else 0.0])
	#print("Failed to Meet Density (within %s attempts each): %s" % [max_gen_attempts_per_run, failed_to_meet_density_count])
	#
	#if successes > 0:
		#print("Average Attempts per Successful Generation: %.2f" % (float(total_attempts_for_successes) / successes))
		#
		#var sum_counts = 0
		#for c_val in active_tile_counts_successful_runs: sum_counts += c_val # Renamed c to c_val
		#print("Average Active Tiles in Successful Runs: %.2f" % (float(sum_counts) / successes))
		#active_tile_counts_successful_runs.sort()
		#print("Min Active Tiles in Successful Runs: %s" % active_tile_counts_successful_runs[0] if active_tile_counts_successful_runs else "N/A")
		#print("Max Active Tiles in Successful Runs: %s" % active_tile_counts_successful_runs[-1] if active_tile_counts_successful_runs else "N/A")
	#print("---------------------------\n")
