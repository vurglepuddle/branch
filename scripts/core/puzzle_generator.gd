# In puzzle_generator.gd
extends Node

const BranchType = preload("res://scripts/core/branch_types.gd").BranchType

# Helper function for graph traversal (BFS) to find all cells reachable from start_node
# through the connections defined in `all_connections_map`.
func find_reachable_cell_keys(start_x: int, start_y: int, all_connections_map: Dictionary,
							 grid_width: int, grid_height: int) -> Dictionary:
	var reachable_keys = {} # Stores "x,y" string keys of reachable cells
	var queue = []          # Our queue for BFS

	var start_key = "%s,%s" % [start_x, start_y]

	# If the source itself isn't in the connection map (e.g., if map is empty or source is invalid)
	if not all_connections_map.has(start_key):
		printerr("Source tile (%s) not found in connection data for reachability check." % start_key)
		return reachable_keys # Return empty set

	queue.append({"x": start_x, "y": start_y})
	reachable_keys[start_key] = true # Mark source as reachable

	var simple_dirs_map = [[0, -1], [1, 0], [0, 1], [-1, 0]] # UP, RIGHT, DOWN, LEFT (dx, dy)

	var head = 0 # Use an index for the queue to avoid pop_front() performance issues with large arrays
	while head < queue.size():
		var current_cell_pos = queue[head]
		head += 1

		var cx = current_cell_pos.x
		var cy = current_cell_pos.y
		var c_key = "%s,%s" % [cx, cy]

		# Current cell's connections (it should exist if it was added to queue correctly)
		if not all_connections_map.has(c_key):
			# This case should ideally not be hit if logic is correct.
			printerr("BFS: Cell %s from queue not found in all_connections_map." % c_key)
			continue
			
		var cell_actual_connections = all_connections_map[c_key]

		for dir_idx in range(4): # 0:UP, 1:RIGHT, 2:DOWN, 3:LEFT
			if cell_actual_connections[dir_idx] == 1: # If current cell has an outgoing connection in dir_idx
				var nx = cx + simple_dirs_map[dir_idx][0]
				var ny = cy + simple_dirs_map[dir_idx][1]
				var n_key = "%s,%s" % [nx, ny]

				# Check if neighbor is valid, part of the connection map, and not yet visited
				if is_valid_position(nx, ny, grid_width, grid_height) and \
				   all_connections_map.has(n_key) and \
				   not reachable_keys.has(n_key):
					
					# IMPORTANT: Also check if the neighbor actually connects BACK.
					# The `all_connections_map` should represent bidirectional solved links.
					var neighbor_actual_connections = all_connections_map[n_key]
					var opposite_dir_for_neighbor = (dir_idx + 2) % 4 # e.g., if dir_idx is RIGHT (1), opposite is LEFT (3)
					
					if neighbor_actual_connections[opposite_dir_for_neighbor] == 1:
						reachable_keys[n_key] = true # Mark neighbor as reachable
						queue.append({"x": nx, "y": ny}) # Add to queue for further exploration
						
	return reachable_keys

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

# Helper: Converts actual solved connections to a canonical base orientation for that type
func normalize_connections(solved_connections: Array, count: int) -> Array:
	var canonical_form = [0,0,0,0]
	if count == 1: # TERMINAL
		canonical_form = [1,0,0,0] # Canonical is UP
	elif count == 2: # STRAIGHT or BEND
		# Check if it's straight (opposite connections)
		if (solved_connections[0] == 1 and solved_connections[2] == 1) or \
		   (solved_connections[1] == 1 and solved_connections[3] == 1): # Straight
			canonical_form = [1,0,1,0] # Canonical is UP-DOWN
		else: # Bend
			canonical_form = [1,1,0,0] # Canonical is UP-RIGHT
	elif count == 3: # THREE
		canonical_form = [1,1,1,0] # Canonical is UP-RIGHT-DOWN
	# If you add BranchType.FOUR, handle count == 4: canonical_form = [1,1,1,1]
	return canonical_form

# Helper: Takes a 4-connection array and returns a 3-connection array by removing one randomly
func degrade_to_three_connections(four_conn_array: Array) -> Array:
	var three_conn_array = four_conn_array.duplicate(true)
	var connected_indices = []
	for i in range(4):
		if three_conn_array[i] == 1:
			connected_indices.append(i)
	
	if connected_indices.size() >= 4: # Should be exactly 4 if called correctly
		var remove_idx_in_list = randi() % connected_indices.size()
		var actual_dir_to_remove = connected_indices[remove_idx_in_list]
		three_conn_array[actual_dir_to_remove] = 0
	return three_conn_array


