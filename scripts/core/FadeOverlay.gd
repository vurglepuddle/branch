# FadeOverlay.gd
extends CanvasLayer

signal fade_finished 

@onready var fade_rect: ColorRect = $FadeRect
var _is_fading: bool = false

func is_currently_fading() -> bool: # Getter method
	return _is_fading

func _ready():
	fade_rect.modulate = Color(1, 1, 1, 0) 
	fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false

func fade_out(duration: float = 0.5): 
	if _is_fading:
		print_verbose("FadeOverlay: Already fading, ignoring new fade_out request.")
		return

	_is_fading = true
	visible = true 
	fade_rect.modulate = Color(1, 1, 1, 0) 

	print_verbose("FadeOverlay: Starting fade_out visual tween (duration: ", duration, "s).")
	var tween = create_tween()
	tween.set_parallel(true) 
	tween.tween_property(fade_rect, "modulate:a", 1.0, duration).set_trans(Tween.TRANS_SINE)
	
	var time_elapsed = 0.0
	while is_instance_valid(tween) and tween.is_running():
		time_elapsed += get_process_delta_time()
		if time_elapsed >= duration * 1.1: # Added a little buffer to ensure tween can finish
			if is_instance_valid(tween): tween.kill() 
			print_verbose("FadeOverlay: Fade_out safety break after duration.")
			break
		await get_tree().process_frame # This makes this function awaitable

	fade_rect.modulate.a = 1.0
	
	print_verbose("FadeOverlay: Visual fade_out tween considered FINISHED.")
	_is_fading = false
	emit_signal("fade_finished", "out")

func fade_in(duration: float = 0.5):
	if _is_fading:
		print_verbose("FadeOverlay: Already fading, ignoring new fade_in request.")
		return
			
	_is_fading = true
	visible = true 
	fade_rect.modulate = Color(1, 1, 1, 1.0) 

	print_verbose("FadeOverlay: Starting fade_in visual tween (duration: ", duration, "s).")
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(fade_rect, "modulate:a", 0.0, duration).set_trans(Tween.TRANS_SINE)

	var time_elapsed = 0.0
	while is_instance_valid(tween) and tween.is_running():
		time_elapsed += get_process_delta_time()
		if time_elapsed >= duration * 1.1: 
			if is_instance_valid(tween): tween.kill()
			print_verbose("FadeOverlay: Fade_in safety break after duration.")
			break
		await get_tree().process_frame # This makes this function awaitable
		
	fade_rect.modulate.a = 0.0
	visible = false 
	
	print_verbose("FadeOverlay: Visual fade_in tween considered FINISHED.")
	_is_fading = false
	emit_signal("fade_finished", "in")

func start_fade_out(duration: float = 0.5):
	if _is_fading: return
	_is_fading = true
	visible = true
	fade_rect.modulate = Color(1, 1, 1, 0)
	var tween = create_tween()
	tween.tween_property(fade_rect, "modulate:a", 1.0, duration).set_trans(Tween.TRANS_SINE)
	tween.connect("finished", Callable(self, "_on_fade_tween_finished").bind("out"))

func start_fade_in(duration: float = 0.5):
	if _is_fading: return
	_is_fading = true
	visible = true
	fade_rect.modulate = Color(1, 1, 1, 1.0)
	var tween = create_tween()
	tween.tween_property(fade_rect, "modulate:a", 0.0, duration).set_trans(Tween.TRANS_SINE)
	tween.connect("finished", Callable(self, "_on_fade_tween_finished").bind("in"))

func _on_fade_tween_finished(type: String):
	_is_fading = false
	if type == "in":
		visible = false
	emit_signal("fade_finished", type)
