extends CanvasLayer

signal give_up_requested

# Panel slides with anchor_top=1 / anchor_bottom=1, so offsets are relative to parent bottom.
# Closed: only handle tab (28px) visible above screen edge.
# Open:   full 144px panel visible.
const PANEL_CLOSED_OFFSET_TOP: float    = -32.0
const PANEL_CLOSED_OFFSET_BOTTOM: float = 70.0
const PANEL_OPEN_OFFSET_TOP: float      = -102.0
const PANEL_OPEN_OFFSET_BOTTOM: float   = 0.0
const PANEL_HEIGHT: float               = 102.0
const HANDLE_HEIGHT: float              = 32.0

# Only detect swipes that start inside the handle zone (below the tile grid).
const SWIPE_ZONE: float     = 35.0
const SWIPE_THRESHOLD: float = 60.0

const BBCODE_FIRST: String = "white"
const BBCODE_REST: String  = "#54fcfc"

var panel_is_open: bool  = false  # read by grid.gd to block branch taps
var locked: bool         = false  # set by grid.gd during solve animation
var _panel_open: bool:
	get: return panel_is_open
	set(v): panel_is_open = v
var _animating: bool     = false
var _drag_start: Vector2 = Vector2(-1.0, -1.0)
var _settings_overlay: Control

@onready var _panel: Control             = $HUDRoot/Panel
@onready var _button_area: HBoxContainer = $HUDRoot/Panel/ButtonArea
@onready var _give_up_button: TextureButton  = %GiveUpButton
@onready var _give_up_label: RichTextLabel   = %GiveUpLabel
@onready var _settings_button: TextureButton = %SettingsButton
@onready var _settings_label: RichTextLabel  = %SettingsLabel

func _ready() -> void:
	_give_up_button.pressed.connect(_on_give_up_pressed)
	_settings_button.pressed.connect(_on_settings_button_pressed)

	var overlay_scene: PackedScene = preload("res://scenes/SettingsOverlay.tscn")
	_settings_overlay = overlay_scene.instantiate()
	$HUDRoot.add_child(_settings_overlay)
	_settings_overlay.language_changed.connect(_refresh_labels)

	_refresh_labels()

func _fmt(text: String) -> String:
	if text.is_empty():
		return ""
	return "[color=%s]%s[/color][color=%s]%s[/color]" % [
		BBCODE_FIRST, text.substr(0, 1).to_upper(),
		BBCODE_REST,  text.substr(1)
	]

func _refresh_labels() -> void:
	_give_up_label.bbcode_text  = _fmt(Locale.t("give_up"))
	_settings_label.bbcode_text = _fmt(Locale.t("settings"))

func _show_panel() -> void:
	if _animating or _panel_open:
		return
	_panel_open = true
	_animating  = true
	_refresh_labels()
	_button_area.modulate.a = 0.0
	var tween := create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(_panel, "offset_top",    PANEL_OPEN_OFFSET_TOP,    0.28)
	tween.tween_property(_panel, "offset_bottom", PANEL_OPEN_OFFSET_BOTTOM, 0.28)
	tween.tween_property(_button_area, "modulate:a", 1.0, 0.08)
	tween.chain().tween_callback(func(): _animating = false)

func _hide_panel() -> void:
	if _animating or not _panel_open:
		return
	_panel_open = false
	_animating  = true
	var tween := create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tween.tween_property(_panel, "offset_top",    PANEL_CLOSED_OFFSET_TOP,    0.22)
	tween.tween_property(_panel, "offset_bottom", PANEL_CLOSED_OFFSET_BOTTOM, 0.22)
	tween.tween_property(_button_area, "modulate:a", 0.0, 0.06)
	tween.chain().tween_callback(func(): _animating = false)

func _toggle_panel() -> void:
	if _panel_open:
		_hide_panel()
	else:
		_show_panel()

func hide_panel() -> void:
	_hide_panel()

func _input(event: InputEvent) -> void:
	if locked or _animating or (_settings_overlay != null and _settings_overlay.visible):
		return

	var vp_h: float = get_viewport().get_visible_rect().size.y

	if event is InputEventScreenTouch or event is InputEventMouseButton:
		if event.pressed:
			_drag_start = event.position
			# Consume presses in the handle zone only when closed — no tiles exist there.
			if not _panel_open and event.position.y >= vp_h - SWIPE_ZONE:
				get_viewport().set_input_as_handled()
		else:
			# Tap-to-toggle: release in handle zone with minimal movement.
			if _drag_start.x >= 0.0:
				var moved: float = event.position.distance_to(_drag_start)
				if moved < 20.0 and _drag_start.y >= vp_h - SWIPE_ZONE and not _panel_open:
					_toggle_panel()
					get_viewport().set_input_as_handled()
			_drag_start = Vector2(-1.0, -1.0)

	elif event is InputEventScreenDrag or (event is InputEventMouseMotion and (event as InputEventMouseMotion).button_mask > 0):
		if _drag_start.x < 0.0:
			return
		var dy: float = event.position.y - _drag_start.y
		if not _panel_open and dy < -SWIPE_THRESHOLD and _drag_start.y >= vp_h - SWIPE_ZONE:
			_show_panel()
			_drag_start = Vector2(-1.0, -1.0)
			get_viewport().set_input_as_handled()
		elif _panel_open and dy > SWIPE_THRESHOLD:
			_hide_panel()
			_drag_start = Vector2(-1.0, -1.0)
			get_viewport().set_input_as_handled()

func _on_give_up_pressed() -> void:
	give_up_requested.emit()

func _on_settings_button_pressed() -> void:
	if AudioManager:
		AudioManager.play_named_sfx("beep_sound")
	_settings_overlay.open()
