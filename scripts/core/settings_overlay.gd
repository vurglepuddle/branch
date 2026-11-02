extends Control

signal language_changed

const BBCODE_FIRST: String = "#590000"
const BBCODE_REST: String = "#590000"
# const BBCODE_FIRST: String = "white"
# const BBCODE_REST: String = "#54fcfc"
const BOTTOM_ROW_WIDTH: float = 304.0
const CREDITS_WORD_WIDTH: float = 148.0 # Credits and Close share the row, with its 8 px gap between them

@onready var title_label: RichTextLabel = %TitleLabel
@onready var music_prev: TextureButton = %MusicPrev
@onready var music_next: TextureButton = %MusicNext
@onready var music_value_label: RichTextLabel = %MusicValueLabel
@onready var sfx_prev: TextureButton = %SFXPrev
@onready var sfx_next: TextureButton = %SFXNext
@onready var sfx_value_label: RichTextLabel = %SFXValueLabel
@onready var graphics_label: RichTextLabel = %GraphicsLabel
@onready var graphics_toggle: TextureButton = %GraphicsToggle
@onready var graphics_value_label: RichTextLabel = %GraphicsValueLabel
@onready var language_prev: TextureButton = %LanguagePrev
@onready var language_next: TextureButton = %LanguageNext
@onready var language_value_label: RichTextLabel = %LanguageValueLabel
@onready var solve_anim_prev: TextureButton = %SolveAnimPrev
@onready var solve_anim_next: TextureButton = %SolveAnimNext
@onready var solve_anim_value_label: RichTextLabel = %SolveAnimValueLabel
@onready var turn_anim_prev: TextureButton = %TurnAnimPrev
@onready var turn_anim_next: TextureButton = %TurnAnimNext
@onready var turn_anim_value_label: RichTextLabel = %TurnAnimValueLabel
@onready var close_label: RichTextLabel = %CloseLabel
@onready var credits_label: RichTextLabel = %CreditsLabel
@onready var credits_body: RichTextLabel = %CreditsBody
@onready var _setting_rows: Array[Control] = [$Panel/MarginContainer/VBox/Row_Music, $Panel/MarginContainer/VBox/Row_SFX,
	$Panel/MarginContainer/VBox/Row_Language, $Panel/MarginContainer/VBox/Row_SolveAnim, $Panel/MarginContainer/VBox/Row_TurnAnim]

var _showing_credits: bool = false

func _ready() -> void:
	music_prev.pressed.connect(_on_music_changed.bind(-1))
	music_next.pressed.connect(_on_music_changed.bind(1))
	graphics_toggle.pressed.connect(_on_graphics_toggle)
	# These settings only have two values, so both arrows do the same thing.
	for selector in [sfx_prev, sfx_next]:
		selector.pressed.connect(_on_sfx_toggle)
	for selector in [language_prev, language_next]:
		selector.pressed.connect(_on_language_toggle)
	for selector in [solve_anim_prev, solve_anim_next]:
		selector.pressed.connect(_on_solve_anim_toggle)
	for selector in [turn_anim_prev, turn_anim_next]:
		selector.pressed.connect(_on_turn_anim_toggle)
	close_label.gui_input.connect(_on_close_label_input)
	credits_label.gui_input.connect(_on_credits_label_input)
	visible = false

func open() -> void:
	_show_credits(false)
	visible = true

func _show_credits(show_them: bool) -> void:
	_showing_credits = show_them
	for row in _setting_rows:
		row.visible = not show_them
	credits_body.visible = show_them
	credits_label.visible = not show_them
	close_label.custom_minimum_size.x = BOTTOM_ROW_WIDTH if show_them else CREDITS_WORD_WIDTH
	_refresh_labels()
	if show_them:
		print(Engine.get_license_text()) # Godot's license asks for its text to be available to players

func close() -> void:
	visible = false

func _fmt(text: String) -> String:
	if text.is_empty():
		return ""
	var first := text.substr(0, 1).to_upper()
	var rest := text.substr(1)
	return "[color=%s]%s[/color][color=%s]%s[/color]" % [BBCODE_FIRST, first, BBCODE_REST, rest]

func _fmt_centered(text: String) -> String:
	return "[center]%s[/center]" % _fmt(text)

