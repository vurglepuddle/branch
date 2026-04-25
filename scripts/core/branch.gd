extends Node2D  # Branch.gd
class_name BranchNode

const BranchType = preload("res://scripts/core/branch_types.gd").BranchType

@export var grid_x: int = 0
@export var grid_y: int = 0
@export var grid_width: int
@export var grid_height: int
@export var branches: Array

@onready var sprite: Sprite2D = $Sprite2D  # Fetch Sprite2D from the scene
@onready var leaf_sprite: Sprite2D = $LeafSprite

# Group 1: Straight Horizontal (0,1,0,1) or 3-way Down (0,1,1,1)
const LEAVES_GROUP_1: Array[Texture2D] = [
	preload("res://sprites/Leaf/1_Str_Horizontal_3-way_down_1.png"),
	preload("res://sprites/Leaf/1_Str_Horizontal_3-way_down_2.png")
]

# Group 2: Straight Vertical (1,0,1,0) or 3-way Left (1,0,1,1)
const LEAVES_GROUP_2: Array[Texture2D] = [
	preload("res://sprites/Leaf/2_Str_Vertical_3-way_left_1.png"),
	preload("res://sprites/Leaf/2_Str_Vertical_3-way_left_2.png")
]

# Group 3: Straight Horizontal (0,1,0,1) or 3-way Up (1,1,0,1)
const LEAVES_GROUP_3: Array[Texture2D] = [
	preload("res://sprites/Leaf/3_Str_Horizontal_3-way_up_1.png"),
	preload("res://sprites/Leaf/3_Str_Horizontal_3-way_up_2.png")
]

# Group 4: Straight Vertical (1,0,1,0) or 3-way Right (1,1,1,0)
const LEAVES_GROUP_4: Array[Texture2D] = [
	preload("res://sprites/Leaf/4_Str_Vertical_3-way_right_1.png"),
	preload("res://sprites/Leaf/4_Str_Vertical_3-way_right_2.png")
]

var _leaf_map: Dictionary = {}


var textures = {
	BranchType.BEND: {
		"alive": [
			preload("res://sprites/branches/BEND/bend_live_1.png"),
			preload("res://sprites/branches/BEND/bend_live_2.png"),
			preload("res://sprites/branches/BEND/bend_live_3.png"),
			preload("res://sprites/branches/BEND/bend_live_4.png")
		],
		"dead": [
			preload("res://sprites/branches/BEND/bend_dead_1.png"),
			preload("res://sprites/branches/BEND/bend_dead_2.png"),
			preload("res://sprites/branches/BEND/bend_dead_3.png"),
			preload("res://sprites/branches/BEND/bend_dead_4.png")
		]
	},
	BranchType.STRAIGHT: {
		"alive": [
			preload("res://sprites/branches/STRAIGHT/straight_live_1.png"),
			preload("res://sprites/branches/STRAIGHT/straight_live_2.png"),
			preload("res://sprites/branches/STRAIGHT/straight_live_1.png"),
			preload("res://sprites/branches/STRAIGHT/straight_live_2.png")
		],
		"dead": [
			preload("res://sprites/branches/STRAIGHT/straight_dead_1.png"),
			preload("res://sprites/branches/STRAIGHT/straight_dead_2.png"),
			preload("res://sprites/branches/STRAIGHT/straight_dead_1.png"),
			preload("res://sprites/branches/STRAIGHT/straight_dead_2.png")
		]
	},
	BranchType.THREE: {
		"alive": [
			preload("res://sprites/branches/THREE/three_live_1.png"),
			preload("res://sprites/branches/THREE/three_live_2.png"),
			preload("res://sprites/branches/THREE/three_live_3.png"),
			preload("res://sprites/branches/THREE/three_live_4.png")
		],
		"dead": [
			preload("res://sprites/branches/THREE/three_dead_1.png"),
			preload("res://sprites/branches/THREE/three_dead_2.png"),
			preload("res://sprites/branches/THREE/three_dead_3.png"),
			preload("res://sprites/branches/THREE/three_dead_4.png")
		]
	},
	BranchType.TERMINAL: {
		"alive": [
			preload("res://sprites/branches/TERMINAL/terminal_live_1.png"),
			preload("res://sprites/branches/TERMINAL/terminal_live_2.png"),
			preload("res://sprites/branches/TERMINAL/terminal_live_3.png"),
			preload("res://sprites/branches/TERMINAL/terminal_live_4.png")
		],
		"dead": [
			preload("res://sprites/branches/TERMINAL/terminal_dead_1.png"),
			preload("res://sprites/branches/TERMINAL/terminal_dead_2.png"),
			preload("res://sprites/branches/TERMINAL/terminal_dead_3.png"),
			preload("res://sprites/branches/TERMINAL/terminal_dead_4.png")
		]
	},
	BranchType.EMPTY: {
		"alive": [null],
		"dead": [null]
	}
}

