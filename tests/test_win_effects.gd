extends SceneTree
# The win celebration. Timing runs on a fake clock, so these 100-second sequences finish instantly and
# can't be flaky. A final test plays a real win through the grid. Run with tests/run_tests.sh.

const Checks = preload("res://tests/board_checks.gd")
const WinEffects = preload("res://scripts/core/win_effects.gd")
const BranchType = preload("res://scripts/core/branch_types.gd").BranchType
const TICK_MS: int = 16

var _failures: int = 0
var _settings: Node

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	await process_frame
	_settings = root.get_node("GlobalSettings")
	_settings.turn_animation = false

	var grid: Node = await _open_grid("expert")
	var tips: Array = _terminal_tiles(grid)
	if tips.size() < 6:
		_fail("the test board needs at least 6 tips, it has %d" % tips.size())
	_test_each_direction_uses_its_own_art(grid)
	_test_flower_schedule(grid, tips)
	_reset_tiles(tips)
	_test_stall_takes_one_step(grid, tips)
	_reset_tiles(tips)
	_test_exit_allowed_at_two_seconds(grid, tips)
	_reset_tiles(tips)
	_test_glints(grid, tips)
	_reset_tiles(tips)
	_test_glint_slots_capped_by_tips(grid, tips)
	_reset_tiles(tips)
	_test_stop_hides_glints(grid, tips)
	_reset_tiles(tips)
	_test_glint_sound(grid, tips)
	_close_grid(grid)

	_test_glint_slots_per_difficulty()
	await _test_real_win_and_leaving()
	await _test_freeing_the_scene_mid_celebration()

	await process_frame
	print("test_win_effects: %s" % ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
	quit(1 if _failures > 0 else 0)

func _test_each_direction_uses_its_own_art(grid: Node) -> void:
	var tile: Node = _terminal_tiles(grid)[0]
	var saved: Array = tile.connections
	var anim: AnimatedSprite2D = tile.get_node("AnimatedSprite2D")
	var star: AnimatedSprite2D = tile.get_node("FruitStar")
	if star.z_index + star.get_parent().z_index <= anim.z_index + anim.get_parent().z_index:
		_fail("the glint should draw above the fruit")
	var cases: Dictionary = {"down": [1, 0, 0, 0], "left": [0, 1, 0, 0], "up": [0, 0, 1, 0], "right": [0, 0, 0, 1]}
	for direction in cases:
		tile.connections = cases[direction]
		var blossom: String = direction + "_blossom"
		var fruit: String = direction + "_fruiting"
		tile.show_flower_pose(0)
		_expect(anim.animation == blossom and anim.frame == 0 and anim.visible, "%s pose 0 should be the first blossom frame" % direction)
		tile.show_flower_pose(tile.FULL_BLOOM_POSE)
		var last_blossom: int = anim.sprite_frames.get_frame_count(blossom) - 1
		_expect(anim.animation == blossom and anim.frame == last_blossom, "%s full bloom should hold the last blossom frame" % direction)
		tile.show_flower_pose(tile.FULL_BLOOM_POSE + 1)
		_expect(anim.animation == fruit and anim.frame == 0, "%s should start ripening at the first fruit frame" % direction)
		tile.show_flower_pose(WinEffects.LAST_STEP - 1)
		var last_fruit: int = anim.sprite_frames.get_frame_count(fruit) - 1
		_expect(anim.animation == fruit and anim.frame == last_fruit, "%s should finish on the last fruit frame" % direction)
		# The glint must land on the fruit, so compare the table with the art itself.
		var image: Image = anim.sprite_frames.get_frame_texture(fruit, last_fruit).get_image()
		var ink: Rect2i = image.get_used_rect()
		var ink_centre := Vector2(ink.get_center()) - Vector2(image.get_size()) / 2.0
		if ink_centre.distance_to(tile.FRUIT_CENTERS[direction]) > 3.0:
			_fail("%s fruit is centred at %s, but the glint goes to %s" % [direction, ink_centre, tile.FRUIT_CENTERS[direction]])
		tile.show_glint(0)
		_expect(star.position == tile.FRUIT_CENTERS[direction], "%s glint should sit on its fruit" % direction)
		tile.hide_glint()
	tile.connections = saved
	anim.visible = false
	var star_frames: int = star.sprite_frames.get_frame_count("FruitStar")
	_expect(star_frames == WinEffects.GLINT_STAGES, "the star sheet has %d frames, the glint plays %d" % [star_frames, WinEffects.GLINT_STAGES])

func _test_flower_schedule(grid: Node, tips: Array) -> void:
	var effects: Node = _new_effects(grid, 5)
	effects.start(tips, 0, 0)
	var finished_signals: Array[int] = []
	effects.all_tips_finished.connect(func(): finished_signals.append(1))
	var anims: Array = tips.map(func(t): return t.get_node("AnimatedSprite2D"))
	var first_seen: Dictionary = {}
	var ripening_seen: Dictionary = {}
	var finished_at: int = -1
	var now: int = 0
	while now < 40000 and finished_at < 0:
		now += TICK_MS
		effects.advance(now)
		for i in range(anims.size()):
			var anim: AnimatedSprite2D = anims[i]
			if anim.visible and not first_seen.has(i):
				first_seen[i] = now
			if anim.visible and String(anim.animation).ends_with("_fruiting") and not ripening_seen.has(i):
				ripening_seen[i] = now
		if not finished_signals.is_empty():
			finished_at = now

	if finished_at < 0:
		_fail("the flowers never finished")
		effects.queue_free()
		return
	var starts: Array = first_seen.values()
	# Tips drift apart a little anyway from their random steps, so a real stagger has to be wider.
	_expect(starts.max() - starts.min() >= 1000, "tips should start well apart, but they span only %d ms" % (starts.max() - starts.min()))
	_expect(starts.max() <= (WinEffects.MAX_START_DELAY_STEPS + 1) * (WinEffects.OPENING_STEP_MAX_MS + TICK_MS), "a tip started too late, at %d ms" % starts.max())
	var longest_opening_ms: int = 20 * (WinEffects.OPENING_STEP_MAX_MS + TICK_MS)
	var holds: Array[int] = []
	for i in first_seen:
		if not ripening_seen.has(i):
			_fail("a tip finished without ever ripening")
			continue
		var opening_and_hold: int = ripening_seen[i] - first_seen[i]
		holds.append(opening_and_hold)
		if opening_and_hold < WinEffects.FULL_BLOOM_HOLD_MIN_MS or opening_and_hold > WinEffects.FULL_BLOOM_HOLD_MAX_MS + longest_opening_ms:
			_fail("a tip took %d ms from opening to ripening" % opening_and_hold)
	if not holds.is_empty():
		# The first tip to open gets the shortest hold, and the others have to spread out after it.
		var first_tip: int = first_seen.keys().reduce(func(a, b): return a if first_seen[a] <= first_seen[b] else b)
		var first_hold: int = ripening_seen[first_tip] - first_seen[first_tip]
		_expect(first_hold <= WinEffects.FULL_BLOOM_HOLD_MIN_MS + longest_opening_ms, "the first tip to open held for %d ms, it should hold for the minimum" % first_hold)
		_expect(holds.max() - holds.min() >= 2000, "holds should be staggered, but they span only %d ms" % (holds.max() - holds.min()))
	_expect(finished_signals.size() == 1, "all_tips_finished should fire once, not %d times" % finished_signals.size())
	var ripening_starts: Array = ripening_seen.values()
	if not ripening_starts.is_empty():
		_expect(finished_at >= ripening_starts.max() + 1500, "the sequence ended before the last fruit ripened")
	for anim in anims:
		var last: int = anim.sprite_frames.get_frame_count(anim.animation) - 1
		_expect(String(anim.animation).ends_with("_fruiting") and anim.frame == last, "every tip should end on its finished fruit")
	# The fruit stays once it's finished.
	var kept: int = anims[0].frame
	for _i in range(200):
		now += TICK_MS
		effects.advance(now)
	_expect(anims[0].frame == kept and anims[0].visible, "the finished fruit should stay on screen")
	effects.queue_free()

func _test_stall_takes_one_step(grid: Node, tips: Array) -> void:
	var effects: Node = _new_effects(grid, 9)
	effects.start(tips, 0, 0)
	var before: int = effects._tips[0]["step"]
	effects.advance(60000)
	_expect(effects._tips[0]["step"] == before + 1, "after a long stall a tip should take one step, not catch up")
	effects.queue_free()

func _test_exit_allowed_at_two_seconds(grid: Node, tips: Array) -> void:
	var effects: Node = _new_effects(grid, 3)
	var allowed_at: Array[int] = []
	effects.exit_allowed.connect(func(): allowed_at.append(1))
	effects.start(tips, 0, 1000)
	effects.advance(1000 + WinEffects.EXIT_ALLOWED_AFTER_MS - 1)
	_expect(allowed_at.is_empty(), "leaving shouldn't be allowed before 2 seconds")
	effects.advance(1000 + WinEffects.EXIT_ALLOWED_AFTER_MS)
	_expect(allowed_at.size() == 1, "leaving should be allowed at 2 seconds")
	effects.advance(1000 + WinEffects.EXIT_ALLOWED_AFTER_MS + 500)
	_expect(allowed_at.size() == 1, "exit_allowed should only fire once")
	effects.queue_free()

func _test_glints(grid: Node, tips: Array) -> void:
	var slots: int = 3
	var effects: Node = _new_effects(grid, 4)
	effects.start(tips, slots, 0)
	var now: int = _run_until_flowers_finish(effects)
	var stars: Array = tips.map(func(t): return t.get_node("FruitStar"))
	var fruit_frames: Array = tips.map(func(t): return t.get_node("AnimatedSprite2D").frame)
	var began: Dictionary = {}
	var sequences: int = 0
	var most_at_once: int = 0
	var stage_orders_ok: bool = true
	var last_stage: Dictionary = {}
	var durations: Array[int] = []
	var last_start: int = -1
	var closest_start: int = 1000000
	var end_time: int = now + WinEffects.GLINT_LIFETIME_MS - 1000
	while now < end_time:
		now += TICK_MS
		effects.advance(now)
		var showing: int = 0
		for i in range(stars.size()):
			var star: AnimatedSprite2D = stars[i]
			if star.visible:
				showing += 1
				if not began.has(i):
					began[i] = now
					last_stage[i] = star.frame
					sequences += 1
					if last_start >= 0:
						closest_start = mini(closest_start, now - last_start)
					last_start = now
					if star.frame != 0:
						stage_orders_ok = false
				elif star.frame < last_stage[i]:
					# A second glint right after the first on the same fruit, which is intended.
					if star.frame != 0:
						stage_orders_ok = false
					durations.append(now - began[i])
					began[i] = now
					last_stage[i] = star.frame
					sequences += 1
				else:
					last_stage[i] = star.frame
			elif began.has(i):
				durations.append(now - began[i])
				began.erase(i)
		most_at_once = maxi(most_at_once, showing)
	# Each slot averages one glint about every 4 seconds, and the old rate was one about every 2.
	var seconds: float = (WinEffects.GLINT_LIFETIME_MS - 1000) / 1000.0
	var seconds_per_glint: float = seconds * slots / max(sequences, 1)
	_expect(seconds_per_glint > 3.0 and seconds_per_glint < 5.0, "each slot glints every %.1f s, it should be about 4" % seconds_per_glint)
	_expect(closest_start < 700, "glints should sometimes land close together, the closest were %d ms apart" % closest_start)
	_expect(most_at_once > 0 and most_at_once <= slots, "at most %d glints should show at once, saw %d" % [slots, most_at_once])
	var waits: Array = range(200).map(func(_i): return effects._glint_wait())
	_expect(waits.min() < 1000 and waits.max() > 5000, "glint waits should vary widely, they ran from %d to %d ms" % [waits.min(), waits.max()])
	_expect(stage_orders_ok, "a glint should play its stages in order from the start")
	var expected_ms: int = WinEffects.GLINT_STAGES * WinEffects.GLINT_STAGE_MS
	_expect(durations.min() >= expected_ms - TICK_MS and durations.max() <= expected_ms + TICK_MS * 2, "glints lasted %d to %d ms, expected about %d" % [durations.min(), durations.max(), expected_ms])
	_expect(tips.map(func(t): return t.get_node("AnimatedSprite2D").frame) == fruit_frames, "glints shouldn't change the fruit")

	# The effect ends by itself, leaving the fruit up and every star hidden.
	for _i in range(200):
		now += TICK_MS
		effects.advance(now)
	_expect(stars.all(func(s): return not s.visible), "glints should stop after their lifetime")
	var stopped_at: int = now
	while now < stopped_at + 5000:
		now += TICK_MS
		effects.advance(now)
	_expect(stars.all(func(s): return not s.visible), "glints shouldn't start again after their lifetime")
	effects.queue_free()

func _test_glint_slots_capped_by_tips(grid: Node, tips: Array) -> void:
	var effects: Node = _new_effects(grid, 6)
	var two_tips: Array = tips.slice(0, 2)
	effects.start(two_tips, 5, 0)
	var now: int = _run_until_flowers_finish(effects)
	_expect(effects._glint_slots.size() == 2, "two tips should only get two glint slots")
	var most: int = 0
	var end_time: int = now + 30000
	while now < end_time:
		now += TICK_MS
		effects.advance(now)
		var showing: int = two_tips.filter(func(t): return t.get_node("FruitStar").visible).size()
		most = maxi(most, showing)
	_expect(most > 0 and most <= 2, "two tips showed %d glints at once" % most)
	effects.queue_free()

func _test_stop_hides_glints(grid: Node, tips: Array) -> void:
	var effects: Node = _new_effects(grid, 7)
	effects.start(tips, 5, 0)
	var now: int = _run_until_flowers_finish(effects)
	var stars: Array = tips.map(func(t): return t.get_node("FruitStar"))
	var deadline: int = now + 20000
	while now < deadline and stars.all(func(s): return not s.visible):
		now += TICK_MS
		effects.advance(now)
	_expect(stars.any(func(s): return s.visible), "a glint should have appeared")
	effects.stop()
	_expect(stars.all(func(s): return not s.visible), "stopping should hide every glint")
	effects.advance(now + 5000)
	_expect(stars.all(func(s): return not s.visible), "nothing should run after stopping")
	effects.queue_free()

func _test_glint_sound(grid: Node, tips: Array) -> void:
	var effects: Node = _new_effects(grid, 8)
	var heard: Array[Node] = []
	effects.glint_started.connect(func(tile): heard.append(tile))
	effects.start(tips, 3, 0)
	var now: int = _run_until_flowers_finish(effects)
	_expect(heard.is_empty(), "no glint should sound before the fruit is finished")
	var appearances: int = 0
	var was_visible: Dictionary = {}
	var end_time: int = now + 20000
	while now < end_time:
		now += TICK_MS
		effects.advance(now)
		for tile in tips:
			var visible_now: bool = tile.get_node("FruitStar").visible
			if visible_now and not was_visible.get(tile, false):
				appearances += 1
			was_visible[tile] = visible_now
	_expect(appearances > 3, "not enough glints appeared to test the sound")
	# A double glint sounds twice without the star ever hiding, so sounds can outnumber appearances.
	_expect(heard.size() >= appearances, "%d glints appeared but only %d asked for a sound" % [appearances, heard.size()])
	effects.queue_free()

	var audio: Node = root.get_node("AudioManager")
	var saved_sfx: bool = audio.sfx_enabled
	audio.sfx_enabled = true
	var pitches: Dictionary = {}
	for tile in tips:
		for _i in range(4):
			grid._on_glint_started(tile)
			pitches[audio.sfx_player.pitch_scale] = true
	_expect(audio.sfx_player.stream == audio.star_twinkle_sound, "a glint should play the title screen's plink")
	_expect(pitches.size() > 5, "glint sounds should vary in pitch, heard %d different pitches" % pitches.size())
	audio.sfx_player.stream = null
	audio.sfx_enabled = false
	grid._on_glint_started(tips[0])
	_expect(audio.sfx_player.stream == null, "a glint shouldn't make a sound with SFX off")
	audio.sfx_enabled = saved_sfx

func _test_glint_slots_per_difficulty() -> void:
	var expected: Dictionary = {"baby": 1, "intern": 2, "profi": 3, "master": 4, "expert": 5, "torrero": 5}
	_expect(WinEffects.GLINT_SLOTS == expected, "glint slots per difficulty changed: %s" % str(WinEffects.GLINT_SLOTS))

# A real win through the grid, on the real clock.
func _test_real_win_and_leaving() -> void:
	var grid: Node = await _open_grid("baby")
	_solve_by_clicking(grid)
	if not grid.all_connected:
		_fail("the board should have won")
		_close_grid(grid)
		return
	await process_frame
	_expect(is_instance_valid(grid._win_effects), "a win should start the effects")
	_expect(grid._win_effects.glint_started.is_connected(grid._on_glint_started), "a real win should play the glint sound")
	_expect(not grid.level_won_waiting_for_exit_input, "leaving shouldn't be allowed straight after a win")
	var tap := InputEventMouseButton.new()
	tap.pressed = true
	tap.button_index = MOUSE_BUTTON_LEFT
	grid._input(tap)
	_expect(grid.all_connected and not grid.level_won_waiting_for_exit_input, "an early tap shouldn't leave")

	var started: int = Time.get_ticks_msec()
	if not await _wait_for(func(): return grid.level_won_waiting_for_exit_input, "leaving to be allowed"):
		_close_grid(grid)
		return
	var seconds: float = (Time.get_ticks_msec() - started) / 1000.0
	_expect(seconds > 1.5 and seconds < 2.6, "leaving became possible after %.2f s" % seconds)
	var effects: Node = grid._win_effects
	# Tips stagger their starts, so a small board can still be waiting on its first flower here.
	await _wait_for(func(): return _terminal_tiles(grid).any(func(t): return t.get_node("AnimatedSprite2D").visible), "the first flower to open")

	var grid_id: int = grid.get_instance_id()
	grid._input(tap)
	_expect(not is_instance_valid(grid._win_effects) or grid._win_effects == null, "leaving should stop the effects")
	_expect(not is_instance_valid(effects) or effects.is_queued_for_deletion(), "the effects node should be cleaned up")
	if await _wait_for(func(): return not is_instance_id_valid(grid_id), "the grid to hand over to the menu"):
		var menu: Node = current_scene
		_expect(menu != null and menu.scene_file_path == "res://scenes/main_menu.tscn", "a win should end on the menu")
		await process_frame
		if menu != null:
			current_scene = null
			menu.queue_free()
			await process_frame

# Freeing the scene mid-celebration must not leave anything running or logging errors.
func _test_freeing_the_scene_mid_celebration() -> void:
	var grid: Node = await _open_grid("baby")
	_solve_by_clicking(grid)
	await process_frame
	await process_frame
	_close_grid(grid)
	for _i in range(30):
		await process_frame

func _solve_by_clicking(grid: Node) -> void:
	var solved: Dictionary = Checks.solved_board(grid.branches)
	for cell in solved:
		var turns: int = 0
		while not grid.all_connected and grid.branches[cell.x][cell.y].connections != solved[cell] and turns < 4:
			grid._on_branch_clicked(cell.x, cell.y)
			turns += 1
		if grid.all_connected:
			return

func _new_effects(grid: Node, seed_value: int) -> Node:
	var effects: Node = WinEffects.new()
	grid.add_child(effects)
	effects.set_process(false)
	effects.rng.seed = seed_value
	return effects

func _run_until_flowers_finish(effects: Node) -> int:
	var now: int = 0
	while not effects._all_finished and now < 60000:
		now += TICK_MS
		effects.advance(now)
	if not effects._all_finished:
		_fail("the flowers never finished")
	return now

func _reset_tiles(tips: Array) -> void:
	for tile in tips:
		tile.get_node("AnimatedSprite2D").visible = false
		tile.get_node("FruitStar").visible = false

func _terminal_tiles(grid: Node) -> Array:
	var tiles: Array = []
	for column in grid.branches:
		for b in column:
			if b.branch_type == BranchType.TERMINAL:
				tiles.append(b)
	return tiles

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

func _wait_for(condition: Callable, what: String) -> bool:
	var deadline: int = Time.get_ticks_msec() + 15000
	while not condition.call():
		if Time.get_ticks_msec() > deadline:
			_fail("timed out waiting for " + what)
			return false
		await process_frame
	return true

func _expect(condition: bool, message: String) -> void:
	if not condition:
		_fail(message)

func _fail(message: String) -> void:
	_failures += 1
	printerr("FAIL: " + message)
