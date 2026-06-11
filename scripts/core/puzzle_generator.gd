# In puzzle_generator.gd
extends Node

const BranchType = preload("res://scripts/core/branch_types.gd").BranchType

# Single source of truth for per-difficulty generation settings.
# Used by grid.gd (fallback generation) and main_menu.gd (pre-generation).
# "size": [width, height]
# "prim_initial_density_factor": Target density for Prim's algorithm (0.0 to 1.0)
# "prim_min_tiles": Absolute minimum tiles for Prim's target, useful for small grids
# "final_target_density_factor": Desired density AFTER pruning (0.0 to 1.0)
# "final_density_variation_factor": +/- variation on final_target_density (0.0 to 1.0 of the target)
const DIFFICULTY_SETTINGS: Dictionary = {
	"baby":   {"size": [6, 17], "prim_initial_density_factor": 0.75, "prim_min_tiles": 7, "final_target_density_factor": 0.75, "final_density_variation_factor": 0.2, "max_gen_attempts": 12},
	"intern": {"size": [6, 17], "prim_initial_density_factor": 0.5, "prim_min_tiles": 14, "final_target_density_factor": 0.5, "final_density_variation_factor": 0.1, "max_gen_attempts": 12},
	"profi":  {"size": [6, 17], "prim_initial_density_factor": 0.55, "prim_min_tiles": 28, "final_target_density_factor": 0.55, "final_density_variation_factor": 0.1, "max_gen_attempts": 14},
	"master": {"size": [6, 17], "prim_initial_density_factor": 0.7, "prim_min_tiles": 38, "final_target_density_factor": 0.7, "final_density_variation_factor": 0.1, "max_gen_attempts": 10},
	"expert": {"size": [6, 17], "prim_initial_density_factor": 1.0, "prim_min_tiles": 85, "final_target_density_factor": 0.75, "final_density_variation_factor": 0.05, "max_gen_attempts": 15},
	"torrero":{"size": [6, 17], "prim_initial_density_factor": 1.0, "prim_min_tiles": 85, "final_target_density_factor": 0.86, "final_density_variation_factor": 0.05, "max_gen_attempts": 15}
}

func get_toroidal_neighbor_coord(val: int, max_val: int) -> int:
	# Handles positive and negative overflow for 1D wrap-around
	# E.g., if val = -1, max_val = 6, returns 5
	# E.g., if val = 6, max_val = 6, returns 0
	return (val % max_val + max_val) % max_val

func deep_copy_dictionary_of_arrays(original_dict: Dictionary) -> Dictionary:
	var new_dict = {}
	for key in original_dict:
		if original_dict[key] is Array:
			new_dict[key] = original_dict[key].duplicate(true) # Deep copy for arrays
		else:
			new_dict[key] = original_dict[key] # Shallow copy for other types (if any)
	return new_dict

# Helper function for graph traversal (BFS) to find all cells reachable from start_node
# through the connections defined in `all_connections_map`.
func find_reachable_cell_keys(start_x: int, start_y: int, all_connections_map: Dictionary,
							 grid_width: int, grid_height: int, p_is_toroidal: bool) -> Dictionary:
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
				var nx_raw = cx + simple_dirs_map[dir_idx][0]
				var ny_raw = cy + simple_dirs_map[dir_idx][1]
				var nx: int
				var ny: int
				#var n_key = "%s,%s" % [nx, ny]
				
				var is_valid_lookup_pos = false
				if p_is_toroidal:
					nx = get_toroidal_neighbor_coord(nx_raw, grid_width)
					ny = get_toroidal_neighbor_coord(ny_raw, grid_height)
					is_valid_lookup_pos = true # Wrapped coordinates are always "valid" for key lookup
				else:
					nx = nx_raw
					ny = ny_raw
					is_valid_lookup_pos = is_valid_position(nx, ny, grid_width, grid_height)
				
				if is_valid_lookup_pos:
					var n_key = "%s,%s" % [nx, ny] # Key uses potentially wrapped coords
					
					if all_connections_map.has(n_key) and not reachable_keys.has(n_key):
						var neighbor_actual_connections = all_connections_map[n_key]
						var opposite_dir_for_neighbor = (dir_idx + 2) % 4
						
						if neighbor_actual_connections[opposite_dir_for_neighbor] == 1:
							reachable_keys[n_key] = true
							queue.append({"x": nx, "y": ny}) # Add with potentially wrapped coords
					
	return reachable_keys

