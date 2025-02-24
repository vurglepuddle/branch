extends Node2D # this is grid.gd #

const BranchType = preload("res://branch_types.gd").BranchType
const PuzzleGenerator = preload("res://puzzle_generator.gd")
var generator = PuzzleGenerator.new()
 
@onready var audio_manager: Node = $AudioManager

# The size of the grid
var difficulty_levels = {
	"baby": [2, 2],
	"intern": [3, 4],
	"profi": [4, 6],
	"master": [5, 8],
	"expert": [6, 10],
	"torrero": [6, 10]
}

# The size of the grid
var grid_width = 6  # Horizontal grid size
var grid_height = 10  # Vertical grid size
var branches = []
var source_tile = null  # Holds a reference to the source tile
# Backgrounds
var bg1
var bg2

# Reference to the Branch scene
@export var BranchScene: PackedScene

func _ready():
	randomize()  # Initialize the random number generator
	
	# Determine the current difficulty level
	var difficulty = "expert"  # Replace with your dynamic difficulty logic
	print("Loading level: %s." % difficulty)

	# Proceed with other setups
	var grid_size = difficulty_levels[difficulty]
	grid_width = grid_size[0]
	grid_height = grid_size[1]
	
	init_branches(grid_width, grid_height)  # Set up the grid
	center_grid()
	add_backgrounds()  # Add and center background images
	audio_manager.setup_audio()
	audio_manager.load_and_play_music_by_difficulty(difficulty)
	
func add_backgrounds():
	# Load the textures
	var bg_texture1 = preload("res://sprites/branches/grid.png")  # Replace with your exact image path
	var bg_texture2 = preload("res://sprites/branches/bg2.png")   # Replace with your image path

	# Create two Sprite2D nodes for backgrounds
	bg1 = Sprite2D.new()
	bg1.texture = bg_texture1
	bg1.centered = false  # We want manual positioning (top-left as the origin)
	bg1.z_index = -8

	bg2 = Sprite2D.new()
	bg2.texture = bg_texture2
	bg2.centered = true  # This one is fine
	bg2.z_index = -10

	# Add the backgrounds to the root node
	add_child(bg1)
	add_child(bg2)

	# Set positions
	position_backgrounds()

func position_backgrounds():
	# Exact position for bg1
	bg1.position = Vector2(0, 0)  # Replace with your desired coordinates

	# Align bg2 to center
	var viewport_size = get_viewport_rect().size
	bg2.position = Vector2(300, 300)

func _process(_delta):
	# Check for the mute keypress
	if Input.is_action_just_pressed("ui_mute"):  # "ui_mute" in Input Map
		audio_manager.toggle_mute()
	# Reposition the backgrounds on resize
	position_backgrounds()

#func init_branches(grid_width: int, grid_height: int) -> void:
	#var source_x = randi_range(0, grid_width - 1)  # Random X position
	#var source_y = randi_range(0, grid_height - 1)  # Random Y position
	#
	#var branch_types = [BranchType.BEND, BranchType.STRAIGHT, BranchType.THREE, BranchType.TERMINAL, BranchType.EMPTY]
	#var non_empty_branch_types = [BranchType.BEND, BranchType.STRAIGHT, BranchType.THREE, BranchType.TERMINAL]
	#
	#print("Initializing branches with grid size: ", grid_width, "x", grid_height)
	##print("Source tile coordinates: (", source_x, ", ", source_y, ")")
	#
	#for x in range(grid_width):
		#branches.append([])
		#for y in range(grid_height):
			#var branch_instance = BranchScene.instantiate()
			#
			#if x == source_x and y == source_y:
				## Ensure the source tile is not EMPTY
				#if non_empty_branch_types.size() > 0:
					#var random_index = randi() % non_empty_branch_types.size()
					#branch_instance.branch_type = non_empty_branch_types[random_index]
					##print("Assigned to source tile (", x, ", ", y, "): ", branch_instance.branch_type, " with index ", random_index)
				#else:
					##print("Error: non_empty_branch_types array is empty! Defaulting to STRAIGHT for source tile.")
					#branch_instance.branch_type = BranchType.STRAIGHT
			#else:
				## Assign random branch type, including EMPTY
				#var random_index = randi() % branch_types.size()
				#branch_instance.branch_type = branch_types[random_index]
				##print("Assigned to tile (", x, ", ", y, "): ", branch_instance.branch_type, " with index ", random_index)
			#
			#match branch_instance.branch_type:
				#BranchType.BEND:
					#branch_instance.connections = [1, 1, 0, 0]
				#BranchType.STRAIGHT:
					#branch_instance.connections = [1, 0, 1, 0]
				#BranchType.THREE:
					#branch_instance.connections = [1, 1, 1, 0]
				#BranchType.TERMINAL:
					#branch_instance.connections = [1, 0, 0, 0]
				#BranchType.EMPTY:
					#branch_instance.connections = [0, 0, 0, 0]
			#
			## Initialize connections based on the random rotation
			#for i in range(branch_instance.rotation_index):
				#branch_instance.connections = branch_instance.rotate_connections(branch_instance.connections)
			#
			#branch_instance.update_texture()
			#
			## Assign grid coordinates to the branch instance
			#branch_instance.grid_x = x
			#branch_instance.grid_y = y
			#
			#if x == source_x and y == source_y:
				## Set the source tile's initial state
				#branch_instance.state = "alive"
				#branch_instance.connected_to_source = true
				#branch_instance.set_state("alive")  # Update visuals
				#source_tile = branch_instance  # Save reference to the source tile
				#
				## Delay propagation until after the grid is fully initialized
				#defer_propagation(branch_instance)
			#else:
				## Set all other branches to start as dead
				#branch_instance.state = "dead"
				#branch_instance.connected_to_source = false
			#
			## Position the branch visually on the grid
			#branch_instance.position = Vector2(x * 84 + 42, y * 68 + 34)
			#
			## Connect the branch's signals to the grid's update functions
			#branch_instance.connect("branch_clicked", Callable(self, "_on_branch_clicked"))
			#branch_instance.connect("branch_right_clicked", Callable(self, "_on_branch_right_clicked"))
			#
			#add_child(branch_instance)
			#branches[x].append(branch_instance)
	#
	#print("Source Tile is at: (", source_x, ", ", source_y, ")")
	#
	## Verification Step
	#if source_tile.branch_type == BranchType.EMPTY:
		#print("Error: Source tile is EMPTY! Correcting to STRAIGHT.")
		#source_tile.branch_type = BranchType.STRAIGHT
		#source_tile.connections = [1, 0, 1, 0]  # Default connections for STRAIGHT
		#source_tile.update_texture()
	#
	## Re-run propagation to ensure connectivity
	#source_tile.propagate_connection(grid_width, grid_height, branches)

