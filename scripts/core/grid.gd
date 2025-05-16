extends Node2D # this is grid.gd #

const BranchType = preload("res://scripts/core/branch_types.gd").BranchType
const PuzzleGenerator = preload("res://scripts/core/puzzle_generator.gd")
var generator = PuzzleGenerator.new()
 
@onready var audio_manager: Node = $AudioManager

# The size of the grid
var difficulty_levels = {
	"baby": [2, 2],
	"intern": [3, 4],
	"profi": [4, 6],
	"master": [5, 8],
	"expert": [6, 17],
	"torrero": [6, 10]
}

# The size of the grid
var grid_width = 6  # Horizontal grid size
var grid_height = 11  # Vertical grid size
var branches = []
var source_tile = null  # Holds a reference to the source tile
# Backgrounds
var bg1

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
	audio_manager.setup_audio()
	audio_manager.load_and_play_music_by_difficulty(difficulty)
	
	#var screen_size = get_viewport_rect().size  # Get actual screen resolution
	#var scale_factor = screen_size.y / 545.0  # Scale based on height
	#get_tree().root.content_scale_factor = scale_factor  # Apply scaling


func center_grid():
	var screen_size = get_viewport_rect().size
	var grid_size = Vector2(grid_width * 84, grid_height * 68)
	position = (screen_size - grid_size) / 2
# Deferred propagation ensures grid initialization
	
	# Load the textures
	var bg_texture1 = preload("res://sprites/branches/grid2.png")

	bg1 = Sprite2D.new()
	bg1.texture = bg_texture1
	bg1.centered = false # Keep top-left as origin
	bg1.z_index = -8
	add_child(bg1)
	#bg1.position = Vector2(0, 0)


func _process(_delta):
	# Check for the mute keypress
	if Input.is_action_just_pressed("ui_mute"):  # "ui_mute" in Input Map
		audio_manager.toggle_mute()
	# Reposition the backgrounds on resize

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
		for branch in get_tree().get_nodes_in_group("branch"):
			branch.disconnect("clicked", branch._on_branch_clicked)
		for branch in get_tree().get_nodes_in_group("branch"):
			if branch.branch_type == BranchType.TERMINAL:
				branch.play_terminal_blossom()
		print("🎉 CONGRATULATIONS! 🎉")
