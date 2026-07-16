extends Control
## Title — the whole menu: title text + "press A" prompt, both spoken by
## the Moon on load (D13). Any jump/interact press, either seat, proceeds
## to main.tscn. No other menu items exist — the design floor forbids
## reading to play.
##
## Polish pass: dusk gradient sky (DuskGradient, a sibling node), a
## heavy-weight title font via FontVariation.variation_embolden (no
## bundled font asset exists for this project — "the Godot default font is
## fine at heavy weight," per the build brief) with a soft drop shadow, a
## slow 5 s breathing scale on the title, three drifting gold orbs
## (DriftingOrb, sibling nodes), and a gently pulsing "press A" prompt.
## Nothing here flashes or shakes — every loop is a smooth sine ease.

const BREATHE_PERIOD: float = 5.0
const BREATHE_SCALE: float = 1.05
const PULSE_PERIOD: float = 1.6
const PULSE_MIN_ALPHA: float = 0.5

@onready var _title_label: Label = $TitleLabel
@onready var _prompt_label: Label = $PromptLabel


func _ready() -> void:
	TheMoon.say("welcome")
	_style_title_font()
	_start_breathing()
	_start_prompt_pulse()


func _style_title_font() -> void:
	var heavy := FontVariation.new()
	heavy.base_font = ThemeDB.fallback_font
	heavy.variation_embolden = 1.4
	_title_label.add_theme_font_override("font", heavy)
	_title_label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.35))
	_title_label.add_theme_constant_override("shadow_offset_x", 0)
	_title_label.add_theme_constant_override("shadow_offset_y", 4)


func _start_breathing() -> void:
	_title_label.pivot_offset = _title_label.size * 0.5
	var tween: Tween = create_tween().set_loops()
	tween.tween_property(_title_label, "scale", Vector2.ONE * BREATHE_SCALE, BREATHE_PERIOD * 0.5) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(_title_label, "scale", Vector2.ONE, BREATHE_PERIOD * 0.5) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _start_prompt_pulse() -> void:
	var tween: Tween = create_tween().set_loops()
	tween.tween_property(_prompt_label, "modulate:a", PULSE_MIN_ALPHA, PULSE_PERIOD * 0.5) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(_prompt_label, "modulate:a", 1.0, PULSE_PERIOD * 0.5) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _unhandled_input(event: InputEvent) -> void:
	if (
		event.is_action_pressed("p1_jump") or event.is_action_pressed("p2_jump")
		or event.is_action_pressed("p1_interact") or event.is_action_pressed("p2_interact")
	):
		get_tree().change_scene_to_file("res://scenes/main.tscn")
