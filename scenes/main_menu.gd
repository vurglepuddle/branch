extends Control # res://scenes/main_menu.gd

# References to UI nodes
@onready var difficulty_label: Label = %MenuItemsContainer/HBox/VBox/DifficultyLabel
@onready var difficulty_button: Button = %MenuItemsContainer/HBox/VBox/DifficultyButton
@onready var start_button: Button = %MenuItemsContainer/HBox/StartButton
@onready var sfx_button: Button = %MenuItemsContainer/HBox/SFX_HBox/VBox2/SFXButton
@onready var sfx_indicator_label: Label = %MenuItemsContainer/HBox/SFX_HBox/VBox2/SFXIndicatorLabel
@onready var music_button: Button = %MenuItemsContainer/HBox/SFX_HBox/VBox3/MusicButton
@onready var music_indicator_label: Label = %MenuItemsContainer/HBox/SFX_HBox/VBox3/MusicIndicatorLabel

@onready var word_preview_renderer: SubViewport = $WordPreviewRenderer
@onready var difficulty_preview_display: TextureRect = $DifficultyPreviewDisplay

# Game settings variables
var difficulty_levels = ["baby", "intern", "profi", "master", "expert", "torrero"]
var current_difficulty_index: int = 0

func _ready():
	print("MainMenu: _ready() - START")

	difficulty_button.pressed.connect(_on_difficulty_button_pressed)
	start_button.pressed.connect(_on_start_button_pressed)
	sfx_button.pressed.connect(_on_sfx_button_pressed)
	music_button.pressed.connect(_on_music_button_pressed)
	print("MainMenu: _ready() - Signals connected.")

	if AudioManager:
		#print("MainMenu: _ready() - AudioManager exists. Connecting music_display_changed signal...")
		var err_code = AudioManager.music_display_changed.connect(_on_music_display_changed)
		# You can add an error print here if err_code != OK if you want
		#print("MainMenu: _ready() - Scheduling _initialize_post_audio_manager_ready via call_deferred.")
		call_deferred("_initialize_post_audio_manager_ready")
	else:
		printerr("MainMenu: _ready() - AudioManager NOT FOUND. Some audio features might not work.")
		# update_sfx_display() was here, but it depends on AudioManager. Moved to deferred call.
		
	update_difficulty_display() # Updates the text label for difficulty
	#print("MainMenu: _ready() - Initial difficulty text label updated.")
	
	if GlobalSettings:
		GlobalSettings.current_difficulty = difficulty_levels[current_difficulty_index]
		#print("MainMenu: _ready() - Initial GlobalSettings.current_difficulty set.")
	# else:
		# printerr("MainMenu: _ready() - GlobalSettings Autoload not found!") # Optional error

	#print("MainMenu: _ready() - Initial setup finished, deferred tasks scheduled.")
	
func _initialize_post_audio_manager_ready():
	#print("!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!")
	#print("MainMenu: _initialize_post_audio_manager_ready() CALLED via call_deferred.")
	#print("!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!")

	if not is_instance_valid(AudioManager) or not AudioManager.is_node_ready():
		printerr("MainMenu: _initialize_post_audio_manager_ready - AudioManager STILL not valid or not ready!")
	else:
		#print("MainMenu: _initialize_post_audio_manager_ready - AudioManager is confirmed ready.")
		update_sfx_display() # Safe to call now
		#print("MainMenu: _initialize_post_audio_manager_ready - SFX display updated.")
	

	#print("MainMenu: _initialize_post_audio_manager_ready - About to call _update_difficulty_preview for the first time.")
	_update_difficulty_preview() 
	#print("MainMenu: _initialize_post_audio_manager_ready - _update_difficulty_preview CALL FINISHED.")
	#print("MainMenu: _initialize_post_audio_manager_ready - END")



# --- Signal Callbacks ---
func _on_difficulty_button_pressed():
	current_difficulty_index = (current_difficulty_index + 1) % difficulty_levels.size()
	update_difficulty_display() 
	
	if GlobalSettings:
		GlobalSettings.current_difficulty = difficulty_levels[current_difficulty_index]
	
	if AudioManager: AudioManager.play_named_sfx("beep_sound")
	
	_update_difficulty_preview() # Update the visual preview

func _update_difficulty_preview():
	# print("--- MainMenu: _update_difficulty_preview called ---") 
	if not is_instance_valid(word_preview_renderer) or not is_instance_valid(difficulty_preview_display):
		printerr("MainMenu: Preview renderer or display TextureRect not ready/assigned for _update_difficulty_preview.")
		if is_instance_valid(difficulty_preview_display): 
			difficulty_preview_display.texture = null 
			difficulty_preview_display.custom_minimum_size = Vector2.ZERO
		return

	var current_difficulty_name = difficulty_levels[current_difficulty_index]
	print("MainMenu: Updating preview for '", current_difficulty_name, "'") # This will now appear once on init (from deferred) and then on button presses
	
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
func _on_start_button_pressed():
	if AudioManager: AudioManager.play_named_sfx("beep_sound")
	# Store difficulty for the game scene to pick up
	var selected_difficulty = difficulty_levels[current_difficulty_index]
	GlobalSettings.current_difficulty = selected_difficulty
	print("MainMenu: Set GlobalSettings.current_difficulty to: " + GlobalSettings.current_difficulty)
	print("Starting game with difficulty: " + difficulty_levels[current_difficulty_index])
	get_tree().change_scene_to_file("res://scenes/grid.tscn")

func _on_sfx_button_pressed():
	if AudioManager:
		AudioManager.toggle_sfx_enabled()
		update_sfx_display() # Update UI based on new state

func _on_music_button_pressed():
	if AudioManager:
		AudioManager.toggle_music_style_and_state() # This will emit the signal
# --- UI Update Functions ---

func update_difficulty_display():
	difficulty_label.text = difficulty_levels[current_difficulty_index].capitalize()

func update_sfx_display(): # Make sure this function correctly reflects AudioManager.sfx_enabled
	if AudioManager:
		sfx_indicator_label.text = "On" if AudioManager.sfx_enabled else "Off"

func _on_music_display_changed(display_name: String):
	if not is_instance_valid(music_indicator_label):
		printerr("MainMenu: music_indicator_label NOT VALID in _on_music_display_changed!")
		return
	music_indicator_label.text = display_name
		#
