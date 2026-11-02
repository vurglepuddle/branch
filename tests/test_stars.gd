extends SceneTree
# Title screen stars: the same speed at any refresh rate, on a fake clock, plus the real splash scene
# spawning and clearing stars. Run with tests/run_tests.sh.

const STAR_SCENE_PATH := "res://scenes/Star.tscn"
const REFRESH_RATES: Array[int] = [30, 60, 120, 240]

var _failures: int = 0

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	await process_frame
	await _test_same_speed_at_any_refresh_rate()
	await _test_every_frame_is_shown_in_order()
	await _test_fourth_frame_is_held()
	await _test_stall_moves_one_frame()
	await _test_splash_spawns_and_clears_stars()
	print("test_stars: %s" % ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
	quit(1 if _failures > 0 else 0)

# A new star with its own clock turned off, so the test controls the time.
func _new_star() -> Node:
	var star: Node = load(STAR_SCENE_PATH).instantiate()
	root.add_child(star)
	star.set_process(false)
	return star

func _test_same_speed_at_any_refresh_rate() -> void:
	var lifetimes: Array[int] = []
	for hz in REFRESH_RATES:
		seed(2026)
		var star: Node = _new_star()
		var started: int = star._next_frame_ms
		var step: int = 1000 / hz
		var now: int = Time.get_ticks_msec()
		var finished: Array[bool] = [false]
		star.animation_cycle_finished.connect(func(): finished[0] = true)
		var deadline: int = now + 10000
		var began: int = now
		while not finished[0] and now < deadline:
			now += step
			star._advance(now)
		lifetimes.append(now - began)
		if not finished[0]:
			_fail("a star at %d Hz never finished" % hz)
		await process_frame
		if is_instance_valid(star):
			_fail("a finished star should remove itself")
			star.queue_free()
	# Each frame can run one display tick over, so slower displays may finish a little later.
	if lifetimes.max() - lifetimes.min() > 5 * 1000 / REFRESH_RATES.min():
		_fail("star lifetimes depend on the refresh rate: %s ms at %s Hz" % [lifetimes, REFRESH_RATES])
	# Today's look at 60 frames per second: four quick frames and one long one.
	if lifetimes.min() < 4 * 67 + 500 - 50 or lifetimes.max() > 4 * 250 + 667 + 200:
		_fail("a star's lifetime changed from today's look: %s ms" % [lifetimes])

func _test_every_frame_is_shown_in_order() -> void:
	seed(7)
	var star: Node = _new_star()
	var seen: Array[int] = [star.frame]
	var now: int = Time.get_ticks_msec()
	var deadline: int = now + 10000
	while is_instance_valid(star) and not star.is_queued_for_deletion() and now < deadline:
		now += 5
		star._advance(now)
		if not star.is_queued_for_deletion() and star.frame != seen[-1]:
			seen.append(star.frame)
	if seen != [0, 1, 2, 3, 4]:
		_fail("star frames played as %s" % str(seen))
	await process_frame

# Today's look holds the fourth frame longer than the rest.
func _test_fourth_frame_is_held() -> void:
	for run in range(20):
		seed(run)
		var star: Node = _new_star()
		var now: int = Time.get_ticks_msec()
		var deadline: int = now + 10000
		var entered: int = -1
		var held: int = -1
		while now < deadline and held < 0:
			now += 5
			star._advance(now)
			if star.frame == 3 and entered < 0:
				entered = now
			elif entered >= 0 and star.frame != 3:
				held = now - entered
		if held < 500 or held > 680:
			_fail("the fourth frame was held for %d ms, it should be 500 to 667" % held)
		star.queue_free()
	await process_frame

func _test_stall_moves_one_frame() -> void:
	seed(9)
	var star: Node = _new_star()
	star._advance(Time.get_ticks_msec() + 60000)
	if star.frame != 1:
		_fail("after a long stall a star should move one frame, it's on frame %d" % star.frame)
	star.queue_free()
	await process_frame

# New stars keep spawning, so the count may never reach zero. It just has to go down when one finishes.
func _test_splash_spawns_and_clears_stars() -> void:
	var splash: Node = load("res://scenes/SplashScreen.tscn").instantiate()
	root.add_child(splash)
	current_scene = splash
	var deadline: int = Time.get_ticks_msec() + 8000
	var previous: int = 0
	var spawned: bool = false
	var counted_down: bool = false
	while Time.get_ticks_msec() < deadline and not counted_down:
		await process_frame
		spawned = spawned or splash.active_stars > 0
		counted_down = splash.active_stars < previous
		previous = splash.active_stars
	if not spawned:
		_fail("the splash screen never spawned a star")
	elif not counted_down:
		_fail("finished stars weren't counted back down")
	current_scene = null
	splash.queue_free()
	await process_frame

func _fail(message: String) -> void:
	_failures += 1
	printerr("FAIL: " + message)
