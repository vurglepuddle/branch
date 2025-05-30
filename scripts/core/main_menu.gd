extends Control # res://scenes/main_menu.gd

# References to UI nodes
@onready var difficulty_label: RichTextLabel = %MenuItemsContainer/HBox/DifficultyLabel
@onready var difficulty_button: TextureButton = %MenuItemsContainer/HBox/VBox/DifficultyButton
@onready var start_button: TextureButton = %MenuItemsContainer/HBox/StartButton
@onready var sfx_button: TextureButton = %MenuItemsContainer/HBox/SFX_HBox/VBox2/SFXButton
@onready var sfx_indicator_label: RichTextLabel = %MenuItemsContainer/HBox/SFX_HBox/SFXIndicatorLabel
@onready var music_button: TextureButton = %MenuItemsContainer/HBox/SFX_HBox/VBox3/MusicButton
@onready var music_indicator_label: RichTextLabel = %MenuItemsContainer/HBox/SFX_HBox/MusicIndicatorLabel

@onready var word_preview_renderer: SubViewport = $WordPreviewRenderer
@onready var difficulty_preview_display: TextureRect = $DifficultyPreviewDisplay

# Game settings variables
var difficulty_levels = ["baby", "intern", "profi", "master", "expert", "torrero"]
var current_difficulty_index: int
const BBCODE_FIRST_LETTER_COLOR: String = "white"
const BBCODE_REST_LETTERS_COLOR: String = "#54fcfc"
const BBCODE_OFF_COLOR: String = "#54fcfc"

func _format_label_text(base_text: String) -> String:
	if base_text.is_empty():
		return ""
	
	var capitalized_text = base_text.capitalize()
	var first_char = capitalized_text.substr(0, 1)
	var rest_chars = capitalized_text.substr(1, capitalized_text.length() - 1)
	
	# Special case for "Off" to potentially use a different color
	if capitalized_text == "Off":
		return "[color=" + BBCODE_FIRST_LETTER_COLOR + "]" + first_char + "[/color][color=" + BBCODE_OFF_COLOR + "]" + rest_chars + "[/color]"
	
	return "[color=" + BBCODE_FIRST_LETTER_COLOR + "]" + first_char + "[/color][color=" + BBCODE_REST_LETTERS_COLOR + "]" + rest_chars + "[/color]"

func _ready():
	difficulty_button.pressed.connect(_on_difficulty_button_pressed)
	start_button.pressed.connect(_on_start_button_pressed)
	sfx_button.pressed.connect(_on_sfx_button_pressed)
	music_button.pressed.connect(_on_music_button_pressed)
	print("MainMenu: _ready() - Signals connected.")
	
	if GlobalSettings:
		current_difficulty_index = GlobalSettings.last_menu_difficulty_index
		if current_difficulty_index < 0 or current_difficulty_index >= difficulty_levels.size():
			print("MainMenu: Invalid last_menu_difficulty_index (", GlobalSettings.last_menu_difficulty_index, ") from GlobalSettings. Resetting to 0.")
			current_difficulty_index = 0
			GlobalSettings.last_menu_difficulty_index = 0
	else:
		current_difficulty_index = 0 
		printerr("MainMenu: GlobalSettings not found in _ready(). Defaulting difficulty index to 0.")

	if AudioManager:
		# Connect the signal before calling _initialize_post_audio_manager_ready which might trigger an update
		AudioManager.music_display_changed.connect(_on_music_display_changed)
		call_deferred("_initialize_post_audio_manager_ready")
	else:
		printerr("MainMenu: _ready() - AudioManager NOT FOUND. Some audio features might not work.")
		# If AudioManager is not found, we might still want to initialize UI elements that don't depend on it.
		call_deferred("_initialize_post_audio_manager_ready") # Call it anyway for UI updates and fade

	# Initial UI updates that don't depend on AudioManager being fully ready
	update_difficulty_display()
	if GlobalSettings:
		GlobalSettings.current_difficulty = difficulty_levels[current_difficulty_index]
		
		
	
func _initialize_post_audio_manager_ready():
	# This function is called after _ready() completes its synchronous part.
	
	# Update displays that might depend on AudioManager state
	if is_instance_valid(AudioManager): # No need for is_node_ready() here, just check if it's valid
		update_sfx_display()
		# For music, the initial state might be set by AudioManager emitting music_display_changed
		# when it initializes. Or we can force an update here.
		# Let's assume AudioManager._ready() or initialize_audio_settings() emits the initial state.
		# If not, you might need to query AudioManager for its current music display name.
		# For now, we rely on the connected signal.
		var initial_music_display_name = "Classic" # Default fallback
		if AudioManager.is_menu_music_off:
			initial_music_display_name = "Off"
		elif AudioManager.current_music_style == AudioManager.MusicStyle.MODERN:
			initial_music_display_name = "Modern"
		_on_music_display_changed(initial_music_display_name) # Manually trigger update with current state
	else:
		# Fallback UI if AudioManager isn't there
		sfx_indicator_label.bbcode_text = _format_label_text("N/A")
		music_indicator_label.bbcode_text = _format_label_text("N/A")


	_update_difficulty_preview() # Generate preview for the loaded/default difficulty

	if FadeOverlay:
		FadeOverlay.fade_rect.color = Color.BLACK
		FadeOverlay.fade_rect.modulate.a = 1.0 
		FadeOverlay.visible = true
		print(self.name, ": Fading in scene (from _initialize_post_audio_manager_ready)...")
		await FadeOverlay.fade_in(0.3)
		print(self.name, ": Scene fade in complete (from _initialize_post_audio_manager_ready).")
	else:
		printerr("MainMenu: _initialize_post_audio_manager_ready - FadeOverlay NOT FOUND.")
	
