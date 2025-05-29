# Star.gd
extends AnimatedSprite2D

# Signal to notify when the star has finished its animation cycle
signal animation_cycle_finished

# Min/max game frames (ticks) a single animation frame will be displayed
@export var min_ticks_per_sprite_frame: int = 4
@export var max_ticks_per_sprite_frame: int = 15

@export var min_ticks_for_frame4: int = 30 # Example: Make it noticeably longer
@export var max_ticks_for_frame4: int = 40 # Example: Make it noticeably longer

# The name of the animation in your SpriteFrames resource
@export var animation_name: String = "default" # Or "twinkle" or whatever you named it

var _current_sprite_frame_ticks: int = 0
var _target_ticks_for_this_sprite_frame: int = 0
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
	_set_new_random_frame_duration()

func _process(_delta):
	_current_sprite_frame_ticks += 1

	if _current_sprite_frame_ticks >= _target_ticks_for_this_sprite_frame:
		_current_animation_frame_index += 1
		if _current_animation_frame_index >= _total_sprite_frames:
			# Completed all 5 frames
			emit_signal("animation_cycle_finished")
			queue_free() # Star disappears after one full cycle
		else:
			# Advance to next frame in the animation
			self.frame = _current_animation_frame_index
			_set_new_random_frame_duration()

func _set_new_random_frame_duration():
	if _current_animation_frame_index == 3: # If this is the 4th frame
		_target_ticks_for_this_sprite_frame = randi_range(min_ticks_for_frame4, max_ticks_for_frame4)
	else: # For all other frames
		_target_ticks_for_this_sprite_frame = randi_range(min_ticks_per_sprite_frame, max_ticks_per_sprite_frame)
	
	_current_sprite_frame_ticks = 0