# Helper function to get direction from (x1,y1) to (x2,y2)
func get_direction(x1: int, y1: int, x2: int, y2: int, p_grid_width: int = 0, p_grid_height: int = 0, p_is_toroidal: bool = false) -> int:
	if not p_is_toroidal:
		if x2 > x1: return 1      # RIGHT
		if x2 < x1: return 3      # LEFT
		if y2 > y1: return 2      # DOWN
		if y2 < y1: return 0      # UP
	else:
		var dx = x2 - x1
		var dy = y2 - y1
		
		# Wrap dx
		if abs(dx) > p_grid_width / 2:
			if dx > 0: dx -= p_grid_width
			else: dx += p_grid_width
		
		# Wrap dy
		if abs(dy) > p_grid_height / 2:
			if dy > 0: dy -= p_grid_height
			else: dy += p_grid_height
		
		if abs(dx) > abs(dy): # Primarily horizontal movement
			if dx > 0: return 1 # RIGHT
			else: return 3      # LEFT
		else: # Primarily vertical movement (or equal, prioritize vertical)
			if dy < 0: return 0 # UP
			else: return 2      # DOWN
		
	return -1 # Should not happen if distinct points

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

func get_active_tile_count(puzzle_data: Dictionary) -> int:
	var count: int = 0
	var branch_grid: Array = puzzle_data.get("branches", [])
	for x in range(branch_grid.size()):
		for y in range(branch_grid[x].size()):
			var branch = branch_grid[x][y]
			if branch != null and branch.branch_type != BranchType.EMPTY:
				count += 1
	return count

func is_puzzle_initially_solved(puzzle_data: Dictionary) -> bool:
	var branch_grid: Array = puzzle_data.get("branches", [])
	var active_count: int = 0
	for x in range(branch_grid.size()):
		for y in range(branch_grid[x].size()):
			var branch = branch_grid[x][y]
			if branch == null or branch.branch_type == BranchType.EMPTY:
				continue
			active_count += 1
			if branch.connections != _get_solution_connections(branch):
				return false
	return active_count > 0

func ensure_puzzle_not_initially_solved(puzzle_data: Dictionary) -> void:
	if not is_puzzle_initially_solved(puzzle_data):
		return

	var branch_grid: Array = puzzle_data.get("branches", [])
	var source_x: int = int(puzzle_data.get("source_x", -1))
	var source_y: int = int(puzzle_data.get("source_y", -1))
	var fallback_branch = null

	for x in range(branch_grid.size()):
		for y in range(branch_grid[x].size()):
			var branch = branch_grid[x][y]
			if branch == null or branch.branch_type == BranchType.EMPTY:
				continue
			if fallback_branch == null:
				fallback_branch = branch
			if x != source_x or y != source_y:
				_rotate_branch_once(branch)
				return

	if fallback_branch != null:
		_rotate_branch_once(fallback_branch)

func free_puzzle_nodes(puzzle_data: Dictionary) -> void:
	var branch_grid: Array = puzzle_data.get("branches", [])
	for x in range(branch_grid.size()):
		for y in range(branch_grid[x].size()):
			var branch = branch_grid[x][y]
			if branch != null and is_instance_valid(branch) and not branch.is_inside_tree():
				branch.free()

func _get_solution_connections(branch) -> Array:
	var solution_connections: Array
	match branch.branch_type:
		BranchType.TERMINAL:
			solution_connections = [1, 0, 0, 0]
		BranchType.STRAIGHT:
			solution_connections = [1, 0, 1, 0]
		BranchType.BEND:
			solution_connections = [1, 1, 0, 0]
		BranchType.THREE:
			solution_connections = [1, 1, 1, 0]
		_:
			return [0, 0, 0, 0]

	for _i in range(branch.solution_rotation_index):
		solution_connections = branch.rotate_connections(solution_connections)
	return solution_connections

