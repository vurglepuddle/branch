extends SceneTree
# Give Up on real grid scenes: which tiles it touches, in what order, how long it takes, and how it
# leaves. Timing runs at normal speed with generous limits. It never saves settings. Run with
# tests/run_tests.sh.

const Checks = preload("res://tests/board_checks.gd")
const BranchType = preload("res://scripts/core/branch_types.gd").BranchType
const W: int = 6
const H: int = 17
const PANEL_SLIDE_SECONDS: float = 0.28 # The wait in _on_give_up_requested

var _failures: int = 0
var _settings: Node

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	await process_frame
	_settings = root.get_node("GlobalSettings")
	_settings.give_up_animation = true
	_settings.turn_animation = false

	await _test_skips_solved_tiles_and_keeps_build_order()
	await _test_straight_twin_counts_as_solved()
	await _test_nearly_solved_board_is_quick()
	await _test_full_board_pace()
	await _test_board_ends_solved_without_a_win()
	await _test_waits_about_a_second_then_leaves()
	await _test_tap_leaves_during_the_wait()
	await _test_setting_off_leaves_straight_away()
	await _test_pending_puzzle_keeps_build_order()

	await process_frame
	print("test_give_up: %s" % ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
	quit(1 if _failures > 0 else 0)

func _test_skips_solved_tiles_and_keeps_build_order() -> void:
	var grid: Node = await _open_grid("master")
	var order: Array = grid._construction_order
	if order.is_empty() or order[0] != Vector2i(grid.source_tile.grid_x, grid.source_tile.grid_y):
		_fail("construction order should start at the source")
	for i in range(0, order.size(), 2):
		_tile(grid, order[i]).solve_rotation()
	var to_solve: Array = grid._get_tiles_to_solve()
	var previous_index: int = -1
	for cell in to_solve:
		if _tile(grid, cell).is_solved():
			_fail("%s is already solved but would be solved again" % cell)
		var index: int = order.find(cell)
		if index <= previous_index:
			_fail("tiles to solve are out of build order at %s" % cell)
		previous_index = index
	for cell in order:
		if not _tile(grid, cell).is_solved() and not to_solve.has(cell):
			_fail("%s is unsolved but would be skipped" % cell)
	_close_grid(grid)

# A straight tile looks identical after 180 degrees, even with a different rotation_index.
func _test_straight_twin_counts_as_solved() -> void:
	var grid: Node = await _open_grid("expert")
	var found: bool = false
	for cell in grid._construction_order:
		var tile: Node = _tile(grid, cell)
		if tile.branch_type != BranchType.STRAIGHT:
			continue
		found = true
		tile.solve_rotation()
		tile.cycle_rotation()
		tile.cycle_rotation()
		if tile.rotation_index == tile.solution_rotation_index:
			_fail("the test needs a different rotation_index here")
		if not tile.is_solved():
			_fail("a straight tile turned 180 degrees from its solution should count as solved")
		break
	if not found:
		_fail("the expert board had no straight tile to test")
	_close_grid(grid)

func _test_nearly_solved_board_is_quick() -> void:
	var grid: Node = await _open_grid("expert")
	var order: Array = grid._construction_order
	for cell in order:
		_tile(grid, cell).solve_rotation()
	var unsolved: Array = [order[10], order[40], order[70]]
	for cell in unsolved:
		_tile(grid, cell).cycle_rotation()
	grid.refresh_connectivity()
	var started: int = Time.get_ticks_msec()
	grid._on_give_up_requested()
	await _wait_until_solved(grid)
	var seconds: float = (Time.get_ticks_msec() - started) / 1000.0
	if seconds > PANEL_SLIDE_SECONDS + 0.5:
		_fail("giving up with 3 tiles left took %.2f s" % seconds)
	_stop_before_exit(grid)
	_close_grid(grid)

func _test_full_board_pace() -> void:
	var grid: Node = await _open_grid("expert")
	var count: int = grid._get_tiles_to_solve().size()
	var started: int = Time.get_ticks_msec()
	grid._on_give_up_requested()
	await _wait_until_solved(grid)
	var seconds: float = (Time.get_ticks_msec() - started) / 1000.0 - PANEL_SLIDE_SECONDS
	if seconds < count * grid.SOLVE_STEP_SECONDS * 0.8 or seconds > count * 0.07:
		_fail("%d tiles took %.2f s, about %.3f s each" % [count, seconds, seconds / count])
	_stop_before_exit(grid)
	_close_grid(grid)

func _test_board_ends_solved_without_a_win() -> void:
	for diff in ["baby", "torrero"]:
		var grid: Node = await _open_grid(diff)
		var solved: Dictionary = Checks.solved_board(grid.branches)
		grid._on_give_up_requested()
		await _wait_until_solved(grid)
		var source := Vector2i(grid.source_tile.grid_x, grid.source_tile.grid_y)
		var board: Dictionary = Checks.current_board(grid.branches)
		if board != solved:
			_fail("%s: give-up should leave the saved solution" % diff)
		if Checks.reachable(board, source, W, H, grid.is_toroidal_grid).size() != board.size():
			_fail("%s: the solved board isn't connected" % diff)
		for cell in board:
			if _tile(grid, cell).state != "alive":
				_fail("%s: tile %s should be alive after give-up" % [diff, cell])
		if grid.all_connected:
			_fail("%s: give-up should not count as a win" % diff)
		for cell in board:
			if _tile(grid, cell).get_node("AnimatedSprite2D").visible:
				_fail("%s: give-up should not play the flowers" % diff)
				break
		_stop_before_exit(grid)
		_close_grid(grid)

func _test_waits_about_a_second_then_leaves() -> void:
	var grid: Node = await _open_grid("baby")
	grid._on_give_up_requested()
	await _wait_until_solved(grid)
	var started: int = Time.get_ticks_msec()
	if not await _wait_for(func(): return not grid.level_won_waiting_for_exit_input, "give-up to leave on its own"):
		return
	var seconds: float = (Time.get_ticks_msec() - started) / 1000.0
	if seconds < 0.85 or seconds > 1.4:
		_fail("the wait after give-up took %.2f s, it should be about 1" % seconds)
	await _finish_returning_to_menu(grid)

func _test_tap_leaves_during_the_wait() -> void:
	var grid: Node = await _open_grid("baby")
	grid._on_give_up_requested()
	await _wait_until_solved(grid)
	var started: int = Time.get_ticks_msec()
	var tap := InputEventMouseButton.new()
	tap.pressed = true
	tap.button_index = MOUSE_BUTTON_LEFT
	grid._input(tap)
	if grid.level_won_waiting_for_exit_input:
		_fail("a tap during the wait should leave straight away")
	await _finish_returning_to_menu(grid)
	if (Time.get_ticks_msec() - started) / 1000.0 > 1.5:
		_fail("leaving after a tap took too long")

func _test_setting_off_leaves_straight_away() -> void:
	_settings.give_up_animation = false
	var grid: Node = await _open_grid("baby")
	var before: Dictionary = Checks.current_board(grid.branches)
	grid._on_give_up_requested()
	await _wait_for(func(): return grid.is_level_complete_animation_playing and not grid._game_hud.panel_is_open, "the panel to close")
	await create_timer(PANEL_SLIDE_SECONDS + 0.05).timeout
	if Checks.current_board(grid.branches) != before:
		_fail("with Solve Anim off, give-up shouldn't solve the board")
	_settings.give_up_animation = true
	await _finish_returning_to_menu(grid)

# Menu games arrive through GlobalSettings rather than generating in the grid.
func _test_pending_puzzle_keeps_build_order() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var puzzle: Dictionary = load("res://scripts/core/puzzle_generator.gd").create_puzzle("profi", load("res://scenes/Branch.tscn"), rng)
	_settings.current_difficulty = "profi"
	_settings.pending_puzzle_data = puzzle
	_settings.pending_puzzle_is_toroidal = false
	var grid: Node = load("res://scenes/Grid.tscn").instantiate()
	root.add_child(grid)
	current_scene = grid
	await process_frame
	await process_frame
	if grid._construction_order != puzzle.construction_order:
		_fail("a menu game should keep its construction order")
	_close_grid(grid)

func _wait_until_solved(grid: Node) -> void:
	await _wait_for(func(): return grid.level_won_waiting_for_exit_input, "give-up to finish solving")

# Stops the grid's own countdown from leaving while a test is still looking at the board.
func _stop_before_exit(grid: Node) -> void:
	grid.level_won_waiting_for_exit_input = false

func _finish_returning_to_menu(grid: Node) -> void:
	var grid_id: int = grid.get_instance_id()
	if not await _wait_for(func(): return not is_instance_id_valid(grid_id), "the grid to hand over to the menu"):
		return
	var menu: Node = current_scene
	if menu == null or menu.scene_file_path != "res://scenes/main_menu.tscn":
		_fail("give-up should end on the menu")
		return
	await process_frame
	current_scene = null
	menu.queue_free()
	await process_frame

func _wait_for(condition: Callable, what: String) -> bool:
	var deadline: int = Time.get_ticks_msec() + 30000
	while not condition.call():
		if Time.get_ticks_msec() > deadline:
			_fail("timed out waiting for " + what)
			return false
		await process_frame
	return true

func _tile(grid: Node, cell: Vector2i) -> Node:
	return grid.branches[cell.x][cell.y]

func _open_grid(diff: String) -> Node:
	_settings.current_difficulty = diff
	_settings.pending_puzzle_data = {}
	var grid: Node = load("res://scenes/Grid.tscn").instantiate()
	root.add_child(grid)
	current_scene = grid
	await process_frame
	await process_frame
	return grid

func _close_grid(grid: Node) -> void:
	current_scene = null
	grid.queue_free()

func _fail(message: String) -> void:
	_failures += 1
	printerr("FAIL: " + message)
