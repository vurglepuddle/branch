# Star.gd
extends AnimatedSprite2D

# Signal to notify when the star has finished its animation cycle
signal animation_cycle_finished

# How long a single animation frame is displayed, so stars look the same at any refresh rate
@export var min_ms_per_sprite_frame: int = 67
@export var max_ms_per_sprite_frame: int = 250

@export var min_ms_for_frame4: int = 500 # Example: Make it noticeably longer
@export var max_ms_for_frame4: int = 667 # Example: Make it noticeably longer

# The name of the animation in your SpriteFrames resource
@export var animation_name: String = "default" # Or "twinkle" or whatever you named it

var _next_frame_ms: int = 0
var _total_sprite_frames: int = 0
var _current_animation_frame_index: int = 0

func _ready():
	if not sprite_frames or not sprite_frames.has_animation(animation_name):
		printerr("Star: SpriteFrames not set or animation '", animation_name, "' not found!")
		queue_free() # Can't operate without animation
		return

	_total_sprite_frames = sprite_frames.get_frame_count(animation_name)
	if _total_sprite_frames == 0:
		printerr("Star: Animation '", animation_name, "' has no frames!")
		queue_free()
		return

	# We control animation manually
	self.animation = animation_name
	self.speed_scale = 0
	self.frame = 0 # Start at the first frame of the animation
	_current_animation_frame_index = 0
	_set_new_random_frame_duration(Time.get_ticks_msec())

func _process(_delta):
	_advance(Time.get_ticks_msec())

# Moves on at most one frame per call, so a stalled frame can't skip drawings.
func _advance(now_ms: int) -> void:
	if now_ms < _next_frame_ms:
		return
	_current_animation_frame_index += 1
	if _current_animation_frame_index >= _total_sprite_frames:
		# Completed all 5 frames
		animation_cycle_finished.emit()
		queue_free() # Star disappears after one full cycle
	else:
		# Advance to next frame in the animation
		self.frame = _current_animation_frame_index
		_set_new_random_frame_duration(now_ms)

func _set_new_random_frame_duration(now_ms: int) -> void:
	if _current_animation_frame_index == 3: # If this is the 4th frame
		_next_frame_ms = now_ms + randi_range(min_ms_for_frame4, max_ms_for_frame4)
	else: # For all other frames
		_next_frame_ms = now_ms + randi_range(min_ms_per_sprite_frame, max_ms_per_sprite_frame)
