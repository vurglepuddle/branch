# puzzle_generator.gd
extends Node

const BranchType = preload("res://scripts/core/branch_types.gd").BranchType

# Generates a solvable puzzle
func generate_solvable_puzzle(grid_width: int, grid_height: int, branch_scene: PackedScene) -> Dictionary:
	# Initialize empty grid
	var branches = []
	for x in range(grid_width):
		branches.append([])
		for y in range(grid_height):
			branches[x].append(null)
	
	# 1. Select a random source position
	var source_x = randi_range(0, grid_width - 1)
	var source_y = randi_range(0, grid_height - 1)
	
	# 2. Generate a connected tree using a modified depth-first approach
	var visited = []
	for x in range(grid_width):
		var row = []
		for y in range(grid_height):
			row.append(false)
		visited.append(row)
	
	# Create a 2D array to track connections between tiles
	var connections = []
	for x in range(grid_width):
		var row = []
		for y in range(grid_height):
			# Initialize with no connections [UP, RIGHT, DOWN, LEFT]
			row.append([0, 0, 0, 0])
		connections.append(row)
	
	# Start from the source and build a tree
	var stack = [[source_x, source_y, -1, -1]]  # [x, y, parent_x, parent_y]
	
	while stack.size() > 0:
		var current = stack.pop_back()
		var x = current[0]
		var y = current[1]
		var parent_x = current[2]
		var parent_y = current[3]
		
		if visited[x][y]:
			continue
		
		visited[x][y] = true
		
		# If this isn't the source, create a connection with its parent
		if parent_x != -1 and parent_y != -1:
			# Determine direction from parent to current
			var dir_to_current = get_direction(parent_x, parent_y, x, y)
			var dir_to_parent = (dir_to_current + 2) % 4
			
			# Create bidirectional connection
			connections[parent_x][parent_y][dir_to_current] = 1
			connections[x][y][dir_to_parent] = 1
		
		# Get neighbors in random order
		var directions = [[0, -1], [1, 0], [0, 1], [-1, 0]]  # UP, RIGHT, DOWN, LEFT
		directions.shuffle()
	
				
				
		for dir in directions:
			var next_x = x + dir[0]
			var next_y = y + dir[1]  # Fixed: was using x + dir[1]
	
			if is_valid_position(next_x, next_y, grid_width, grid_height) and not visited[next_x][next_y]:
				stack.append([next_x, next_y, x, y])
				
	# 3. Create branch instances with the correct types based on connections
	for x in range(grid_width):
		for y in range(grid_height):
			var branch_instance = branch_scene.instantiate()
			
			# Set grid coordinates
			branch_instance.grid_x = x
			branch_instance.grid_y = y
			
			# Determine branch type based on number of connections
			var conn = connections[x][y]
			var connection_count = conn[0] + conn[1] + conn[2] + conn[3]
			
			# Special handling for source tile - ensure it has at least one connection
			if x == source_x and y == source_y and connection_count == 0:
				# If the source ended up with no connections, give it at least one
				conn[randi() % 4] = 1  # Add a random connection
				connection_count = 1
			
			if connection_count == 0:
				branch_instance.branch_type = BranchType.EMPTY
				branch_instance.connections = [0, 0, 0, 0]
			elif connection_count == 1:
				branch_instance.branch_type = BranchType.TERMINAL
				branch_instance.connections = normalize_connections(conn)
			elif connection_count == 2:
				# Check if it's a straight or bend
				if (conn[0] == 1 and conn[2] == 1) or (conn[1] == 1 and conn[3] == 1):
					branch_instance.branch_type = BranchType.STRAIGHT
				else:
					branch_instance.branch_type = BranchType.BEND
				branch_instance.connections = normalize_connections(conn)
			elif connection_count == 3:
				branch_instance.branch_type = BranchType.THREE
				branch_instance.connections = normalize_connections(conn)
			
			# Source tile setup
			if x == source_x and y == source_y:
				branch_instance.state = "alive"
				branch_instance.connected_to_source = true
			else:
				branch_instance.state = "dead"
				branch_instance.connected_to_source = false
	
			
			# 4. Randomize rotation for puzzle state
			var random_rotations = randi() % 4
			for i in range(random_rotations):
				branch_instance.connections = branch_instance.rotate_connections(branch_instance.connections)
			branch_instance.rotation_index = random_rotations
			
			branch_instance.update_texture()
			branches[x][y] = branch_instance
	
	# Return the generated puzzle
	return {
		"branches": branches,
		"source_x": source_x,
		"source_y": source_y
	}

# Helper function to get direction from (x1,y1) to (x2,y2)
func get_direction(x1: int, y1: int, x2: int, y2: int) -> int:
	if x2 > x1: return 1      # RIGHT
	if x2 < x1: return 3      # LEFT
	if y2 > y1: return 2      # DOWN
	if y2 < y1: return 0      # UP
	return -1                 # Same position (error)

# Helper function to check if position is within grid bounds
func is_valid_position(x: int, y: int, width: int, height: int) -> bool:
	return x >= 0 and x < width and y >= 0 and y < height

# Helper function to normalize connections to the expected format for a branch type
func normalize_connections(conn: Array) -> Array:
	var normalized = [0, 0, 0, 0]
	
	# Count connections
	var count = conn[0] + conn[1] + conn[2] + conn[3]
	
	if count == 1:
		# Terminal - find the single connection and make it UP
		for i in range(4):
			if conn[i] == 1:
				normalized[0] = 1  # UP
				break
	elif count == 2:
		# Straight or Bend
		if (conn[0] == 1 and conn[2] == 1) or (conn[1] == 1 and conn[3] == 1):
			# Straight - normalize to UP and DOWN
			normalized = [1, 0, 1, 0]
		else:
			# Bend - normalize to UP and RIGHT
			normalized = [1, 1, 0, 0]
	elif count == 3:
		# Three - normalize to UP, RIGHT, DOWN
		normalized = [1, 1, 1, 0]
	
	return normalized