func _rotate_branch_once(branch) -> void:
	branch.rotation_index = (branch.rotation_index + 1) % 4
	branch.connections = branch.rotate_connections(branch.connections)
	branch.update_texture()

func generate_solvable_puzzle(grid_width: int, grid_height: int, branch_scene: PackedScene,
							  prim_initial_density_factor: float = 0.85,
							  prim_min_target_tiles: int = 10,
							  p_is_toroidal: bool = false,
							  valid_cells: Dictionary = {}) -> Dictionary:
	var final_branches_grid = []
	for x in range(grid_width):
		final_branches_grid.append([])
		for y in range(grid_height):
			final_branches_grid[x].append(null)

	var num_total_cells: int = valid_cells.size() if not valid_cells.is_empty() else grid_width * grid_height
	
	# Calculate the target number of active tiles for Prim's algorithm
	var calculated_target_for_prim = floor(num_total_cells * prim_initial_density_factor)
	var num_active_tiles_target_for_prim = max(1, max(prim_min_target_tiles, calculated_target_for_prim))
	num_active_tiles_target_for_prim = min(num_active_tiles_target_for_prim, num_total_cells) # Clamp to max

	var initial_active_cell_keys = {}
	var cell_tree_connections = {}
	var source_x: int
	var source_y: int
	if not valid_cells.is_empty():
		var cell_keys: Array = valid_cells.keys()
		var chosen: String = cell_keys[randi() % cell_keys.size()]
		var parts: Array = chosen.split(",")
		source_x = int(parts[0]); source_y = int(parts[1])
	else:
		source_x = randi_range(0, grid_width - 1)
		source_y = randi_range(0, grid_height - 1)
	var frontier = [] 
	var source_key_str = "%s,%s" % [source_x, source_y]
	initial_active_cell_keys[source_key_str] = true
	cell_tree_connections[source_key_str] = [0,0,0,0] 
	var cells_in_tree_count = 1
	var prim_directions = [[0, -1, 0], [1, 0, 1], [0, 1, 2], [-1, 0, 3]] 

	# --- 1. Grow the tree (Prim's algorithm variant) ---

	for dir_info in prim_directions:
		var nx_raw = source_x + dir_info[0]
		var ny_raw = source_y + dir_info[1]
		var nx: int; var ny: int
		
		if p_is_toroidal:
			nx = get_toroidal_neighbor_coord(nx_raw, grid_width)
			ny = get_toroidal_neighbor_coord(ny_raw, grid_height)
			var nk: String = "%s,%s" % [nx, ny]
			if nk != source_key_str and (valid_cells.is_empty() or valid_cells.has(nk)):
				frontier.append({"x": nx, "y": ny, "parent_x": source_x, "parent_y": source_y})
		else:
			nx = nx_raw
			ny = ny_raw
			var nk: String = "%s,%s" % [nx, ny]
			if is_valid_position(nx, ny, grid_width, grid_height) and \
			   (valid_cells.is_empty() or valid_cells.has(nk)):
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
		
		var dir_to_current = get_direction(parent_x, parent_y, x, y, grid_width, grid_height, p_is_toroidal)
		var dir_to_parent = (dir_to_current + 2) % 4       
		if dir_to_current != -1: # Ensure valid direction 
			cell_tree_connections[parent_key][dir_to_current] = 1
			cell_tree_connections[cell_key][dir_to_parent] = 1
		else:
			printerr("Prim's: Could not determine direction between parent (%s,%s) and child (%s,%s)" % [parent_x, parent_y, x,y])
			
		for dir_info in prim_directions:
			var nx_raw = x + dir_info[0]
			var ny_raw = y + dir_info[1]
			var nx: int; var ny: int
			var consider_neighbor = false
			
			if p_is_toroidal:
				nx = get_toroidal_neighbor_coord(nx_raw, grid_width)
				ny = get_toroidal_neighbor_coord(ny_raw, grid_height)
				var nk2: String = "%s,%s" % [nx, ny]
				if not initial_active_cell_keys.has(nk2) and \
				   (valid_cells.is_empty() or valid_cells.has(nk2)):
					consider_neighbor = true
			else: # Non-toroidal
				nx = nx_raw
				ny = ny_raw
				var nk2: String = "%s,%s" % [nx, ny]
				if is_valid_position(nx, ny, grid_width, grid_height) and \
				   not initial_active_cell_keys.has(nk2) and \
				   (valid_cells.is_empty() or valid_cells.has(nk2)):
					consider_neighbor = true
					
			if consider_neighbor:
				var in_frontier = false
				for f_item in frontier:
					if f_item.x == nx and f_item.y == ny:
						in_frontier = true; break
				if not in_frontier:
					frontier.append({"x": nx, "y": ny, "parent_x": x, "parent_y": y})
			
		# --- End of 1. Grow the tree ---
		# --- 2. Post-process cell_tree_connections to eliminate 4-way junctions ---
	var keys_from_tree_gen = cell_tree_connections.keys()
	var simple_dirs_map_degradation = [[0, -1], [1, 0], [0, 1], [-1, 0]]

	for cell_key_str in keys_from_tree_gen:
		if not cell_tree_connections.has(cell_key_str): continue
		var coords = cell_key_str.split(","); var current_x = int(coords[0]); var current_y = int(coords[1])
		var connections_at_cell = cell_tree_connections[cell_key_str]
		var connection_count = connections_at_cell[0] + connections_at_cell[1] + connections_at_cell[2] + connections_at_cell[3]
		
		if connection_count >= 4: 
			var original_conns_at_cell = cell_tree_connections[cell_key_str].duplicate(true)
			var connection_indices_to_try_removing = []
			for i in range(4):
				if original_conns_at_cell[i] == 1:
					connection_indices_to_try_removing.append(i)

			# Check if we have enough connections to actually perform the smart removal logic
			# A true 4-way junction should have 4 connections.
			if connection_indices_to_try_removing.size() == 4: # Strict check for 4 connections
				var best_degraded_conns_for_this_cell = null # Renamed for clarity
				var max_reachable_after_degrade = -1

				# Iterate through each of the 4 connections as a candidate for removal
				for dir_to_remove in connection_indices_to_try_removing:
					var temp_connections_map = deep_copy_dictionary_of_arrays(cell_tree_connections)
					temp_connections_map[cell_key_str][dir_to_remove] = 0
					
					var loc_neighbor_x_raw = current_x + simple_dirs_map_degradation[dir_to_remove][0]
					var loc_neighbor_y_raw = current_y + simple_dirs_map_degradation[dir_to_remove][1]
					var loc_neighbor_x: int; var loc_neighbor_y: int
					if p_is_toroidal:
						loc_neighbor_x = get_toroidal_neighbor_coord(loc_neighbor_x_raw, grid_width)
						loc_neighbor_y = get_toroidal_neighbor_coord(loc_neighbor_y_raw, grid_height) # Corrected here
					else:
						loc_neighbor_x = loc_neighbor_x_raw
						loc_neighbor_y = loc_neighbor_y_raw
					
					var loc_neighbor_key = "%s,%s" % [loc_neighbor_x, loc_neighbor_y]
					if temp_connections_map.has(loc_neighbor_key):
						var opposite_dir = (dir_to_remove + 2) % 4
						temp_connections_map[loc_neighbor_key][opposite_dir] = 0
					
					var reachable_keys_after_this_removal = find_reachable_cell_keys(source_x, source_y, temp_connections_map, grid_width, grid_height, p_is_toroidal)
					var num_reachable = reachable_keys_after_this_removal.size()

					if num_reachable > max_reachable_after_degrade:
						max_reachable_after_degrade = num_reachable
						best_degraded_conns_for_this_cell = temp_connections_map[cell_key_str].duplicate(true)
					elif num_reachable == max_reachable_after_degrade:
						if randf() < 0.5: 
							best_degraded_conns_for_this_cell = temp_connections_map[cell_key_str].duplicate(true)
				
				# Apply the best degradation found (if any)
				if best_degraded_conns_for_this_cell != null:
					# ... (logic to apply best_degraded_conns_for_this_cell and update the neighbor) ...
					# (This part was in your previous snippet and should be mostly correct,
					# just ensure it uses best_degraded_conns_for_this_cell and original_conns_at_cell
					# to find the *actually* removed connection and update the correct neighbor in the
					# main cell_tree_connections map)
					var effectively_removed_dir = -1
					for i_check in range(4):
						if original_conns_at_cell[i_check] == 1 and best_degraded_conns_for_this_cell[i_check] == 0:
							effectively_removed_dir = i_check
							break
					
					if effectively_removed_dir != -1:
						cell_tree_connections[cell_key_str] = best_degraded_conns_for_this_cell # Apply to main map
						# Update neighbor in main map
						var fnx_raw = current_x + simple_dirs_map_degradation[effectively_removed_dir][0]
						var fny_raw = current_y + simple_dirs_map_degradation[effectively_removed_dir][1]
						# ... (calculate fnx, fny, fn_key for toroidal/non-toroidal) ...
						# ... (cell_tree_connections[fn_key][opposite_dir] = 0) ...
						var fnx_final:int; var fny_final:int # explicit new names
						if p_is_toroidal:
							fnx_final = get_toroidal_neighbor_coord(fnx_raw, grid_width)
							fny_final = get_toroidal_neighbor_coord(fny_raw, grid_height)
						else:
							fnx_final = fnx_raw; fny_final = fny_raw
						var fn_key_final = "%s,%s" % [fnx_final, fny_final]
						if cell_tree_connections.has(fn_key_final):
							var f_opposite_final = (effectively_removed_dir + 2) % 4
							if cell_tree_connections[fn_key_final][f_opposite_final] == 1:
								cell_tree_connections[fn_key_final][f_opposite_final] = 0
					else:
						printerr("Degradation Error: Could not determine which connection was removed for smart degradation of %s." % cell_key_str)
						# Fallback to simple if logic failed to find removed_dir
						# (This block is essentially the same as the 'else' below now)
						var degraded_conns_simple = degrade_to_three_connections(original_conns_at_cell.duplicate(true))
						cell_tree_connections[cell_key_str] = degraded_conns_simple
						# ... (and update neighbor for the simple degradation) ...
						for i_simple in range(4):
							if original_conns_at_cell[i_simple] == 1 and degraded_conns_simple[i_simple] == 0:
								# ... (update neighbor for this i_simple as above) ...
								break


				else: # Should not happen if connection_indices_to_try_removing had items
					printerr("Degradation Error: Smart degradation found no best option for %s. Applying simple." % cell_key_str)
					# Fallback to simple (same as below)
					var degraded_conns_simple = degrade_to_three_connections(original_conns_at_cell.duplicate(true))
					cell_tree_connections[cell_key_str] = degraded_conns_simple
					# ... (and update neighbor for the simple degradation, find the removed dir and update) ...
					for i_simple in range(4):
						if original_conns_at_cell[i_simple] == 1 and degraded_conns_simple[i_simple] == 0:
							var s_fnx_raw = current_x + simple_dirs_map_degradation[i_simple][0]
							var s_fny_raw = current_y + simple_dirs_map_degradation[i_simple][1]
							var s_fnx_final:int; var s_fny_final:int
							if p_is_toroidal: # toroidal check
								s_fnx_final = get_toroidal_neighbor_coord(s_fnx_raw, grid_width)
								s_fny_final = get_toroidal_neighbor_coord(s_fny_raw, grid_height)
							else:
								s_fnx_final = s_fnx_raw; s_fny_final = s_fny_raw
							var s_fn_key_final = "%s,%s" % [s_fnx_final, s_fny_final]
							if cell_tree_connections.has(s_fn_key_final):
								var s_f_opposite_final = (i_simple + 2) % 4
								if cell_tree_connections[s_fn_key_final][s_f_opposite_final] == 1:
									cell_tree_connections[s_fn_key_final][s_f_opposite_final] = 0
							break # Done for simple fallback

			else: # Not a 4-connection piece that we can "smartly" degrade (e.g. 5+ ways, or <4 but somehow count was >=4)
				printerr("Degradation: Cell %s has %s connections, but found %s removable indices. Applying simple degradation." % [cell_key_str, connection_count, connection_indices_to_try_removing.size()])
				var degraded_conns_simple = degrade_to_three_connections(original_conns_at_cell.duplicate(true)) # operate on a copy
				cell_tree_connections[cell_key_str] = degraded_conns_simple # apply to main map
				# Update the corresponding neighbor
				for i_simple_fallback in range(4):
					if original_conns_at_cell[i_simple_fallback] == 1 and degraded_conns_simple[i_simple_fallback] == 0:
						# This dir_idx_final was the one effectively removed
						var neighbor_x_raw_f = current_x + simple_dirs_map_degradation[i_simple_fallback][0]
						var neighbor_y_raw_f = current_y + simple_dirs_map_degradation[i_simple_fallback][1]
						var neighbor_x_f: int; var neighbor_y_f: int
						if p_is_toroidal:
							neighbor_x_f = get_toroidal_neighbor_coord(neighbor_x_raw_f, grid_width)
							neighbor_y_f = get_toroidal_neighbor_coord(neighbor_y_raw_f, grid_height)
						else:
							neighbor_x_f = neighbor_x_raw_f; neighbor_y_f = neighbor_y_raw_f
						
						var neighbor_key_f = "%s,%s" % [neighbor_x_f, neighbor_y_f]
						if cell_tree_connections.has(neighbor_key_f):
							var opposite_dir_f = (i_simple_fallback + 2) % 4
							if cell_tree_connections[neighbor_key_f][opposite_dir_f] == 1:
								cell_tree_connections[neighbor_key_f][opposite_dir_f] = 0
						break # Found the removed connection
	
		
		#if connection_count >= 4: 
			#var original_conns = connections_at_cell.duplicate(true)
			#var degraded_conns = degrade_to_three_connections(original_conns)
			#cell_tree_connections[cell_key_str] = degraded_conns 
				#
			#for dir_idx in range(4): 
				#if original_conns[dir_idx] == 1 and degraded_conns[dir_idx] == 0: # Connection was removed
					#var neighbor_x_raw = current_x + simple_dirs_map_degradation[dir_idx][0]
					#var neighbor_y_raw = current_y + simple_dirs_map_degradation[dir_idx][1]
					#var neighbor_x: int; var neighbor_y: int
