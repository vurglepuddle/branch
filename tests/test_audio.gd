extends SceneTree
# Checks every music library and the settings cycle. It never saves settings, so it uses
# _advance_music_style() rather than toggle_music_style_and_state(). Run with tests/run_tests.sh.

const DIFFICULTIES: Array[String] = ["baby", "intern", "profi", "master", "expert", "torrero"]

var _failures: int = 0
var _audio: Node

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	await process_frame
	_audio = root.get_node("AudioManager")
	var settings: Node = root.get_node("GlobalSettings")
	var saved_style: String = settings.music_style

	_test_libraries_load()
	_test_cycle(settings)
	_test_style_routes_music_and_sfx()
	_test_saved_style_is_restored(settings)
	_test_labels(settings)

	settings.music_style = saved_style
	print("test_audio: %s" % ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
	quit(1 if _failures > 0 else 0)

func _test_libraries_load() -> void:
	for library in [_audio.difficulty_music, _audio.difficulty_music_modern, _audio.difficulty_music_midi_new]:
		for diff in DIFFICULTIES:
			if not library.has(diff):
				_fail("a music library is missing " + diff)
			elif not (load(library[diff]) is AudioStream):
				_fail("could not load " + library[diff])
	for theme in ["classic_menu_theme", "modern_menu_theme", "midi_new_menu_theme",
			"classic_victory_theme", "modern_victory_theme", "midi_new_victory_theme"]:
		if not (_audio.get(theme) is AudioStream):
			_fail("%s is not assigned" % theme)

func _test_cycle(settings: Node) -> void:
	_audio.is_menu_music_off = false
	_audio.current_music_style = _audio.MusicStyle.CLASSIC
	for step in [["modern", "Modern"], ["midi_new", "Midi New"], ["off", "Off"], ["classic", "Classic"]]:
		_audio._advance_music_style()
		if settings.music_style != step[0]:
			_fail("cycle reached setting '%s', expected '%s'" % [settings.music_style, step[0]])
		if _audio._music_display_name() != step[1]:
			_fail("cycle shows '%s', expected '%s'" % [_audio._music_display_name(), step[1]])

func _test_style_routes_music_and_sfx() -> void:
	var cases: Array = [
		[_audio.MusicStyle.CLASSIC, "res://audio/midi/", _audio.beep_sound, _audio.button_sound],
		[_audio.MusicStyle.MODERN, "res://audio/modern/", _audio.modern_beep_sound, _audio.modern_button_sound],
		[_audio.MusicStyle.MIDI_NEW, "res://audio/Midi_beautiful/", _audio.modern_beep_sound, _audio.modern_button_sound],
	]
	_audio.is_menu_music_off = false
	_audio.sfx_enabled = true
	for c in cases:
		_audio.current_music_style = c[0]
		_audio._update_menu_music_on_state_change(false)
		_check_track(c[1], "menu")
		_audio.play_difficulty_music("baby", true, false)
		_check_track(c[1], "difficulty")
		_audio.play_victory_music(true, false)
		_check_track(c[1], "victory")

		_audio.play_beep_pitched(3, 17)
		if _audio.sfx_player.stream != c[2]:
			_fail("%s: wrong tile beep" % c[1])
		_audio.play_named_sfx("button_sound")
		if _audio.sfx_player.stream != c[3]:
			_fail("%s: wrong button sound" % c[1])

	# Midi New loops seamlessly; the other libraries keep restarting on "finished".
	_audio.current_music_style = _audio.MusicStyle.MIDI_NEW
	_audio.play_difficulty_music("master", true, false)
	if not _audio.bg_player.stream.loop:
		_fail("Midi New track is not set to loop")
	_audio.current_music_style = _audio.MusicStyle.CLASSIC
	_audio.play_difficulty_music("master", true, false)
	if _audio.bg_player.stream.loop:
		_fail("classic track was unexpectedly set to loop")

func _check_track(folder: String, what: String) -> void:
	if not _audio.current_music_path.begins_with(folder):
		_fail("%s track came from '%s', expected %s" % [what, _audio.current_music_path, folder])

func _test_saved_style_is_restored(settings: Node) -> void:
	settings.music_style = "midi_new"
	_audio.current_music_style = _audio.MusicStyle.CLASSIC
	_audio.is_menu_music_off = true
	_audio.initialize_audio_settings()
	if _audio.current_music_style != _audio.MusicStyle.MIDI_NEW or _audio.is_menu_music_off:
		_fail("saved midi_new setting did not restore Midi New")

func _test_labels(settings: Node) -> void:
	var locale: Node = root.get_node("Locale")
	var font: Font = load("res://fonts/vetka.ttf")
	var saved_language: String = settings.language
	for language in ["en", "ru"]:
		settings.language = language
		var label: String = locale.t("midi_new")
		if label == "midi_new":
			_fail("no %s label for Midi New" % language)
		for i in range(label.length()):
			if label[i] != " " and not font.has_char(label.unicode_at(i)):
				_fail("the game font has no '%s' for the %s label" % [label[i], language])
	settings.language = saved_language

func _fail(message: String) -> void:
	_failures += 1
	printerr("FAIL: " + message)