# --- Signal Callbacks ---
func _on_difficulty_button_pressed():
	current_difficulty_index = (current_difficulty_index + 1) % difficulty_levels.size()
	update_difficulty_display() 
	
	if GlobalSettings:
		GlobalSettings.current_difficulty = difficulty_levels[current_difficulty_index]
		GlobalSettings.last_menu_difficulty_index = current_difficulty_index
	
	if AudioManager: AudioManager.play_named_sfx("beep_sound")
	
	_update_difficulty_preview()

func _update_difficulty_preview():
	if not is_instance_valid(word_preview_renderer) or not is_instance_valid(difficulty_preview_display):
		printerr("MainMenu: Preview renderer or display TextureRect not ready/assigned for _update_difficulty_preview.")
		if is_instance_valid(difficulty_preview_display): 
			difficulty_preview_display.texture = null 
			difficulty_preview_display.custom_minimum_size = Vector2.ZERO
		return

	var current_difficulty_name = difficulty_levels[current_difficulty_index]
	print("MainMenu: Updating preview for '", current_difficulty_name, "'")
	
	if not word_preview_renderer.is_node_ready():
		print("MainMenu: word_preview_renderer not ready yet for '", current_difficulty_name, "', awaiting...")
		await word_preview_renderer.ready 
		print("MainMenu: word_preview_renderer is now ready for '", current_difficulty_name, "'.")

	word_preview_renderer.generate_preview(current_difficulty_name)
	await get_tree().process_frame 
	var vp_texture: ViewportTexture = word_preview_renderer.get_texture()

	if vp_texture and vp_texture.get_width() > 0 and vp_texture.get_height() > 0:
		difficulty_preview_display.texture = vp_texture
		difficulty_preview_display.custom_minimum_size = vp_texture.get_size()
		difficulty_preview_display.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	else:
		printerr("MainMenu: Failed to get valid texture from SubViewport for '", current_difficulty_name, 
				 "'. SubViewport size: ", word_preview_renderer.size if is_instance_valid(word_preview_renderer) else "renderer invalid")
		difficulty_preview_display.texture = null
		difficulty_preview_display.custom_minimum_size = Vector2.ZERO
	
	# This specific update for difficulty_label was in _update_difficulty_preview
	# It's better to have it in update_difficulty_display for clarity.
	# var current_diff_text_for_label = difficulty_levels[current_difficulty_index]
	# difficulty_label.bbcode_text = _format_label_text(current_diff_text_for_label)
		
func _on_start_button_pressed():
	if AudioManager: AudioManager.play_named_sfx("beep_sound")
	# var selected_difficulty = difficulty_levels[current_difficulty_index] # Already set in GlobalSettings
	# GlobalSettings.current_difficulty = selected_difficulty
	# GlobalSettings.last_menu_difficulty_index = current_difficulty_index
	print("MainMenu: Set GlobalSettings.current_difficulty to: " + GlobalSettings.current_difficulty)
	print("Starting game with difficulty: " + difficulty_levels[current_difficulty_index])
	
	SceneChanger.change_scene_with_fade("res://scenes/Grid.tscn", 0.3)
	
func _on_sfx_button_pressed():
	if AudioManager:
		AudioManager.toggle_sfx_enabled()
		# update_sfx_display() is called AFTER AudioManager has processed the toggle
		# and played its own confirmation beep if sfx became enabled.
		# Call it deferred to ensure AudioManager's internal state is fully updated.
		call_deferred("update_sfx_display")


func _on_music_button_pressed():
	if AudioManager:
		AudioManager.toggle_music_style_and_state() # This will emit music_display_changed signal
		
# --- UI Update Functions ---

func update_difficulty_display():
	var text_to_display = difficulty_levels[current_difficulty_index]
	difficulty_label.bbcode_text = _format_label_text(text_to_display)

func update_sfx_display():
	var sfx_state_text = "Off" # Default to Off
	if AudioManager and AudioManager.sfx_enabled:
		sfx_state_text = "On"
	sfx_indicator_label.bbcode_text = _format_label_text(sfx_state_text)

func _on_music_display_changed(display_name: String):
	if not is_instance_valid(music_indicator_label):
		printerr("MainMenu: music_indicator_label NOT VALID in _on_music_display_changed!")
		return
	music_indicator_label.bbcode_text = _format_label_text(display_name)