#
					#if p_is_toroidal:
						#neighbor_x = get_toroidal_neighbor_coord(neighbor_x_raw, grid_width)
						#neighbor_y = get_toroidal_neighbor_coord(neighbor_y_raw, grid_height)
					#else:
						#neighbor_x = neighbor_x_raw; neighbor_y = neighbor_y_raw
						#
					#var neighbor_key = "%s,%s" % [neighbor_x, neighbor_y] # Key from (potentially wrapped) coords
					#if cell_tree_connections.has(neighbor_key): 
						#var opposite_dir_for_neighbor = (dir_idx + 2) % 4
						#if cell_tree_connections[neighbor_key][opposite_dir_for_neighbor] == 1:
							#cell_tree_connections[neighbor_key][opposite_dir_for_neighbor] = 0
					## No need to break, degradation might remove multiple. But degrade_to_three only removes one. So break is fine.
					#break 
		# --- End of 2. Post-process for degradation ---
		# --- 2.5: Connectivity Validation and Pruning ---
		# MODIFIED: Pass p_is_toroidal to find_reachable_cell_keys
	var truly_reachable_active_keys = find_reachable_cell_keys(source_x, source_y, cell_tree_connections, 
															   grid_width, grid_height, p_is_toroidal)
	
	var final_active_cell_keys = {}
	var final_cell_tree_connections = {}
	for cell_key_str in cell_tree_connections.keys():
		if truly_reachable_active_keys.has(cell_key_str):
			final_cell_tree_connections[cell_key_str] = cell_tree_connections[cell_key_str]
			if initial_active_cell_keys.has(cell_key_str):
				final_active_cell_keys[cell_key_str] = true
	cell_tree_connections = final_cell_tree_connections
	initial_active_cell_keys = final_active_cell_keys
	# --- End of 2.5 Connectivity Validation ---

	# --- 3. Create Branch Instances ---
	# This part should be fine as it uses the processed cell_tree_connections keys,
	# which are already correct for toroidal/non-toroidal.
	for x_idx in range(grid_width):
		for y_idx in range(grid_height):
			var branch_instance = branch_scene.instantiate()
			branch_instance.grid_x = x_idx; branch_instance.grid_y = y_idx
			var current_cell_key = "%s,%s" % [x_idx, y_idx]

			if initial_active_cell_keys.has(current_cell_key) and cell_tree_connections.has(current_cell_key):
				var final_solved_conn = cell_tree_connections[current_cell_key]
				var final_conn_count = final_solved_conn[0] + final_solved_conn[1] + final_solved_conn[2] + final_solved_conn[3]

				if final_conn_count == 0: branch_instance.branch_type = BranchType.EMPTY
				elif final_conn_count == 1: branch_instance.branch_type = BranchType.TERMINAL
				elif final_conn_count == 2:
					if (final_solved_conn[0]==1 && final_solved_conn[2]==1) || (final_solved_conn[1]==1 && final_solved_conn[3]==1):
						branch_instance.branch_type = BranchType.STRAIGHT
					else: branch_instance.branch_type = BranchType.BEND
				elif final_conn_count == 3: branch_instance.branch_type = BranchType.THREE
				else: 
					printerr("Error: Cell %s has unexpected connection count %s after validation." % [current_cell_key, final_conn_count])
					branch_instance.branch_type = BranchType.EMPTY

				if branch_instance.branch_type != BranchType.EMPTY:
					branch_instance.connections = normalize_connections(final_solved_conn, final_conn_count)
					# Find how many rotations from canonical reach the actual puzzle-correct orientation
					var sol_rot: int = 0
					var test_conn: Array = branch_instance.connections.duplicate()
					for r in range(4):
						if test_conn == final_solved_conn:
							sol_rot = r
							break
						test_conn = branch_instance.rotate_connections(test_conn)
					branch_instance.solution_rotation_index = sol_rot
					var random_rotations = randi() % 4
					for _i in range(random_rotations):
						branch_instance.connections = branch_instance.rotate_connections(branch_instance.connections)
					branch_instance.rotation_index = random_rotations
				else: branch_instance.connections = [0,0,0,0]

				if current_cell_key == source_key_str:
					if initial_active_cell_keys.has(source_key_str) and cell_tree_connections.has(source_key_str):
						branch_instance.state = "alive"
						branch_instance.connected_to_source = true
					else: 
						printerr("CRITICAL: Source tile %s was pruned! Puzzle will be unplayable." % source_key_str)
						branch_instance.state = "dead"; branch_instance.connected_to_source = false
				else:
					branch_instance.state = "dead"; branch_instance.connected_to_source = false
			else: 
				branch_instance.branch_type = BranchType.EMPTY
				branch_instance.connections = [0,0,0,0]
				branch_instance.state = "dead"; branch_instance.connected_to_source = false
				
			branch_instance.update_texture()
			final_branches_grid[x_idx][y_idx] = branch_instance
	# --- End of 3. Create Branch Instances ---

	return {
		"branches": final_branches_grid,
		"source_x": source_x,
		"source_y": source_y
	}
