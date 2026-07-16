class_name StarField
extends Control
## StarField — the title sky's star sprinkle (title screen v2, D20 UI
## pass). Fixed random positions (seeded once, so the arrangement doesn't
## rearrange itself frame to frame — only opacity twinkles), painted as
## tiny soft-white dots confined to the sky's upper band. Deliberately
## calm: slow, staggered, sine-eased twinkle, never a strobe.

const STAR_COUNT: int = 46
const COLOR: Color = Color(0.960784, 0.94902, 0.909804, 1.0) # milk white
const MIN_RADIUS: float = 1.0
const MAX_RADIUS: float = 2.4
const TWINKLE_PERIOD_MIN: float = 2.5
const TWINKLE_PERIOD_MAX: float = 5.5
const MIN_ALPHA: float = 0.25
const MAX_ALPHA: float = 0.9
const SKY_BAND: float = 0.7 # stars only live in the upper 70% of the rect
const SEED: int = 20260716 # fixed so re-layout doesn't reshuffle the sky

var _stars: Array[Dictionary] = []
var _time: float = 0.0


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(_regenerate)
	_regenerate()


func _regenerate() -> void:
	if size.x <= 0.0 or size.y <= 0.0:
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	_stars.clear()
	for _i in range(STAR_COUNT):
		_stars.append({
			"pos": Vector2(rng.randf() * size.x, rng.randf() * size.y * SKY_BAND),
			"radius": rng.randf_range(MIN_RADIUS, MAX_RADIUS),
			"period": rng.randf_range(TWINKLE_PERIOD_MIN, TWINKLE_PERIOD_MAX),
			"phase": rng.randf() * TAU,
		})
	queue_redraw()


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


func _draw() -> void:
	for star: Dictionary in _stars:
		var t: float = _time * TAU / float(star["period"]) + float(star["phase"])
		var alpha: float = lerpf(MIN_ALPHA, MAX_ALPHA, 0.5 * (1.0 + sin(t)))
		draw_circle(star["pos"], star["radius"], Color(COLOR.r, COLOR.g, COLOR.b, alpha))
