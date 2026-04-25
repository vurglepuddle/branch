extends Control

signal language_changed

const BBCODE_FIRST: String = "white"
const BBCODE_REST: String = "#54fcfc"

@onready var title_label: RichTextLabel = %TitleLabel
@onready var music_label: RichTextLabel = %MusicLabel
@onready var music_toggle: TextureButton = %MusicToggle
@onready var music_value_label: RichTextLabel = %MusicValueLabel
@onready var sfx_label: RichTextLabel = %SFXLabel
@onready var sfx_toggle: TextureButton = %SFXToggle
@onready var sfx_value_label: RichTextLabel = %SFXValueLabel
@onready var graphics_label: RichTextLabel = %GraphicsLabel
@onready var graphics_toggle: TextureButton = %GraphicsToggle
@onready var graphics_value_label: RichTextLabel = %GraphicsValueLabel
@onready var language_label: RichTextLabel = %LanguageLabel
@onready var language_toggle: TextureButton = %LanguageToggle
@onready var language_value_label: RichTextLabel = %LanguageValueLabel
@onready var close_label: RichTextLabel = %CloseLabel
@onready var close_button: TextureButton = %CloseButton

func _ready() -> void:
	music_toggle.pressed.connect(_on_music_toggle)
	sfx_toggle.pressed.connect(_on_sfx_toggle)
	graphics_toggle.pressed.connect(_on_graphics_toggle)
	language_toggle.pressed.connect(_on_language_toggle)
	close_button.pressed.connect(_on_close_pressed)
	visible = false

func open() -> void:
	_refresh_labels()
	visible = true

func close() -> void:
	visible = false

func _fmt(text: String) -> String:
	if text.is_empty():
		return ""
	var first := text.substr(0, 1).to_upper()
	var rest := text.substr(1)
	return "[color=%s]%s[/color][color=%s]%s[/color]" % [BBCODE_FIRST, first, BBCODE_REST, rest]

func _music_value_text() -> String:
	match GlobalSettings.music_style:
		"modern": return Locale.t("modern")
		"off":    return Locale.t("off")
		_:        return Locale.t("classic")

func _sfx_value_text() -> String:
	return Locale.t("on") if GlobalSettings.sfx_enabled else Locale.t("off")

func _graphics_value_text() -> String:
	return Locale.t("graphics_old_label") if GlobalSettings.graphics_old else Locale.t("modern")

func _language_value_text() -> String:
	return "EN" if GlobalSettings.language == "en" else "RU"

func _refresh_labels() -> void:
	title_label.bbcode_text    = _fmt(Locale.t("settings"))
	music_label.bbcode_text    = _fmt(Locale.t("music"))
	sfx_label.bbcode_text      = _fmt(Locale.t("sfx"))
	graphics_label.bbcode_text = _fmt(Locale.t("graphics"))
	language_label.bbcode_text = _fmt(Locale.t("language"))
	close_label.bbcode_text    = _fmt(Locale.t("close"))
	music_value_label.bbcode_text    = _fmt(_music_value_text())
	sfx_value_label.bbcode_text      = _fmt(_sfx_value_text())
	graphics_value_label.bbcode_text = _fmt(_graphics_value_text())
	language_value_label.bbcode_text = _fmt(_language_value_text())

func _on_music_toggle() -> void:
	AudioManager.toggle_music_style_and_state()
	music_value_label.bbcode_text = _fmt(_music_value_text())

func _on_sfx_toggle() -> void:
	AudioManager.toggle_sfx_enabled()
	sfx_value_label.bbcode_text = _fmt(_sfx_value_text())

func _on_graphics_toggle() -> void:
	GlobalSettings.graphics_old = !GlobalSettings.graphics_old
	GlobalSettings.save_settings()
	graphics_value_label.bbcode_text = _fmt(_graphics_value_text())

func _on_language_toggle() -> void:
	GlobalSettings.language = "ru" if GlobalSettings.language == "en" else "en"
	GlobalSettings.save_settings()
	_refresh_labels()
	language_changed.emit()

func _on_close_pressed() -> void:
	close()
