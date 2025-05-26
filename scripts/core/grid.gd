extends Node2D # this is grid.gd #

const BranchType = preload("res://scripts/core/branch_types.gd").BranchType
const PuzzleGenerator = preload("res://scripts/core/puzzle_generator.gd")
var generator = PuzzleGenerator.new()
# Reference to the Branch scene
@export var BranchScene: PackedScene
@onready var audio_manager: Node = $AudioManager

var is_level_complete_animation_playing: bool = false # Prevent re-triggering

# The size of the grid
var difficulty_levels = {
    # "size": [width, height]
    # "prim_initial_density_factor": Target density for Prim's algorithm (0.0 to 1.0)
    # "prim_min_tiles": Absolute minimum tiles for Prim's target, useful for small grids
    # "final_target_density_factor": Desired density AFTER pruning (0.0 to 1.0)
    # "final_density_variation_factor": +/- variation on final_target_density (0.0 to 1.0 of the target)
    "baby":   {"size": [6, 17], "prim_initial_density_factor": 0.1, "prim_min_tiles": 4, "final_target_density_factor": 0.1, "final_density_variation_factor": 0.1},
    "intern": {"size": [6, 17], "prim_initial_density_factor": 0.35, "prim_min_tiles": 8, "final_target_density_factor": 0.35, "final_density_variation_factor": 0.1},
    "profi":  {"size": [6, 17], "prim_initial_density_factor": 0.9, "prim_min_tiles": 20, "final_target_density_factor": 0.75, "final_density_variation_factor": 0.1},
    "master": {"size": [6, 17], "prim_initial_density_factor": 0.95, "prim_min_tiles": 38, "final_target_density_factor": 0.85, "final_density_variation_factor": 0.05},
    "expert": {"size": [6, 17], "prim_initial_density_factor": 1.0, "prim_min_tiles": 85, "final_target_density_factor": 0.75, "final_density_variation_factor": 0.05},
    "torrero":{"size": [6, 17], "prim_initial_density_factor": 1.0, "prim_min_tiles": 85, "final_target_density_factor": 0.75, "final_density_variation_factor": 0.05}
}

var difficulty_key_map = {
    KEY_1: "baby",
    KEY_2: "intern",
    KEY_3: "profi",
    KEY_4: "master",
    KEY_5: "expert",
    KEY_6: "torrero"
}

var current_difficulty_str: String = "expert"

# The size of the grid
var grid_width = 6  # Horizontal grid size
var grid_height = 17  # Vertical grid size
var branches = []
var source_tile = null  # Holds a reference to the source tile
# Backgrounds
var bg1

#wincondition
var all_connected = false # class-level variable



func load_level_for_current_difficulty():
    """
    Helper function to load/reload the level based on self.current_difficulty_str.
    This encapsulates the logic from _ready() that sets up a new puzzle.
    """
    print("Loading level for difficulty: %s." % self.current_difficulty_str)

    if not difficulty_levels.has(self.current_difficulty_str):
        printerr("Error: Difficulty level '%s' not found!" % self.current_difficulty_str)
        # Fallback to the first defined difficulty if current one is invalid
        if difficulty_levels.size() > 0:
            self.current_difficulty_str = difficulty_levels.keys()[0]
            print("Fell back to difficulty: %s" % self.current_difficulty_str)
        else:
            printerr("FATAL: No difficulty levels defined!")
            return # Cannot proceed

    var current_difficulty_settings = difficulty_levels[self.current_difficulty_str]
    
    grid_width = current_difficulty_settings.size[0]
    grid_height = current_difficulty_settings.size[1]
    
    var prim_density_factor = current_difficulty_settings.prim_initial_density_factor
    var prim_min_tiles = current_difficulty_settings.prim_min_tiles
    var final_target_density = current_difficulty_settings.final_target_density_factor
    var final_variation = current_difficulty_settings.final_density_variation_factor

    print("Clearing old branches...")
    var children_to_remove = []
    for child in get_children():
        # Keep essential nodes by name or specific type if they aren't BranchNode
        if child.name == "AudioManager" or child.name == "bg1_sprite": # Example
            continue
            
        # Check if the child is an instance of your BranchNode class
        if child is BranchNode: # <--- THIS IS THE CLEAN CHECK
            children_to_remove.append(child)
        # else:
            # print("Keeping non-branch child: %s (Type: %s)" % [child.name, child.get_class()])
            
    for child_to_remove in children_to_remove:
        child_to_remove.queue_free()
    
    
    # Reset game state variables
    self.all_connected = false # Crucial for new level

    init_branches(grid_width, grid_height, BranchScene, 
                  prim_density_factor, prim_min_tiles,
                  final_target_density, final_variation)
    
    center_grid() 
    
    audio_manager.load_and_play_music_by_difficulty(self.current_difficulty_str)

