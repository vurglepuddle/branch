extends Control # res://scenes/main_menu.gd

const BranchType = preload("res://scripts/core/branch_types.gd").BranchType
const _BranchScene: PackedScene = preload("res://scenes/Branch.tscn")
const _PuzzleGenerator = preload("res://scripts/core/puzzle_generator.gd")

# Prim density settings mirrored from grid.gd (only what generate_solvable_puzzle needs).
const _PRIM_SETTINGS: Dictionary = {
	"baby":    {"factor": 0.75, "min": 7, "final_factor": 0.75, "variation": 0.2, "attempts": 12},
	"intern":  {"factor": 0.5, "min": 14, "final_factor": 0.5, "variation": 0.1, "attempts": 12},
	"profi":   {"factor": 0.55, "min": 28, "final_factor": 0.55, "variation": 0.1, "attempts": 14},
	"master":  {"factor": 0.7, "min": 38, "final_factor": 0.7, "variation": 0.1, "attempts": 10},
	"expert":  {"factor": 1.0, "min": 85, "final_factor": 0.75, "variation": 0.05, "attempts": 15},
	"torrero": {"factor": 1.0, "min": 85, "final_factor": 0.86, "variation": 0.05, "attempts": 15},
}

@onready var difficulty_label: RichTextLabel = %DifficultyLabel
@onready var start_button: TextureButton = %MenuItemsContainer/HBox/StartButton
@onready var start_label: RichTextLabel = %MenuItemsContainer/HBox/StartLabel
@onready var settings_label: RichTextLabel = %MenuItemsContainer/HBox/SFX_HBox/SettingsLabel
@onready var settings_button: TextureButton = %MenuItemsContainer/HBox/SFX_HBox/SettingsButton

@onready var word_preview_renderer: SubViewport = $WordPreviewRenderer
@onready var difficulty_preview_display: TextureRect = $DifficultyPreviewDisplay
@onready var _hint_left: RichTextLabel = %SwipeHintLeft
@onready var _hint_right: RichTextLabel = %SwipeHintRight

var difficulty_levels: Array = ["baby", "intern", "profi", "master", "expert", "torrero"]
var current_difficulty_index: int

const BBCODE_FIRST_LETTER_COLOR: String = "white"
const BBCODE_REST_LETTERS_COLOR: String = "#54fcfc"
const SWIPE_THRESHOLD: float = 60.0

var _drag_start: Vector2 = Vector2(-1.0, -1.0)
var _settings_overlay: Control
var _transitioning: bool = false
var _preview_generation_id: int = 0

func _format_label_text(base_text: String) -> String:
	if base_text.is_empty():
		return ""
	var first_char := base_text.substr(0, 1).to_upper()
	var rest_chars := base_text.substr(1)
	return "[color=%s]%s[/color][color=%s]%s[/color]" % [BBCODE_FIRST_LETTER_COLOR, first_char, BBCODE_REST_LETTERS_COLOR, rest_chars]

func _ready():
	start_button.pressed.connect(_on_start_button_pressed)
	settings_button.pressed.connect(_on_settings_button_pressed)
	difficulty_preview_display.visible = false
	difficulty_preview_display.texture = null
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
	_animate_swipe_hints()
	update_difficulty_display()
	if GlobalSettings:
		GlobalSettings.current_difficulty = difficulty_levels[current_difficulty_index]

