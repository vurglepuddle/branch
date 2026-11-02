extends SceneTree
# Generates many boards per difficulty with fixed seeds, fails on anything invalid, and prints shape
# numbers to compare against tests/baseline_2026-11-02.txt. Run with tests/run_tests.sh. Pass a board
# count after "--" to change the default.

const Checks = preload("res://tests/board_checks.gd")
const Generator = preload("res://scripts/core/puzzle_generator.gd")
const BranchType = preload("res://scripts/core/branch_types.gd").BranchType
const BranchScene: PackedScene = preload("res://scenes/Branch.tscn")
const DIFFICULTIES: Array[String] = ["baby", "intern", "profi", "master", "expert", "torrero"]
const W: int = 6
const H: int = 17
# Long lines beside each other are the shape this generator exists to avoid. These are the old
# generator's averages from the baseline file, so a change that brings the forks back fails here.
const OLD_SIDE_BY_SIDE: Dictionary = {"master": 0.23, "expert": 0.28, "torrero": 0.27}

var _failures: int = 0

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	await process_frame
	_test_checks_catch_bad_boards()
	_test_same_seed_makes_same_board()
	_test_unusable_cells_fail_cleanly()
	_test_retry_budget_keeps_best_board()
	_test_two_tile_boards()
	_test_already_connected_starts_get_broken()

	var args: PackedStringArray = OS.get_cmdline_user_args()
	var runs: int = int(args[0]) if args.size() > 0 else 200
	var layouts: Node = root.get_node("DifficultyLayouts")
	print("difficulty allowed | tiles avg [min..max] | tips str% bend% 3way% | line avg max | on5+% beside% | depth | starts connected")
	for diff in DIFFICULTIES:
		_test_difficulty(diff, layouts.get_allowed_cells(diff), runs)

	await process_frame
	var orphans: int = int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))
	if orphans != 0:
		_fail("%d orphan nodes left after freeing every board" % orphans)
	print("test_generator: %s" % ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
	quit(1 if _failures > 0 else 0)

func _test_difficulty(diff: String, allowed_cells: Array[Vector2i], runs: int) -> void:
	var settings: Dictionary = Generator.DIFFICULTY_SETTINGS[diff]
	var wrap: bool = settings.wrap
	var mask: Dictionary = {}
	for cell in allowed_cells:
		mask[cell] = true
	var rows: Array[Dictionary] = []
	var starts_connected: int = 0
	var edges_across_x: int = 0
	var edges_across_y: int = 0
	var turned_tiles: int = 0
	var total_tiles: int = 0
	var rng := RandomNumberGenerator.new()
	for run in range(runs):
		rng.seed = hash(diff) + run
		var puzzle: Dictionary = Generator.create_puzzle(diff, BranchScene, rng)
		if puzzle.is_empty():
			_fail("%s seed %d: generation failed" % [diff, run])
			continue
		var label: String = "%s seed %d" % [diff, run]
		_check_puzzle(puzzle, mask, label)
		var shape: Dictionary = Checks.shape(puzzle.solved, puzzle.source, W, H, wrap)
		rows.append(shape)
		if shape.tiles < settings.tile_range[0] or shape.tiles > settings.tile_range[1]:
			_fail("%s: %d tiles, wanted %s" % [label, shape.tiles, settings.tile_range])
		if shape.longest_line > Generator.MAX_STRAIGHT_LINE:
			_fail("%s: a straight line of %d tiles" % [label, shape.longest_line])
		if Checks.reachable(puzzle.scrambled, puzzle.source, W, H, wrap).size() == puzzle.solved.size():
			starts_connected += 1
			_fail("%s: the board starts already connected" % label)
		for y in range(H):
			if puzzle.solved.has(Vector2i(0, y)) and puzzle.solved[Vector2i(0, y)][3] == 1:
				edges_across_x += 1
		for x in range(W):
			if puzzle.solved.has(Vector2i(x, 0)) and puzzle.solved[Vector2i(x, 0)][0] == 1:
				edges_across_y += 1
		for cell in puzzle.solved:
			total_tiles += 1
			if puzzle.scrambled[cell] != puzzle.solved[cell]:
				turned_tiles += 1
		_free_nodes(puzzle)

	# Breaking a connected start only turns a tile or two, so it could hide a scramble that did nothing.
	# Random turns leave about a quarter of tiles solved, a bit more with straight tiles' 180-degree twins.
	if total_tiles > 0 and float(turned_tiles) / total_tiles < 0.6:
		_fail("%s: only %d of %d tiles start turned away from their solution" % [diff, turned_tiles, total_tiles])
	if wrap and (edges_across_x == 0 or edges_across_y == 0):
		_fail("%s: boards never use wrapping (%d across x, %d across y)" % [diff, edges_across_x, edges_across_y])
	if not wrap and (edges_across_x > 0 or edges_across_y > 0):
		_fail("%s: a non-wrapping board has an edge across the border" % diff)
	if OLD_SIDE_BY_SIDE.has(diff):
		var total: float = 0.0
		for row in rows:
			total += row.side_by_side
		if total / rows.size() >= OLD_SIDE_BY_SIDE[diff]:
			_fail("%s: %.0f%% of tiles sit in side-by-side lines, no better than the old generator" % [diff, 100.0 * total / rows.size()])
	_report(diff, mask.size(), rows, starts_connected)

func _check_puzzle(puzzle: Dictionary, mask: Dictionary, label: String) -> void:
	var wrap: bool = puzzle.wrap
	var problems: Array[String] = Checks.solved_violations(puzzle.solved, puzzle.source, mask, W, H, wrap)
	problems.append_array(Checks.node_violations(puzzle.branches))
	for problem in problems:
		_fail("%s: %s" % [label, problem])

	# The nodes must hold exactly the board, and undoing the scramble must reach the solution.
	if Checks.current_board(puzzle.branches) != puzzle.scrambled:
		_fail("%s: tile nodes don't match the scrambled board" % label)
	if Checks.solved_board(puzzle.branches) != puzzle.solved:
		_fail("%s: undoing the scramble doesn't reach the solution" % label)
	for cell in puzzle.solved:
		var scrambled: Array = puzzle.scrambled[cell]
		var reached: bool = false
		for _turn in range(4):
			scrambled = Checks.rotate_clockwise(scrambled)
			reached = reached or scrambled == puzzle.solved[cell]
		if not reached:
			_fail("%s: tile %s can't turn into its solution" % [label, cell])

	var source_node: Node = puzzle.branches[puzzle.source_x][puzzle.source_y]
	if source_node.state != "alive" or not source_node.connected_to_source:
		_fail("%s: the source tile should start alive" % label)
	for column in puzzle.branches:
		for b in column:
			if b != source_node and (b.state != "dead" or b.connected_to_source):
				_fail("%s: tile %d,%d should start dead" % [label, b.grid_x, b.grid_y])

	_check_construction_order(puzzle, label)

# Give-up replays this order, so the source comes first and every tile follows the one it grew from.
func _check_construction_order(puzzle: Dictionary, label: String) -> void:
	var order: Array = puzzle.construction_order
	if order.is_empty() or order[0] != puzzle.source:
		_fail("%s: construction order should start at the source" % label)
		return
	var placed: Dictionary = {}
	for cell in order:
		if placed.has(cell):
			_fail("%s: %s appears twice in the construction order" % [label, cell])
		if cell != puzzle.source:
			var joins_earlier_tile: bool = false
			for dir in range(4):
				if puzzle.solved[cell][dir] == 1 and placed.has(Checks.neighbor(cell, dir, W, H, puzzle.wrap)):
					joins_earlier_tile = true
			if not joins_earlier_tile:
				_fail("%s: %s comes before anything it connects to" % [label, cell])
		placed[cell] = true
	if placed.size() != puzzle.solved.size():
		_fail("%s: construction order has %d of %d tiles" % [label, placed.size(), puzzle.solved.size()])

func _test_same_seed_makes_same_board() -> void:
	var rng := RandomNumberGenerator.new()
	var cells: Array[Vector2i] = root.get_node("DifficultyLayouts").get_allowed_cells("torrero")
	rng.seed = 2026
	var first: Dictionary = Generator.generate_board(W, H, cells, true, [85, 94], 15, rng)
	rng.seed = 2026
	var second: Dictionary = Generator.generate_board(W, H, cells, true, [85, 94], 15, rng)
	if first.solved != second.solved or first.scrambled != second.scrambled or first.source != second.source:
		_fail("the same seed should make the same board")
	rng.seed = 2027
	var other: Dictionary = Generator.generate_board(W, H, cells, true, [85, 94], 15, rng)
	if first.solved == other.solved:
		_fail("different seeds should make different boards")

func _test_unusable_cells_fail_cleanly() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	var cases: Dictionary = {
		"no cells": [[], false],
		"one cell": [[Vector2i(2, 2)], false],
		"one cell with wrapping": [[Vector2i(2, 2)], true],
		"cells that don't touch": [[Vector2i(0, 0), Vector2i(2, 2), Vector2i(4, 4)], false],
		"edge cells that only touch by wrapping": [[Vector2i(0, 5), Vector2i(5, 5)], false],
	}
	for name in cases:
		var cells: Array[Vector2i] = []
		cells.assign(cases[name][0])
		var started: int = Time.get_ticks_msec()
		var board: Dictionary = Generator.generate_board(W, H, cells, cases[name][1], [2, 5], 15, rng)
		if not board.is_empty():
			_fail("%s: should fail instead of making a board" % name)
		if Time.get_ticks_msec() - started > 1000:
			_fail("%s: took too long to give up" % name)

# A plus shape can't be filled, because its centre would need four ports. The budget must run out
# and hand back the best valid board.
func _test_retry_budget_keeps_best_board() -> void:
	var rng := RandomNumberGenerator.new()
	var cells: Array[Vector2i] = [Vector2i(2, 2), Vector2i(2, 1), Vector2i(3, 2), Vector2i(2, 3), Vector2i(1, 2)]
	var mask: Dictionary = {}
	for cell in cells:
		mask[cell] = true
	for run in range(100):
		rng.seed = run
		var board: Dictionary = Generator.generate_board(W, H, cells, false, [5, 5], 6, rng)
		if board.is_empty():
			_fail("the plus shape should still give its best valid board")
			return
		if board.solved.size() != 4:
			_fail("the plus shape's best board has %d tiles, not 4" % board.solved.size())
		for problem in Checks.solved_violations(board.solved, board.source, mask, W, H, false):
			_fail("plus shape: %s" % problem)
		if Checks.reachable(board.scrambled, board.source, W, H, false).size() == board.solved.size():
			_fail("the plus shape's fallback board starts connected")

func _test_two_tile_boards() -> void:
	var rng := RandomNumberGenerator.new()
	var cases: Array = [
		[[Vector2i(2, 2), Vector2i(3, 2)], false],
		[[Vector2i(0, 5), Vector2i(5, 5)], true], # Only joined across the x border
		[[Vector2i(3, 0), Vector2i(3, 16)], true], # Only joined across the y border
	]
	for c in cases:
		var cells: Array[Vector2i] = []
		cells.assign(c[0])
		var mask: Dictionary = {cells[0]: true, cells[1]: true}
		for run in range(100):
			rng.seed = run
			var board: Dictionary = Generator.generate_board(W, H, cells, c[1], [2, 2], 10, rng)
			if board.is_empty():
				_fail("%s should make a two-tile board" % str(cells))
				break
			for problem in Checks.solved_violations(board.solved, board.source, mask, W, H, c[1]):
				_fail("two tiles %s: %s" % [cells, problem])
			if Checks.reachable(board.scrambled, board.source, W, H, c[1]).size() == 2:
				_fail("two tiles %s: starts connected" % str(cells))

# Straight tiles look identical after 180 degrees, so a scramble can land on a solved board without
# a single connection differing. This straight line starts in exactly that state.
func _test_already_connected_starts_get_broken() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var solved: Dictionary = {
		Vector2i(1, 3): [0, 1, 0, 0],
		Vector2i(2, 3): [0, 1, 0, 1],
		Vector2i(3, 3): [0, 1, 0, 1],
		Vector2i(4, 3): [0, 0, 0, 1],
	}
	var board: Dictionary = {"width": W, "height": H, "wrap": false, "source": Vector2i(1, 3),
		"solved": solved, "scrambled": solved.duplicate(true)}
	if not Generator.ensure_starts_disconnected(board, rng):
		_fail("should be able to break a connected line")
	if Checks.reachable(board.scrambled, board.source, W, H, false).size() == solved.size():
		_fail("the line still starts connected")
	if board.scrambled[Vector2i(1, 3)] != [0, 1, 0, 0]:
		_fail("breaking a connected start shouldn't need to turn the source")
	var already_broken: Dictionary = {"width": W, "height": H, "wrap": false, "source": Vector2i(1, 3),
		"solved": solved, "scrambled": solved.duplicate(true)}
	already_broken.scrambled[Vector2i(4, 3)] = [1, 0, 0, 0]
	var before: Dictionary = already_broken.scrambled.duplicate(true)
	Generator.ensure_starts_disconnected(already_broken, rng)
	if already_broken.scrambled != before:
		_fail("an already broken start shouldn't change")

# A check that can't fail proves nothing, so feed it one broken board per rule.
func _test_checks_catch_bad_boards() -> void:
	var a := Vector2i(1, 1)
	var b := Vector2i(2, 1)
	var c := Vector2i(1, 2)
	var d := Vector2i(2, 2)
	var mask: Dictionary = {a: true, b: true, c: true, d: true}
	var good: Dictionary = {a: [0, 1, 0, 0], b: [0, 0, 0, 1]}
	if not Checks.solved_violations(good, a, mask, W, H, false).is_empty():
		_fail("board_checks rejected a valid board")
	var bad: Dictionary = {
		"source missing": [{b: [0, 0, 0, 0]}, a],
		"dangling port": [{a: [0, 1, 0, 0]}, a],
		"no reciprocal port": [{a: [0, 1, 0, 0], b: [0, 0, 0, 0]}, a],
		"four ports": [{a: [1, 1, 1, 1]}, a],
		"outside allowed cells": [{a: [1, 0, 0, 0], Vector2i(1, 0): [0, 0, 1, 0]}, a],
		"unreachable tile": [{a: [0, 1, 0, 0], b: [0, 0, 0, 1], c: [0, 1, 0, 0], d: [0, 0, 0, 1]}, a],
		"loop": [{a: [0, 1, 1, 0], b: [0, 0, 1, 1], c: [1, 1, 0, 0], d: [1, 0, 0, 1]}, a],
	}
	for name in bad:
		if Checks.solved_violations(bad[name][0], bad[name][1], mask, W, H, false).is_empty():
			_fail("board_checks missed a broken board: " + name)
	# The same two cells only join across the edge when wrapping is on.
	var across: Dictionary = {Vector2i(0, 0): [0, 0, 0, 1], Vector2i(5, 0): [0, 1, 0, 0]}
	var edge_mask: Dictionary = {Vector2i(0, 0): true, Vector2i(5, 0): true}
	if not Checks.solved_violations(across, Vector2i(0, 0), edge_mask, W, H, true).is_empty():
		_fail("board_checks rejected a valid wrapped board")
	if Checks.solved_violations(across, Vector2i(0, 0), edge_mask, W, H, false).is_empty():
		_fail("board_checks accepted a wrapped board on a non-wrapping grid")

func _free_nodes(puzzle: Dictionary) -> void:
	for column in puzzle.branches:
		for b in column:
			b.free()

func _report(diff: String, allowed: int, rows: Array[Dictionary], starts_connected: int) -> void:
	var avg := func(key: String) -> float:
		var total: float = 0.0
		for row in rows:
			total += row[key]
		return total / rows.size()
	var share := func(key: String) -> float:
		var total: float = 0.0
		for row in rows:
			total += float(row[key]) / row.tiles
		return 100.0 * total / rows.size()
	var tile_counts: Array = rows.map(func(row): return row.tiles)
	var lines: Array = rows.map(func(row): return row.longest_line)
	print("%-10s %7d | %5.1f [%3d..%3d] | %4.1f %4.0f %5.0f %5.0f | %4.1f %3d | %5.0f %7.0f | %5.1f | %d" % [
		diff, allowed, avg.call("tiles"), tile_counts.min(), tile_counts.max(),
		avg.call("tips"), share.call("straight"), share.call("bend"), share.call("three"),
		avg.call("longest_line"), lines.max(),
		100.0 * avg.call("on_long_line"), 100.0 * avg.call("side_by_side"),
		avg.call("depth"), starts_connected])

func _fail(message: String) -> void:
	_failures += 1
	printerr("FAIL: " + message)
