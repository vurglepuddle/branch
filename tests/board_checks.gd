extends RefCounted
# Checks on puzzle boards, shared by the test scripts. A board here is plain data:
# a Dictionary of Vector2i cell -> connections [UP, RIGHT, DOWN, LEFT].

const BranchType = preload("res://scripts/core/branch_types.gd").BranchType
const DIRS: Array[Vector2i] = [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]
const OFF_GRID := Vector2i(-1, -1)
const CANONICAL := {
	BranchType.TERMINAL: [1, 0, 0, 0],
	BranchType.STRAIGHT: [1, 0, 1, 0],
	BranchType.BEND: [1, 1, 0, 0],
	BranchType.THREE: [1, 1, 1, 0],
}

static func neighbor(cell: Vector2i, dir: int, w: int, h: int, wrap: bool) -> Vector2i:
	var n: Vector2i = cell + DIRS[dir]
	if wrap:
		return Vector2i(posmod(n.x, w), posmod(n.y, h))
	if n.x < 0 or n.x >= w or n.y < 0 or n.y >= h:
		return OFF_GRID
	return n

static func rotate_clockwise(c: Array) -> Array:
	return [c[3], c[0], c[1], c[2]]

# Cells reachable from source over reciprocal connections.
static func reachable(board: Dictionary, source: Vector2i, w: int, h: int, wrap: bool) -> Dictionary:
	var seen: Dictionary = {}
	if not board.has(source):
		return seen
	seen[source] = true
	var queue: Array[Vector2i] = [source]
	var head: int = 0
	while head < queue.size():
		var cell: Vector2i = queue[head]
		head += 1
		for dir in range(4):
			if board[cell][dir] != 1:
				continue
			var n: Vector2i = neighbor(cell, dir, w, h, wrap)
			if n != OFF_GRID and board.has(n) and board[n][(dir + 2) % 4] == 1 and not seen.has(n):
				seen[n] = true
				queue.append(n)
	return seen

# Everything a solved board must satisfy. Returns human-readable problems; empty means valid.
static func solved_violations(board: Dictionary, source: Vector2i, mask: Dictionary, w: int, h: int, wrap: bool) -> Array[String]:
	var problems: Array[String] = []
	if not board.has(source):
		problems.append("source %s is not an occupied tile" % source)
		return problems
	var port_count: int = 0
	for cell in board:
		if not mask.has(cell):
			problems.append("tile %s is outside the allowed cells" % cell)
		var c: Array = board[cell]
		var degree: int = c[0] + c[1] + c[2] + c[3]
		port_count += degree
		if degree < 1 or degree > 3:
			problems.append("tile %s has %d ports" % [cell, degree])
		for dir in range(4):
			if c[dir] != 1:
				continue
			var n: Vector2i = neighbor(cell, dir, w, h, wrap)
			if n == OFF_GRID or not board.has(n):
				problems.append("tile %s has a dangling port %d" % [cell, dir])
			elif board[n][(dir + 2) % 4] != 1:
				problems.append("tile %s port %d is not reciprocated by %s" % [cell, dir, n])
	if port_count / 2 != board.size() - 1:
		problems.append("%d edges for %d tiles (a tree has N-1)" % [port_count / 2, board.size()])
	var seen: Dictionary = reachable(board, source, w, h, wrap)
	if seen.size() != board.size():
		problems.append("only %d of %d tiles reachable from the source" % [seen.size(), board.size()])
	return problems

# Node-level agreement between type, rotation_index and connections.
static func node_violations(branches: Array) -> Array[String]:
	var problems: Array[String] = []
	for x in range(branches.size()):
		for y in range(branches[x].size()):
			var b = branches[x][y]
			if b == null:
				problems.append("null tile at %d,%d" % [x, y])
				continue
			if b.grid_x != x or b.grid_y != y:
				problems.append("tile at %d,%d thinks it is at %d,%d" % [x, y, b.grid_x, b.grid_y])
			if b.branch_type == BranchType.EMPTY:
				if b.connections != [0, 0, 0, 0]:
					problems.append("empty tile at %d,%d has ports" % [x, y])
				continue
			var expected: Array = CANONICAL[b.branch_type]
			for _i in range(b.rotation_index):
				expected = rotate_clockwise(expected)
			if b.connections != expected:
				problems.append("tile at %d,%d: rotation_index %d does not match connections %s" % [x, y, b.rotation_index, b.connections])
	return problems

