class_name PauseMenu
extends CanvasLayer
## PauseMenu — Start-button pause (project.godot "pause" action: both
## pads' Start + Esc). Dusk-blue dim overlay + a row of big rounded,
## icon+label buttons (icon-only was the v1 floor; v2 adds short labels
## per the Xbox Accessibility Guidelines' icon-consistency rule —
## docs/research/v2/ui_writing.md §2 — since the parent-facing options
## subpanel below genuinely needs more than three unlabeled glyphs to stay
## legible). "Keep Playing" resumes instantly. "Options" opens a subpanel
## (music/sfx volume, voice_mode, camera manual + sensitivity — all
## persisted through GameState.settings/SaveManager, D18/D20). "Sleep"
## quits to the title screen, but now requires a **hold**, not a tap
## (HoldRing) — "no quit-without-confirm" for a pre-reader who might tap
## a button just to see what it does; progress is already autosaved on
## every dream_returned/fort change (D14), so the hold is about accidental
## taps, not data loss. process_mode WHEN_PAUSED keeps everything live
## while get_tree().paused freezes gameplay.
##
## "Photo" (camera icon, between Options and Sleep) hands off to PhotoMode
## (scenes/ui/photo_mode.gd) via the photo_mode_requested signal below --
## GameUI owns and wires the actual PhotoMode instance since it also owns
## HUD, which photo mode needs to hide. This menu just hides itself
## (visible = false, tree stays paused) for the duration; PhotoMode's own
## exit() flips it back to visible.

signal photo_mode_requested

const OVERLAY_COLOR: Color = Color(0.180392, 0.231373, 0.368627, 0.82) # dusk blue, dim overlay
const BUTTON_BG_COLOR: Color = Color(0.243137, 0.301961, 0.427451, 1.0) # lighter dusk blue
const BUTTON_FOCUS_COLOR: Color = Color(0.94902, 0.784314, 0.474510, 1.0) # honey glow
const TEXT_COLOR: Color = Color(0.960784, 0.94902, 0.909804, 1.0) # milk white
const BUTTON_SIZE: Vector2 = Vector2(180.0, 180.0)
const BUTTON_GAP: float = 40.0
const CORNER_RADIUS: int = 32
const FOCUS_BORDER_WIDTH: int = 6
const LABEL_FONT_SIZE: int = 16

const ROW_ICON_SIZE: float = 40.0
const ROW_HEIGHT: float = 56.0
const ROW_GAP: float = 14.0
const OPTIONS_PANEL_WIDTH: float = 480.0
const SLIDER_MIN_WIDTH: float = 200.0

const SLEEP_HOLD_SECONDS: float = 1.1
const HOLD_RING_MARGIN: float = -10.0 # ring drawn slightly outside the Sleep button's own rect

const VOICE_MODE_CYCLE: PackedStringArray = ["moonsong+text", "moonsong+tts", "text_only"]
const VOICE_MODE_ICON: Dictionary = {
	"moonsong+text": IconDraw.Kind.VOICE_NOTES,
	"moonsong+tts": IconDraw.Kind.VOICE_MOUTH,
	"text_only": IconDraw.Kind.VOICE_TEXT,
}
const VOICE_MODE_LABEL: Dictionary = {
	"moonsong+text": "Moon (song)",
	"moonsong+tts": "Moon (song + voice)",
	"text_only": "Words only",
}

var _keep_playing_button: Button = null
var _options_button: Button = null
var _photo_button: Button = null
var _sleep_button: Button = null
var _sleep_ring: HoldRing = null

var _main_row: HBoxContainer = null
var _options_panel: PanelContainer = null
var _music_slider: HSlider = null
var _sfx_slider: HSlider = null
var _voice_button: Button = null
var _voice_icon: IconDraw = null
var _camera_toggle_button: Button = null
var _sensitivity_slider: HSlider = null
var _back_button: Button = null

