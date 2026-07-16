class_name PauseMenu
extends CanvasLayer
## PauseMenu — Start-button pause (project.godot "pause" action: both
## pads' Start + Esc). Dusk-blue dim overlay + two big rounded, icon-only
## buttons (no words on-screen — design floor: no reading required to
## play; the icons are self-explanatory and TheMoon speaks each choice out
## loud, D13). "Keep Playing" resumes instantly. "Sleep" quits to the
## title screen — progress is already autosaved on every
## dream_returned/fort change (D14), so no confirm dialog is needed.
## process_mode WHEN_PAUSED keeps the buttons live while
## get_tree().paused freezes gameplay.

const OVERLAY_COLOR: Color = Color(0.180392, 0.231373, 0.368627, 0.82) # dusk blue, dim overlay
const BUTTON_BG_COLOR: Color = Color(0.243137, 0.301961, 0.427451, 1.0) # lighter dusk blue
const BUTTON_FOCUS_COLOR: Color = Color(0.94902, 0.784314, 0.474510, 1.0) # honey glow
const BUTTON_SIZE: Vector2 = Vector2(220.0, 220.0)
const BUTTON_GAP: float = 48.0
const CORNER_RADIUS: int = 36
const FOCUS_BORDER_WIDTH: int = 6

var _keep_playing_button: Button = null
var _sleep_button: Button = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	layer = 10 # above the HUD (layer 5)
	visible = false
	_build_ui()
	_keep_playing_button.pressed.connect(_on_keep_playing_pressed)
	_sleep_button.pressed.connect(_on_sleep_pressed)


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

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", int(BUTTON_GAP))
	center.add_child(row)

	_keep_playing_button = _make_button(IconDraw.Kind.PLAY)
	_sleep_button = _make_button(IconDraw.Kind.MOON)
	row.add_child(_keep_playing_button)
	row.add_child(_sleep_button)

	_keep_playing_button.focus_neighbor_right = _keep_playing_button.get_path_to(_sleep_button)
	_sleep_button.focus_neighbor_left = _sleep_button.get_path_to(_keep_playing_button)


func _make_button(icon_kind: IconDraw.Kind) -> Button:
	var button := Button.new()
	button.custom_minimum_size = BUTTON_SIZE
	button.focus_mode = Control.FOCUS_ALL
	button.mouse_filter = Control.MOUSE_FILTER_STOP

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

	var icon := IconDraw.new()
	icon.kind = icon_kind
	icon.cutout_color = BUTTON_BG_COLOR
	icon.icon_size = BUTTON_SIZE.x * 0.4
	icon.anchor_left = 0.5
	icon.anchor_top = 0.5
	icon.anchor_right = 0.5
	icon.anchor_bottom = 0.5
	var half: float = icon.icon_size * 0.5
	icon.offset_left = -half
	icon.offset_top = -half
	icon.offset_right = half
	icon.offset_bottom = half
	button.add_child(icon)

	return button


func _tinted(base: StyleBoxFlat, amount: float) -> StyleBoxFlat:
	var copy: StyleBoxFlat = base.duplicate() as StyleBoxFlat
	copy.bg_color = base.bg_color.lightened(amount) if amount >= 0.0 else base.bg_color.darkened(-amount)
	return copy


## open — called by GameUI on the "pause" action, or by the ui-VERIFY debug
## seam (Harness.flag("debug_pause")) so a windowed --shots run can capture
## a still of the menu without a real Start-button press (the harness has
## no scripted "pause" action, by design — it never edits InputRouter's
## action vocabulary for a menu that isn't gameplay).
func open() -> void:
	if visible:
		return
	visible = true
	get_tree().paused = true
	TheMoon.say("paused")
	_keep_playing_button.grab_focus()


func _on_keep_playing_pressed() -> void:
	TheMoon.say("keep_playing")
	visible = false
	get_tree().paused = false


func _on_sleep_pressed() -> void:
	TheMoon.say("goodnight")
	get_tree().paused = false
	visible = false
	get_tree().change_scene_to_file("res://scenes/title.tscn")


## Extra activation paths beyond the default ui_accept (which already
## covers "either pad's A button" for free — it's a device-agnostic
## built-in action): p1_interact/p2_interact (B/X) also confirm a
## selection, per the build brief. Godot's input propagation runs
## GUI-focus handling (where ui_accept gets consumed by the focused
## Button) BEFORE _unhandled_input, so a jump-button press that ui_accept
## already consumed never reaches here — no double-activation.
func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if _is_extra_activate(event):
		var focused: Control = get_viewport().gui_get_focus_owner()
		if focused is BaseButton:
			(focused as BaseButton).pressed.emit()
		get_viewport().set_input_as_handled()


func _is_extra_activate(event: InputEvent) -> bool:
	return (
		event.is_action_pressed("p1_interact") or event.is_action_pressed("p2_interact")
		or event.is_action_pressed("p1_jump") or event.is_action_pressed("p2_jump")
	)