func play_terminal_blossom():
	var animation_name = ""
	if connections[0] == 1: animation_name = "down_blossom"
	elif connections[1] == 1: animation_name = "left_blossom"
	elif connections[2] == 1: animation_name = "up_blossom"
	elif connections[3] == 1: animation_name = "right_blossom"
	else:
		printerr("Terminal branch has no connections to determine blossom direction!")
		return
	
	var anim_sprite = $AnimatedSprite2D # Get the node
	if anim_sprite:
		if anim_sprite.sprite_frames.has_animation(animation_name):
			anim_sprite.visible = true # Make it visible NOW
			anim_sprite.animation = animation_name # Set the animation
			anim_sprite.play() # Play it from the beginning
			#print("Branch at (%s,%s) playing animation: %s" % [grid_x, grid_y, animation_name])
		else:
			printerr("Branch at (%s,%s) animation '%s' not found in SpriteFrames." % [grid_x, grid_y, animation_name])
	else:
		printerr("Branch at (%s,%s) missing AnimatedSprite2D node!" % [grid_x, grid_y])


# Default connections for rotation 0
var connections = [1, 1, 0, 0]
var rotation_index = 0
var solution_rotation_index: int = 0

# Branch state and connection to source
var state: String = "dead"  # Default state
var connected_to_source: bool = false  # Not connected to source by default

# Branch type
@export var branch_type: BranchType = BranchType.BEND  # Default type

# Signal to notify when this branch is clicked
signal branch_clicked(x: int, y: int)
signal branch_right_clicked(x: int, y: int)

func _ready():
	if sprite == null:
		print("Error: Sprite2D node is missing!")
		return
	#print("Textures dictionary:", textures)
	sprite.visible = true
	sprite.scale = Vector2(1, 1)  # Ensure correct scaling
	sprite.z_index = 1            # Ensure it's drawn above other visuals
	update_texture()
	
	# ... existing _ready() code ...
	if leaf_sprite == null:
		printerr("Branch at (%s,%s) missing LeafSprite node!" % [grid_x, grid_y])
	else:
		leaf_sprite.visible = false # Ensure it's hidden initially

	# Initialize _leaf_map (can also be done directly above, but _ready is fine)
	# Key: String representation of the effective connections array [U,R,D,L]
	# Straight Horizontal: [0,1,0,1]
	_leaf_map["[0, 1, 0, 1]"] = [LEAVES_GROUP_1, LEAVES_GROUP_3] # Can use either group 1 or 3 for horizontal straight
	# 3-way Down: [0,1,1,1]
	_leaf_map["[0, 1, 1, 1]"] = [LEAVES_GROUP_1]
	
	# Straight Vertical: [1,0,1,0]
	_leaf_map["[1, 0, 1, 0]"] = [LEAVES_GROUP_2, LEAVES_GROUP_4] # Can use either group 2 or 4 for vertical straight
	# 3-way Left: [1,0,1,1]
	_leaf_map["[1, 0, 1, 1]"] = [LEAVES_GROUP_2]
	
	# 3-way Up: [1,1,0,1]
	_leaf_map["[1, 1, 0, 1]"] = [LEAVES_GROUP_3]
	
	# 3-way Right: [1,1,1,0]
	_leaf_map["[1, 1, 1, 0]"] = [LEAVES_GROUP_4]
	
