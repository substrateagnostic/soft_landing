extends Control
## Title — the whole menu: title text + "press A" prompt, both spoken by
## the Moon on load (D13). Any jump/interact press, either seat, proceeds
## to main.tscn. No other menu items exist — the design floor forbids
## reading to play.
##
## Title screen v2 (D20 UI/writing pass): a layered night sky (DuskGradient
## + StarField + BigMoon, all sibling Control scripts already wired in
## title.tscn), a heavy-weight title built from individually-bobbing
## FloatingLetter labels riding on top of a shared group-breathing scale
## (so the whole word breathes together AND each letter has its own tiny
## independent float — "keep the breathing title but elevate" per the
## build brief), the existing pulsing "press A" prompt, a settled
## SleepingCat silhouette accent, and (save-slot vignette groundwork,
## intentionally partial — see docs/verify/ui-v2-VERIFY.md) a small
## text-free dream-count summary when a save already exists. Nothing here
## flashes or shakes — every loop is a smooth sine ease. No bundled font
## asset exists for this project, so title/prompt/summary all use
## ThemeDB.fallback_font at a heavy embolden weight (unchanged decision
## from v1).

const BREATHE_PERIOD: float = 5.0
const BREATHE_SCALE: float = 1.05
const PULSE_PERIOD: float = 1.6
const PULSE_MIN_ALPHA: float = 0.5

const TITLE_TEXT: String = "THE BIG NAP"
const LETTER_FONT_SIZE: int = 64
const LETTER_BOB_PERIOD: float = 2.6 # shared by every glyph (B12, C1-S6)

const COLOR_TEXT: Color = Color(0.960784, 0.94902, 0.909804, 1.0) # milk white

const START_CHIME_SFX: String = "ui_select"

@onready var _title_stage: Control = $TitleStage
@onready var _prompt_label: Label = $PromptLabel
@onready var _summary_row: HBoxContainer = $SaveSummary

var _title_row: HBoxContainer = null
var _started: bool = false


func _ready() -> void:
	AudioManager.play_sfx(START_CHIME_SFX)
	TheMoon.say("welcome")
	_build_title_row()
	_start_prompt_pulse()
	_build_save_summary()


func _build_title_row() -> void:
	var center := CenterContainer.new()
	center.name = "TitleCenter"
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_title_stage.add_child(center)

	_title_row = HBoxContainer.new()
	_title_row.name = "TitleRow"
	_title_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_title_row.add_theme_constant_override("separation", 2)
	center.add_child(_title_row)

	var heavy := FontVariation.new()
	heavy.base_font = ThemeDB.fallback_font
	heavy.variation_embolden = 1.4

	for i: int in range(TITLE_TEXT.length()):
		var ch: String = TITLE_TEXT[i]
		var letter := FloatingLetter.new()
		letter.text = ch if ch != " " else " " # keep spaces as real gaps, not collapsed
		# One shared period + a small progressive phase = a gentle wave
		# traveling through the word. Mixed per-letter periods drifted the
		# glyphs into reading as mixed case — "THe BIg NAp" (B12, C1-S6).
		letter.bob_period = LETTER_BOB_PERIOD
		letter.phase = float(i) * 0.35
		letter.add_theme_font_override("font", heavy)
		letter.add_theme_font_size_override("font_size", LETTER_FONT_SIZE)
		letter.add_theme_color_override("font_color", COLOR_TEXT)
		letter.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.35))
		letter.add_theme_constant_override("shadow_offset_x", 0)
		letter.add_theme_constant_override("shadow_offset_y", 4)
		_title_row.add_child(letter)

	_start_group_breathing(center)


## The row breathes as one group (the original v1 effect) while each
## FloatingLetter child ALSO bobs independently (v2 addition) — pivoting
## on the CenterContainer (which re-centers every frame regardless of the
## row's measured size) keeps the group-scale pivot stable even though the
## row's content is a dynamically-built set of labels, not a single node
## with a fixed rect.
func _start_group_breathing(center: CenterContainer) -> void:
	center.pivot_offset = center.size * 0.5
	var tween: Tween = create_tween().set_loops()
	tween.tween_property(center, "scale", Vector2.ONE * BREATHE_SCALE, BREATHE_PERIOD * 0.5) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(center, "scale", Vector2.ONE, BREATHE_PERIOD * 0.5) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _start_prompt_pulse() -> void:
	var tween: Tween = create_tween().set_loops()
	tween.tween_property(_prompt_label, "modulate:a", PULSE_MIN_ALPHA, PULSE_PERIOD * 0.5) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(_prompt_label, "modulate:a", 1.0, PULSE_PERIOD * 0.5) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


## Save-slot vignette groundwork (deliverable 6, intentionally partial —
## see docs/verify/ui-v2-VERIFY.md "UNVERIFIED / skipped"): a tiny
## text-free summary (one gold dot + a numeral, no words) when a save
## already has dreams in it. A real continue-vs-new-nap CHOICE needs a
## save-wipe path, which is a destructive action nothing in this pass
## builds a confirm-gesture for yet — honest-skip rather than ship an
## unconfirmed "delete your save" button.
func _build_save_summary() -> void:
	var total: int = GameState.total_returned()
	if total <= 0:
		_summary_row.visible = false
		return
	_summary_row.visible = true

	var dot := HudPip.new() # reuse the HUD's own "returned" gold-dot glyph
	_summary_row.add_child(dot)
	dot.paint(HudPip.PipState.RETURNED)

	var numeral := Label.new()
	numeral.text = str(total)
	numeral.add_theme_font_size_override("font_size", 22)
	numeral.add_theme_color_override("font_color", COLOR_TEXT)
	_summary_row.add_child(numeral)


func _unhandled_input(event: InputEvent) -> void:
	if _started:
		return
	if (
		event.is_action_pressed("p1_jump") or event.is_action_pressed("p2_jump")
		or event.is_action_pressed("p1_interact") or event.is_action_pressed("p2_interact")
	):
		_started = true
		AudioManager.play_sfx(START_CHIME_SFX)
		get_tree().change_scene_to_file("res://scenes/main.tscn")