func _input(event): # Use _input for discrete key presses
    if event is InputEventKey and event.pressed and not event.is_echo():
        var new_difficulty_selected = false
        var selected_difficulty_str = ""

        # Check against our key map
        if difficulty_key_map.has(event.keycode):
            selected_difficulty_str = difficulty_key_map[event.keycode]
            new_difficulty_selected = true

        if new_difficulty_selected:
            if self.current_difficulty_str != selected_difficulty_str:
                print("Difficulty changed to: %s" % selected_difficulty_str)
                self.current_difficulty_str = selected_difficulty_str
                load_level_for_current_difficulty() # Reload the level with new difficulty
            else:
                print("Difficulty %s already selected." % selected_difficulty_str)


func _ready():
    randomize()
    
    # self.current_difficulty_str is already initialized as a class var
    print("Initial game difficulty from _ready(): %s" % self.current_difficulty_str)
    load_level_for_current_difficulty() # This will handle all setup

    # The audio_manager.setup_audio() might only need to be called once.
    # If it's safe to call multiple times, keeping it in load_level_for_current_difficulty
    # (as it is now for music changes) is fine. Otherwise, move it here.
    audio_manager.setup_audio() # Call once here
    #randomize()  # Initialize the random number generator
    #
    ## Determine the current difficulty level
    ##self.current_difficulty_str = "intern"
    #print("Initial game difficulty: %s" % self.current_difficulty_str)
    #load_level_for_current_difficulty()
    #
    #if not difficulty_levels.has(self.current_difficulty_str):
        #printerr("Error: Difficulty level '%s' not found!" % self.current_difficulty_str)
        #self.current_difficulty_str = difficulty_levels.keys()[0] 
#
    #var current_difficulty_settings = difficulty_levels[self.current_difficulty_str]
    #
    ## CORRECTED ACCESS TO GRID SIZE:
    #if not current_difficulty_settings.has("size") or not current_difficulty_settings.size is Array or current_difficulty_settings.size.size() < 2:
        #printerr("Error: 'size' key missing or invalid in difficulty_settings for '%s'" % self.current_difficulty_str)
        ## Fallback to a default size
        #grid_width = current_difficulty_settings.size[0]
        #grid_height = current_difficulty_settings.size[1]
    #
    ## Parameters for the generator (Prim's algorithm targets)
    #var prim_density_factor = current_difficulty_settings.prim_initial_density_factor
    #var prim_min_tiles = current_difficulty_settings.prim_min_tiles
    #
    ## Parameters for the final puzzle check (after generator's pruning)
    #var final_target_density = current_difficulty_settings.final_target_density_factor
    #var final_variation = current_difficulty_settings.final_density_variation_factor
    #
    #init_branches(grid_width, grid_height, BranchScene, 
                  #prim_density_factor, prim_min_tiles,
                  #final_target_density, final_variation)
    #center_grid()
    #
    #audio_manager.setup_audio()
    #audio_manager.load_and_play_music_by_difficulty(self.current_difficulty_str)
    #
    ##var screen_size = get_viewport_rect().size  # Get actual screen resolution
    ##var scale_factor = screen_size.y / 545.0  # Scale based on height
    ##get_tree().root.content_scale_factor = scale_factor  # Apply scaling


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
    if Input.is_action_just_pressed("ui_mute"):  # "ui_mute" in Input Map
        audio_manager.toggle_mute()
        
    if Input.is_action_just_pressed("ui_accepted"):
        print("Test triggered for difficulty: %s" % self.current_difficulty_str)
        run_batch_generation_test(self.current_difficulty_str, 200)