func set_state(new_state: String):
		
	if state != new_state:
		state = new_state
		update_texture()
				
func _input(event):
	if event is InputEventMouseButton and event.pressed:
		if sprite.get_rect().has_point(to_local(event.position)):
			if event.button_index == MOUSE_BUTTON_LEFT:
				emit_signal("branch_clicked", grid_x, grid_y)
			elif event.button_index == MOUSE_BUTTON_RIGHT:
				emit_signal("branch_right_clicked", grid_x, grid_y)

func propagate_connection(p_grid_width: int, p_grid_height: int, p_branches: Array, p_is_toroidal: bool):
	# Skip propagation if the tile is dead or not connected to the source
	if state != "alive" or not connected_to_source:
		return

	var directions = [[0, -1], [1, 0], [0, 1], [-1, 0]]  # UP, RIGHT, DOWN, LEFT
	for i in range(4):
		if connections[i] == 1:  # This branch has an outgoing connection
			var dx = directions[i][0]
			var dy = directions[i][1]
			var raw_neighbor_x = grid_x + dx
			var raw_neighbor_y = grid_y + dy
			var neighbor_x: int
			var neighbor_y: int
			
			if p_is_toroidal:
				neighbor_x = (raw_neighbor_x % p_grid_width + p_grid_width) % p_grid_width
				neighbor_y = (raw_neighbor_y % p_grid_height + p_grid_height) % p_grid_height
			else:
				neighbor_x = raw_neighbor_x
				neighbor_y = raw_neighbor_y
			
			var is_valid_neighbor_pos = false
			if p_is_toroidal: # For toroidal, wrapped coordinates are always logically "on the grid"
				is_valid_neighbor_pos = true
			else: # For non-toroidal, check bounds
				is_valid_neighbor_pos = (neighbor_x >= 0 and neighbor_x < p_grid_width and \
																				 neighbor_y >= 0 and neighbor_y < p_grid_height)
				
			if is_valid_neighbor_pos: # Defensive check for array bounds, though logic should ensure this.
				if neighbor_x < 0 or neighbor_x >= p_branches.size() or \
				neighbor_y < 0 or neighbor_y >= p_branches[neighbor_x].size():
					printerr("PROPAGATE: Calculated neighbor (%s, %s) for branch (%s, %s) is out of p_branches bounds! Toroidal: %s" % [neighbor_x, neighbor_y, grid_x, grid_y, p_is_toroidal])	
					continue
				var neighbor = p_branches[neighbor_x][neighbor_y]

				# Skip EMPTY tiles
				if neighbor.branch_type == BranchType.EMPTY:
					continue

				# Check if the neighbor connects back in the opposite direction
				if neighbor.connections[(i + 2) % 4] == 1:
					if not neighbor.connected_to_source:  # Avoid redundant propagation
						neighbor.connected_to_source = true
						neighbor.set_state("alive")
						neighbor.propagate_connection(p_grid_width, p_grid_height, p_branches, p_is_toroidal)

