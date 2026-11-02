extends Node2D # this is grid.gd #

const BranchType = preload("res://scripts/core/branch_types.gd").BranchType
const PuzzleGenerator = preload("res://scripts/core/puzzle_generator.gd")
const WinEffects = preload("res://scripts/core/win_effects.gd")
const NEIGHBOR_OFFSETS: Array[Vector2i] = [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)] # UP, RIGHT, DOWN, LEFT
const SOLVE_STEP_SECONDS: float = 0.035
const POST_SOLVE_WAIT_SECONDS: float = 1.0
# Reference to the Branch scene
@export var BranchScene: PackedScene
#@onready var audio_manager: Node = $AudioManager

var level_won_waiting_for_exit_input: bool = false
var is_level_complete_animation_playing: bool = false # Prevent re-triggering

# Per-difficulty generation settings — shared with main_menu.gd, single source
# of truth lives in PuzzleGenerator.DIFFICULTY_SETTINGS.
var difficulty_levels = PuzzleGenerator.DIFFICULTY_SETTINGS

var difficulty_key_map = {
	KEY_1: "baby",
	KEY_2: "intern",
	KEY_3: "profi",
	KEY_4: "master",
	KEY_5: "expert",
	KEY_6: "torrero"
}

var current_difficulty_str: String
var is_toroidal_grid: bool = false

var grid_width
var grid_height
var branches = []
var source_tile = null
var all_connected = false
var _construction_order: Array = [] # Every tile, source first, in the order the board was built

var _game_hud: CanvasLayer
var _win_effects: Node = null

func _ready():
	randomize()
	_game_hud = preload("res://scenes/GameHUD.tscn").instantiate()
	add_child(_game_hud)
	_game_hud.give_up_requested.connect(_on_give_up_requested)
	if GlobalSettings:
		current_difficulty_str = GlobalSettings.current_difficulty
		print_verbose("Grid: Loaded difficulty from GlobalSettings: " + current_difficulty_str)
	else:
		current_difficulty_str = "torrero"
		printerr("Grid: GlobalSettings Autoload not found! Using default difficulty: " + current_difficulty_str)

	if GlobalSettings and not GlobalSettings.pending_puzzle_data.is_empty():
		is_toroidal_grid = GlobalSettings.pending_puzzle_is_toroidal
		_load_from_pending_puzzle()
		GlobalSettings.pending_puzzle_data = {}
	else:
		load_level_for_current_difficulty()
		if FadeOverlay:
			FadeOverlay.fade_rect.color = Color.BLACK
			FadeOverlay.fade_rect.modulate.a = 1.0
			FadeOverlay.visible = true
			FadeOverlay.start_fade_in(0.5)
			print_verbose("Grid: Fade-in initiated.")
		else:
			printerr("Grid: FadeOverlay Autoload not found! Scene will appear abruptly.")

func load_level_for_current_difficulty():
	print_verbose("--- load_level_for_current_difficulty START for: %s ---" % self.current_difficulty_str)

	if not difficulty_levels.has(self.current_difficulty_str):
		printerr("Error: Difficulty level '%s' not found!" % self.current_difficulty_str)
		var difficulty_keys = difficulty_levels.keys()
		if difficulty_keys.size() > 0:
			self.current_difficulty_str = difficulty_keys[0]
			print_verbose("Fell back to difficulty: %s" % self.current_difficulty_str)
		else:
			printerr("FATAL: No difficulty levels defined!")
			return

	var current_difficulty_settings = difficulty_levels[self.current_difficulty_str]
	
	grid_width = current_difficulty_settings.size[0]
	grid_height = current_difficulty_settings.size[1]
	self.is_toroidal_grid = current_difficulty_settings.wrap
	print_verbose("Grid settings: WxH=%sx%s, Toroidal=%s" % [grid_width, grid_height, self.is_toroidal_grid])
	
	_cancel_turns()
	_stop_win_effects()
	print_verbose("Clearing old branches...")
	var children_to_remove = []
	for child in get_children():
		if child is BranchNode: # Assumes branch.gd has class_name BranchNode
			children_to_remove.append(child)
			
	if children_to_remove.size() > 0:
		print_verbose("Found %s BranchNode children to remove." % children_to_remove.size())
	else:
		print_verbose("No existing BranchNode children found to remove (this is normal on first load).")
		
	for child_to_remove in children_to_remove:
		if is_instance_valid(child_to_remove):
			child_to_remove.queue_free()
	
	branches.clear() # Clear the internal array
	source_tile = null # Reset source tile
	self.all_connected = false
	is_level_complete_animation_playing = false
	if is_instance_valid(_game_hud):
		_game_hud.locked = false
	print_verbose("Old branches cleared and state reset.")

	var puzzle: Dictionary = PuzzleGenerator.create_puzzle(self.current_difficulty_str, BranchScene)
	if puzzle.is_empty():
		_on_generation_failed()
		return
	branches = puzzle.branches
	source_tile = branches[puzzle.source_x][puzzle.source_y]
	_construction_order = puzzle.construction_order
	_place_tiles()
	center_grid()

	if AudioManager: # Ensure AudioManager is capitalized correctly if that's its autoload name
		AudioManager.play_difficulty_music(self.current_difficulty_str)
		print_verbose("AudioManager instructed to play music for %s" % self.current_difficulty_str)
	else:
		printerr("AudioManager not found when trying to play music in load_level.")
		
	print_verbose("--- load_level_for_current_difficulty END for: %s ---" % self.current_difficulty_str)



