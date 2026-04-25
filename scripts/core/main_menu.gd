extends Control # res://scenes/main_menu.gd

@onready var difficulty_label: RichTextLabel = %MenuItemsContainer/HBox/DifficultyLabel
@onready var start_button: TextureButton = %MenuItemsContainer/HBox/StartButton
@onready var start_label: RichTextLabel = %MenuItemsContainer/HBox/StartLabel
@onready var settings_label: RichTextLabel = %MenuItemsContainer/HBox/SFX_HBox/SettingsLabel
@onready var settings_button: TextureButton = %MenuItemsContainer/HBox/SFX_HBox/SettingsButton

@onready var word_preview_renderer: SubViewport = $WordPreviewRenderer
@onready var difficulty_preview_display: TextureRect = $DifficultyPreviewDisplay

var difficulty_levels: Array = ["baby", "intern", "profi", "master", "expert", "torrero"]
var current_difficulty_index: int

const BBCODE_FIRST_LETTER_COLOR: String = "white"
const BBCODE_REST_LETTERS_COLOR: String = "#54fcfc"
const SWIPE_THRESHOLD: float = 60.0

var _drag_start: Vector2 = Vector2(-1.0, -1.0)
var _settings_overlay: Control

func _format_label_text(base_text: String) -> String:
	if base_text.is_empty():
		return ""
	var first_char := base_text.substr(0, 1).to_upper()
	var rest_chars := base_text.substr(1)
	return "[color=%s]%s[/color][color=%s]%s[/color]" % [BBCODE_FIRST_LETTER_COLOR, first_char, BBCODE_REST_LETTERS_COLOR, rest_chars]

func _ready():
	start_button.pressed.connect(_on_start_button_pressed)
	settings_button.pressed.connect(_on_settings_button_pressed)
	print("MainMenu: _ready() - Signals connected.")

	var overlay_scene: PackedScene = preload("res://scenes/SettingsOverlay.tscn")
	_settings_overlay = overlay_scene.instantiate()
	add_child(_settings_overlay)
	_settings_overlay.language_changed.connect(update_difficulty_display)

	if GlobalSettings:
		current_difficulty_index = GlobalSettings.last_menu_difficulty_index
		if current_difficulty_index < 0 or current_difficulty_index >= difficulty_levels.size():
			current_difficulty_index = 0
			GlobalSettings.last_menu_difficulty_index = 0
	else:
		current_difficulty_index = 0
		printerr("MainMenu: GlobalSettings not found in _ready(). Defaulting difficulty index to 0.")

	call_deferred("_initialize_post_audio_manager_ready")
	update_difficulty_display()
	if GlobalSettings:
		GlobalSettings.current_difficulty = difficulty_levels[current_difficulty_index]

func _initialize_post_audio_manager_ready():
	_update_difficulty_preview()

	if FadeOverlay:
		FadeOverlay.fade_rect.color = Color.BLACK
		FadeOverlay.fade_rect.modulate.a = 1.0
		FadeOverlay.visible = true
		print(self.name, ": Fading in scene...")
		await FadeOverlay.fade_in(0.3)
		print(self.name, ": Scene fade in complete.")
	else:
		printerr("MainMenu: _initialize_post_audio_manager_ready - FadeOverlay NOT FOUND.")

func _input(event: InputEvent) -> void:
	if _settings_overlay != null and _settings_overlay.visible:
		return

	if event is InputEventScreenTouch or event is InputEventMouseButton:
		if event.pressed:
			_drag_start = event.position
		else:
			_drag_start = Vector2(-1.0, -1.0)
	elif event is InputEventScreenDrag or (event is InputEventMouseMotion and (event as InputEventMouseMotion).button_mask > 0):
		if _drag_start.x < 0.0:
			return
		var dx: float = event.position.x - _drag_start.x
		if abs(dx) > SWIPE_THRESHOLD:
			_cycle_difficulty(1 if dx > 0 else -1)
			_drag_start = Vector2(-1.0, -1.0)
			get_viewport().set_input_as_handled()

func _cycle_difficulty(direction: int) -> void:
	current_difficulty_index = (current_difficulty_index + direction + difficulty_levels.size()) % difficulty_levels.size()
	update_difficulty_display()
	if GlobalSettings:
		GlobalSettings.current_difficulty = difficulty_levels[current_difficulty_index]
		GlobalSettings.last_menu_difficulty_index = current_difficulty_index
		GlobalSettings.save_settings()
	if AudioManager:
		AudioManager.play_named_sfx("beep_sound")
	_update_difficulty_preview()

func _update_difficulty_preview():
	if not is_instance_valid(word_preview_renderer) or not is_instance_valid(difficulty_preview_display):
		printerr("MainMenu: Preview renderer or display TextureRect not ready/assigned.")
		if is_instance_valid(difficulty_preview_display):
			difficulty_preview_display.texture = null
			difficulty_preview_display.custom_minimum_size = Vector2.ZERO
		return

	var current_difficulty_name: String = difficulty_levels[current_difficulty_index]
	print("MainMenu: Updating preview for '", current_difficulty_name, "'")

	if not word_preview_renderer.is_node_ready():
		print("MainMenu: word_preview_renderer not ready yet, awaiting...")
		await word_preview_renderer.ready

	word_preview_renderer.generate_preview(current_difficulty_name)
	await get_tree().process_frame
	var vp_texture: ViewportTexture = word_preview_renderer.get_texture()

	if vp_texture and vp_texture.get_width() > 0 and vp_texture.get_height() > 0:
		difficulty_preview_display.texture = vp_texture
		difficulty_preview_display.custom_minimum_size = vp_texture.get_size()
		difficulty_preview_display.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	else:
		printerr("MainMenu: Failed to get valid texture from SubViewport for '", current_difficulty_name, "'")
		difficulty_preview_display.texture = null
		difficulty_preview_display.custom_minimum_size = Vector2.ZERO

func _on_settings_button_pressed():
	if AudioManager: AudioManager.play_named_sfx("beep_sound")
	_settings_overlay.open()

func _on_start_button_pressed():
	if AudioManager: AudioManager.play_named_sfx("beep_sound")
	print("MainMenu: Starting game with difficulty: " + difficulty_levels[current_difficulty_index])
	SceneChanger.change_scene_with_fade("res://scenes/Grid.tscn", 0.3)

func update_difficulty_display():
	var key: String = difficulty_levels[current_difficulty_index]
	difficulty_label.bbcode_text = _format_label_text(Locale.t(key))
	start_label.bbcode_text     = _format_label_text(Locale.t("start"))
	settings_label.bbcode_text  = _format_label_text(Locale.t("settings"))