func init_branches(g_width: int, g_height: int, b_scene: PackedScene, # Arg 1, 2, 3
                   initial_prim_density: float, min_prim_abs_tiles: int,  # Arg 4, 5
                   target_final_density: float, final_density_variation: float) -> void: # Arg 6, 7

    var puzzle_data = null
    var actual_final_active_tile_count = 0
    var num_total_cells_on_grid = g_width * g_height

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
    var max_generation_attempts = 35 

    while attempts < max_generation_attempts:
        attempts += 1
        print("Generation attempt #%s (Prim's target: density_factor=%s, min_tiles=%s)..." % [attempts, initial_prim_density, min_prim_abs_tiles])
        puzzle_data = generator.generate_solvable_puzzle(g_width, g_height, b_scene, 
                                                         initial_prim_density, min_prim_abs_tiles)
        
        actual_final_active_tile_count = 0 
        if puzzle_data and puzzle_data.has("branches"):
            for x_col in puzzle_data.branches:
                for branch_node in x_col:
                    if branch_node and branch_node.branch_type != BranchType.EMPTY:
                        actual_final_active_tile_count += 1
        else:
            printerr("Puzzle generation failed to return valid branches structure on attempt %s." % attempts)
            if attempts < max_generation_attempts:
                continue 
            else:
                break 

        print("Generated puzzle with %s active tiles." % actual_final_active_tile_count)

        if actual_final_active_tile_count >= min_acceptable_final_tiles:
            print("Acceptable density achieved.")
            break 
        
        if attempts < max_generation_attempts:
            print("Too sparse (min desired: %s). Retrying..." % min_acceptable_final_tiles)

    if actual_final_active_tile_count < min_acceptable_final_tiles:
        print("Warning: Could not achieve desired minimum density (%s) after %s attempts. Proceeding with %s active tiles." % [min_acceptable_final_tiles, max_generation_attempts, actual_final_active_tile_count])

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
            if child.name == "AudioManager" or child.name == "bg1_sprite": # Keep essentials
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
        if child.name == "AudioManager" or child.name == "bg1_sprite": # Keep essentials
            continue
        if child is BranchNode: # USE class_name CHECK
            children_to_remove_init.append(child)
    for child_to_remove in children_to_remove_init:
        child_to_remove.queue_free()
        # Alternative, if branches are added to a specific group:
        # for branch_node_in_scene in get_tree().get_nodes_in_group("branches_group"):
            # branch_node_in_scene.queue_free()


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
        defer_propagation(source_tile)
    else:
        printerr("Source tile is null or invalid before defer_propagation.")


func _on_branch_clicked(x: int, y: int):
    if all_connected:
        print("Input disabled, level already complete.")
        return
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
    # Assume all are connected initially, then prove otherwise.
    self.all_connected = true # Use 'self' to be explicit or just 'all_connected'
    
    for x in range(grid_width):
        for y in range(grid_height):
            var branch = branches[x][y]
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

    # --- Orchestrate the animation ---
    # We'll use a loop and timers.

    var overall_animation_delay_accumulator: float = 0.0
    var max_initial_delay: float = 4.0 # Max N seconds (was 5, reduced to make total time reasonable)
    var max_subsequent_delay: float = 1.5 # Max Y seconds (was 3, reduced)

    for i in range(alive_terminal_branches.size()):
        var branch_to_animate: BranchNode = alive_terminal_branches[i]
        var current_delay: float = 0.0

        if i == 0: # First terminal branch
            current_delay = randf_range(0.1, max_initial_delay) # Random delay between 0.1 and N
        elif i == 1: # Second terminal branch
            # This delay is *additional* to the first one's start,
            # or could be relative to game time if preferred.
            # Let's make it a delay *after* the previous one started its own delay.
            current_delay = randf_range(0.05, max_subsequent_delay) # Random delay between 0.05 and Y
                                                                  # (0.05 to avoid exact same time)
        else: # Subsequent branches
            # Shorter, more rapid, slightly overlapping delays
            current_delay = randf_range(0.05, 0.5) # e.g., 0.05 to 0.5 seconds

        # Create a timer for this specific branch's animation start
        # The timer starts *after* the accumulated delay from previous branches
        var actual_start_delay = overall_animation_delay_accumulator + current_delay
        
        # Using await for cleaner async-like code within this function
        # This requires start_blossom_sequence to be an async function if you use await directly
        # For non-async, we'd use Timer nodes manually. Let's use Timer nodes for broader compatibility.

        var individual_timer = Timer.new()
        individual_timer.wait_time = actual_start_delay
        individual_timer.one_shot = true
        # Connect its timeout signal to a method that plays the animation for THIS branch
        # We need to pass the branch_to_animate to the callback.
        individual_timer.connect("timeout", Callable(self, "_play_single_blossom").bind(branch_to_animate, individual_timer))
        add_child(individual_timer) # Timer needs to be in the scene tree to process
        individual_timer.start()
        
        # Accumulate delay for the *start* of the next potential animation trigger
        # This creates a cascading effect.
        overall_animation_delay_accumulator += current_delay 
        # If you want them more overlapped, make overall_animation_delay_accumulator increase by less,
        # e.g., overall_animation_delay_accumulator += current_delay * 0.3

    # After setting up all timers, decide when the "level complete" fully resolves
    # This could be after the longest possible animation sequence.
    # Longest path: max_initial_delay + (num_terminals - 1) * max_subsequent_delay_for_others
    # For simplicity, let's say after a fixed duration from the start of the sequence,
    # or after the overall_animation_delay_accumulator + longest animation duration.
    var cleanup_delay = overall_animation_delay_accumulator + 2.0 # 2 seconds for last animation to play out
    var final_timer = Timer.new()
    final_timer.wait_time = cleanup_delay
    final_timer.one_shot = true
    final_timer.connect("timeout", Callable(self, "_finish_level_complete_sequence").bind(final_timer))
    add_child(final_timer)
    final_timer.start()
    print("Blossom sequence initiated. Total estimated duration: ~%s seconds" % cleanup_delay)


