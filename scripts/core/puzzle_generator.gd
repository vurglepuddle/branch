# In puzzle_generator.gd
extends RefCounted

const BranchType = preload("res://scripts/core/branch_types.gd").BranchType
const Layouts = preload("res://scripts/core/difficulty_layouts.gd")

# Single source of truth for per-difficulty generation settings.
# "size": [width, height]
# "tile_range": [min, max] tiles on a generated board
# "wrap": Left/right and top/bottom edges connect
# "max_gen_attempts": How many boards to try before settling for the largest valid one
const DIFFICULTY_SETTINGS: Dictionary = {
	"baby":    {"size": [6, 17], "tile_range": [7, 7], "wrap": false, "max_gen_attempts": 12},
	"intern":  {"size": [6, 17], "tile_range": [14, 15], "wrap": false, "max_gen_attempts": 12},
	"profi":   {"size": [6, 17], "tile_range": [27, 29], "wrap": false, "max_gen_attempts": 14},
	"master":  {"size": [6, 17], "tile_range": [45, 49], "wrap": false, "max_gen_attempts": 10},
	"expert":  {"size": [6, 17], "tile_range": [87, 98], "wrap": false, "max_gen_attempts": 15},
	"torrero": {"size": [6, 17], "tile_range": [85, 94], "wrap": true, "max_gen_attempts": 15},
}

# How boards grow, one tile at a time. A new tile is weighted 1.0 for a turn and less for carrying
# a line straight on. Limiting lines and discouraging side-by-side ones avoids long fork shapes.
const MAX_STRAIGHT_LINE: int = 7
const STRAIGHT_WEIGHT: float = 0.5
const BESIDE_LINE_WEIGHT: float = 0.6 # Applied per parallel line the new tile would sit beside
const NEWEST_TILE_CHANCE: float = 0.15 # Otherwise grow from a random tile, which branches more
const MIN_PLAYABLE_TILES: int = 2
const DIRECTION_OFFSETS: Array[Vector2i] = [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)] # UP, RIGHT, DOWN, LEFT
const OFF_GRID := Vector2i(-1, -1)
const CANONICAL_CONNECTIONS: Dictionary = {
	BranchType.TERMINAL: [1, 0, 0, 0],
	BranchType.STRAIGHT: [1, 0, 1, 0],
	BranchType.BEND: [1, 1, 0, 0],
	BranchType.THREE: [1, 1, 1, 0],
}

# Builds a playable puzzle for a difficulty: the board as plain data, plus the tile nodes made from it.
# Returns {} if the difficulty's allowed cells can't hold a playable board.
static func create_puzzle(difficulty: String, branch_scene: PackedScene, rng: RandomNumberGenerator = null) -> Dictionary:
	if not DIFFICULTY_SETTINGS.has(difficulty):
		printerr("PuzzleGenerator: Unknown difficulty '%s'." % difficulty)
		return {}
	var settings: Dictionary = DIFFICULTY_SETTINGS[difficulty]
	if rng == null:
		rng = RandomNumberGenerator.new()
		rng.randomize()
	var board: Dictionary = generate_board(settings["size"][0], settings["size"][1], Layouts.get_allowed_cells(difficulty),
		settings["wrap"], settings["tile_range"], settings["max_gen_attempts"], rng)
	if board.is_empty():
		printerr("PuzzleGenerator: The allowed cells for '%s' can't hold a playable board." % difficulty)
		return {}
	board["branches"] = _create_branch_nodes(board, branch_scene)
	board["source_x"] = board["source"].x
	board["source_y"] = board["source"].y
	return board

# Returns plain board data: width, height, wrap, source, solved and scrambled (cell -> connections),
# and construction_order (source first, every tile after the one it grew from). The retry budget
# lives here: the first board in the size range wins, otherwise the largest valid one. Returns {}
# if no attempt made a playable board.
static func generate_board(width: int, height: int, allowed_cells: Array[Vector2i], wrap: bool,
		tile_range: Array, max_attempts: int, rng: RandomNumberGenerator) -> Dictionary:
	if allowed_cells.is_empty():
		return {}
	var allowed: Dictionary = {}
	for cell in allowed_cells:
		allowed[cell] = true

	var min_tiles: int = mini(tile_range[0], allowed.size())
	var best: Dictionary = {}
	for _attempt in range(max_attempts):
		var target: int = mini(rng.randi_range(tile_range[0], tile_range[1]), allowed.size())
		var board: Dictionary = _grow_board(width, height, allowed, allowed_cells, wrap, target, rng)
		var tile_count: int = board["solved"].size()
		if tile_count < MIN_PLAYABLE_TILES or not _is_valid_tree(board, allowed):
			continue
		board["scrambled"] = _scrambled_connections(board["solved"], rng)
		if not ensure_starts_disconnected(board, rng):
			continue
		if tile_count >= min_tiles:
			return board
		if best.is_empty() or tile_count > best["solved"].size():
			best = board
	return best