func init_branches(grid_width: int, grid_height: int) -> void:
	# Generate a solvable puzzle
	var puzzle_data = generator.generate_solvable_puzzle(grid_width, grid_height, BranchScene)
	
	# Extract the generated branches and source position
	branches = puzzle_data.branches
	var source_x = puzzle_data.source_x
	var source_y = puzzle_data.source_y
	source_tile = branches[source_x][source_y]
	
	print("Source Tile is at: (", source_x, ", ", source_y, ")")
	
	# Add all branches to the scene and connect signals
	for x in range(grid_width):
		for y in range(grid_height):
			var branch_instance = branches[x][y]
			
			# Position the branch visually on the grid
			branch_instance.position = Vector2(x * 84 + 42, y * 68 + 34)
			
			# Connect the branch's signals to the grid's update functions
			branch_instance.connect("branch_clicked", Callable(self, "_on_branch_clicked"))
			branch_instance.connect("branch_right_clicked", Callable(self, "_on_branch_right_clicked"))
			
			add_child(branch_instance)
	
	# Run initial propagation from source
	defer_propagation(source_tile)


func _on_branch_clicked(x: int, y: int):
	# Play the beep sound
	if audio_manager:
		audio_manager.sfx_player.play()

	var clicked_branch = branches[x][y]

	# Step 1: Rotate the clicked tile
	clicked_branch.cycle_rotation()

	# Step 2: Phase 1 - Clear connected_to_source flags for all tiles
	for row in branches:
		for branch in row:
			branch.connected_to_source = false  # Reset connection flags

	# Step 3: Phase 2 - Propagate connections starting from the source tile
	source_tile.connected_to_source = true
	source_tile.propagate_connection(grid_width, grid_height, branches)

	# Step 4: Phase 3 - Turn disconnected tiles dead
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
	print("--------------------------------------------")

func center_grid():
	var screen_size = get_viewport_rect().size
	var grid_size = Vector2(grid_width * 84, grid_height * 68)
	position = (screen_size - grid_size) / 2
# Deferred propagation ensures grid initialization
func defer_propagation(source_tile):
	call_deferred("run_propagation", source_tile)

func run_propagation(source_tile):
	source_tile.propagate_connection(grid_width, grid_height, branches)
	
func validate_initial_connections():
	# Start propagation from the source tile
	source_tile.propagate_connection(grid_width, grid_height, branches)
	
	# Force cleanup for disconnected tiles
	for row in branches:
		for branch in row:
			if not branch.connected_to_source and branch.state == "alive":
				branch.set_state("dead")

func check_win_condition():
	# Check if all non-empty tiles are alive
	var all_connected = true
	
	for x in range(grid_width):
		for y in range(grid_height):
			var branch = branches[x][y]
			# Skip empty tiles
			if branch.branch_type == BranchType.EMPTY:
				continue
				
			# If any non-empty tile is dead, puzzle is not solved
			if branch.state != "alive":
				all_connected = false
				break
		
		if not all_connected:
			break
	
	if all_connected:
		print("🎉 CONGRATULATIONS! 🎉")
		print("All branches are connected to the source!")
		print("You solved the puzzle!")
	
		# Optional: Play a victory sound
		#if audio_manager:
			#audio_manager.play_victory_sound()  # You'd need to implement this method
	
		# Optional: Visual feedback
		# You could create a simple animation or effect here
		# For now, just print some ASCII art
		print("╔═══════════════════════════╗")
		print("║         YOU WIN!          ║")
		print("╚═══════════════════════════╝")