static func current_board(branches: Array) -> Dictionary:
	var board: Dictionary = {}
	for x in range(branches.size()):
		for y in range(branches[x].size()):
			var b = branches[x][y]
			if b != null and b.branch_type != BranchType.EMPTY:
				board[Vector2i(x, y)] = b.connections.duplicate()
	return board

static func solved_board(branches: Array) -> Dictionary:
	var board: Dictionary = {}
	for x in range(branches.size()):
		for y in range(branches[x].size()):
			var b = branches[x][y]
			if b == null or b.branch_type == BranchType.EMPTY:
				continue
			var c: Array = b.connections.duplicate()
			for _i in range((b.solution_rotation_index - b.rotation_index + 4) % 4):
				c = rotate_clockwise(c)
			board[Vector2i(x, y)] = c
	return board

# Shape numbers for a solved board. "side_by_side" is the share of tiles on a straight line
# of 4+ with another such line directly beside it: the long-fork look.
static func shape(board: Dictionary, source: Vector2i, w: int, h: int, wrap: bool) -> Dictionary:
	var result := {"tiles": board.size(), "tips": 0, "straight": 0, "bend": 0, "three": 0,
		"longest_line": 0, "on_long_line": 0.0, "side_by_side": 0.0, "depth": 0}
	for cell in board:
		var c: Array = board[cell]
		match c[0] + c[1] + c[2] + c[3]:
			1: result.tips += 1
			3: result.three += 1
			2:
				if (c[0] == 1 and c[2] == 1) or (c[1] == 1 and c[3] == 1):
					result.straight += 1
				else:
					result.bend += 1

	var on_long: Dictionary = {}
	var beside: Dictionary = {}
	# [backward, forward, sideways, sideways] for vertical then horizontal lines
	for axis in [[0, 2, 1, 3], [3, 1, 0, 2]]:
		var line_of: Dictionary = {}
		var line_lengths: Array[int] = []
		for cell in board:
			if board[cell][axis[1]] != 1 or board[cell][axis[0]] == 1:
				continue
			var cells: Array[Vector2i] = [cell]
			var cur: Vector2i = cell
			while board[cur][axis[1]] == 1:
				cur = neighbor(cur, axis[1], w, h, wrap)
				cells.append(cur)
			var id: int = line_lengths.size()
			line_lengths.append(cells.size())
			for k in cells:
				line_of[k] = id
				if cells.size() >= 5:
					on_long[k] = true
			result.longest_line = maxi(result.longest_line, cells.size())
		for cell in line_of:
			if line_lengths[line_of[cell]] < 4:
				continue
			for side in [axis[2], axis[3]]:
				var n: Vector2i = neighbor(cell, side, w, h, wrap)
				if line_of.has(n) and line_of[n] != line_of[cell] and line_lengths[line_of[n]] >= 4:
					beside[cell] = true
	result.on_long_line = float(on_long.size()) / board.size()
	result.side_by_side = float(beside.size()) / board.size()

	var dist: Dictionary = {source: 0}
	var queue: Array[Vector2i] = [source]
	var head: int = 0
	while head < queue.size():
		var cell: Vector2i = queue[head]
		head += 1
		for dir in range(4):
			if board[cell][dir] != 1:
				continue
			var n: Vector2i = neighbor(cell, dir, w, h, wrap)
			if not dist.has(n):
				dist[n] = dist[cell] + 1
				result.depth = maxi(result.depth, dist[n])
				queue.append(n)
	return result