func _input(event: InputEvent):
	if level_won_waiting_for_exit_input:
			var should_return_to_menu = false
			if event is InputEventKey and event.is_pressed() and not event.is_echo():
				print_verbose("Grid: Key pressed after win. Returning to menu.")
				should_return_to_menu = true
			elif event is InputEventMouseButton and event.is_pressed():
				print_verbose("Grid: Mouse button pressed after win. Returning to menu.")
				should_return_to_menu = true
			elif event is InputEventScreenTouch and event.is_pressed(): # For touch devices
				print_verbose("Grid: Screen touched after win. Returning to menu.")
				should_return_to_menu = true

			if should_return_to_menu:
				# Consume the input BEFORE changing the scene
				get_viewport().set_input_as_handled() 
				_exit_to_main_menu()
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
				print_verbose("Grid: Difficulty changed by hotkey to: " + current_difficulty_str)
				get_viewport().set_input_as_handled() 

	if difficulty_changed_by_hotkey:
		level_won_waiting_for_exit_input = false # Reset if they change difficulty (reloads level)
		load_level_for_current_difficulty()
		if AudioManager:
			AudioManager.play_difficulty_music(current_difficulty_str)
		return

func center_grid():
	var screen_size = get_viewport_rect().size
	var grid_size = Vector2(grid_width * 84, grid_height * 68)
	position = ((screen_size - grid_size) / 2.0).ceil() + Vector2(1, 0)


func _place_tiles() -> void:
	for x in range(grid_width):
		for y in range(grid_height):
			var b: BranchNode = branches[x][y]
			b.position = Vector2(x * 84 + 42, y * 68 + 34)
			b.branch_clicked.connect(_on_branch_clicked)
			b.branch_right_clicked.connect(_on_branch_right_clicked)
			b.turn_finished.connect(_on_branch_turn_finished)
			add_child(b)
	call_deferred("refresh_connectivity")

# There's no board to show, so go back to the menu rather than leave a broken scene up.
# This doesn't use SceneChanger, which refuses to run while a fade is already in progress.
func _on_generation_failed() -> void:
	printerr("Grid: Could not generate a puzzle for '%s'. Returning to the menu." % current_difficulty_str)
	if is_instance_valid(_game_hud):
		_game_hud.locked = true
	get_tree().call_deferred("change_scene_to_file", "res://scenes/main_menu.tscn")

func _on_branch_clicked(x: int, y: int):
	if all_connected or is_level_complete_animation_playing or level_won_waiting_for_exit_input:
		return
	if is_instance_valid(_game_hud) and _game_hud.panel_is_open:
		return
	var clicked_branch = branches[x][y]
	if clicked_branch.branch_type == BranchType.EMPTY:
		return
	var animate: bool = GlobalSettings.turn_animation and clicked_branch.can_animate_turn()
	if animate and not clicked_branch.accepts_turn():
		return
	# Play the beep sound
	if AudioManager:
		AudioManager.play_beep_pitched(y, grid_height)

	if animate:
		clicked_branch.start_turn()
		return
	clicked_branch.cycle_rotation()
	refresh_connectivity()
	check_win_condition()

func _on_branch_turn_finished(_x: int, _y: int) -> void:
	refresh_connectivity()
	check_win_condition()

func _cancel_turns() -> void:
	for column in branches:
		for branch in column:
			if is_instance_valid(branch):
				branch.cancel_turn()

