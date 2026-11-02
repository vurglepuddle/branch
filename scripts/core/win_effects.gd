extends Node # win_effects.gd
# The celebration after a win. Every tip opens into a flower, holds at full bloom and ripens into
# fruit on its own schedule, then glints play on the finished fruit. It all runs from _process
# against one clock, so nothing can fire once this node has gone.

signal exit_allowed
signal all_tips_finished
signal glint_started(tile: Node)

const EXIT_ALLOWED_AFTER_MS: int = 2000

# Each tip moves through numbered steps. It stays hidden until step 1, so a random negative start
# staggers the tips. Step 21 is full bloom, and step 41 is the finished fruit. The first tip to open
# holds its flower for the minimum and the rest hold for random times, so the first fruit comes soon
# and flowers stay on screen while the others ripen.
const MAX_START_DELAY_STEPS: int = 59
const OPENING_STEP_MIN_MS: int = 50
const OPENING_STEP_MAX_MS: int = 99
const FULL_BLOOM_STEP: int = 21
const FULL_BLOOM_HOLD_MIN_MS: int = 6000
const FULL_BLOOM_HOLD_MAX_MS: int = 12000
const RIPENING_STEP_MS: int = 100
const LAST_STEP: int = 41

const GLINT_SLOTS: Dictionary = {"baby": 1, "intern": 2, "profi": 3, "master": 4, "expert": 5, "torrero": 5}
const GLINT_STAGES: int = 9 # Five drawings, forward then back, on the FruitStar sheet
const GLINT_STAGE_MS: int = 45
# A wide range: on average a slot rests about 3.6 seconds, but two glints can still land close together.
const GLINT_WAIT_MIN_MS: int = 225
const GLINT_WAIT_MAX_MS: int = 7000
const GLINT_LIFETIME_MS: int = 100000

var rng := RandomNumberGenerator.new()

var _started_ms: int = -1
var _exit_was_allowed: bool = false
var _tips: Array[Dictionary] = []
var _all_finished: bool = false
var _glint_slot_count: int = 0
var _glint_slots: Array[Dictionary] = []
var _glints_started_ms: int = -1
var _glints_ended_ms: int = -1

func _ready() -> void:
	rng.randomize()

func _process(_delta: float) -> void:
	advance(Time.get_ticks_msec())

func start(tips: Array, glint_slot_count: int, now_ms: int = Time.get_ticks_msec()) -> void:
	_started_ms = now_ms
	_tips.clear()
	for tile in tips:
		_tips.append({
			"tile": tile,
			"step": -rng.randi_range(0, MAX_START_DELAY_STEPS),
			"interval": rng.randi_range(OPENING_STEP_MIN_MS, OPENING_STEP_MAX_MS),
			"last_ms": now_ms,
			"finished": false,
			"hold_ms": rng.randi_range(FULL_BLOOM_HOLD_MIN_MS, FULL_BLOOM_HOLD_MAX_MS),
		})
	if not _tips.is_empty():
		var first_to_open: Dictionary = _tips[0]
		for tip in _tips:
			if tip["step"] > first_to_open["step"]:
				first_to_open = tip
		first_to_open["hold_ms"] = FULL_BLOOM_HOLD_MIN_MS
	_glint_slot_count = mini(glint_slot_count, tips.size())

# Called every frame. Each tip takes at most one step per call, so a stalled frame can't make it jump.
func advance(now_ms: int) -> void:
	if _started_ms < 0:
		return
	if not _exit_was_allowed and now_ms - _started_ms >= EXIT_ALLOWED_AFTER_MS:
		_exit_was_allowed = true
		exit_allowed.emit()
	if not _all_finished:
		_advance_tips(now_ms)
	elif _glints_ended_ms < 0:
		_advance_glints(now_ms)

func stop() -> void:
	_hide_glints()
	_started_ms = -1
	set_process(false)

func _advance_tips(now_ms: int) -> void:
	var any_unfinished: bool = false
	for tip in _tips:
		if tip["finished"]:
			continue
		any_unfinished = true
		if now_ms - tip["last_ms"] <= tip["interval"]:
			continue
		tip["last_ms"] = now_ms
		tip["step"] += 1
		if tip["step"] >= 1:
			tip["tile"].show_flower_pose(tip["step"] - 1)
		if tip["step"] == LAST_STEP:
			tip["finished"] = true
		elif tip["step"] == FULL_BLOOM_STEP:
			tip["interval"] = tip["hold_ms"]
		elif tip["step"] > FULL_BLOOM_STEP:
			tip["interval"] = RIPENING_STEP_MS
		else:
			tip["interval"] = rng.randi_range(OPENING_STEP_MIN_MS, OPENING_STEP_MAX_MS)
	if not any_unfinished:
		_all_finished = true
		all_tips_finished.emit()
		_start_glints(now_ms)

func _start_glints(now_ms: int) -> void:
	_glints_ended_ms = -1
	_glint_slots.clear()
	for _i in range(_glint_slot_count):
		_glint_slots.append({"tile": null, "started_ms": -1, "next_ms": now_ms + _glint_wait()})
	_glints_started_ms = now_ms

func _advance_glints(now_ms: int) -> void:
	if now_ms - _glints_started_ms >= GLINT_LIFETIME_MS:
		_hide_glints()
		_glints_ended_ms = now_ms
		return
	for slot in _glint_slots:
		if slot["tile"] == null:
			if now_ms >= slot["next_ms"]:
				slot["tile"] = _pick_free_tip()
				slot["started_ms"] = now_ms
				slot["tile"].show_glint(0)
				glint_started.emit(slot["tile"])
			continue
		var stage: int = (now_ms - slot["started_ms"]) / GLINT_STAGE_MS
		if stage < GLINT_STAGES:
			slot["tile"].show_glint(stage)
		else:
			slot["tile"].hide_glint()
			slot["tile"] = null
			slot["next_ms"] = now_ms + _glint_wait()

func _pick_free_tip() -> Node:
	var free: Array = []
	for tip in _tips:
		var taken: bool = false
		for slot in _glint_slots:
			if slot["tile"] == tip["tile"]:
				taken = true
		if not taken:
			free.append(tip["tile"])
	return free[rng.randi_range(0, free.size() - 1)]

func _glint_wait() -> int:
	return rng.randi_range(GLINT_WAIT_MIN_MS, GLINT_WAIT_MAX_MS)

func _hide_glints() -> void:
	for slot in _glint_slots:
		if slot["tile"] != null and is_instance_valid(slot["tile"]):
			slot["tile"].hide_glint()
		slot["tile"] = null