# Grows a tree from a random source until it reaches target tiles or has nowhere left to go.
# Tiles only join by an edge to one tile already on the board, so loops and dangling ports can't happen.
static func _grow_board(width: int, height: int, allowed: Dictionary, allowed_cells: Array[Vector2i], wrap: bool,
		target: int, rng: RandomNumberGenerator) -> Dictionary:
	var source: Vector2i = allowed_cells[rng.randi_range(0, allowed_cells.size() - 1)]
	var board: Dictionary = {"width": width, "height": height, "wrap": wrap, "source": source,
		"solved": {source: [0, 0, 0, 0]}, "construction_order": [source]}
	var solved: Dictionary = board["solved"]
	var growing: Array[Vector2i] = [source]
	while solved.size() < target and not growing.is_empty():
		var index: int = growing.size() - 1 if rng.randf() < NEWEST_TILE_CHANCE else rng.randi_range(0, growing.size() - 1)
		var tile: Vector2i = growing[index]
		var dir: int = _pick_growth_direction(board, allowed, tile, rng)
		if dir < 0:
			growing.remove_at(index)
			continue
		var new_tile: Vector2i = _neighbor(tile, dir, width, height, wrap)
		solved[tile][dir] = 1
		solved[new_tile] = [0, 0, 0, 0]
		solved[new_tile][(dir + 2) % 4] = 1
		board["construction_order"].append(new_tile)
		growing.append(new_tile)
	return board

# Returns -1 if this tile can't grow any further.
static func _pick_growth_direction(board: Dictionary, allowed: Dictionary, tile: Vector2i, rng: RandomNumberGenerator) -> int:
	var solved: Dictionary = board["solved"]
	var connections: Array = solved[tile]
	if connections[0] + connections[1] + connections[2] + connections[3] >= 3:
		return -1

	var options: Array[int] = []
	var weights: Array[float] = []
	var total_weight: float = 0.0
	for dir in range(4):
		var next: Vector2i = _neighbor(tile, dir, board["width"], board["height"], board["wrap"])
		if next == OFF_GRID or not allowed.has(next) or solved.has(next):
			continue
		var weight: float = 1.0
		if connections[(dir + 2) % 4] == 1:
			if _line_length_ending_at(board, tile, dir) + 1 > MAX_STRAIGHT_LINE:
				continue
			weight = STRAIGHT_WEIGHT
		for side in [(dir + 1) % 4, (dir + 3) % 4]:
			var beside: Vector2i = _neighbor(next, side, board["width"], board["height"], board["wrap"])
			if solved.has(beside) and (solved[beside][dir] == 1 or solved[beside][(dir + 2) % 4] == 1):
				weight *= BESIDE_LINE_WEIGHT
		options.append(dir)
		weights.append(weight)
		total_weight += weight

	if options.is_empty():
		return -1
	var roll: float = rng.randf() * total_weight
	for i in range(options.size()):
		roll -= weights[i]
		if roll <= 0.0:
			return options[i]
	return options[-1]

# Counts the tiles in the straight line ending at this tile, which is heading in direction dir.
static func _line_length_ending_at(board: Dictionary, tile: Vector2i, dir: int) -> int:
	var back: int = (dir + 2) % 4
	var length: int = 1
	var current: Vector2i = tile
	while board["solved"][current][back] == 1:
		current = _neighbor(current, back, board["width"], board["height"], board["wrap"])
		length += 1
	return length

static func _neighbor(cell: Vector2i, dir: int, width: int, height: int, wrap: bool) -> Vector2i:
	var next: Vector2i = cell + DIRECTION_OFFSETS[dir]
	if wrap:
		return Vector2i(posmod(next.x, width), posmod(next.y, height))
	if next.x < 0 or next.x >= width or next.y < 0 or next.y >= height:
		return OFF_GRID
	return next