func _play_single_blossom(branch: BranchNode, timer_node: Timer):
    if is_instance_valid(branch):
        print("Playing blossom for branch at: (%s, %s)" % [branch.grid_x, branch.grid_y])
        branch.play_terminal_blossom() # Call the animation player on the branch
    if is_instance_valid(timer_node):
        timer_node.queue_free() # Clean up the timer

func _finish_level_complete_sequence(timer_node: Timer):
    print("Level complete animation sequence finished.")
    is_level_complete_animation_playing = false # Reset flag for next level

    # Here you would transition to the next level, show a "Level Cleared!" popup, etc.
    # For example:
    # get_tree().change_scene_to_file("res://scenes/level_select.tscn")
    # or
    # $LevelCompletePopup.popup()
    
    if is_instance_valid(timer_node):
        timer_node.queue_free() # Clean up the final timer

func run_batch_generation_test(difficulty_to_test: String, num_runs: int = 100):
    if not difficulty_levels.has(difficulty_to_test):
        printerr("Test Error: Difficulty '%s' not found." % difficulty_to_test)
        return
        
    print("\n--- Starting Batch Generation Test ---")
    print("Difficulty: %s, Runs: %s" % [difficulty_to_test, num_runs]) # Use the argument
    var current_difficulty_settings = difficulty_levels[difficulty_to_test] # Use the argument
    #var current_difficulty_settings = difficulty_levels[difficulty_str]
    var g_width = current_difficulty_settings.size[0]
    var g_height = current_difficulty_settings.size[1]
    var b_scene = BranchScene # Assuming BranchScene is loaded

    var prim_density = current_difficulty_settings.prim_initial_density_factor
    var prim_min = current_difficulty_settings.prim_min_tiles
    var final_target_density = current_difficulty_settings.final_target_density_factor
    var final_variation = current_difficulty_settings.final_density_variation_factor

    var num_total_cells = g_width * g_height
    var base_desired_final = floor(num_total_cells * final_target_density)
    var variation_abs = floor(base_desired_final * final_variation)
    var min_acceptable_final = max(1, base_desired_final - variation_abs)
    min_acceptable_final = min(min_acceptable_final, num_total_cells)


    var successes = 0
    var total_attempts_for_successes = 0
    var failed_to_meet_density = 0
    var active_tile_counts = [] # To store counts of successful generations

    var max_gen_attempts_per_run = 35 # Use your current value from init_branches

    for i in range(num_runs):
        var current_run_attempts = 0
        var achieved_density = false
        var last_active_count_this_run = 0

        while current_run_attempts < max_gen_attempts_per_run:
            current_run_attempts += 1
            var puzzle_data = generator.generate_solvable_puzzle(g_width, g_height, b_scene, prim_density, prim_min)
            
            var active_count = 0
            if puzzle_data and puzzle_data.has("branches"):
                for x_col in puzzle_data.branches:
                    for branch_node in x_col:
                        if branch_node and branch_node.branch_type != BranchType.EMPTY:
                            active_count += 1
            last_active_count_this_run = active_count

            if active_count >= min_acceptable_final:
                successes += 1
                total_attempts_for_successes += current_run_attempts
                active_tile_counts.append(active_count)
                achieved_density = true
                break # Success for this run
        
        if not achieved_density:
            failed_to_meet_density += 1
            # Optionally log the sparse count:
            # print("Run %s failed density, got %s tiles." % [i+1, last_active_count_this_run])


    print("\n--- Batch Test Results ---")
    print("Difficulty: %s" % difficulty_to_test)
    print("Target Min Acceptable Tiles: %s" % min_acceptable_final)
    print("Total Runs: %s" % num_runs)
    print("Successful Generations (met density): %s (%s%%)" % [successes, float(successes)/num_runs * 100.0 if num_runs > 0 else 0])
    print("Failed to Meet Density (after %s attempts each): %s" % [max_gen_attempts_per_run, failed_to_meet_density])
    if successes > 0:
        print("Average Attempts per Successful Generation: %s" % (float(total_attempts_for_successes) / successes))
        
        var sum_counts = 0
        for c in active_tile_counts: sum_counts += c
        print("Average Active Tiles in Successful Runs: %s" % (float(sum_counts) / successes))
        active_tile_counts.sort()
        print("Min Active Tiles in Successful Runs: %s" % active_tile_counts[0] if active_tile_counts else "N/A")
        print("Max Active Tiles in Successful Runs: %s" % active_tile_counts[-1] if active_tile_counts else "N/A")
    print("---------------------------\n")
