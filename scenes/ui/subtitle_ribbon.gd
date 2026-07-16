class_name SubtitleRibbon
extends CanvasLayer
## SubtitleRibbon — bottom-center caption for TheMoon's lines (D20 UI/
## writing pass). A soft rounded panel, dream-cream text on translucent
## dusk-blue, fades in/out with whatever's speaking (moonsong syllables
## and/or TTS, depending on settings.voice_mode). TheMoon instantiates and
## owns this directly as ITS OWN child (`SubtitleRibbon.new()`, no .tscn
## needed — same "script-only, no scene" pattern as IconDraw/DriftingOrb/
## DuskGradient) rather than mounting through GameUI, so a caption can
## appear over ANY scene — title, pause, or gameplay — without any of
## those scenes needing to know captions exist.
##
## Font note: no bundled font asset exists in this project yet (matches
## scenes/title.gd's own note in ART_BIBLE.md's absence of a UI font);
## this uses ThemeDB.fallback_font at a large size with a soft embolden,
## the same technique the title screen already uses for its heading.

const MARGIN_BOTTOM: float = 70.0
const MARGIN_SIDE: float = 220.0
const PANEL_MIN_HEIGHT: float = 88.0
const PANEL_PADDING_H: float = 28.0
const PANEL_PADDING_V: float = 16.0
const FONT_SIZE: int = 30
const FADE_IN_DURATION: float = 0.25
const FADE_OUT_DURATION: float = 0.4
const MIN_HOLD_SECONDS: float = 0.6

const COLOR_PANEL_BG: Color = Color(0.180392, 0.231373, 0.368627, 0.78) # dusk blue, translucent
const COLOR_TEXT: Color = Color(0.960784, 0.94902, 0.909804, 1.0) # dream-cream / milk white

var _panel: PanelContainer = null
var _label: Label = null
var _tween: Tween = null


func _ready() -> void:
	layer = 6 # above HUD (5), below PauseMenu (10) — never blocks the pause UI
	_build_ui()


func _build_ui() -> void:
	_panel = PanelContainer.new()
	_panel.name = "Panel"
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.modulate.a = 0.0
	_panel.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_panel.offset_left = MARGIN_SIDE
	_panel.offset_right = -MARGIN_SIDE
	_panel.offset_bottom = -MARGIN_BOTTOM
	_panel.offset_top = -(MARGIN_BOTTOM + PANEL_MIN_HEIGHT)
	_panel.custom_minimum_size = Vector2(0.0, PANEL_MIN_HEIGHT)

	var style := StyleBoxFlat.new()
	style.bg_color = COLOR_PANEL_BG
	style.set_corner_radius_all(20)
	style.content_margin_left = PANEL_PADDING_H
	style.content_margin_right = PANEL_PADDING_H
	style.content_margin_top = PANEL_PADDING_V
	style.content_margin_bottom = PANEL_PADDING_V
	_panel.add_theme_stylebox_override("panel", style)
	add_child(_panel)

	_label = Label.new()
	_label.name = "Text"
	_label.text = ""
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	var font := FontVariation.new()
	font.base_font = ThemeDB.fallback_font
	font.variation_embolden = 0.6
	_label.add_theme_font_override("font", font)
	_label.add_theme_font_size_override("font_size", FONT_SIZE)
	_label.add_theme_color_override("font_color", COLOR_TEXT)
	_panel.add_child(_label)


## show_line — fade in, hold for `duration` seconds, fade out. A call
## arriving before the previous line finished simply restarts the cycle
## with the new text (defensive; TheMoon's job queue already serializes
## calls, so overlap shouldn't normally happen).
func show_line(text: String, duration: float) -> void:
	_label.text = text
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_panel.modulate.a = 0.0
	_tween = create_tween()
	_tween.tween_property(_panel, "modulate:a", 1.0, FADE_IN_DURATION).set_trans(Tween.TRANS_SINE)
	_tween.tween_interval(maxf(duration, MIN_HOLD_SECONDS))
	_tween.tween_property(_panel, "modulate:a", 0.0, FADE_OUT_DURATION).set_trans(Tween.TRANS_SINE)