static func _reachable_from_source(board: Dictionary, connections_by_cell: Dictionary) -> Dictionary:
	var source: Vector2i = board["source"]
	var reachable: Dictionary = {source: true}
	var to_visit: Array[Vector2i] = [source]
	while not to_visit.is_empty():
		var cell: Vector2i = to_visit.pop_back()
		for dir in range(4):
			if connections_by_cell[cell][dir] != 1:
				continue
			var next: Vector2i = _neighbor(cell, dir, board["width"], board["height"], board["wrap"])
			if connections_by_cell.has(next) and connections_by_cell[next][(dir + 2) % 4] == 1 and not reachable.has(next):
				reachable[next] = true
				to_visit.append(next)
	return reachable

static func _is_valid_tree(board: Dictionary, allowed: Dictionary) -> bool:
	var solved: Dictionary = board["solved"]
	var port_count: int = 0
	for cell in solved:
		var degree: int = solved[cell][0] + solved[cell][1] + solved[cell][2] + solved[cell][3]
		if not allowed.has(cell) or degree < 1 or degree > 3:
			return false
		port_count += degree
		for dir in range(4):
			if solved[cell][dir] != 1:
				continue
			var next: Vector2i = _neighbor(cell, dir, board["width"], board["height"], board["wrap"])
			if not solved.has(next) or solved[next][(dir + 2) % 4] != 1:
				return false
	return port_count / 2 == solved.size() - 1 and _reachable_from_source(board, solved).size() == solved.size()

static func _rotated_clockwise(connections: Array) -> Array:
	return [connections[3], connections[0], connections[1], connections[2]]

static func _scrambled_connections(solved: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var scrambled: Dictionary = {}
	for cell in solved:
		var connections: Array = solved[cell].duplicate()
		for _turn in range(rng.randi_range(0, 3)):
			connections = _rotated_clockwise(connections)
		scrambled[cell] = connections
	return scrambled

# A scramble can land on a connected board, including through a straight tile's 180-degree twin, so
# this checks actual connectivity. It turns tiles one at a time until the board is broken, and
# returns false if it can't be.
static func ensure_starts_disconnected(board: Dictionary, rng: RandomNumberGenerator) -> bool:
	var scrambled: Dictionary = board["scrambled"]
	if _reachable_from_source(board, scrambled).size() < scrambled.size():
		return true
	var cells: Array = scrambled.keys()
	cells.erase(board["source"])
	var offset: int = rng.randi_range(0, cells.size() - 1)
	for i in range(cells.size()):
		var cell: Vector2i = cells[(offset + i) % cells.size()]
		scrambled[cell] = _rotated_clockwise(scrambled[cell])
		if _reachable_from_source(board, scrambled).size() < scrambled.size():
			return true
	return false

static func _tile_type_for(connections: Array) -> BranchType:
	match connections[0] + connections[1] + connections[2] + connections[3]:
		1: return BranchType.TERMINAL
		3: return BranchType.THREE
	if connections[0] == connections[2]:
		return BranchType.STRAIGHT
	return BranchType.BEND

static func _rotations_from_canonical(type: BranchType, connections: Array) -> int:
	var current: Array = CANONICAL_CONNECTIONS[type]
	for rotation_count in range(4):
		if current == connections:
			return rotation_count
		current = _rotated_clockwise(current)
	return 0

# The boundary between plain board data and scene nodes: fills the grid the rest of the game expects.
static func _create_branch_nodes(board: Dictionary, branch_scene: PackedScene) -> Array:
	var grid: Array = []
	for x in range(board["width"]):
		var column: Array = []
		for y in range(board["height"]):
			var cell := Vector2i(x, y)
			var branch: Node = branch_scene.instantiate()
			branch.grid_x = x
			branch.grid_y = y
			branch.rotation_index = 0
			branch.solution_rotation_index = 0
			if board["scrambled"].has(cell):
				var type: BranchType = _tile_type_for(board["solved"][cell])
				branch.branch_type = type
				branch.connections = board["scrambled"][cell].duplicate()
				branch.rotation_index = _rotations_from_canonical(type, board["scrambled"][cell])
				branch.solution_rotation_index = _rotations_from_canonical(type, board["solved"][cell])
			else:
				branch.branch_type = BranchType.EMPTY
				branch.connections = [0, 0, 0, 0]
			var is_source: bool = cell == board["source"]
			branch.state = "alive" if is_source else "dead"
			branch.connected_to_source = is_source
			column.append(branch)
		grid.append(column)
	return grid
