extends SceneTree
# The settings panel: every selector changes its setting in both directions, and the panel closes
# when it should. Saving is switched off, and the test checks the player's file wasn't touched.
# Run with tests/run_tests.sh.

const SETTINGS_FILE := "user://settings.cfg"
const MIN_TAP_SIZE := Vector2(54, 70)
const ARROW_INK_WIDTH: float = 42.0

var _failures: int = 0
var _settings: Node
var _overlay: Control

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	await process_frame
	_settings = root.get_node("GlobalSettings")
	var file_before: PackedByteArray = FileAccess.get_file_as_bytes(SETTINGS_FILE)
	var saved: Dictionary = {
		"music_style": _settings.music_style, "sfx_enabled": _settings.sfx_enabled, "language": _settings.language,
		"give_up_animation": _settings.give_up_animation, "turn_animation": _settings.turn_animation,
	}
	_settings.persist_settings = false

	_overlay = load("res://scenes/SettingsOverlay.tscn").instantiate()
	root.add_child(_overlay)
	_overlay.open()
	await process_frame
	await process_frame

	_test_rows_have_icons_and_big_tap_areas()
	_test_icons_are_exact_3x_art()
	_test_font_sizes_are_crisp()
	_test_value_column_fits_every_value()
	_test_names_are_gone()
	_test_title_and_close_are_centred_on_the_rows()
	_test_music_selectors_go_both_ways()
	_test_two_value_selectors()
	_test_language_updates_everything()
	_test_credits()
	await _test_closing()

	_overlay.queue_free()
	for key in saved:
		_settings.set(key, saved[key])
	await process_frame
	if FileAccess.get_file_as_bytes(SETTINGS_FILE) != file_before:
		_fail("the test changed the player's settings file")
	print("test_settings: %s" % ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
	quit(1 if _failures > 0 else 0)

func _test_rows_have_icons_and_big_tap_areas() -> void:
	for row in ["Music", "SFX", "Language", "SolveAnim", "TurnAnim"]:
		var icon: TextureRect = _overlay.get_node("Panel/MarginContainer/VBox/Row_%s/%sIcon" % [row, row])
		if icon.texture == null:
			_fail("%s has no icon" % row)
		for side in ["Prev", "Next"]:
			var selector: TextureButton = _overlay.get_node("%%%s%s" % [row, side])
			if selector.texture_normal == null or selector.texture_pressed == null:
				_fail("%s %s is missing a selector image" % [row, side])
			elif selector.texture_normal.get_size() != selector.texture_pressed.get_size():
				_fail("%s %s jumps when pressed, its images are different sizes" % [row, side])
			elif selector.size.x < MIN_TAP_SIZE.x or selector.size.y < MIN_TAP_SIZE.y:
				_fail("%s %s has a tap area of only %s" % [row, side, selector.size])

func _test_icons_are_exact_3x_art() -> void:
	for icon in ["Music_icon", "SFX_icon", "Language_icon", "Animation_icon", "Turn_icon",
			"Selector_left_icon_normal", "Selector_left_icon_pressed", "Selector_right_icon_normal", "Selector_right_icon_pressed"]:
		var image: Image = load("res://sprites/UI/%s.png" % icon).get_image()
		if image.get_size() != Vector2i(60, 60):
			_fail("%s is %s, the panel expects 60x60" % [icon, image.get_size()])

# The font's pixel grid is 16 per em, so any other multiple draws its pixels at fractional sizes and
# looks blurry. This reads the files, because it has to cover every screen.
func _test_font_sizes_are_crisp() -> void:
	var size_pattern := RegEx.create_from_string("font_size = (\\d+)")
	for path in ["res://scenes/SettingsOverlay.tscn", "res://scenes/main_menu.tscn", "res://scenes/GameHUD.tscn", "res://fonts/main_theme.tres"]:
		var text: String = FileAccess.get_file_as_string(path)
		for found in size_pattern.search_all(text):
			if int(found.get_string(1)) % 16 != 0:
				_fail("%s uses font size %s, which isn't crisp. Use a multiple of 16" % [path, found.get_string(1)])

# A value wider than its column pushes the row out, which makes the arrows jump as you click through.
func _test_value_column_fits_every_value() -> void:
	var font: Font = load("res://fonts/vetka.ttf")
	var strings: Dictionary = load("res://scripts/core/locale.gd").STRINGS
	for row in ["Music", "SFX", "Language", "SolveAnim", "TurnAnim"]:
		var label: RichTextLabel = _overlay.get_node("%%%sValueLabel" % row)
		var size: int = label.get_theme_font_size("normal_font_size")
		var values: Array[String] = ["EN", "RU"]
		for language in strings:
			for key in ["classic", "modern", "midi_new", "off", "on"]:
				values.append(strings[language][key])
		for value in values:
			var width: float = font.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
			if width > label.custom_minimum_size.x:
				_fail("'%s' is %.0f px wide, but the %s value column is only %.0f" % [value, width, row, label.custom_minimum_size.x])

func _test_names_are_gone() -> void:
	for row in ["Music", "SFX", "Language", "SolveAnim", "TurnAnim"]:
		if _overlay.get_node_or_null("Panel/MarginContainer/VBox/Row_%s/%sLabel" % [row, row]) != null:
			_fail("%s should use its icon instead of a name" % row)

# The right arrow's tap area runs on past its drawing, so the group ends where the arrow's ink does.
func _test_title_and_close_are_centred_on_the_rows() -> void:
	var left: float = _overlay.get_node("Panel/MarginContainer/VBox/Row_Music/MusicIcon").get_global_rect().position.x
	var right: float = _overlay.get_node("%MusicNext").get_global_rect().position.x + ARROW_INK_WIDTH
	var centre: float = (left + right) / 2.0
	var bottom_row: Control = _overlay.get_node("%CloseLabel").get_parent()
	for item in [_overlay.get_node("%TitleLabel"), bottom_row]:
		var item_centre: float = item.get_global_rect().get_center().x
		if absf(item_centre - centre) > 1.0:
			_fail("%s is centred at x %.0f, but the rows are centred at %.0f" % [item.name, item_centre, centre])

func _test_music_selectors_go_both_ways() -> void:
	_settings.music_style = "classic"
	root.get_node("AudioManager").is_menu_music_off = false
	root.get_node("AudioManager").current_music_style = root.get_node("AudioManager").MusicStyle.CLASSIC
	var forward: Array[String] = ["modern", "midi_new", "off", "classic"]
	for expected in forward:
		_overlay.get_node("%MusicNext").pressed.emit()
		_check_music(expected)
	var backward: Array[String] = ["off", "midi_new", "modern", "classic"]
	for expected in backward:
		_overlay.get_node("%MusicPrev").pressed.emit()
		_check_music(expected)

func _check_music(expected: String) -> void:
	if _settings.music_style != expected:
		_fail("the music selector reached '%s', expected '%s'" % [_settings.music_style, expected])
	var shown: String = _overlay.get_node("%MusicValueLabel").get_parsed_text()
	var wanted: String = {"classic": "Classic", "modern": "Modern", "midi_new": "Midi New", "off": "Off"}[expected]
	if _settings.language == "en" and shown != wanted:
		_fail("the music value shows '%s', expected '%s'" % [shown, wanted])

func _test_two_value_selectors() -> void:
	var cases: Dictionary = {"SFX": "sfx_enabled", "SolveAnim": "give_up_animation", "TurnAnim": "turn_animation"}
	for row in cases:
		for side in ["Prev", "Next"]:
			var before: bool = _settings.get(cases[row])
			var label: RichTextLabel = _overlay.get_node("%%%sValueLabel" % row)
			var shown_before: String = label.get_parsed_text()
			_overlay.get_node("%%%s%s" % [row, side]).pressed.emit()
			if _settings.get(cases[row]) == before:
				_fail("%s %s didn't change the setting" % [row, side])
			if label.get_parsed_text() == shown_before:
				_fail("%s %s didn't update the value on screen" % [row, side])

func _test_language_updates_everything() -> void:
	var title: RichTextLabel = _overlay.get_node("%TitleLabel")
	var heard_signal: Array[bool] = [false]
	_overlay.language_changed.connect(func(): heard_signal[0] = true)
	_settings.language = "en"
	_overlay._refresh_labels()
	var english_title: String = title.get_parsed_text()
	_overlay.get_node("%LanguageNext").pressed.emit()
	if _settings.language != "ru" or title.get_parsed_text() == english_title:
		_fail("the language selector should switch the panel to the other language")
	if not heard_signal[0]:
		_fail("changing language should tell the rest of the game")
	_overlay.get_node("%LanguagePrev").pressed.emit()
	if _settings.language != "en" or title.get_parsed_text() != english_title:
		_fail("the other language arrow should switch back")

func _test_credits() -> void:
	_settings.language = "en"
	_overlay.open()
	var title: RichTextLabel = _overlay.get_node("%TitleLabel")
	var body: RichTextLabel = _overlay.get_node("%CreditsBody")
	var close_word: RichTextLabel = _overlay.get_node("%CloseLabel")
	var credits_word: RichTextLabel = _overlay.get_node("%CreditsLabel")
	var row: Control = _overlay.get_node("%MusicNext").get_parent()
	_expect(not body.visible and credits_word.visible and row.visible, "settings should show its rows and the Credits word")

	_click(credits_word)
	_expect(_overlay.visible and body.visible and not row.visible and not credits_word.visible, "Credits should replace the rows with the credits")
	_expect(title.get_parsed_text() == "Credits" and close_word.get_parsed_text() == "Back", "the credits page should say Credits and Back")

	var required: Array[String] = ["vurglepuddle", "Salamander Grand Piano V3", "Alexander Holm", "CC BY 3.0", "Godot", "godotengine.org/license", "GPL-3.0", "CC BY-NC-SA 4.0"]
	var version: String = ProjectSettings.get_setting("application/config/version", "")
	_expect(version == "1.0.0", "the project version should be 1.0.0, it is '%s'" % version)
	var font: Font = load("res://fonts/vetka.ttf")
	var locale: Node = root.get_node("Locale")
	for language in ["en", "ru"]:
		_settings.language = language
		_overlay._refresh_labels()
		var text: String = body.get_parsed_text().replace("\n", " ")
		_expect(text.contains(version), "the %s credits should show the version" % language)
		for piece in required:
			_expect(text.contains(piece), "the %s credits are missing '%s'" % [language, piece])
		_expect(text.split(" ", false).size() < 40, "the %s credits should stay brief" % language)
		for word in [text, locale.t("credits"), locale.t("back")]:
			for i in range(word.length()):
				if word[i] != " " and word[i] != "\n" and not font.has_char(word.unicode_at(i)):
					_fail("the game font has no '%s' for the %s credits" % [word[i], language])
	_settings.language = "en"
	_overlay._refresh_labels()

	_click(close_word)
	_expect(_overlay.visible, "Back should return to settings, not close the panel")
	_expect(not body.visible and row.visible and credits_word.visible, "Back should bring the rows back")
	_expect(title.get_parsed_text() == "Settings" and close_word.get_parsed_text() == "Close", "Back should restore Settings and Close")

	# Leaving from the credits page and coming back starts on settings.
	_click(credits_word)
	_press_at(Vector2(4, 4))
	_expect(not _overlay.visible, "a tap outside should still close the panel from the credits")
	_overlay.open()
	_expect(not body.visible and row.visible, "opening the panel should always start on settings")

	# A phone sends a touch as well as the mouse press, and only one of them may count.
	var touch := InputEventScreenTouch.new()
	touch.pressed = true
	credits_word.gui_input.emit(touch)
	_expect(not body.visible, "a touch event alone shouldn't count, or one tap would act twice")

func _click(control: Control) -> void:
	var tap := InputEventMouseButton.new()
	tap.pressed = true
	tap.button_index = MOUSE_BUTTON_LEFT
	control.gui_input.emit(tap)

func _expect(condition: bool, message: String) -> void:
	if not condition:
		_fail(message)

func _test_closing() -> void:
	_overlay.open()
	await process_frame
	var inside: Vector2 = _overlay.get_node("%TurnAnimPrev").get_global_rect().get_center()
	_press_at(inside)
	if not _overlay.visible:
		_fail("a tap on a selector shouldn't close the panel")
	_press_at(Vector2(4, 4))
	if _overlay.visible:
		_fail("a tap outside the panel should close it")

	_overlay.open()
	var tap := InputEventMouseButton.new()
	tap.pressed = true
	tap.button_index = MOUSE_BUTTON_LEFT
	_overlay.get_node("%CloseLabel").gui_input.emit(tap)
	if _overlay.visible:
		_fail("tapping Close should close the panel")

func _press_at(where: Vector2) -> void:
	var tap := InputEventMouseButton.new()
	tap.pressed = true
	tap.button_index = MOUSE_BUTTON_LEFT
	tap.position = where
	_overlay._input(tap)

func _fail(message: String) -> void:
	_failures += 1
	printerr("FAIL: " + message)