var _sleep_hold_time: float = 0.0
var _sleep_mouse_held: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	layer = 10 # above the HUD (layer 5) and subtitle ribbon (layer 6)
	visible = false
	_build_ui()
	_keep_playing_button.pressed.connect(_on_keep_playing_pressed)
	_options_button.pressed.connect(_on_options_pressed)
	_photo_button.pressed.connect(_on_photo_pressed)
	_sleep_button.button_down.connect(func() -> void: _sleep_mouse_held = true)
	_sleep_button.button_up.connect(func() -> void: _sleep_mouse_held = false)
	_back_button.pressed.connect(_on_back_pressed)


func _build_ui() -> void:
	var overlay := ColorRect.new()
	overlay.name = "Overlay"
	overlay.color = OVERLAY_COLOR
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(overlay)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(center)

	_build_main_row(center)
	_build_options_panel(center)
	_layout_focus_neighbors()


# ---------------------------------------------------------------------------
# Main row: Keep Playing / Options / Sleep
# ---------------------------------------------------------------------------

func _build_main_row(parent: Control) -> void:
	_main_row = HBoxContainer.new()
	_main_row.name = "MainRow"
	_main_row.add_theme_constant_override("separation", int(BUTTON_GAP))
	parent.add_child(_main_row)

	_keep_playing_button = _make_icon_button(IconDraw.Kind.PLAY, "Keep Playing")
	_options_button = _make_icon_button(IconDraw.Kind.GEAR, "Options")
	_photo_button = _make_icon_button(IconDraw.Kind.CAMERA, "Photo")
	_sleep_button = _make_icon_button(IconDraw.Kind.MOON, "Sleep")
	_main_row.add_child(_keep_playing_button)
	_main_row.add_child(_options_button)
	_main_row.add_child(_photo_button)
	_main_row.add_child(_sleep_button)

	_sleep_ring = HoldRing.new()
	_sleep_ring.name = "SleepHoldRing"
	_sleep_ring.set_anchors_preset(Control.PRESET_FULL_RECT)
	_sleep_ring.offset_left = HOLD_RING_MARGIN
	_sleep_ring.offset_top = HOLD_RING_MARGIN
	_sleep_ring.offset_right = -HOLD_RING_MARGIN
	_sleep_ring.offset_bottom = -HOLD_RING_MARGIN
	_sleep_button.add_child(_sleep_ring)


func _make_icon_button(icon_kind: IconDraw.Kind, label_text: String) -> Button:
	var button := Button.new()
	button.custom_minimum_size = BUTTON_SIZE
	button.focus_mode = Control.FOCUS_ALL
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	_style_button(button)

	var content := VBoxContainer.new()
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.set_anchors_preset(Control.PRESET_FULL_RECT)
	content.alignment = BoxContainer.ALIGNMENT_CENTER
	content.add_theme_constant_override("separation", 10)
	button.add_child(content)

	var icon_slot := CenterContainer.new()
	icon_slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon_slot.custom_minimum_size = Vector2(0.0, BUTTON_SIZE.y * 0.5)
	content.add_child(icon_slot)

	var icon := IconDraw.new()
	icon.kind = icon_kind
	icon.cutout_color = BUTTON_BG_COLOR
	icon.icon_size = BUTTON_SIZE.x * 0.4
	icon.custom_minimum_size = Vector2(icon.icon_size, icon.icon_size)
	icon_slot.add_child(icon)

	var label := Label.new()
	label.text = label_text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", LABEL_FONT_SIZE)
	label.add_theme_color_override("font_color", TEXT_COLOR)
	content.add_child(label)

	return button


func _style_button(button: Button) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = BUTTON_BG_COLOR
	normal.set_corner_radius_all(CORNER_RADIUS)
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", _tinted(normal, 0.12))
	button.add_theme_stylebox_override("pressed", _tinted(normal, -0.12))

	var focus: StyleBoxFlat = _tinted(normal, 0.0)
	focus.border_width_left = FOCUS_BORDER_WIDTH
	focus.border_width_right = FOCUS_BORDER_WIDTH
	focus.border_width_top = FOCUS_BORDER_WIDTH
	focus.border_width_bottom = FOCUS_BORDER_WIDTH
	focus.border_color = BUTTON_FOCUS_COLOR
	button.add_theme_stylebox_override("focus", focus)


