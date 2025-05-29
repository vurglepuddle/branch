# SceneChanger.gd (for Godot 3.x)
extends Node

func change_scene_with_fade(scene_path: String, fade_out_duration: float = 0.3, fade_in_on_fail_duration: float = 0.3):
	print("SceneChanger: Attempting to change scene to ", scene_path)

	# --- Debugging for Root Node Children ---
	print("SceneChanger: --- Root Node Children ---")
	if get_tree() and is_instance_valid(get_tree().get_root()):
		var root_children = get_tree().get_root().get_children()
		# --- CORRECTED LINE BELOW ---
		if root_children.is_empty(): # Use is_empty() for Godot 3.x arrays
			print("SceneChanger: Root has NO children.")
		else:
			for child in root_children:
				print("  - Child Name: '", child.name, "', Path: '", child.get_path(), "', Type: '", child.get_class(), "'")
	else:
		print("SceneChanger: Cannot access get_tree() or root node for child listing.")
	print("SceneChanger: --- End Root Node Children ---")
	print("SceneChanger: Engine.get_singleton_list() still reports: ", Engine.get_singleton_list())
	# --- End Debugging ---

	var fade_overlay_node = null

	# Priority 1: Try to get as a node in /root
	if get_tree() and is_instance_valid(get_tree().get_root()) and get_tree().get_root().has_node("FadeOverlay"):
		print("SceneChanger: Found '/root/FadeOverlay' node directly.")
		fade_overlay_node = get_tree().get_root().get_node("FadeOverlay")
	else:
		print("SceneChanger: Node '/root/FadeOverlay' NOT found directly.")
		# Priority 2: Fallback to Engine.singleton check
		if Engine.has_singleton("FadeOverlay"):
			print("SceneChanger: Engine.has_singleton('FadeOverlay') is TRUE (unexpected fallback).")
			fade_overlay_node = Engine.get_singleton("FadeOverlay")
		else:
			print("SceneChanger: Engine.has_singleton('FadeOverlay') is FALSE (as observed before).")

	if not is_instance_valid(fade_overlay_node):
		printerr("SceneChanger: FadeOverlay could not be retrieved or is not a valid instance! Changing scene directly.")
		var direct_change_error = get_tree().change_scene_to_file(scene_path)
		if direct_change_error != OK:
			printerr("SceneChanger: Direct scene change to '", scene_path, "' also failed. Error: ", direct_change_error)
		return

	var is_busy = false
	if fade_overlay_node.has_method("is_currently_fading"):
		if fade_overlay_node.is_currently_fading():
			is_busy = true
	elif fade_overlay_node.has("_is_fading"):
		if fade_overlay_node.get("_is_fading"): # Using .get() is safer for properties
			is_busy = true
	
	if is_busy:
		printerr("SceneChanger: FadeOverlay is already busy. Scene change to '", scene_path, "' aborted.")
		return

	if not fade_overlay_node.has_method("fade_out"):
		printerr("SceneChanger: Retrieved FadeOverlay node does not have a 'fade_out' method!")
		get_tree().change_scene_to_file(scene_path)
		return

	await fade_overlay_node.fade_out(fade_out_duration)
	
	var error_code = get_tree().change_scene_to_file(scene_path)
	
	if error_code != OK:
		printerr("SceneChanger: Failed to change scene to: '", scene_path, "'. Error code: ", error_code)
		if is_instance_valid(fade_overlay_node) and fade_overlay_node.has_method("fade_in"):
			await fade_overlay_node.fade_in(fade_in_on_fail_duration)
		else:
			printerr("SceneChanger: FadeOverlay became invalid or lacks fade_in after failed scene change attempt.")