func _initialize_post_audio_manager_ready():
	_update_difficulty_preview()

	if GlobalSettings.return_from_game:
		GlobalSettings.return_from_game = false
		return  # overlay in grid.gd is still covering; no fade needed

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
	if _transitioning or (_settings_overlay != null and _settings_overlay.visible):
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
			_cycle_difficulty(-1 if dx > 0 else 1)
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
	_preview_generation_id += 1
	var generation_id: int = _preview_generation_id

	if not is_instance_valid(word_preview_renderer) or not is_instance_valid(difficulty_preview_display):
		printerr("MainMenu: Preview renderer or display TextureRect not ready/assigned.")
		if is_instance_valid(difficulty_preview_display):
			difficulty_preview_display.texture = null
			difficulty_preview_display.custom_minimum_size = Vector2.ZERO
			difficulty_preview_display.visible = false
		return

	var current_difficulty_name: String = difficulty_levels[current_difficulty_index]
	print("MainMenu: Updating preview for '", current_difficulty_name, "'")

	difficulty_preview_display.visible = false
	difficulty_preview_display.texture = null

	if not word_preview_renderer.is_node_ready():
		print("MainMenu: word_preview_renderer not ready yet, awaiting...")
		await word_preview_renderer.ready
		if generation_id != _preview_generation_id:
			return

	word_preview_renderer.generate_preview(current_difficulty_name)
	await get_tree().process_frame
	await get_tree().process_frame
	if generation_id != _preview_generation_id:
		return

	var vp_texture: ViewportTexture = word_preview_renderer.get_texture()

	if vp_texture and vp_texture.get_width() > 0 and vp_texture.get_height() > 0:
		difficulty_preview_display.texture = vp_texture
		difficulty_preview_display.custom_minimum_size = vp_texture.get_size()
		difficulty_preview_display.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		difficulty_preview_display.visible = true
	else:
		printerr("MainMenu: Failed to get valid texture from SubViewport for '", current_difficulty_name, "'")
		difficulty_preview_display.texture = null
		difficulty_preview_display.custom_minimum_size = Vector2.ZERO
		difficulty_preview_display.visible = false

func _animate_swipe_hints() -> void:
	var orig_left: float  = _hint_left.position.x
	var orig_right: float = _hint_right.position.x
	while is_instance_valid(self) and not _transitioning:
		await get_tree().create_timer(2.5).timeout
		if not is_instance_valid(self) or _transitioning:
			break
		var t1 := create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		t1.tween_property(_hint_left,  "position:x", orig_left  - 12.0, 0.22)
		t1.tween_property(_hint_right, "position:x", orig_right + 12.0, 0.22)
		await t1.finished
		var t2 := create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		t2.tween_property(_hint_left,  "position:x", orig_left,  0.22)
		t2.tween_property(_hint_right, "position:x", orig_right, 0.22)
		await t2.finished

func _on_settings_button_pressed():
	if AudioManager: AudioManager.play_named_sfx("beep_sound")
	_settings_overlay.open()

func _on_start_button_pressed() -> void:
	if _transitioning:
		return
	if AudioManager:
		AudioManager.play_named_sfx("beep_sound")
	_start_transition()

func _start_transition() -> void:
	_transitioning = true
	start_button.disabled = true
	settings_button.disabled = true

	_generate_and_store_puzzle()
	_slide_menu_down()
	await _animate_tile_loadout()

	# Add Grid to root before freeing self — no scene switch, no viewport clear.
	var grid: Node = load("res://scenes/Grid.tscn").instantiate()
	get_tree().root.add_child(grid)
	get_tree().current_scene = grid
	_retire_preview_renderer()
	await get_tree().process_frame
	queue_free()

func _retire_preview_renderer() -> void:
	if is_instance_valid(difficulty_preview_display):
		difficulty_preview_display.texture = null
		difficulty_preview_display.visible = false
	if is_instance_valid(word_preview_renderer) and word_preview_renderer.has_method("clear_preview"):
		word_preview_renderer.clear_preview()

