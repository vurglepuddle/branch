extends SceneTree
# The optional turn animation and the sprite pointer. Stage timing uses a fake clock so it can't
# be flaky; one test also runs on the real clock. It never saves settings. Run with tests/run_tests.sh.

const Checks = preload("res://tests/board_checks.gd")
const BranchType = preload("res://scripts/core/branch_types.gd").BranchType
const W: int = 6
const H: int = 17
const SOURCE := Vector2i(1, 1)
const BEND_CELL := Vector2i(2, 1)
const STRAIGHT_CELL := Vector2i(4, 4)
const OTHER_BEND_CELL := Vector2i(4, 2)
const DEFAULT_TILES: Dictionary = {
	SOURCE: [BranchType.TERMINAL, [0, 1, 0, 0]],
	BEND_CELL: [BranchType.BEND, [1, 1, 0, 0]],
	STRAIGHT_CELL: [BranchType.STRAIGHT, [1, 0, 1, 0]],
	OTHER_BEND_CELL: [BranchType.BEND, [1, 1, 0, 0]],
}

var _failures: int = 0
var _settings: Node

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	await process_frame
	_settings = root.get_node("GlobalSettings")
	var saved_setting: bool = _settings.turn_animation
	_settings.give_up_animation = true

	_test_on_by_default()
	_test_turn_sheet_layout()
	_test_pointer()
	await _test_settings_row()

	var grid: Node = await _open_grid()
	_test_instant_when_off(grid)
	_settings.turn_animation = true
	_test_stages(grid)
	_test_every_orientation_uses_the_drawing(grid)
	_test_drawings_match_their_tiles(grid)
	_test_shows_dead_drawing_when_alive(grid)
	_test_remembered_tap(grid)
	_test_stall_skips_ahead(grid)
	_test_state_change_during_turn(grid)
	await _test_real_clock(grid)
	_test_win_cancels_other_turns(grid)
	_close_grid(grid)

	grid = await _open_grid()
	await _test_give_up_cancels_turns(grid)
	_close_grid(grid)

	grid = await _open_grid()
	await _test_reload_during_turn(grid)
	await _test_freed_during_turn(grid)

	_settings.turn_animation = saved_setting
	await process_frame
	print("test_turns: %s" % ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
	quit(1 if _failures > 0 else 0)

func _test_on_by_default() -> void:
	var fresh: Node = load("res://scripts/core/GlobalSettings.gd").new()
	if not fresh.turn_animation:
		_fail("turn animation should be on by default")
	fresh.free()

# A re-export that changes the trim would shift every drawing, so this asks for the table to be checked.
func _test_turn_sheet_layout() -> void:
	var sheet: Texture2D = BranchNode.TURN_SHEET
	var cells: int = BranchNode.TURN_DRAWINGS.size() * 2
	if sheet.get_width() + BranchNode.TURN_SHEET_LEFT_TRIM != cells * BranchNode.TURN_CELL_SIZE.x or sheet.get_height() != BranchNode.TURN_CELL_SIZE.y:
		_fail("branch_turn.png is %dx%d, so TURN_SHEET_LEFT_TRIM or TURN_DRAWINGS in branch.gd needs updating" % [sheet.get_width(), sheet.get_height()])
		return
	var image: Image = sheet.get_image()
	for type in BranchNode.TURN_DRAWINGS:
		for frame in BranchNode._get_turn_textures(type):
			if frame.get_size() != Vector2(BranchNode.TURN_CELL_SIZE):
				_fail("a turn drawing is %s, it should fill the tile" % frame.get_size())
			if image.get_region(Rect2i(frame.region)).is_invisible():
				_fail("a turn cell at %s is blank" % frame.region)

func _test_pointer() -> void:
	var pointer: Sprite2D = _settings._pointer_sprite
	if pointer == null:
		_fail("the pointer sprite was not created")
		return
	if pointer.texture != _settings.POINTER_CURSOR or pointer.centered:
		_fail("the pointer sprite should draw the pointer image from its top-left corner")
	var layer: CanvasLayer = pointer.get_parent()
	for node in root.find_children("*", "CanvasLayer", true, false):
		if node != layer and node.layer >= layer.layer:
			_fail("the pointer draws under %s" % node.name)
	_settings.notification(Node.NOTIFICATION_WM_MOUSE_EXIT)
	if pointer.visible:
		_fail("the pointer should hide when the mouse leaves the window")
	_settings.notification(Node.NOTIFICATION_WM_MOUSE_ENTER)
	if not pointer.visible:
		_fail("the pointer should return when the mouse comes back")

func _test_settings_row() -> void:
	var overlay: Control = load("res://scenes/SettingsOverlay.tscn").instantiate()
	root.add_child(overlay)
	overlay.open()
	await process_frame
	await process_frame
	var locale: Node = root.get_node("Locale")
	if locale.t("turn_anim") == "turn_anim":
		_fail("the Turn Anim label has no translation")
	if overlay.get_node("%TurnAnimValueLabel").text.is_empty():
		_fail("the Turn Anim row has no value")
	overlay.queue_free()

func _test_instant_when_off(grid: Node) -> void:
	_settings.turn_animation = false
	_build_board(grid)
	var bend: Node = _tile(grid, BEND_CELL)
	var before: Array = bend.connections.duplicate()
	grid._on_branch_clicked(BEND_CELL.x, BEND_CELL.y)
	if bend.connections == before or bend.is_turning():
		_fail("with the setting off, a tap should turn the tile immediately")

func _test_stages(grid: Node) -> void:
	_build_board(grid)
	var bend: Node = _tile(grid, BEND_CELL)
	bend.rotation_index = 2
	bend.connections = [0, 0, 1, 1]
	bend.state = "dead"
	bend.update_texture()
	var start_texture: Texture2D = bend.sprite.texture
	var frames: Array = bend._get_turn_textures(BranchType.BEND)
	for frame in frames:
		if frame.get_size() != Vector2(84, 68):
			_fail("a turn drawing is %s, it should fill the 84x68 tile" % frame.get_size())

	bend.start_turn(1000)
	for step in [[1034, start_texture], [1035, frames[0]], [1069, frames[0]], [1070, frames[1]], [1104, frames[1]]]:
		bend._advance_turn(step[0])
		if bend.sprite.texture != step[1]:
			_fail("wrong drawing %d ms into a turn" % (step[0] - 1000))
		if bend.connections != [0, 0, 1, 1]:
			_fail("the tile rotated early, %d ms into a turn" % (step[0] - 1000))
	bend._advance_turn(1105)
	if bend.is_turning() or bend.rotation_index != 3 or bend.connections != [1, 0, 0, 1]:
		_fail("the turn should finish 105 ms in")
	if bend.state != "alive":
		_fail("the turn connected the bend to the source, so it should be alive")
	if bend.sprite.texture != bend.textures[BranchType.BEND]["alive"][3] or bend.sprite.rotation != 0.0 or bend.sprite.scale != Vector2.ONE:
		_fail("the finished tile should show its normal sprite, unrotated and unstretched")

func _test_every_orientation_uses_the_drawing(grid: Node) -> void:
	_build_board(grid)
	var tile: Node = _tile(grid, BEND_CELL)
	var canonical: Dictionary = {
		BranchType.BEND: [1, 1, 0, 0],
		BranchType.TERMINAL: [1, 0, 0, 0],
		BranchType.STRAIGHT: [1, 0, 1, 0],
		BranchType.THREE: [1, 1, 1, 0],
	}
	for type in canonical:
		tile.branch_type = type
		var connections: Array = canonical[type]
		for rotation_index in range(4):
			tile.rotation_index = rotation_index
			tile.connections = connections.duplicate()
			tile.update_texture()
			if not tile.can_animate_turn():
				_fail("tile type %d has no turn drawings" % type)
			tile.start_turn(1000)
			tile._advance_turn(1040)
			var expected: float = deg_to_rad(90.0 * (rotation_index - BranchNode.TURN_DRAWINGS[type]["drawn_rotation"]))
			if not is_equal_approx(tile.sprite.rotation, expected):
				_fail("type %d rotation %d: the drawing is turned %.0f degrees" % [type, rotation_index, rad_to_deg(tile.sprite.rotation)])
			_check_drawing_stays_in_cell(tile, rotation_index)
			tile._advance_turn(1075)
			_check_drawing_stays_in_cell(tile, rotation_index)
			tile.cancel_turn()
			if tile.sprite.rotation != 0.0 or tile.sprite.texture != tile.textures[type][tile.state][rotation_index]:
				_fail("type %d rotation %d: cancelling should restore the normal sprite" % [type, rotation_index])
			connections = tile.rotate_connections(connections)
	tile.branch_type = BranchType.BEND

# TURN_DRAWINGS says which orientation each drawing starts from, and nothing else in the game can
# catch a wrong entry. So this compares pixels: the first drawing should sit nearest its starting
# sprite and the second nearest the sprite it's turning into. Three-way tiles share a lot of ink
# around the centre, so near-ties are allowed.
func _test_drawings_match_their_tiles(grid: Node) -> void:
	var tile: Node = _tile(grid, BEND_CELL)
	for type in BranchNode.TURN_DRAWINGS:
		var start: int = BranchNode.TURN_DRAWINGS[type]["drawn_rotation"]
		var frames: Array = BranchNode._get_turn_textures(type)
		var sprites: Array = tile.textures[type]["dead"]
		for stage in range(2):
			var drawing: Image = frames[stage].get_image()
			drawing.convert(Image.FORMAT_RGBA8)
			var best: int = 0
			for sprite in sprites:
				best = maxi(best, _overlap(drawing, sprite.get_image()))
			var expected: int = (start + stage) % 4
			var score: int = _overlap(drawing, sprites[expected].get_image())
			if score < best * 0.95:
				_fail("type %d drawing %d overlaps sprite %d by %d px, but another orientation by %d px, so its drawn_rotation looks wrong" % [type, stage, expected, score, best])

func _overlap(drawing: Image, sprite: Image) -> int:
	sprite.convert(Image.FORMAT_RGBA8)
	var count: int = 0
	for y in range(drawing.get_height()):
		for x in range(drawing.get_width()):
			if drawing.get_pixel(x, y).a > 0.5 and sprite.get_pixel(x, y).a > 0.5:
				count += 1
	return count

func _check_drawing_stays_in_cell(bend: Node, rotation_index: int) -> void:
	var cell := Rect2(-42, -34, 84, 68).grow(0.01)
	var drawn: Rect2 = bend.sprite.get_rect()
	var corners: Array[Vector2] = [drawn.position, drawn.position + Vector2(drawn.size.x, 0),
		drawn.position + Vector2(0, drawn.size.y), drawn.end]
	for corner in corners:
		if not cell.has_point(bend.sprite.transform * corner):
			_fail("rotation %d: the turn drawing pokes out of its cell at %s" % [rotation_index, bend.sprite.transform * corner])

func _test_shows_dead_drawing_when_alive(grid: Node) -> void:
	_build_board(grid)
	var bend: Node = _tile(grid, BEND_CELL)
	bend.rotation_index = 2
	bend.state = "alive"
	bend.start_turn(1000)
	bend._advance_turn(1040)
	if bend.sprite.texture != bend._get_turn_textures(BranchType.BEND)[0]:
		_fail("an alive tile should show the same turn drawing")
	bend.cancel_turn()

func _test_remembered_tap(grid: Node) -> void:
	_build_board(grid)
	var bend: Node = _tile(grid, BEND_CELL)
	var start_rotation: int = bend.rotation_index
	for _tap in range(3):
		grid._on_branch_clicked(BEND_CELL.x, BEND_CELL.y)
	if bend.accepts_turn():
		_fail("a tile with a remembered tap should ignore more taps")
	var now: int = Time.get_ticks_msec()
	bend._advance_turn(now + 200)
	if bend.rotation_index != (start_rotation + 1) % 4 or not bend.is_turning():
		_fail("the remembered tap should start a second turn")
	bend._advance_turn(now + 400)
	if bend.rotation_index != (start_rotation + 2) % 4 or bend.is_turning():
		_fail("three quick taps should make exactly two turns")

func _test_stall_skips_ahead(grid: Node) -> void:
	_build_board(grid)
	var bend: Node = _tile(grid, BEND_CELL)
	var start_rotation: int = bend.rotation_index
	bend.start_turn(1000)
	bend._advance_turn(5000)
	if bend.rotation_index != (start_rotation + 1) % 4 or bend.is_turning():
		_fail("after a long stall, a turn should just finish, once")

func _test_state_change_during_turn(grid: Node) -> void:
	_build_board(grid)
	var bend: Node = _tile(grid, BEND_CELL)
	bend.start_turn(1000)
	bend._advance_turn(1040)
	var shown: Texture2D = bend.sprite.texture
	bend.set_state("alive" if bend.state == "dead" else "dead")
	if bend.sprite.texture != shown:
		_fail("another tile's turn replaced the drawing mid-turn")
	bend.cancel_turn()

func _test_real_clock(grid: Node) -> void:
	_build_board(grid)
	var bend: Node = _tile(grid, BEND_CELL)
	var start_rotation: int = bend.rotation_index
	grid._on_branch_clicked(BEND_CELL.x, BEND_CELL.y)
	if bend.rotation_index != start_rotation:
		_fail("the tile rotated before its animation")
	var deadline: int = Time.get_ticks_msec() + 2000
	while bend.is_turning() and Time.get_ticks_msec() < deadline:
		await process_frame
	if bend.is_turning() or bend.rotation_index != (start_rotation + 1) % 4:
		_fail("a turn never finished on the real clock")
	_check_state(grid, "after a real turn")

func _test_win_cancels_other_turns(grid: Node) -> void:
	# The turning bend joins source -> bend -> waiting tile. That wins the board while the
	# waiting tile is still mid-turn, and that tile must not rotate afterwards and break the win.
	var waiting_cell := Vector2i(2, 2)
	_build_board(grid, {
		SOURCE: [BranchType.TERMINAL, [0, 1, 0, 0]],
		BEND_CELL: [BranchType.BEND, [0, 1, 1, 0]],
		waiting_cell: [BranchType.BEND, [1, 1, 0, 0]],
	})
	var bend: Node = _tile(grid, BEND_CELL)
	bend.rotation_index = 1
	var waiting: Node = _tile(grid, waiting_cell)
	grid.refresh_connectivity()

	waiting.start_turn(1000)
	bend.start_turn(1000)
	bend._advance_turn(1105)
	if not grid.all_connected:
		_fail("the board should win when the bend finishes turning, it has %s" % str(bend.connections))
	if waiting.is_turning() or waiting.connections != [1, 1, 0, 0] or waiting.rotation_index != 0:
		_fail("a win should cancel other turns and leave those tiles where they were")

func _test_give_up_cancels_turns(grid: Node) -> void:
	_settings.turn_animation = true
	var cells: Array = Checks.current_board(grid.branches).keys()
	var bends: Array = cells.filter(func(cell): return _tile(grid, cell).branch_type == BranchType.BEND)
	if bends.is_empty():
		return
	var cell: Vector2i = bends[0]
	var solved: Dictionary = Checks.solved_board(grid.branches)
	grid._on_branch_clicked(cell.x, cell.y)
	if not _tile(grid, cell).is_turning():
		_fail("the tile should be turning before the give-up")
	Engine.time_scale = 8.0
	grid._on_give_up_requested()
	if _tile(grid, cell).is_turning():
		_fail("giving up should cancel a turn in progress")
	var deadline: int = Time.get_ticks_msec() + 30000
	while not grid.level_won_waiting_for_exit_input and Time.get_ticks_msec() < deadline:
		await process_frame
	Engine.time_scale = 1.0
	for c in solved:
		if _tile(grid, c).connections != solved[c]:
			_fail("give-up left %s unsolved after cancelling a turn" % c)
	grid.level_won_waiting_for_exit_input = false

func _test_reload_during_turn(grid: Node) -> void:
	_settings.turn_animation = true
	_build_board(grid)
	var old_tile: Node = _tile(grid, BEND_CELL)
	grid._on_branch_clicked(BEND_CELL.x, BEND_CELL.y)
	grid.load_level_for_current_difficulty()
	if is_instance_valid(old_tile) and old_tile.is_turning():
		_fail("reloading the board should cancel turns in progress")
	await process_frame
	await process_frame
	_check_state(grid, "after reloading during a turn")

func _test_freed_during_turn(grid: Node) -> void:
	var cells: Array = Checks.current_board(grid.branches).keys()
	var bends: Array = cells.filter(func(cell): return _tile(grid, cell).branch_type == BranchType.BEND)
	if not bends.is_empty():
		grid._on_branch_clicked(bends[0].x, bends[0].y)
	_close_grid(grid)
	for _i in range(20):
		await process_frame

# Empties the grid, then places the given tiles as cell -> [type, connections].
func _build_board(grid: Node, tiles: Dictionary = DEFAULT_TILES) -> void:
	grid.all_connected = false
	grid.is_level_complete_animation_playing = false
	grid.level_won_waiting_for_exit_input = false
	grid._game_hud.locked = false
	grid._cancel_turns()
	for column in grid.branches:
		for b in column:
			var cell := Vector2i(b.grid_x, b.grid_y)
			b.rotation_index = 0
			b.solution_rotation_index = 0
			b.connected_to_source = false
			b.state = "dead"
			if tiles.has(cell):
				b.branch_type = tiles[cell][0]
				b.connections = tiles[cell][1].duplicate()
			else:
				b.branch_type = BranchType.EMPTY
				b.connections = [0, 0, 0, 0]
			b.update_texture()
	grid.source_tile = _tile(grid, SOURCE)
	grid.source_tile.state = "alive"

func _tile(grid: Node, cell: Vector2i) -> Node:
	return grid.branches[cell.x][cell.y]

func _check_state(grid: Node, where: String) -> void:
	var source := Vector2i(grid.source_tile.grid_x, grid.source_tile.grid_y)
	var seen: Dictionary = Checks.reachable(Checks.current_board(grid.branches), source, W, H, grid.is_toroidal_grid)
	for column in grid.branches:
		for b in column:
			var cell := Vector2i(b.grid_x, b.grid_y)
			if (b.state == "alive") != seen.has(cell):
				_fail("%s: tile %s is %s" % [where, cell, b.state])

func _open_grid() -> Node:
	_settings.current_difficulty = "expert"
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