func _tinted(base: StyleBoxFlat, amount: float) -> StyleBoxFlat:
	var copy: StyleBoxFlat = base.duplicate() as StyleBoxFlat
	copy.bg_color = base.bg_color.lightened(amount) if amount >= 0.0 else base.bg_color.darkened(-amount)
	return copy


# ---------------------------------------------------------------------------
# Options subpanel: music/sfx sliders, voice_mode cycler, camera toggle +
# sensitivity slider — all read/write GameState.settings directly.
# ---------------------------------------------------------------------------

func _build_options_panel(parent: Control) -> void:
	_options_panel = PanelContainer.new()
	_options_panel.name = "OptionsPanel"
	_options_panel.visible = false
	_options_panel.custom_minimum_size = Vector2(OPTIONS_PANEL_WIDTH, 0.0)

	var style := StyleBoxFlat.new()
	style.bg_color = BUTTON_BG_COLOR
	style.set_corner_radius_all(CORNER_RADIUS)
	style.content_margin_left = 28.0
	style.content_margin_right = 28.0
	style.content_margin_top = 24.0
	style.content_margin_bottom = 24.0
	_options_panel.add_theme_stylebox_override("panel", style)
	parent.add_child(_options_panel)

	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", int(ROW_GAP))
	_options_panel.add_child(list)

	_music_slider = _build_slider_row(
		list, IconDraw.Kind.MUSIC, "Music", float(GameState.get_setting("music_volume"))
	)
	_music_slider.value_changed.connect(_on_music_slider_changed)

	_sfx_slider = _build_slider_row(
		list, IconDraw.Kind.SPEAKER, "Sound", float(GameState.get_setting("sfx_volume"))
	)
	_sfx_slider.value_changed.connect(_on_sfx_slider_changed)

	_build_voice_row(list)
	_build_camera_row(list)

	_sensitivity_slider = _build_slider_row(
		list, IconDraw.Kind.CAMERA, "Camera speed", float(GameState.get_setting("camera_sensitivity")) / 2.0
	)
	_sensitivity_slider.value_changed.connect(_on_sensitivity_slider_changed)

	var back_row := HBoxContainer.new()
	back_row.alignment = BoxContainer.ALIGNMENT_CENTER
	list.add_child(back_row)
	_back_button = _make_row_button(IconDraw.Kind.BACK, "Back")
	back_row.add_child(_back_button)


## _build_slider_row — icon + short label + HSlider, all sharing one
## visual row height (Xbox Accessibility Guidelines' "icon + label
## together" rule, §2 of the research). `initial` is 0..1 slider space.
func _build_slider_row(parent: VBoxContainer, icon_kind: IconDraw.Kind, label_text: String, initial: float) -> HSlider:
	var row := HBoxContainer.new()
	row.custom_minimum_size = Vector2(0.0, ROW_HEIGHT)
	row.add_theme_constant_override("separation", 16)
	parent.add_child(row)

	_add_row_icon(row, icon_kind)
	_add_row_label(row, label_text)

	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.05
	slider.value = clampf(initial, 0.0, 1.0)
	slider.custom_minimum_size = Vector2(SLIDER_MIN_WIDTH, 0.0)
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.focus_mode = Control.FOCUS_ALL
	_style_slider(slider)
	row.add_child(slider)
	return slider


