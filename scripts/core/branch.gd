extends Node2D  # Branch.gd

const BranchType = preload("res://scripts/core/branch_types.gd").BranchType

@export var grid_x: int = 0
@export var grid_y: int = 0
@export var grid_width: int
@export var grid_height: int
@export var branches: Array

@onready var sprite: Sprite2D = $Sprite2D  # Fetch Sprite2D from the scene

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
	match rotation_index:
		0:
			animation_name = "down_blossom"
		1:
			animation_name = "left_blossom"
		2:
			animation_name = "up_blossom"
		3:
			animation_name = "right_blossom"
	if animation_name != "":
		$AnimatedSprite2D.play(animation_name)


# Default connections for rotation 0
var connections = [1, 1, 0, 0]
var rotation_index = 0

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

func propagate_connection(grid_width: int, grid_height: int, branches: Array):
	# Skip propagation if the tile is dead or not connected to the source
	if state != "alive" or not connected_to_source:
		return

	var directions = [[0, -1], [1, 0], [0, 1], [-1, 0]]  # UP, RIGHT, DOWN, LEFT
	for i in range(4):
		if connections[i] == 1:  # This branch has an outgoing connection
			var dx = directions[i][0]
			var dy = directions[i][1]
			var neighbor_x = grid_x + dx
			var neighbor_y = grid_y + dy

			# Bounds check
			if neighbor_x >= 0 and neighbor_x < grid_width and neighbor_y >= 0 and neighbor_y < grid_height:
				var neighbor = branches[neighbor_x][neighbor_y]

				# Skip EMPTY tiles
				if neighbor.branch_type == BranchType.EMPTY:
					continue

				# Check if the neighbor connects back in the opposite direction
				if neighbor.connections[(i + 2) % 4] == 1:
					if not neighbor.connected_to_source:  # Avoid redundant propagation
						neighbor.connected_to_source = true
						neighbor.set_state("alive")
						neighbor.propagate_connection(grid_width, grid_height, branches)

func disconnect_if_isolated(grid_width: int, grid_height: int, branches: Array):

	# Check if still connected to any alive neighbor
	var directions = [[0, -1], [1, 0], [0, 1], [-1, 0]]
	for i in range(4):
		var dx = directions[i][0]
		var dy = directions[i][1]
		var neighbor_x = grid_x + dx
		var neighbor_y = grid_y + dy

		if neighbor_x >= 0 and neighbor_x < grid_width and neighbor_y >= 0 and neighbor_y < grid_height:
			var neighbor = branches[neighbor_x][neighbor_y]
			if neighbor.state == "alive" and neighbor.connected_to_source:
				return  # Remain alive if connected to a valid neighbor

	# If no connections, set to dead
	set_state("dead")
	connected_to_source = false

	# Recursively check neighbors
	for i in range(4):
		var dx = directions[i][0]
		var dy = directions[i][1]
		var neighbor_x = grid_x + dx
		var neighbor_y = grid_y + dy

		if neighbor_x >= 0 and neighbor_x < grid_width and neighbor_y >= 0 and neighbor_y < grid_height:
			var neighbor = branches[neighbor_x][neighbor_y]
			if neighbor.state == "alive":
				neighbor.disconnect_if_isolated(grid_width, grid_height, branches)

func check_disconnected():
	# Check if the tile is connected to any alive neighbors
	var connected = false
	var directions = [[0, -1], [1, 0], [0, 1], [-1, 0]]  # UP, RIGHT, DOWN, LEFT

	for i in range(4):
		var dx = directions[i][0]
		var dy = directions[i][1]
		var neighbor_x = grid_x + dx
		var neighbor_y = grid_y + dy

		if neighbor_x < 0 or neighbor_x >= grid_width or neighbor_y < 0 or neighbor_y >= grid_height:
			continue

		var neighbor = branches[neighbor_x][neighbor_y]
		if neighbor.state == "alive" and neighbor.connected_to_source: 
			connected = true
			break

func get_connections() -> Array:
	return connections
	
func cycle_rotation():
	rotation_index = (rotation_index + 1) % 4
	connections = rotate_connections(connections)
	update_texture()
	print("Rotated connections: ", connections)

func rotate_connections(current_connections: Array) -> Array:
	# Rotate connections clockwise
	return [
		current_connections[3],  # LEFT becomes UP
		current_connections[0],  # UP becomes RIGHT
		current_connections[1],  # RIGHT becomes DOWN
		current_connections[2]   # DOWN becomes LEFT
	]
	
func mark_connected(grid_width: int, grid_height: int, branches: Array):
	if connected_to_source or state != "alive":
		return  # Already marked or not alive

	connected_to_source = true  # Mark this tile as connected

	# Recursively mark neighbors
	var directions = [[0, -1], [1, 0], [0, 1], [-1, 0]]  # UP, RIGHT, DOWN, LEFT
	for i in range(4):
		var dx = directions[i][0]
		var dy = directions[i][1]
		var neighbor_x = grid_x + dx
		var neighbor_y = grid_y + dy

		if neighbor_x >= 0 and neighbor_x < grid_width and neighbor_y >= 0 and neighbor_y < grid_height:
			var neighbor = branches[neighbor_x][neighbor_y]
			if get_connections()[i] == 1 and neighbor.get_connections()[(i + 2) % 4] == 1:
				neighbor.mark_connected(grid_width, grid_height, branches)

func propagate_disconnection(grid_width: int, grid_height: int, branches: Array):
	if state == "dead":
		return  # Skip already dead tiles

	set_state("dead")  # Mark this tile as dead
	connected_to_source = false

	# Recursively propagate to neighbors
	var directions = [[0, -1], [1, 0], [0, 1], [-1, 0]]  # UP, RIGHT, DOWN, LEFT
	for i in range(4):
		var dx = directions[i][0]
		var dy = directions[i][1]
		var neighbor_x = grid_x + dx
		var neighbor_y = grid_y + dy

		if neighbor_x >= 0 and neighbor_x < grid_width and neighbor_y >= 0 and neighbor_y < grid_height:
			var neighbor = branches[neighbor_x][neighbor_y]
			if neighbor.state == "alive" and not neighbor.connected_to_source:
				neighbor.propagate_disconnection(grid_width, grid_height, branches)

func update_texture():
	if sprite == null:
		print("Error: Sprite2D is null for tile at (", grid_x, ", ", grid_y, ")")
		return
		
	# Ensure branch_type is valid
	if not branch_type in textures:
		print("Error: Invalid branch_type: ", branch_type)
		return
		
	# Ensure state is valid
	if not state in textures[branch_type]:
		print("Error: Invalid state: ", state, " for branch type: ", branch_type)
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
		print("Warning: Texture is null for branch type ", branch_type, " and state ", state, " at (", grid_x, ", ", grid_y, ")")

#func update_texture():
	#if sprite == null:
		##print("Error: Sprite2D is null for tile at (", grid_x, ", ", grid_y, ")")
		#return
	#
	#if state in textures[branch_type]:
		#var texture_path = textures[branch_type][state][rotation_index]
		#if texture_path != null:
			#sprite.texture = texture_path
			#sprite.visible = true
			#sprite.scale = Vector2(1, 1)  # Reset scale to 1:1
			#sprite.z_index = 1           # Ensure correct rendering order
			##print("Texture updated for tile at (", grid_x, ", ", grid_y, ") to texture: ", sprite.texture.resource_path)
		##else:
			##print("Warning: Texture is null for branch type ", branch_type, " and state ", state, " at (", grid_x, ", ", grid_y, ")")
	#else:
		#print("Error: Texture missing for state ", state, " at (", grid_x, ", ", grid_y, ")")
