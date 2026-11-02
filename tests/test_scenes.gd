extends SceneTree
# Plays the real scenes headlessly: both puzzle entry points, tile clicks, winning, giving up,
# and returning to the menu, for every difficulty. Timers run fast, so this checks logic rather
# than feel. It never saves settings. Run with tests/run_tests.sh.

const Checks = preload("res://tests/board_checks.gd")
const BranchType = preload("res://scripts/core/branch_types.gd").BranchType
const DIFFICULTIES: Array[String] = ["baby", "intern", "profi", "master", "expert", "torrero"]
const W: int = 6
const H: int = 17
const TIME_SCALE: float = 8.0
const WAIT_LIMIT_MS: int = 60000
# Each grid and each menu start leaks its generator Node today. Phase 2 removes this: set it to 0 then.
const KNOWN_LEAKED_GENERATORS: int = 30

var _failures: int = 0
var _settings: Node

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	await process_frame
	_settings = root.get_node("GlobalSettings")
	# Tests set what they depend on in memory, so saved player settings can't change the result.
	_settings.give_up_animation = true
	_settings.turn_animation = false
	Engine.time_scale = TIME_SCALE

	await _test_grid_fallback_entry()
	await _test_menu_round_trips()
	_settings.turn_animation = true
	await _test_menu_round_trips()

	Engine.time_scale = 1.0
	for _i in range(10):
		await process_frame
	var orphans: int = int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))
	if orphans != KNOWN_LEAKED_GENERATORS:
		_fail("%d orphan nodes at the end, expected %d" % [orphans, KNOWN_LEAKED_GENERATORS])
		Node.print_orphan_nodes()
	print("test_scenes: %s" % ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
	quit(1 if _failures > 0 else 0)

# Grid opened with no pending puzzle uses its own generation path.
func _test_grid_fallback_entry() -> void:
	for diff in DIFFICULTIES:
		_settings.current_difficulty = diff
		_settings.pending_puzzle_data = {}
		var grid: Node = load("res://scenes/Grid.tscn").instantiate()
		root.add_child(grid)
		current_scene = grid
		await process_frame
		await process_frame
		_check_board(grid, diff, "fallback")
		_check_alive_matches_connections(grid, "%s fallback start" % diff)
		current_scene = null
		grid.queue_free()
		await process_frame

# Menu -> game -> win or give up -> menu, the path players actually take.
func _test_menu_round_trips() -> void:
	var menu: Node = load("res://scenes/main_menu.tscn").instantiate()
	root.add_child(menu)
	current_scene = menu
	if not await _wait_frames(3):
		return

	for i in range(DIFFICULTIES.size()):
		var diff: String = DIFFICULTIES[i]
		menu.current_difficulty_index = i
		_settings.current_difficulty = diff
		menu._start_transition()
		if not await _wait_for_freed(menu.get_instance_id(), "%s: menu to hand over" % diff):
			return
		var grid: Node = current_scene
		if grid == null or grid.scene_file_path != "res://scenes/Grid.tscn":
			_fail("%s: current scene is not the grid after the menu transition" % diff)
			return
		await process_frame
		await process_frame
		_check_board(grid, diff, "menu")
		_check_alive_matches_connections(grid, "%s menu start" % diff)

		await _click_some_tiles(grid, diff)
		# Alternate endings so both exits are covered at every difficulty over repeated runs.
		if i % 2 == 0:
			await _finish_by_winning(grid, diff)
		else:
			await _finish_by_giving_up(grid, diff)

		if not await _wait_for_freed(grid.get_instance_id(), "%s: grid to hand over" % diff):
			return
		menu = current_scene
		if menu == null or menu.scene_file_path != "res://scenes/main_menu.tscn":
			_fail("%s: current scene is not the menu after leaving the game" % diff)
			return
		await _wait_frames(6)

	current_scene = null
	menu.queue_free()
	await process_frame

func _click_some_tiles(grid: Node, diff: String) -> void:
	var cells: Array = Checks.current_board(grid.branches).keys()
	cells.shuffle()
	for cell in cells.slice(0, 12):
		await _click(grid, cell)
		_check_alive_matches_connections(grid, "%s after clicking %s" % [diff, cell])
		if grid.all_connected:
			return

func _finish_by_winning(grid: Node, diff: String) -> void:
	var solved: Dictionary = Checks.solved_board(grid.branches)
	for cell in solved:
		var turns: int = 0
		while not grid.all_connected and grid.branches[cell.x][cell.y].connections != solved[cell]:
			await _click(grid, cell)
			_check_alive_matches_connections(grid, "%s solving %s" % [diff, cell])
			turns += 1
			if turns > 4:
				_fail("%s: tile %s never reached its solution" % [diff, cell])
				return
		if grid.all_connected:
			break
	if not grid.all_connected:
		_fail("%s: every tile is solved but the board does not report a win" % diff)
		return
	if not await _wait_for(func(): return grid.level_won_waiting_for_exit_input, "%s: exit prompt after win" % diff):
		return
	grid._exit_to_main_menu()

# Clicks a tile and waits out its turn animation, if it has one.
func _click(grid: Node, cell: Vector2i) -> void:
	var tile: Node = grid.branches[cell.x][cell.y]
	grid._on_branch_clicked(cell.x, cell.y)
	await _wait_for(func(): return not tile.is_turning(), "tile %s to finish turning" % cell)

func _finish_by_giving_up(grid: Node, diff: String) -> void:
	var solved: Dictionary = Checks.solved_board(grid.branches)
	grid._on_give_up_requested()
	if not await _wait_for(func(): return grid.level_won_waiting_for_exit_input, "%s: give-up to finish" % diff):
		return
	for cell in solved:
		if grid.branches[cell.x][cell.y].connections != solved[cell]:
			_fail("%s: give-up left tile %s unsolved" % [diff, cell])
	_check_alive_matches_connections(grid, "%s after give-up" % diff)
	if grid.all_connected:
		_fail("%s: give-up reported a normal win" % diff)
	# Leaving straight away covers the interruptible wait; the grid's own delay also exits.
	grid._exit_to_main_menu()

func _check_board(grid: Node, diff: String, entry: String) -> void:
	var mask: Dictionary = {}
	for key in root.get_node("DifficultyLayouts").get_valid_cells(diff):
		var parts: PackedStringArray = key.split(",")
		mask[Vector2i(int(parts[0]), int(parts[1]))] = true
	var wrap: bool = diff == "torrero"
	if grid.is_toroidal_grid != wrap:
		_fail("%s %s: is_toroidal_grid is %s" % [diff, entry, grid.is_toroidal_grid])
	var source := Vector2i(grid.source_tile.grid_x, grid.source_tile.grid_y)
	var solved: Dictionary = Checks.solved_board(grid.branches)
	var problems: Array[String] = Checks.solved_violations(solved, source, mask, W, H, wrap)
	problems.append_array(Checks.node_violations(grid.branches))
	for problem in problems:
		_fail("%s %s: %s" % [diff, entry, problem])

# Independent check of the game's alive/dead tiles against a fresh walk of the board.
func _check_alive_matches_connections(grid: Node, where: String) -> void:
	var source := Vector2i(grid.source_tile.grid_x, grid.source_tile.grid_y)
	var board: Dictionary = Checks.current_board(grid.branches)
	var seen: Dictionary = Checks.reachable(board, source, W, H, grid.is_toroidal_grid)
	for cell in board:
		var alive: bool = grid.branches[cell.x][cell.y].state == "alive"
		if alive != seen.has(cell):
			_fail("%s: tile %s is %s but %s reachable" % [where, cell, "alive" if alive else "dead", "is" if seen.has(cell) else "is not"])

func _wait_frames(count: int) -> bool:
	for _i in range(count):
		await process_frame
	return true

# Takes an id because a lambda holding the node itself errors once the node is freed.
func _wait_for_freed(instance_id: int, what: String) -> bool:
	return await _wait_for(func(): return not is_instance_id_valid(instance_id), what)

func _wait_for(condition: Callable, what: String) -> bool:
	var deadline: int = Time.get_ticks_msec() + WAIT_LIMIT_MS
	while not condition.call():
		if Time.get_ticks_msec() > deadline:
			_fail("timed out waiting for " + what)
			return false
		await process_frame
	return true

func _fail(message: String) -> void:
	_failures += 1
	printerr("FAIL: " + message)