func _music_value_text() -> String:
	match GlobalSettings.music_style:
		"modern": return Locale.t("modern")
		"midi_new": return Locale.t("midi_new")
		"off":    return Locale.t("off")
		_:        return Locale.t("classic")

# The name goes with the value, because the rows only have icons to say what they are.
func _on_off_text(name_key: String, enabled: bool) -> String:
	return "%s %s" % [Locale.t(name_key), Locale.t("on" if enabled else "off")]

func _sfx_value_text() -> String:
	return _on_off_text("sfx_value", GlobalSettings.sfx_enabled)

func _graphics_value_text() -> String:
	return Locale.t("graphics_old_label") if GlobalSettings.graphics_old else Locale.t("modern")

func _language_value_text() -> String:
	return "EN" if GlobalSettings.language == "en" else "RU"

func _solve_anim_value_text() -> String:
	return _on_off_text("anim_value", GlobalSettings.give_up_animation)

func _turn_anim_value_text() -> String:
	return _on_off_text("turn_value", GlobalSettings.turn_animation)

func _refresh_labels() -> void:
	title_label.bbcode_text          = _fmt_centered(Locale.t("credits" if _showing_credits else "settings"))
	graphics_label.bbcode_text       = _fmt(Locale.t("graphics"))
	close_label.bbcode_text          = _fmt_centered(Locale.t("back" if _showing_credits else "close"))
	credits_label.bbcode_text        = _fmt_centered(Locale.t("credits"))
	credits_body.bbcode_text         = "[center][color=%s]%s[/color][/center]" % [BBCODE_REST, Locale.t("credits_body") % ProjectSettings.get_setting("application/config/version", "")]
	music_value_label.bbcode_text    = _fmt_centered(_music_value_text())
	sfx_value_label.bbcode_text      = _fmt_centered(_sfx_value_text())
	graphics_value_label.bbcode_text = _fmt(_graphics_value_text())
	language_value_label.bbcode_text = _fmt_centered(_language_value_text())
	solve_anim_value_label.bbcode_text = _fmt_centered(_solve_anim_value_text())
	turn_anim_value_label.bbcode_text = _fmt_centered(_turn_anim_value_text())

func _on_music_changed(direction: int) -> void:
	AudioManager.toggle_music_style_and_state(direction)
	music_value_label.bbcode_text = _fmt_centered(_music_value_text())

func _on_sfx_toggle() -> void:
	AudioManager.toggle_sfx_enabled()
	sfx_value_label.bbcode_text = _fmt_centered(_sfx_value_text())

func _on_graphics_toggle() -> void:
	_play_button_sound()
	GlobalSettings.graphics_old = !GlobalSettings.graphics_old
	GlobalSettings.save_settings()
	graphics_value_label.bbcode_text = _fmt(_graphics_value_text())

func _on_language_toggle() -> void:
	_play_button_sound()
	GlobalSettings.language = "ru" if GlobalSettings.language == "en" else "en"
	GlobalSettings.save_settings()
	_refresh_labels()
	language_changed.emit()

func _on_solve_anim_toggle() -> void:
	_play_button_sound()
	GlobalSettings.give_up_animation = !GlobalSettings.give_up_animation
	GlobalSettings.save_settings()
	solve_anim_value_label.bbcode_text = _fmt_centered(_solve_anim_value_text())

func _on_turn_anim_toggle() -> void:
	_play_button_sound()
	GlobalSettings.turn_animation = !GlobalSettings.turn_animation
	GlobalSettings.save_settings()
	turn_anim_value_label.bbcode_text = _fmt_centered(_turn_anim_value_text())

func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventMouseButton or event is InputEventScreenTouch:
		if event.pressed and not $Panel.get_global_rect().has_point(event.position):
			_play_button_sound()
			close()
			get_viewport().set_input_as_handled()

# Only mouse presses count here. A phone sends a touch and then a matching mouse press for every tap,
# so handling both would make one tap on Back also close the panel.
func _on_close_label_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_play_button_sound()
		if _showing_credits:
			_show_credits(false)
		else:
			close()

func _on_credits_label_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_play_button_sound()
		_show_credits(true)

func _play_button_sound() -> void:
	if AudioManager:
		AudioManager.play_named_sfx("button_sound")