func disconnect_if_isolated(p_grid_width: int, p_grid_height: int, p_branches: Array, p_is_toroidal: bool):
	if state == "dead": # Already dead, nothing to do
		return
	var is_still_connected_to_live_source_path = false

	# Check if still connected to any alive neighbor
	var directions = [[0, -1], [1, 0], [0, 1], [-1, 0]]
	for i in range(4):
		if connections[i] == 1:
			var dx = directions[i][0]
			var dy = directions[i][1]
			var raw_neighbor_x = grid_x + dx
			var raw_neighbor_y = grid_y + dy
			var neighbor_x: int
			var neighbor_y: int
			if p_is_toroidal:
				neighbor_x = (raw_neighbor_x % p_grid_width + p_grid_width) % p_grid_width
				neighbor_y = (raw_neighbor_y % p_grid_height + p_grid_height) % p_grid_height
			else:
				neighbor_x = raw_neighbor_x
				neighbor_y = raw_neighbor_y
				
			var is_valid_lookup_pos = false
			if p_is_toroidal:
				is_valid_lookup_pos = true
			else:
				is_valid_lookup_pos = (neighbor_x >= 0 and neighbor_x < p_grid_width and \
									   neighbor_y >= 0 and neighbor_y < p_grid_height)
			if is_valid_lookup_pos:
				if neighbor_x >= 0 and neighbor_x < p_branches.size() and \
				   neighbor_y >= 0 and neighbor_y < p_branches[neighbor_x].size():
					var neighbor = p_branches[neighbor_x][neighbor_y]
					# Check if neighbor connects back AND is alive AND is connected to source
					if neighbor.connections[(i + 2) % 4] == 1 and \
					   neighbor.state == "alive" and \
					   neighbor.connected_to_source:
						is_still_connected_to_live_source_path = true
						break # Found a live connection path, no need to check further
	if not is_still_connected_to_live_source_path:
		# No connection to a live source path found, so this branch becomes dead
		set_state("dead") # This will call update_texture
		connected_to_source = false # Crucial: if it's dead, it's not connected
		
		for i_rec in range(4):
			if connections[i_rec] == 1: # Check actual openings of *this* newly dead branch
				var dx_rec = directions[i_rec][0]
				var dy_rec = directions[i_rec][1]
				# ... (calculate neighbor_x_rec, neighbor_y_rec with toroidal logic) ...
				var raw_n_x_rec = grid_x + dx_rec # Use grid_x of *this* branch
				var raw_n_y_rec = grid_y + dy_rec # Use grid_y of *this* branch
				var n_x_rec: int
				var n_y_rec: int
				if p_is_toroidal:
					n_x_rec = (raw_n_x_rec % p_grid_width + p_grid_width) % p_grid_width
					n_y_rec = (raw_n_y_rec % p_grid_height + p_grid_height) % p_grid_height
				else:
					n_x_rec = raw_n_x_rec
					n_y_rec = raw_n_y_rec
				
				var is_valid_rec_lookup = false
				if p_is_toroidal: is_valid_rec_lookup = true
				else: is_valid_rec_lookup = (n_x_rec >=0 and n_x_rec < p_grid_width and n_y_rec >=0 and n_y_rec < p_grid_height)

				if is_valid_rec_lookup and \
					n_x_rec < p_branches.size() and n_y_rec < p_branches[n_x_rec].size():
					var neighbor_rec = p_branches[n_x_rec][n_y_rec]
					# If neighbor was connected to this now-dead branch, and is alive, it might become isolated
					if neighbor_rec.connections[(i_rec+2)%4] == 1 and neighbor_rec.state == "alive":
						# Pass p_is_toroidal to the recursive call
						neighbor_rec.disconnect_if_isolated(p_grid_width, p_grid_height, p_branches, p_is_toroidal)

func check_disconnected(p_grid_width: int, p_grid_height: int, p_branches: Array, p_is_toroidal: bool) -> bool:
	var directions = [[0, -1], [1, 0], [0, 1], [-1, 0]]

	for i in range(4): # Iterate through UP, RIGHT, DOWN, LEFT
		if connections[i] == 1: # If this branch has an opening
			var dx = directions[i][0]
			var dy = directions[i][1]
			var raw_neighbor_x = grid_x + dx
			var raw_neighbor_y = grid_y + dy
			var neighbor_x: int
			var neighbor_y: int

			if p_is_toroidal:
				neighbor_x = (raw_neighbor_x % p_grid_width + p_grid_width) % p_grid_width
				neighbor_y = (raw_neighbor_y % p_grid_height + p_grid_height) % p_grid_height
			else:
				neighbor_x = raw_neighbor_x
				neighbor_y = raw_neighbor_y
			
			var is_valid_lookup_pos = false
			if p_is_toroidal: is_valid_lookup_pos = true
			else: is_valid_lookup_pos = (neighbor_x >=0 and neighbor_x < p_grid_width and \
										neighbor_y >=0 and neighbor_y < p_grid_height)

			if is_valid_lookup_pos:
				if neighbor_x < p_branches.size() and neighbor_y < p_branches[neighbor_x].size(): # Bounds check
					var neighbor = p_branches[neighbor_x][neighbor_y]
					if neighbor.connections[(i + 2) % 4] == 1 and \
					   neighbor.state == "alive" and \
					   neighbor.connected_to_source:
						return false # Found a live connection, so NOT disconnected
	
	return true # No live, properly connected neighbor found, so it IS disconnected

