extends SceneTree
# Generates many boards per difficulty, fails on anything invalid, and prints shape numbers.
# Run with tests/run_tests.sh. Pass a board count after "--" to change the default.

const Checks = preload("res://tests/board_checks.gd")
const Generator = preload("res://scripts/core/puzzle_generator.gd")
const Layouts = preload("res://scripts/core/difficulty_layouts.gd")
const BranchScene: PackedScene = preload("res://scenes/Branch.tscn")
const DIFFICULTIES: Array[String] = ["baby", "intern", "profi", "master", "expert", "torrero"]
const W: int = 6
const H: int = 17

var _failures: int = 0

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	await process_frame
	_test_checks_catch_bad_boards()
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var runs: int = int(args[0]) if args.size() > 0 else 200
	var layouts: Node = Layouts.new()
	var generator: Node = Generator.new()

	print("difficulty allowed | tiles avg [min..max] | tips str% bend% 3way% | line avg max | on5+% beside% | depth | starts connected")
	for diff in DIFFICULTIES:
		seed(hash(diff) + 2026)
		var valid_cells: Dictionary = layouts.get_valid_cells(diff)
		var mask: Dictionary = {}
		for key in valid_cells:
			var parts: PackedStringArray = key.split(",")
			mask[Vector2i(int(parts[0]), int(parts[1]))] = true
		var wrap: bool = diff == "torrero"
		var rows: Array[Dictionary] = []
		var starts_connected: int = 0
		for run in range(runs):
			var puzzle: Dictionary = _generate(generator, diff, valid_cells, wrap)
			var source := Vector2i(puzzle.source_x, puzzle.source_y)
			var solved: Dictionary = Checks.solved_board(puzzle.branches)
			var problems: Array[String] = Checks.solved_violations(solved, source, mask, W, H, wrap)
			problems.append_array(Checks.node_violations(puzzle.branches))
			for problem in problems:
				_fail("%s board %d: %s" % [diff, run, problem])
			rows.append(Checks.shape(solved, source, W, H, wrap))
			if Checks.reachable(Checks.current_board(puzzle.branches), source, W, H, wrap).size() == solved.size():
				starts_connected += 1
			generator.free_puzzle_nodes(puzzle)
		_report(diff, mask.size(), rows, starts_connected)

	generator.free()
	layouts.free()
	var orphans: int = int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))
	if orphans != 0:
		_fail("%d orphan nodes left after freeing every board" % orphans)
	print("test_generator: %s" % ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
	quit(1 if _failures > 0 else 0)

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

# Same retry policy the menu uses today.
func _generate(generator: Node, diff: String, valid_cells: Dictionary, wrap: bool) -> Dictionary:
	var s: Dictionary = Generator.DIFFICULTY_SETTINGS[diff]
	var base: int = int(floor(valid_cells.size() * s.final_target_density_factor))
	var minimum: int = clampi(base - int(floor(base * s.final_density_variation_factor)), 1, valid_cells.size())
	var best: Dictionary = {}
	var best_count: int = -1
	for _attempt in range(int(s.max_gen_attempts)):
		var candidate: Dictionary = generator.generate_solvable_puzzle(W, H, BranchScene,
			s.prim_initial_density_factor, s.prim_min_tiles, wrap, valid_cells)
		var count: int = generator.get_active_tile_count(candidate)
		var solved: bool = generator.is_puzzle_initially_solved(candidate)
		if not solved and count >= minimum:
			if not best.is_empty():
				generator.free_puzzle_nodes(best)
			return candidate
		if not solved and count > best_count:
			if not best.is_empty():
				generator.free_puzzle_nodes(best)
			best = candidate
			best_count = count
		else:
			generator.free_puzzle_nodes(candidate)
	return best

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