func _style_slider(slider: HSlider) -> void:
	var track := StyleBoxFlat.new()
	track.bg_color = Color(0.180392, 0.231373, 0.368627, 0.6)
	track.set_corner_radius_all(8)
	track.content_margin_top = 6.0
	track.content_margin_bottom = 6.0

	var fill := StyleBoxFlat.new()
	fill.bg_color = BUTTON_FOCUS_COLOR
	fill.set_corner_radius_all(8)
	fill.content_margin_top = 6.0
	fill.content_margin_bottom = 6.0

	slider.add_theme_stylebox_override("slider", track)
	slider.add_theme_stylebox_override("grabber_area", fill)
	slider.add_theme_stylebox_override("grabber_area_highlight", fill)

	var focus: StyleBoxFlat = track.duplicate() as StyleBoxFlat
	focus.border_width_left = 3
	focus.border_width_right = 3
	focus.border_width_top = 3
	focus.border_width_bottom = 3
	focus.border_color = BUTTON_FOCUS_COLOR
	slider.add_theme_stylebox_override("focus", focus)


func _add_row_icon(row: HBoxContainer, icon_kind: IconDraw.Kind) -> IconDraw:
	var icon := IconDraw.new()
	icon.kind = icon_kind
	icon.cutout_color = BUTTON_BG_COLOR
	icon.icon_size = ROW_ICON_SIZE
	icon.custom_minimum_size = Vector2(ROW_ICON_SIZE, ROW_ICON_SIZE)
	row.add_child(icon)
	return icon


