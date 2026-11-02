extends SceneTree
# The settings panel: every selector changes its setting in both directions, and the panel closes
# when it should. Saving is switched off, and the test checks the player's file wasn't touched.
# Run with tests/run_tests.sh.

const SETTINGS_FILE := "user://settings.cfg"
const MIN_TAP_SIZE := Vector2(60, 70)
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
	_test_names_are_gone()
	_test_title_and_close_are_centred_on_the_rows()
	_test_music_selectors_go_both_ways()
	_test_two_value_selectors()
	_test_language_updates_everything()
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

func _test_names_are_gone() -> void:
	for row in ["Music", "SFX", "Language", "SolveAnim", "TurnAnim"]:
		if _overlay.get_node_or_null("Panel/MarginContainer/VBox/Row_%s/%sLabel" % [row, row]) != null:
			_fail("%s should use its icon instead of a name" % row)

# The right arrow's tap area runs on past its drawing, so the group ends where the arrow's ink does.
func _test_title_and_close_are_centred_on_the_rows() -> void:
	var left: float = _overlay.get_node("Panel/MarginContainer/VBox/Row_Music/MusicIcon").get_global_rect().position.x
	var right: float = _overlay.get_node("%MusicNext").get_global_rect().position.x + ARROW_INK_WIDTH
	var centre: float = (left + right) / 2.0
	for label in ["%TitleLabel", "%CloseLabel"]:
		var label_centre: float = _overlay.get_node(label).get_global_rect().get_center().x
		if absf(label_centre - centre) > 1.0:
			_fail("%s is centred at x %.0f, but the rows are centred at %.0f" % [label, label_centre, centre])

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