# Walks reciprocal connections out from the source, then sets every tile's alive/dead state in one pass.
func refresh_connectivity() -> void:
	if not is_instance_valid(source_tile):
		return
	var start := Vector2i(source_tile.grid_x, source_tile.grid_y)
	var reachable: Dictionary = {start: true}
	var to_visit: Array[Vector2i] = [start]
	while not to_visit.is_empty():
		var pos: Vector2i = to_visit.pop_back()
		var connections: Array = branches[pos.x][pos.y].connections
		for dir in range(4):
			if connections[dir] != 1:
				continue
			var next: Vector2i = pos + NEIGHBOR_OFFSETS[dir]
			if is_toroidal_grid:
				next = Vector2i(posmod(next.x, grid_width), posmod(next.y, grid_height))
			elif next.x < 0 or next.x >= grid_width or next.y < 0 or next.y >= grid_height:
				continue
			if not reachable.has(next) and branches[next.x][next.y].connections[(dir + 2) % 4] == 1:
				reachable[next] = true
				to_visit.append(next)

	for column in branches:
		for branch in column:
			var is_alive: bool = reachable.has(Vector2i(branch.grid_x, branch.grid_y))
			branch.connected_to_source = is_alive
			branch.set_state("alive" if is_alive else "dead")

func _on_branch_right_clicked(x: int, y: int):
	var clicked_branch = branches[x][y]
	print_verbose("--- Debug Info for Tile at (", x, ", ", y, ") ---")
	print_verbose("Connections (UP, RIGHT, DOWN, LEFT): ", clicked_branch.get_connections())
	print_verbose("Rotation Index: ", clicked_branch.rotation_index)
	print_verbose("State: ", clicked_branch.state)
	print_verbose("Connected to Source: ", clicked_branch.connected_to_source)
	print_verbose("Is Toroidal Grid: ", self.is_toroidal_grid)
	print_verbose("--------------------------------------------")


func check_win_condition():
	if all_connected or is_level_complete_animation_playing:
		return
	for column in branches:
		for branch in column:
			if branch.branch_type != BranchType.EMPTY and branch.state != "alive":
				return

	all_connected = true
	is_level_complete_animation_playing = true # Set flag
	_cancel_turns()
	if is_instance_valid(_game_hud):
		_game_hud.hide_panel()
		_game_hud.locked = true
	print_verbose("🎉 CONGRATULATIONS! 🎉")
	if AudioManager:
		AudioManager.play_victory_music()
	call_deferred("start_leaf_spawn_sequence")
	call_deferred("_start_win_effects")

func _start_win_effects() -> void:
	var tips: Array = []
	for column in branches:
		for branch in column:
			if branch.branch_type == BranchType.TERMINAL and branch.state == "alive":
				tips.append(branch)
	_win_effects = WinEffects.new()
	add_child(_win_effects)
	_win_effects.exit_allowed.connect(_on_win_exit_allowed)
	_win_effects.glint_started.connect(_on_glint_started)
	_win_effects.start(tips, WinEffects.GLINT_SLOTS.get(current_difficulty_str, 1))

func _on_win_exit_allowed() -> void:
	is_level_complete_animation_playing = false
	level_won_waiting_for_exit_input = true
	print_verbose("Grid: Now waiting for input to return to menu.")

func _on_glint_started(tile: Node) -> void:
	if AudioManager:
		AudioManager.play_star_twinkle_sound(tile.global_position.y, get_viewport_rect().size.y)

func _stop_win_effects() -> void:
	if is_instance_valid(_win_effects):
		_win_effects.stop()
		_win_effects.queue_free()
	_win_effects = null

func start_leaf_spawn_sequence():
	var eligible_leaf_branches = []
	for x in range(grid_width):
		for y in range(grid_height):
			var branch: BranchNode = branches[x][y]
			if (branch.branch_type == BranchType.STRAIGHT or branch.branch_type == BranchType.THREE) \
			   and branch.state == "alive":
				eligible_leaf_branches.append(branch)

	if eligible_leaf_branches.is_empty():
		print_verbose("No eligible branches found for leaf spawning.")
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

	print_verbose("Leaf spawn sequence initiated for %s branches." % eligible_leaf_branches.size())


func _spawn_single_leaf(branch: BranchNode, timer_node: Timer):
	if is_instance_valid(branch):
		branch.spawn_leaf_animation() # Call the method on the BranchNode
	if is_instance_valid(timer_node):
		timer_node.queue_free()


func _load_from_pending_puzzle() -> void:
	var data: Dictionary = GlobalSettings.pending_puzzle_data
	branches = data["branches"]
	var src_x: int = data["source_x"]
	var src_y: int = data["source_y"]

	grid_width = difficulty_levels[current_difficulty_str].size[0]
	grid_height = difficulty_levels[current_difficulty_str].size[1]
	all_connected = false
	is_level_complete_animation_playing = false
	if is_instance_valid(_game_hud):
		_game_hud.locked = false

	if src_x < 0 or src_x >= grid_width or src_y < 0 or src_y >= grid_height or \
	   branches[src_x][src_y] == null:
		printerr("Grid: Invalid source in pending puzzle. Falling back to normal load.")
		branches.clear()
		load_level_for_current_difficulty()
		return

	source_tile = branches[src_x][src_y]
	_construction_order = data["construction_order"]
	_place_tiles()
	center_grid()
	if AudioManager:
		AudioManager.play_difficulty_music(current_difficulty_str)