func generate_solvable_puzzle(grid_width: int, grid_height: int, branch_scene: PackedScene, # Args 1, 2, 3
							  prim_initial_density_factor: float = 0.85,  # Arg 4 (new)
							  prim_min_target_tiles: int = 10) -> Dictionary: # Arg 5 (new)
	var final_branches_grid = []
	for x in range(grid_width):
		final_branches_grid.append([])
		for y in range(grid_height):
			final_branches_grid[x].append(null)

	var num_total_cells = grid_width * grid_height
	
	# Calculate the target number of active tiles for Prim's algorithm
	var calculated_target_for_prim = floor(num_total_cells * prim_initial_density_factor)
	var num_active_tiles_target_for_prim = max(1, max(prim_min_target_tiles, calculated_target_for_prim))
	num_active_tiles_target_for_prim = min(num_active_tiles_target_for_prim, num_total_cells) # Clamp to max

	var initial_active_cell_keys = {}
	var cell_tree_connections = {} 
	var source_x = randi_range(0, grid_width - 1)
	var source_y = randi_range(0, grid_height - 1)
	var frontier = [] 
	var source_key_str = "%s,%s" % [source_x, source_y]
	initial_active_cell_keys[source_key_str] = true
	cell_tree_connections[source_key_str] = [0,0,0,0] 
	var cells_in_tree_count = 1
	var prim_directions = [[0, -1, 0], [1, 0, 1], [0, 1, 2], [-1, 0, 3]] 

	for dir_info in prim_directions:
		var nx = source_x + dir_info[0]
		var ny = source_y + dir_info[1]
		if is_valid_position(nx, ny, grid_width, grid_height):
			frontier.append({"x": nx, "y": ny, "parent_x": source_x, "parent_y": source_y})

	# --- 1. Grow the tree (Prim's algorithm variant) ---

	for dir_info in prim_directions:
		var nx = source_x + dir_info[0]
		var ny = source_y + dir_info[1]
		if is_valid_position(nx, ny, grid_width, grid_height):
			frontier.append({"x": nx, "y": ny, "parent_x": source_x, "parent_y": source_y})

	while frontier.size() > 0 and cells_in_tree_count < num_active_tiles_target_for_prim:
		var rand_idx = randi() % frontier.size()
		var current_prospect = frontier[rand_idx]
		frontier.remove_at(rand_idx)
		var x = current_prospect.x; var y = current_prospect.y
		var cell_key = "%s,%s" % [x,y]
		if initial_active_cell_keys.has(cell_key): continue
		initial_active_cell_keys[cell_key] = true
		cell_tree_connections[cell_key] = [0,0,0,0] 
		cells_in_tree_count += 1
		var parent_x = current_prospect.parent_x; var parent_y = current_prospect.parent_y
		var parent_key = "%s,%s" % [parent_x, parent_y]
		var dir_to_current = get_direction(parent_x, parent_y, x, y) 
		var dir_to_parent = (dir_to_current + 2) % 4                 
		cell_tree_connections[parent_key][dir_to_current] = 1
		cell_tree_connections[cell_key][dir_to_parent] = 1
		for dir_info in prim_directions:
			var nx = x + dir_info[0]; var ny = y + dir_info[1]
			if is_valid_position(nx, ny, grid_width, grid_height) and not initial_active_cell_keys.has("%s,%s" % [nx,ny]):
				var in_frontier = false
				for f_item in frontier:
					if f_item.x == nx and f_item.y == ny: in_frontier = true; break
				if not in_frontier: frontier.append({"x": nx, "y": ny, "parent_x": x, "parent_y": y})
	# --- End of 1. Grow the tree ---

	# --- 2. Post-process cell_tree_connections to eliminate 4-way junctions ---
	var keys_from_tree_gen = cell_tree_connections.keys() # Iterate on a copy of keys
	var simple_dirs_map_degradation = [[0, -1], [1, 0], [0, 1], [-1, 0]] 

	for cell_key_str in keys_from_tree_gen:
		if not cell_tree_connections.has(cell_key_str): continue # Cell might have been removed if logic changes
		var coords = cell_key_str.split(","); var current_x = int(coords[0]); var current_y = int(coords[1])
		var connections_at_cell = cell_tree_connections[cell_key_str]
		var connection_count = connections_at_cell[0] + connections_at_cell[1] + connections_at_cell[2] + connections_at_cell[3]
		if connection_count >= 4: 
			var original_conns = connections_at_cell.duplicate(true)
			var degraded_conns = degrade_to_three_connections(original_conns) # Pass original, returns modified
			cell_tree_connections[cell_key_str] = degraded_conns 
			for dir_idx in range(4): 
				if original_conns[dir_idx] == 1 and degraded_conns[dir_idx] == 0:
					var neighbor_x = current_x + simple_dirs_map_degradation[dir_idx][0]
					var neighbor_y = current_y + simple_dirs_map_degradation[dir_idx][1]
					var neighbor_key = "%s,%s" % [neighbor_x, neighbor_y]
					if cell_tree_connections.has(neighbor_key): 
						var opposite_dir_for_neighbor = (dir_idx + 2) % 4
						if cell_tree_connections[neighbor_key][opposite_dir_for_neighbor] == 1:
							cell_tree_connections[neighbor_key][opposite_dir_for_neighbor] = 0
					break 
	# --- End of 2. Post-process for degradation ---

	# --- 2.5: Connectivity Validation and Pruning ---
	# Find all cells truly reachable from the source using the (potentially modified) cell_tree_connections
	var truly_reachable_active_keys = find_reachable_cell_keys(source_x, source_y, cell_tree_connections, grid_width, grid_height)
	
	# Create a new set of connections and active cells, keeping only the reachable ones
	var final_active_cell_keys = {}
	var final_cell_tree_connections = {}

	for cell_key_str in cell_tree_connections.keys(): # Iterate original potentially fragmented connections
		if truly_reachable_active_keys.has(cell_key_str):
			# This cell is part of the main connected component including the source
			final_cell_tree_connections[cell_key_str] = cell_tree_connections[cell_key_str]
			if initial_active_cell_keys.has(cell_key_str): # And it was intended to be an active tile
				final_active_cell_keys[cell_key_str] = true
		# else: The cell_key_str was in cell_tree_connections but is not reachable from source.
		# It will be omitted from final_cell_tree_connections and final_active_cell_keys,
		# effectively making it an empty tile later.

	# Replace the old maps with the validated ones
	cell_tree_connections = final_cell_tree_connections
	initial_active_cell_keys = final_active_cell_keys # Rename for clarity in step 3 if you like
	# --- End of 2.5 Connectivity Validation ---


	# --- 3. Create Branch Instances ---
	for x_idx in range(grid_width):
		for y_idx in range(grid_height):
			var branch_instance = branch_scene.instantiate()
			branch_instance.grid_x = x_idx; branch_instance.grid_y = y_idx
			var current_cell_key = "%s,%s" % [x_idx, y_idx]

			# Check if this cell is an active, connected part of the puzzle
			if initial_active_cell_keys.has(current_cell_key) and cell_tree_connections.has(current_cell_key):
				var final_solved_conn = cell_tree_connections[current_cell_key]
				var final_conn_count = final_solved_conn[0] + final_solved_conn[1] + final_solved_conn[2] + final_solved_conn[3]

				if final_conn_count == 0: # Could happen if a tile became isolated and its connections zeroed
					branch_instance.branch_type = BranchType.EMPTY
				elif final_conn_count == 1: branch_instance.branch_type = BranchType.TERMINAL
				elif final_conn_count == 2:
					if (final_solved_conn[0]==1 && final_solved_conn[2]==1) || (final_solved_conn[1]==1 && final_solved_conn[3]==1):
						branch_instance.branch_type = BranchType.STRAIGHT
					else: branch_instance.branch_type = BranchType.BEND
				elif final_conn_count == 3: branch_instance.branch_type = BranchType.THREE
				else: # Should not happen if final_conn_count >= 4 was degraded and validated
					printerr("Error: Cell %s has unexpected connection count %s after validation." % [current_cell_key, final_conn_count])
					branch_instance.branch_type = BranchType.EMPTY # Fallback

				if branch_instance.branch_type != BranchType.EMPTY:
					branch_instance.connections = normalize_connections(final_solved_conn, final_conn_count)
					var random_rotations = randi() % 4
					for _i in range(random_rotations):
						branch_instance.connections = branch_instance.rotate_connections(branch_instance.connections)
					branch_instance.rotation_index = random_rotations
				else: branch_instance.connections = [0,0,0,0]

				# Set initial gameplay state
				if current_cell_key == source_key_str: # Check if current cell is the source
					# Source must be part of the final active tree to be "alive"
					if initial_active_cell_keys.has(source_key_str) and cell_tree_connections.has(source_key_str):
						branch_instance.state = "alive"
						branch_instance.connected_to_source = true
					else: # Source itself got pruned - puzzle is fundamentally broken
						printerr("CRITICAL: Source tile %s was pruned! Puzzle will be unplayable." % source_key_str)
						branch_instance.state = "dead" # Or make it empty
						branch_instance.connected_to_source = false
				else:
					branch_instance.state = "dead"
					branch_instance.connected_to_source = false
			else: # Not an active cell (either never was, or pruned in step 2.5)
				branch_instance.branch_type = BranchType.EMPTY
				branch_instance.connections = [0,0,0,0]
				branch_instance.state = "dead" 
				branch_instance.connected_to_source = false
			
			branch_instance.update_texture()
			final_branches_grid[x_idx][y_idx] = branch_instance
	# --- End of 3. Create Branch Instances ---
	
	return {
		"branches": final_branches_grid,
		"source_x": source_x,
		"source_y": source_y
	}