func _generate_and_store_puzzle() -> void:
	var diff: String = difficulty_levels[current_difficulty_index]
	var is_toroidal: bool = (diff == "torrero")
	var s: Dictionary = _PRIM_SETTINGS[diff]
	var valid_cells: Dictionary = DifficultyLayouts.get_valid_cells(diff)
	var min_acceptable_tiles: int = _get_min_acceptable_tiles(valid_cells.size(), s)
	var max_attempts: int = int(s["attempts"])

	var generator = _PuzzleGenerator.new()
	var puzzle_data: Dictionary = {}
	var best_puzzle_data: Dictionary = {}
	var best_active_count: int = -1

	for attempt in range(max_attempts):
		var candidate: Dictionary = generator.generate_solvable_puzzle(
			6, 17,
			_BranchScene,
			s["factor"], s["min"],
			is_toroidal,
			valid_cells
		)
		var active_count: int = generator.get_active_tile_count(candidate)
		var initially_solved: bool = generator.is_puzzle_initially_solved(candidate)

		if not initially_solved and active_count >= min_acceptable_tiles:
			if not best_puzzle_data.is_empty():
				generator.free_puzzle_nodes(best_puzzle_data)
			puzzle_data = candidate
			break

		if not initially_solved and active_count > best_active_count:
			if not best_puzzle_data.is_empty():
				generator.free_puzzle_nodes(best_puzzle_data)
			best_active_count = active_count
			best_puzzle_data = candidate
		else:
			generator.free_puzzle_nodes(candidate)

	if puzzle_data.is_empty():
		puzzle_data = best_puzzle_data
	if puzzle_data.is_empty():
		puzzle_data = generator.generate_solvable_puzzle(
			6, 17,
			_BranchScene,
			s["factor"], s["min"],
			is_toroidal,
			valid_cells
		)
	generator.ensure_puzzle_not_initially_solved(puzzle_data)

	GlobalSettings.pending_puzzle_data = puzzle_data
	GlobalSettings.pending_puzzle_is_toroidal = is_toroidal

func _get_min_acceptable_tiles(num_total_cells: int, settings: Dictionary) -> int:
	var base_desired_tiles: int = int(floor(num_total_cells * settings["final_factor"]))
	var variation_amount: int = int(floor(base_desired_tiles * settings["variation"]))
	return int(clamp(base_desired_tiles - variation_amount, 1, num_total_cells))

func _slide_menu_down() -> void:
	var mic: Node = %MenuItemsContainer
	var panel: Node = $PanelBg_mainmenu
	var hbox: Node = $MenuItemsContainer/HBox
	var tween := create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tween.tween_property(mic,   "offset_top",    mic.offset_top    + 300.0, 0.5)
	tween.tween_property(mic,   "offset_bottom", mic.offset_bottom + 300.0, 0.5)
	tween.tween_property(panel, "offset_top",    panel.offset_top  + 300.0, 0.5)
	tween.tween_property(panel, "offset_bottom", panel.offset_bottom + 300.0, 0.5)
	tween.tween_property(%DifficultyLabel, "modulate:a", 0.0, 0.25)
	tween.tween_property(hbox, "modulate:a", 0.0, 0.25)
	tween.tween_property(_hint_left,  "modulate:a", 0.0, 0.25)
	tween.tween_property(_hint_right, "modulate:a", 0.0, 0.25)

func _collect_animation_positions() -> Array:
	var pos_set: Dictionary = {}
	var diff: String = difficulty_levels[current_difficulty_index]

	# All positions shown in the preview layout
	for tile_info in DifficultyLayouts.PREVIEW_LAYOUTS.get(diff, []):
		pos_set[tile_info["pos"]] = true

	# All non-EMPTY positions in the generated puzzle
	var branches: Array = GlobalSettings.pending_puzzle_data.get("branches", [])
	for x in range(branches.size()):
		for y in range(branches[x].size()):
			var b = branches[x][y]
			if b != null and b.branch_type != BranchType.EMPTY:
				pos_set[Vector2i(x, y)] = true

	var result: Array = pos_set.keys()
	result.shuffle()
	return result

func _animate_tile_loadout() -> void:
	var branches: Array = GlobalSettings.pending_puzzle_data.get("branches", [])
	var positions: Array = _collect_animation_positions()

	for pos in positions:
		await get_tree().create_timer(0.02).timeout
		var x: int = pos.x
		var y: int = pos.y
		var b = branches[x][y] if x < branches.size() and y < branches[x].size() else null

		if b != null and b.branch_type != BranchType.EMPTY:
			word_preview_renderer.update_tile(x, y, b.branch_type, b.rotation_index, b.state)
		else:
			word_preview_renderer.hide_tile(x, y)

		if AudioManager:
			AudioManager.play_beep_pitched(pos.y, 17)

func update_difficulty_display():
	var key: String = difficulty_levels[current_difficulty_index]
	difficulty_label.bbcode_text = "[center][color=#54fcfc]" + Locale.t(key) + "[/color][/center]"
	start_label.bbcode_text     = _format_label_text(Locale.t("start"))
	settings_label.bbcode_text  = _format_label_text(Locale.t("settings"))