func _on_give_up_requested() -> void:
	if all_connected or is_level_complete_animation_playing or level_won_waiting_for_exit_input:
		return
	_cancel_turns()
	_game_hud.hide_panel()
	_game_hud.locked = true
	is_level_complete_animation_playing = true
	level_won_waiting_for_exit_input = false
	await get_tree().create_timer(0.28).timeout  # wait for panel to slide down
	if not GlobalSettings.give_up_animation:
		_exit_to_main_menu()
		return
	_run_solve_animation()

# Tiles the player already has right are skipped, so giving up on a nearly solved board is quick.
func _get_tiles_to_solve() -> Array:
	return _construction_order.filter(func(pos): return not branches[pos.x][pos.y].is_solved())

func _run_solve_animation() -> void:
	for pos in _get_tiles_to_solve():
		await get_tree().create_timer(SOLVE_STEP_SECONDS).timeout
		branches[pos.x][pos.y].solve_rotation()
		refresh_connectivity()
		if AudioManager:
			AudioManager.play_beep_pitched(pos.y, grid_height)
	is_level_complete_animation_playing = false
	level_won_waiting_for_exit_input = true
	await get_tree().create_timer(POST_SOLVE_WAIT_SECONDS).timeout
	if level_won_waiting_for_exit_input:
		_exit_to_main_menu()

func _exit_to_main_menu() -> void:
	_stop_win_effects()
	level_won_waiting_for_exit_input = false
	is_level_complete_animation_playing = true

	var fake_board := Sprite2D.new()
	fake_board.texture = preload("res://sprites/branches/grid2.png")
	fake_board.centered = false
	fake_board.z_index = -7
	add_child(fake_board)

	var canvas := CanvasLayer.new()
	canvas.layer = 3
	add_child(canvas)

	var handoff_board := Sprite2D.new()
	handoff_board.texture = preload("res://sprites/branches/grid2.png")
	handoff_board.centered = false
	handoff_board.position = position
	handoff_board.z_index = 102
	handoff_board.visible = false
	canvas.add_child(handoff_board)

	var fake_panel := ColorRect.new()
	fake_panel.color = Color(0, 0, 0.658824, 1)
	fake_panel.size = Vector2(505, 116)
	fake_panel.position = Vector2(21.0, 1538.0)
	fake_panel.z_index = 300
	canvas.add_child(fake_panel)

	var diff: String = current_difficulty_str
	var preview_layout: Array = DifficultyLayouts.PREVIEW_LAYOUTS.get(diff, [])
	var preview_map: Dictionary = {}
	for tile_info in preview_layout:
		preview_map[tile_info["pos"]] = tile_info

	var pos_set: Dictionary = {}
	for tile_info in preview_layout:
		pos_set[tile_info["pos"]] = true
	for x in range(grid_width):
		for y in range(grid_height):
			var b: BranchNode = branches[x][y]
			if b != null and b.branch_type != BranchType.EMPTY:
				pos_set[Vector2i(x, y)] = true

	var positions: Array = pos_set.keys()
	positions.shuffle()

	var total: int = positions.size()
	var slide_started: bool = false
	var branch_preview_scene: PackedScene = preload("res://scenes/Branch_Preview.tscn")

	for i in range(total):
		var pos: Vector2i = positions[i]
		var screen_pos := position + Vector2(pos.x * 84 + 42, pos.y * 68 + 34)

		if pos.x < branches.size() and pos.y < branches[pos.x].size() and branches[pos.x][pos.y] != null:
			branches[pos.x][pos.y].visible = false

		if preview_map.has(pos):
			var info: Dictionary = preview_map[pos]
			var node: Node2D = branch_preview_scene.instantiate()
			node.position = screen_pos
			node.z_index = 200
			canvas.add_child(node)
			node.set_tile_visuals(info["tile_type_enum"], info["rot_idx"],
								  info.get("state", "alive"))

		if AudioManager:
			AudioManager.play_beep_pitched(pos.y, grid_height)

		if not slide_started and i >= int(total * 0.70):
			slide_started = true
			var slide_duration: float = maxf((total - i) * 0.01, 0.12)
			var tween := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
			tween.tween_property(fake_panel, "position:y", 1122.0, slide_duration)

		if i < total - 1:
			await get_tree().create_timer(0.01).timeout

	handoff_board.visible = true
	await get_tree().process_frame

	GlobalSettings.return_from_game = true
	var menu: Node = load("res://scenes/main_menu.tscn").instantiate()
	get_tree().root.add_child(menu)
	get_tree().current_scene = menu
	# Frame-based wait: call_deferred(frame1) → generate_preview+await(frame2)
	# → texture set(frame3) → buffer(frames 4-5).
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	queue_free()