func get_connections() -> Array:
	return connections
	
func cycle_rotation():
	rotation_index = (rotation_index + 1) % 4
	connections = rotate_connections(connections)
	update_texture()

func solve_rotation() -> void:
	var steps: int = (solution_rotation_index - rotation_index + 4) % 4
	for _i in range(steps):
		rotation_index = (rotation_index + 1) % 4
		connections = rotate_connections(connections)
	update_texture()
	#print("Rotated connections: ", connections)

func rotate_connections(current_connections: Array) -> Array:
	# Rotate connections clockwise
	return [
		current_connections[3],  # LEFT becomes UP
		current_connections[0],  # UP becomes RIGHT
		current_connections[1],  # RIGHT becomes DOWN
		current_connections[2]   # DOWN becomes LEFT
	]
	
func mark_connected(p_grid_width: int, p_grid_height: int, p_branches: Array, p_is_toroidal: bool):

	if connected_to_source: # If already marked, or if not alive and we only mark alive ones
		return
		
	connected_to_source = true  # Mark this tile as connected

	var directions = [[0, -1], [1, 0], [0, 1], [-1, 0]]
	for i in range(4):
		if connections[i] == 1: # If this branch has an opening
			var dx = directions[i][0]
			var dy = directions[i][1]
			# ... (calculate neighbor_x, neighbor_y with toroidal logic as above) ...
			var raw_neighbor_x = grid_x + dx
			var raw_neighbor_y = grid_y + dy
			var neighbor_x: int; var neighbor_y: int
			if p_is_toroidal:
				neighbor_x = (raw_neighbor_x % p_grid_width + p_grid_width) % p_grid_width
				neighbor_y = (raw_neighbor_y % p_grid_height + p_grid_height) % p_grid_height
			else:
				neighbor_x = raw_neighbor_x
				neighbor_y = raw_neighbor_y

			var is_valid_lookup_pos = false
			if p_is_toroidal: is_valid_lookup_pos = true
			else: is_valid_lookup_pos = (neighbor_x >=0 and neighbor_x < p_grid_width and \
										neighbor_y >=0 and neighbor_y < p_grid_height)

			if is_valid_lookup_pos:
				if neighbor_x < p_branches.size() and neighbor_y < p_branches[neighbor_x].size():
					var neighbor = p_branches[neighbor_x][neighbor_y]
					# If this connects to neighbor AND neighbor connects back
					if neighbor.connections[(i + 2) % 4] == 1:
						# Recursive call, passing p_is_toroidal
						neighbor.mark_connected(p_grid_width, p_grid_height, p_branches, p_is_toroidal)

