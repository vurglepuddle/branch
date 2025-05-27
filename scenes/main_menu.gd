# res://scenes/main_menu.gd
extends Control

# References to UI nodes
@onready var difficulty_label: Label = %MenuItemsContainer/DifficultyLabel
@onready var difficulty_button: Button = %MenuItemsContainer/DifficultyButton
@onready var start_button: Button = %MenuItemsContainer/StartButton
@onready var sfx_button: Button = %MenuItemsContainer/SFX_HBox/SFXButton
@onready var sfx_indicator_label: Label = %MenuItemsContainer/SFX_HBox/SFXIndicatorLabel
@onready var music_button: Button = %MenuItemsContainer/Music_HBox/MusicButton
@onready var music_indicator_label: Label = %MenuItemsContainer/Music_HBox/MusicIndicatorLabel

# Game settings variables
var difficulty_levels = ["baby", "intern", "profi", "master", "expert", "torrero"] # Customize as needed
var current_difficulty_index: int = 0


func _ready():
	# Connect button signals to functions
	difficulty_button.pressed.connect(_on_difficulty_button_pressed)
	start_button.pressed.connect(_on_start_button_pressed)
	sfx_button.pressed.connect(_on_sfx_button_pressed)
	music_button.pressed.connect(_on_music_button_pressed)
	

	# Ensure AudioManager is ready before updating UI that depends on it
	if AudioManager:
		await AudioManager.ready # Wait for AudioManager's _ready to complete if it has heavy init
		update_sfx_display()
		update_music_display()
	else:
		printerr("MainMenu: AudioManager not found. Audio controls will not initialize correctly.")

	# Initialize UI text
	update_difficulty_display()
	GlobalSettings.current_difficulty = difficulty_levels[current_difficulty_index]


# --- Signal Callbacks ---

func _on_difficulty_button_pressed():
	current_difficulty_index = (current_difficulty_index + 1) % difficulty_levels.size()
	update_difficulty_display()
	GlobalSettings.current_difficulty = difficulty_levels[current_difficulty_index]
	if AudioManager:
		AudioManager.play_sfx("click") # Example: if you have a named "click" SFX

func _on_start_button_pressed():
	# Store difficulty for the game scene to pick up
	var selected_difficulty = difficulty_levels[current_difficulty_index]
	GlobalSettings.current_difficulty = selected_difficulty
	print("MainMenu: Set GlobalSettings.current_difficulty to: " + GlobalSettings.current_difficulty)
	print("Starting game with difficulty: " + difficulty_levels[current_difficulty_index])
	
	# Optionally, tell AudioManager to play music based on difficulty now,
	# or let the game scene (grid.tscn) handle it upon loading.
	# Example: if AudioManager.difficulty_music keys match difficulty_levels:
	# if AudioManager:
	#    AudioManager.load_and_play_music_by_difficulty(difficulty_levels[current_difficulty_index])

	get_tree().change_scene_to_file("res://scenes/grid.tscn")

func _on_sfx_button_pressed():
	if AudioManager:
		AudioManager.toggle_sfx_enabled() # New function in AudioManager
		update_sfx_display()
		# AudioManager.play_sfx("click") # Play click sound after toggling, if desired and SFX still on

func _on_music_button_pressed():
	if AudioManager:
		AudioManager.cycle_menu_music_track() # Renamed for clarity if needed, or use existing cycle_music_track
		update_music_display()
		# AudioManager.play_sfx("click")

# --- UI Update Functions ---

func update_difficulty_display():
	if difficulty_label:
		difficulty_label.text = "Difficulty: " + difficulty_levels[current_difficulty_index]

func update_sfx_display():
	if sfx_indicator_label and AudioManager:
		# Assuming AudioManager has an 'sfx_enabled' boolean property
		sfx_indicator_label.text = "SFX: " + ("ON" if AudioManager.sfx_enabled else "OFF")

func update_music_display():
	if music_indicator_label and AudioManager:
		# Assuming AudioManager has 'get_current_music_track_name()'
		music_indicator_label.text = "Music: " + AudioManager.get_current_menu_music_track_name()