func _add_row_label(row: HBoxContainer, text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.custom_minimum_size = Vector2(120.0, 0.0)
	label.add_theme_font_size_override("font_size", LABEL_FONT_SIZE)
	label.add_theme_color_override("font_color", TEXT_COLOR)
	row.add_child(label)
	return label


func _make_row_button(icon_kind: IconDraw.Kind, label_text: String) -> Button:
	var button := Button.new()
	button.custom_minimum_size = Vector2(140.0, 56.0)
	button.focus_mode = Control.FOCUS_ALL
	_style_button(button)

	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.set_anchors_preset(Control.PRESET_FULL_RECT)
	row.add_theme_constant_override("separation", 10)
	button.add_child(row)

	var icon := IconDraw.new()
	icon.kind = icon_kind
	icon.cutout_color = BUTTON_BG_COLOR
	icon.icon_size = 28.0
	icon.custom_minimum_size = Vector2(28.0, 28.0)
	row.add_child(icon)

	var label := Label.new()
	label.text = label_text
	label.add_theme_font_size_override("font_size", LABEL_FONT_SIZE)
	label.add_theme_color_override("font_color", TEXT_COLOR)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(label)

	return button


func _build_voice_row(parent: VBoxContainer) -> void:
	var row := HBoxContainer.new()
	row.custom_minimum_size = Vector2(0.0, ROW_HEIGHT)
	row.add_theme_constant_override("separation", 16)
	parent.add_child(row)

	var current_mode: String = _current_voice_mode()
	_voice_icon = _add_row_icon(row, VOICE_MODE_ICON.get(current_mode, IconDraw.Kind.VOICE_MOUTH))
	_add_row_label(row, "Voice")

	_voice_button = Button.new()
	_voice_button.custom_minimum_size = Vector2(SLIDER_MIN_WIDTH, ROW_HEIGHT - 10.0)
	_voice_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_voice_button.focus_mode = Control.FOCUS_ALL
	_voice_button.text = VOICE_MODE_LABEL.get(current_mode, "")
	_style_button(_voice_button)
	_voice_button.pressed.connect(_on_voice_button_pressed)
	row.add_child(_voice_button)


func _build_camera_row(parent: VBoxContainer) -> void:
	var row := HBoxContainer.new()
	row.custom_minimum_size = Vector2(0.0, ROW_HEIGHT)
	row.add_theme_constant_override("separation", 16)
	parent.add_child(row)

	_add_row_icon(row, IconDraw.Kind.CAMERA)
	_add_row_label(row, "Manual look")

	_camera_toggle_button = Button.new()
	_camera_toggle_button.custom_minimum_size = Vector2(SLIDER_MIN_WIDTH, ROW_HEIGHT - 10.0)
	_camera_toggle_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_camera_toggle_button.focus_mode = Control.FOCUS_ALL
	_style_button(_camera_toggle_button)
	_refresh_camera_toggle_text()
	_camera_toggle_button.pressed.connect(_on_camera_toggle_pressed)
	row.add_child(_camera_toggle_button)


func _refresh_camera_toggle_text() -> void:
	var manual: bool = bool(GameState.get_setting("camera_manual"))
	_camera_toggle_button.text = "On (right stick)" if manual else "Off (auto)"


func _current_voice_mode() -> String:
	var mode: String = str(GameState.get_setting("voice_mode"))
	return mode if VOICE_MODE_CYCLE.has(mode) else VOICE_MODE_CYCLE[1]


# ---------------------------------------------------------------------------
# Focus neighbors — controller/keyboard navigation across both panels.
# ---------------------------------------------------------------------------

func _layout_focus_neighbors() -> void:
	_keep_playing_button.focus_neighbor_right = _keep_playing_button.get_path_to(_options_button)
	_options_button.focus_neighbor_left = _options_button.get_path_to(_keep_playing_button)
	_options_button.focus_neighbor_right = _options_button.get_path_to(_photo_button)
	_photo_button.focus_neighbor_left = _photo_button.get_path_to(_options_button)
	_photo_button.focus_neighbor_right = _photo_button.get_path_to(_sleep_button)
	_sleep_button.focus_neighbor_left = _sleep_button.get_path_to(_photo_button)

	var chain: Array[Control] = [
		_music_slider, _sfx_slider, _voice_button, _camera_toggle_button,
		_sensitivity_slider, _back_button,
	]
	for i: int in range(chain.size()):
		if i > 0:
			chain[i].focus_neighbor_top = chain[i].get_path_to(chain[i - 1])
		if i < chain.size() - 1:
			chain[i].focus_neighbor_bottom = chain[i].get_path_to(chain[i + 1])


# ---------------------------------------------------------------------------
# Open / close
# ---------------------------------------------------------------------------

## open — called by GameUI on the "pause" action, or by the ui-VERIFY
## debug seam (Harness.flag("debug_pause")) so a windowed --shots run can
## capture a still of the menu without a real Start-button press.
func open() -> void:
	if visible:
		return
	visible = true
	get_tree().paused = true
	TheMoon.say("paused")
	_main_row.visible = true
	_options_panel.visible = false
	_reset_sleep_hold()
	_keep_playing_button.grab_focus()


## open_to_options — debug-seam convenience for docs/verify (see
## game_ui.gd's --debug_options): open the pause menu already on the
## options subpanel, for a windowed --shots run to capture without
## scripting focus-navigation + a button press.
func open_to_options() -> void:
	open()
	_on_options_pressed()


## open_focus_sleep — debug-seam convenience for docs/verify (see
## game_ui.gd's --debug_pause_sleep): open the pause menu with focus
## already on Sleep, so a harness --script can prove the hold-to-quit
## gesture end-to-end (press-and-hold p1_interact, watch the ring fill,
## confirm the scene changes) — the harness's --script format has no raw
## ui_right to move focus there itself.
func open_focus_sleep() -> void:
	open()
	_sleep_button.grab_focus()


func _on_keep_playing_pressed() -> void:
	TheMoon.say("keep_playing")
	visible = false
	get_tree().paused = false


func _on_options_pressed() -> void:
	AudioManager.play_sfx("ui_select")
	_main_row.visible = false
	_options_panel.visible = true
	_music_slider.grab_focus()


## _on_photo_pressed — this menu's own job stops at emitting the request;
## GameUI (which owns both HUD and the actual PhotoMode instance) does the
## rest, including hiding this menu (see class doc comment above).
func _on_photo_pressed() -> void:
	AudioManager.play_sfx("ui_select")
	photo_mode_requested.emit()


func _on_back_pressed() -> void:
	AudioManager.play_sfx("ui_select")
	_options_panel.visible = false
	_main_row.visible = true
	_options_button.grab_focus()


func _confirm_sleep() -> void:
	_reset_sleep_hold()
	TheMoon.say("goodnight")
	get_tree().paused = false
	visible = false
	get_tree().change_scene_to_file("res://scenes/title.tscn")


# ---------------------------------------------------------------------------
# Options handlers — every one writes straight through to
# GameState.settings, which SaveManager persists automatically.
# ---------------------------------------------------------------------------

func _on_music_slider_changed(value: float) -> void:
	GameState.set_setting("music_volume", value)
	AudioManager.set_music_volume(value)


func _on_sfx_slider_changed(value: float) -> void:
	GameState.set_setting("sfx_volume", value)
	AudioManager.set_sfx_volume(value)
	AudioManager.play_sfx("ui_select") # audible feedback for where the new level lands


func _on_voice_button_pressed() -> void:
	var current: String = _current_voice_mode()
	var index: int = VOICE_MODE_CYCLE.find(current)
	var next_mode: String = VOICE_MODE_CYCLE[(index + 1) % VOICE_MODE_CYCLE.size()]
	GameState.set_setting("voice_mode", next_mode)
	_voice_button.text = VOICE_MODE_LABEL.get(next_mode, "")
	_voice_icon.kind = VOICE_MODE_ICON.get(next_mode, IconDraw.Kind.VOICE_MOUTH)
	_voice_icon.queue_redraw()
	AudioManager.play_sfx("ui_select")


func _on_camera_toggle_pressed() -> void:
	var manual: bool = not bool(GameState.get_setting("camera_manual"))
	GameState.set_setting("camera_manual", manual)
	_refresh_camera_toggle_text()
	AudioManager.play_sfx("ui_select")


## camera_sensitivity is persisted as a 0..2 multiplier (1.0 = default);
## the slider itself is 0..1 space like the volume sliders, so it's
## rescaled both ways at the read/write boundary.
func _on_sensitivity_slider_changed(value: float) -> void:
	GameState.set_setting("camera_sensitivity", value * 2.0)


# ---------------------------------------------------------------------------
# Sleep hold-to-quit — polled every frame rather than driven off a single
# press/release pair, so it works uniformly across mouse (button_down/up),
# keyboard/gamepad ui_accept, and the extra p1/p2 interact+jump paths.
# ---------------------------------------------------------------------------

func _process(delta: float) -> void:
	if not visible or not _main_row.visible:
		_reset_sleep_hold()
		return
	if _sleep_button.has_focus() and _is_confirm_held():
		_sleep_hold_time = minf(_sleep_hold_time + delta, SLEEP_HOLD_SECONDS)
		_sleep_ring.progress = _sleep_hold_time / SLEEP_HOLD_SECONDS
		if _sleep_hold_time >= SLEEP_HOLD_SECONDS:
			_confirm_sleep()
	else:
		_reset_sleep_hold()


func _reset_sleep_hold() -> void:
	_sleep_hold_time = 0.0
	if _sleep_ring != null:
		_sleep_ring.progress = 0.0


func _is_confirm_held() -> bool:
	return (
		_sleep_mouse_held
		or Input.is_action_pressed("ui_accept")
		or Input.is_action_pressed("p1_interact") or Input.is_action_pressed("p2_interact")
		or Input.is_action_pressed("p1_jump") or Input.is_action_pressed("p2_jump")
	)


## Extra activation paths beyond the default ui_accept (which already
## covers "either pad's A button" for free): p1_interact/p2_interact (B/X)
## also confirm a selection, per the build brief. Sleep is deliberately
## excluded — it only confirms through the hold above, never a tap.
func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if _is_extra_activate(event):
		var focused: Control = get_viewport().gui_get_focus_owner()
		if focused is BaseButton and focused != _sleep_button:
			(focused as BaseButton).pressed.emit()
		get_viewport().set_input_as_handled()


func _is_extra_activate(event: InputEvent) -> bool:
	return (
		event.is_action_pressed("p1_interact") or event.is_action_pressed("p2_interact")
		or event.is_action_pressed("p1_jump") or event.is_action_pressed("p2_jump")
	)