func propagate_disconnection(p_grid_width: int, p_grid_height: int, p_branches: Array, p_is_toroidal: bool):
	if state == "dead" and not connected_to_source: # If already fully dead and marked disconnected
		return

	set_state("dead") # Mark this tile as dead
	connected_to_source = false # Explicitly mark as not connected

	var directions = [[0, -1], [1, 0], [0, 1], [-1, 0]]
	for i in range(4):
		# We need to check neighbors that *were* connected to this now-dead tile.
		if connections[i] == 1: # If this branch HAD an opening
			var dx = directions[i][0]
			var dy = directions[i][1]
			# ... (calculate neighbor_x, neighbor_y with toroidal logic) ...
			var raw_neighbor_x = grid_x + dx
			var raw_neighbor_y = grid_y + dy
			var neighbor_x: int; var neighbor_y: int
			if p_is_toroidal:
				neighbor_x = (raw_neighbor_x % p_grid_width + p_grid_width) % p_grid_width
				neighbor_y = (raw_neighbor_y % p_grid_height + p_grid_height) % p_grid_height
			else:
				neighbor_x = raw_neighbor_x
				neighbor_y = raw_neighbor_y
			
			var is_valid_lookup_pos = false
			if p_is_toroidal: is_valid_lookup_pos = true
			else: is_valid_lookup_pos = (neighbor_x >=0 and neighbor_x < p_grid_width and \
										neighbor_y >=0 and neighbor_y < p_grid_height)

			if is_valid_lookup_pos:
				if neighbor_x < p_branches.size() and neighbor_y < p_branches[neighbor_x].size():
					var neighbor = p_branches[neighbor_x][neighbor_y]
					# If neighbor connected back to this tile AND is currently alive
					if neighbor.connections[(i + 2) % 4] == 1 and neighbor.state == "alive":
						neighbor.disconnect_if_isolated(p_grid_width, p_grid_height, p_branches, p_is_toroidal)

func update_texture():
	if sprite == null:
		return
		
	# Ensure branch_type is valid
	if not branch_type in textures:
		#print("Error: Invalid branch_type: ", branch_type)
		if textures.has(BranchType.EMPTY) and textures[BranchType.EMPTY].has("dead"):
			if textures[BranchType.EMPTY]["dead"].size() > 0:
				sprite.texture = textures[BranchType.EMPTY]["dead"][0]
		return
		
	# Ensure state is valid
	if not state in textures[branch_type]:
		#print("Error: Invalid state: ", state, " for branch type: ", branch_type)
		return
		
	# Ensure rotation_index is valid
	var textures_for_state = textures[branch_type][state]
	if rotation_index < 0 or rotation_index >= textures_for_state.size():
		print("Error: Invalid rotation_index: ", rotation_index, " (max: ", textures_for_state.size()-1, ")")
		rotation_index = rotation_index % textures_for_state.size()  # Ensure it's within bounds
		
	var texture_path = textures_for_state[rotation_index]
	if texture_path != null:
		sprite.texture = texture_path
		sprite.visible = true
		sprite.scale = Vector2(1, 1)  # Reset scale to 1:1
		sprite.z_index = 1           # Ensure correct rendering order
	else:
		return
	
func spawn_leaf_animation():
	if leaf_sprite == null or not is_instance_valid(leaf_sprite):
		return # No sprite to use

	# Determine which leaf group to use based on CURRENT effective connections
	# The 'connections' var already holds the effective connections after rotation
	var effective_connections_str = str(connections) # Convert array [0,1,0,1] to string "[0, 1, 0, 1]"

	if not _leaf_map.has(effective_connections_str):
		# print("Branch (%s,%s) type/rotation %s not eligible for leaves." % [grid_x, grid_y, effective_connections_str])
		return # This shape doesn't get leaves

	var possible_leaf_groups = _leaf_map[effective_connections_str]
	if possible_leaf_groups.is_empty():
		return

	# If multiple groups are possible (e.g., for straight pieces), pick one group randomly
	var selected_leaf_texture_array = possible_leaf_groups[randi() % possible_leaf_groups.size()]
	
	if selected_leaf_texture_array.is_empty():
		return # Should not happen if constants are defined

	# Small chance of no leaf appearing
	if randf() < 0.1: # 10% chance of no leaf
		leaf_sprite.visible = false
		return

	# Pick a random leaf from the selected group
	var random_leaf_texture: Texture2D = selected_leaf_texture_array[randi() % selected_leaf_texture_array.size()]

	leaf_sprite.texture = random_leaf_texture
	leaf_sprite.visible = true
	# print("Branch (%s,%s) spawning leaf from group matching %s" % [grid_x, grid_y, effective_connections_str])
