extends SceneTree
# Alive/dead state and win detection on real grid scenes: random turns on every difficulty against
# an independent walk, plus hand-built boards for wrapping and edge cases. Run with tests/run_tests.sh.

const Checks = preload("res://tests/board_checks.gd")
const BranchType = preload("res://scripts/core/branch_types.gd").BranchType
const DIFFICULTIES: Array[String] = ["baby", "intern", "profi", "master", "expert", "torrero"]
const W: int = 6
const H: int = 17
const RANDOM_TURNS: int = 1500
const RANDOM_SCRAMBLES: int = 200

var _failures: int = 0
var _settings: Node

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	await process_frame
	_settings = root.get_node("GlobalSettings")

	for diff in DIFFICULTIES:
		var grid: Node = await _open_grid(diff)
		_test_random_turns(grid, diff)
		_close_grid(grid)

	var grid: Node = await _open_grid("baby")
	_test_wrapping(grid)
	_test_breaking_and_restoring_a_limb(grid)
	_test_ports_that_lead_nowhere(grid)
	_test_ignored_clicks(grid)
	_close_grid(grid)

	grid = await _open_grid("baby")
	await _test_any_connected_arrangement_wins_once(grid)
	_close_grid(grid)

	await process_frame
	print("test_connectivity: %s" % ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
	quit(1 if _failures > 0 else 0)

func _test_random_turns(grid: Node, diff: String) -> void:
	_check_state(grid, "%s at load" % diff)
	var cells: Array = Checks.current_board(grid.branches).keys()
	for _i in range(RANDOM_TURNS):
		var cell: Vector2i = cells[randi() % cells.size()]
		grid.branches[cell.x][cell.y].cycle_rotation()
		grid.refresh_connectivity()
		_check_state(grid, "%s after turning %s" % [diff, cell])
	for _i in range(RANDOM_SCRAMBLES):
		for cell in cells:
			for _turn in range(randi() % 4):
				grid.branches[cell.x][cell.y].cycle_rotation()
		grid.refresh_connectivity()
		_check_state(grid, "%s after a scramble" % diff)

func _test_wrapping(grid: Node) -> void:
	# Left edge to right edge, top edge to bottom edge, and a path that needs both.
	var cases: Array = [
		["across x", {Vector2i(0, 5): [0, 0, 0, 1], Vector2i(5, 5): [0, 1, 0, 0]}, Vector2i(0, 5)],
		["across y", {Vector2i(2, 0): [1, 0, 0, 0], Vector2i(2, 16): [0, 0, 1, 0]}, Vector2i(2, 0)],
		["both axes", {Vector2i(0, 0): [1, 0, 0, 0], Vector2i(0, 16): [0, 0, 1, 1], Vector2i(5, 16): [0, 1, 0, 0]}, Vector2i(0, 0)],
	]
	for c in cases:
		_build_board(grid, c[1], c[2], true)
		grid.refresh_connectivity()
		for cell in c[1]:
			if grid.branches[cell.x][cell.y].state != "alive":
				_fail("wrapping %s: tile %s should be alive" % [c[0], cell])
		_build_board(grid, c[1], c[2], false)
		grid.refresh_connectivity()
		for cell in c[1]:
			if cell != c[2] and grid.branches[cell.x][cell.y].state != "dead":
				_fail("no wrapping %s: tile %s should be dead" % [c[0], cell])

func _test_breaking_and_restoring_a_limb(grid: Node) -> void:
	var source := Vector2i(1, 1)
	var middle := Vector2i(2, 1)
	var end := Vector2i(3, 1)
	_build_board(grid, {source: [0, 1, 0, 0], middle: [0, 1, 0, 1], end: [0, 0, 0, 1]}, source, false)
	grid.refresh_connectivity()
	_check_state(grid, "limb connected")
	if grid.branches[end.x][end.y].state != "alive":
		_fail("limb: far tile should start alive")
	for turn in range(4):
		grid.branches[middle.x][middle.y].cycle_rotation()
		grid.refresh_connectivity()
		_check_state(grid, "limb turn %d" % turn)
		var connected: bool = turn % 2 == 1
		for cell in [middle, end]:
			if (grid.branches[cell.x][cell.y].state == "alive") != connected:
				_fail("limb turn %d: tile %s should be %s" % [turn, cell, "alive" if connected else "dead"])

func _test_ports_that_lead_nowhere(grid: Node) -> void:
	var source := Vector2i(0, 0)
	var facing_away := Vector2i(1, 0)
	# Source's left and up ports leave the grid and its down port faces an empty cell.
	_build_board(grid, {source: [1, 1, 1, 1], facing_away: [1, 0, 0, 0]}, source, false)
	grid.refresh_connectivity()
	if grid.branches[source.x][source.y].state != "alive":
		_fail("source should always be alive")
	if grid.branches[facing_away.x][facing_away.y].state != "dead":
		_fail("a tile that doesn't connect back should be dead")
	if grid.branches[0][1].state != "dead":
		_fail("an empty cell should stay dead")

func _test_ignored_clicks(grid: Node) -> void:
	var source := Vector2i(1, 1)
	var other := Vector2i(2, 1)
	_build_board(grid, {source: [0, 1, 0, 0], other: [1, 0, 0, 0]}, source, false)
	grid.refresh_connectivity()

	grid._on_branch_clicked(4, 4) # Empty cell
	var empty_tile: Node = grid.branches[4][4]
	if empty_tile.rotation_index != 0 or empty_tile.connections != [0, 0, 0, 0]:
		_fail("clicking an empty cell changed it")

	var hud: Node = grid._game_hud
	hud.panel_is_open = true
	grid._on_branch_clicked(other.x, other.y)
	if grid.branches[other.x][other.y].connections != [1, 0, 0, 0]:
		_fail("a tile turned while the HUD panel was open")
	hud.panel_is_open = false

# The saved solution points the far tile up, so this only wins if any connected board counts.
func _test_any_connected_arrangement_wins_once(grid: Node) -> void:
	var source := Vector2i(1, 1)
	var other := Vector2i(2, 1)
	_build_board(grid, {source: [0, 1, 0, 0], other: [1, 0, 0, 0]}, source, false)
	grid.branches[other.x][other.y].solution_rotation_index = 0
	grid.refresh_connectivity()

	for click in range(2):
		grid._on_branch_clicked(other.x, other.y)
		if grid.all_connected:
			_fail("won after %d clicks with the board still broken" % (click + 1))
	grid._on_branch_clicked(other.x, other.y)
	if not grid.all_connected:
		_fail("a fully connected board did not win")

	var after_win: Array = grid.branches[other.x][other.y].connections.duplicate()
	grid._on_branch_clicked(other.x, other.y)
	if grid.branches[other.x][other.y].connections != after_win:
		_fail("a tile turned after the win")

	await process_frame
	var timers: int = _count_timers(grid)
	if timers == 0:
		_fail("the win sequence did not start")
	grid.check_win_condition()
	await process_frame
	if _count_timers(grid) > timers:
		_fail("the win sequence started twice")

func _count_timers(grid: Node) -> int:
	return grid.get_children().filter(func(child): return child is Timer).size()

# Empties the grid, then places the given tiles. Connections are set directly, so tile types only
# need to be non-empty here.
func _build_board(grid: Node, tiles: Dictionary, source: Vector2i, wrap: bool) -> void:
	grid.is_toroidal_grid = wrap
	for column in grid.branches:
		for b in column:
			var cell := Vector2i(b.grid_x, b.grid_y)
			b.rotation_index = 0
			b.solution_rotation_index = 0
			b.connected_to_source = false
			b.state = "dead"
			if tiles.has(cell):
				b.branch_type = BranchType.TERMINAL
				b.connections = tiles[cell].duplicate()
			else:
				b.branch_type = BranchType.EMPTY
				b.connections = [0, 0, 0, 0]
	grid.source_tile = grid.branches[source.x][source.y]
	grid.source_tile.state = "alive"

func _check_state(grid: Node, where: String) -> void:
	var source := Vector2i(grid.source_tile.grid_x, grid.source_tile.grid_y)
	var seen: Dictionary = Checks.reachable(Checks.current_board(grid.branches), source, W, H, grid.is_toroidal_grid)
	for column in grid.branches:
		for b in column:
			var cell := Vector2i(b.grid_x, b.grid_y)
			if (b.state == "alive") != seen.has(cell) or b.connected_to_source != seen.has(cell):
				_fail("%s: tile %s is %s, connected_to_source %s, reachable %s" % [where, cell, b.state, b.connected_to_source, seen.has(cell)])

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
